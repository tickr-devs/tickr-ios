import ApertureKit
import Foundation
import Observation

enum AppTab: Hashable { case home, positions, chart, activity, lab }

/// A short message shown over the screen after a command (queued, done, refused, not sent).
struct Notice: Identifiable, Equatable {
  enum Tone: Equatable { case info, success, failure }

  let id = UUID()
  let text: String
  let tone: Tone

  init(_ text: LocalizedStringResource, tone: Tone) {
    self.text = String(localized: text)
    self.tone = tone
  }
}

/// Polls GET /status while the app is on screen and queues operator commands. The phone shows what
/// the bot wrote; it never decides anything and never talks to the broker.
@MainActor
@Observable
final class AppModel {
  var connection = Connection.load() {
    didSet {
      guard connection != oldValue else { return }
      connection.save()
      restart()
    }
  }
  private(set) var response: StatusResponseV1?
  private(set) var fetchError: String?
  /// The bot's configuration (GET /settings): risk limits and session. Read once per address.
  private(set) var settings: SettingsV1?
  /// Why the settings could not be read, if they could not.
  private(set) var settingsError: String?
  /// The bot's last broker read (GET /account), read while Settings is on screen.
  private(set) var account: AccountResponseV1?
  /// Why the broker read could not be fetched, if it could not.
  private(set) var accountError: String?
  private(set) var sending = false
  var notice: Notice?
  var selectedTab: AppTab = .home
  var selectedSymbol: String?
  /// A pairing link opened from outside (AirDrop), waiting for the owner to confirm.
  var pendingPairing: Pairing?

  @ObservationIgnored private var pollTask: Task<Void, Never>?
  /// Commands this phone queued whose outcome has not appeared in recent_commands yet.
  @ObservationIgnored private var awaited: [String: CommandKind] = [:]
  /// Seconds between reads until the first answer gives the server's poll_seconds.
  static let initialPollSeconds = 3.0
  /// Shortest wait between two reads, whatever the server asks for.
  static let minimumPollSeconds = 1.0

  var status: StatusV1? { response?.status }
  var isConfigured: Bool { connection.url != nil }

  var headline: Headline {
    guard isConfigured else {
      return Headline(text: String(localized: L10n.Connect.notConnected), severity: .attention)
    }
    return Headline.make(response: response, fetchError: fetchError)
  }

  /// The last read succeeded and the bot's status is current.
  var isFresh: Bool { status != nil && response?.stale == false && fetchError == nil }

  /// Commands are offered, and sent, only while the status is fresh and no command is in flight.
  var canCommand: Bool { isFresh && !sending }

  func start() {
    guard pollTask == nil else { return }
    pollTask = Task { [weak self] in
      while !Task.isCancelled {
        guard let self else { return }
        await self.refresh()
        let seconds = self.response.map { NSDecimalNumber(decimal: $0.pollSeconds.value).doubleValue }
          ?? Self.initialPollSeconds
        try? await Task.sleep(for: .seconds(max(seconds, Self.minimumPollSeconds)))
      }
    }
  }

  func stop() {
    pollTask?.cancel()
    pollTask = nil
  }

  private func restart() {
    stop()
    response = nil
    fetchError = nil
    settings = nil
    settingsError = nil
    account = nil
    accountError = nil
    start()
  }

  func refresh() async {
    guard let url = connection.url else {
      response = nil
      fetchError = nil
      return
    }
    do {
      let fresh = try await Container.shared.apiClient(connection.endpoint(for: url)).status()
      response = fresh
      fetchError = nil
      resolveAwaited(fresh)
    } catch {
      fetchError = Self.describe(error)
      return
    }
    if settings == nil { await refreshSettings(url) }
  }

  /// Pull to refresh: the status, and the settings read again, since the owner may have changed
  /// config/bot.toml and restarted the bot.
  func refreshAll() async {
    await refresh()
    guard let url = connection.url, fetchError == nil else { return }
    await refreshSettings(url)
  }

  /// Reads the bot's last broker read; the answer is dropped when the address changed meanwhile.
  func refreshAccount() async {
    guard let url = connection.url else { return }
    do {
      let read = try await Container.shared.apiClient(connection.endpoint(for: url)).account()
      guard connection.url == url else { return }
      account = read
      accountError = nil
    } catch is CancellationError {
      return
    } catch {
      // An old snapshot proves nothing about the broker now.
      if connection.url == url {
        account = nil
        accountError = Self.describe(error)
      }
    }
  }

  /// Reads the bot's configuration; the answer is dropped when the address changed meanwhile.
  private func refreshSettings(_ url: URL) async {
    do {
      let read = try await Container.shared.apiClient(connection.endpoint(for: url)).settings()
      guard connection.url == url else { return }
      settings = read
      settingsError = nil
    } catch {
      if connection.url == url { settingsError = Self.describe(error) }
    }
  }

  /// Queues a command once. Refused unless the status is fresh when tapped; `confirmOwner`
  /// (Face ID or passcode) runs first when given. Right before the send the status is read again
  /// from the bot (not the last poll), and the command is refused unless that read is current, so
  /// a bot that went stale during the dialog or Face ID never gets the command.
  func send(_ command: OperatorCommand, confirmOwner: (() async -> Biometrics.Outcome)? = nil) async {
    let title = Board.commandTitle(command.kind)
    guard !sending else {
      notice = Notice(L10n.Notice.busy(title), tone: .failure)
      return
    }
    guard canCommand, let url = connection.url else {
      notice = Notice(L10n.Notice.notCurrent(title), tone: .failure)
      return
    }
    sending = true
    defer { sending = false }
    if let confirmOwner {
      switch await confirmOwner() {
      case .confirmed: break
      case .declined: return
      case .unavailable(let cause):
        notice = Notice(L10n.Notice.notConfirmed(title, cause), tone: .failure)
        return
      }
    }
    await refresh()
    guard isFresh, connection.url == url else {
      notice = Notice(L10n.Notice.wentStale(title), tone: .failure)
      return
    }
    do {
      let accepted = try await Container.shared.apiClient(connection.endpoint(for: url)).send(command)
      awaited[accepted.command.commandId] = command.kind
      if let warning = accepted.warning {
        notice = Notice(L10n.Notice.queuedWarning(title, warning), tone: .failure)
      } else {
        notice = Notice(L10n.Notice.queued(title), tone: .info)
      }
    } catch {
      notice = Notice(L10n.Notice.failed(title, Self.describe(error)), tone: .failure)
    }
    await refresh()
  }

  /// Uses a pairing link: the Mac's HTTPS address and its token replace the current connection.
  /// Refused, with the earlier connection kept, when the Keychain does not take the token.
  func pair(_ pairing: Pairing) {
    guard Container.shared.keychain().saveToken(pairing.token) else {
      notice = Notice(L10n.Pair.notSaved, tone: .failure)
      return
    }
    connection = Connection(pairing)
    notice = Notice(L10n.Pair.paired(Connection.displayHost(pairing.url) ?? String(localized: L10n.Pair.thisMac)),
      tone: .success)
  }

  private func resolveAwaited(_ fresh: StatusResponseV1) {
    for record in fresh.status?.recentCommands ?? [] {
      guard awaited.removeValue(forKey: record.commandId) != nil else { continue }
      let title = Board.commandTitle(record.kind)
      switch record.outcome {
      case .done: notice = Notice(L10n.Notice.done(title), tone: .success)
      case .refused:
        let cause = record.cause ?? String(localized: L10n.Notice.noCause)
        notice = Notice(L10n.Notice.refused(title, cause), tone: .failure)
      }
    }
  }

  static func describe(_ error: Error) -> String {
    (error as? LocalizedError)?.errorDescription ?? String(describing: error)
  }
}
