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
  private(set) var sending = false
  var notice: Notice?
  var selectedTab: AppTab = .home
  var selectedSymbol: String?

  @ObservationIgnored private var pollTask: Task<Void, Never>?
  /// Commands this phone queued whose outcome has not appeared in recent_commands yet.
  @ObservationIgnored private var awaited: [String: CommandKind] = [:]
  /// Used only until the first answer gives the server's poll_seconds.
  @ObservationIgnored private let initialPollSeconds: Double = 3

  var status: StatusV1? { response?.status }
  var isConfigured: Bool { connection.url != nil }

  var headline: Headline {
    guard isConfigured else {
      return Headline(text: "Not connected. Add your Mac's address in Settings.", severity: .attention)
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
          ?? self.initialPollSeconds
        try? await Task.sleep(for: .seconds(max(seconds, 1)))
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
    start()
  }

  func refresh() async {
    guard let url = connection.url else {
      response = nil
      fetchError = nil
      return
    }
    do {
      let fresh = try await Container.shared.apiClient(APIClient.Endpoint(baseURL: url)).status()
      response = fresh
      fetchError = nil
      resolveAwaited(fresh)
    } catch {
      fetchError = Self.describe(error)
    }
  }

  /// Queues a command once. Refused unless the status is fresh when tapped; `confirmOwner`
  /// (Face ID or passcode) runs first when given. Right before the send the status is read again
  /// from the bot (not the last poll), and the command is refused unless that read is current, so
  /// a bot that went stale during the dialog or Face ID never gets the command.
  func send(_ command: OperatorCommand, confirmOwner: (() async -> Biometrics.Outcome)? = nil) async {
    let title = Board.commandTitle(command.kind)
    guard !sending else {
      notice = Notice(text: "\(title) not sent: another command is being sent.", tone: .failure)
      return
    }
    guard canCommand, let url = connection.url else {
      notice = Notice(text: "\(title) not sent: the bot's status is not current.", tone: .failure)
      return
    }
    sending = true
    defer { sending = false }
    if let confirmOwner {
      switch await confirmOwner() {
      case .confirmed: break
      case .declined: return
      case .unavailable(let cause):
        notice = Notice(text: "\(title) not sent: owner not confirmed (\(cause)).", tone: .failure)
        return
      }
    }
    await refresh()
    guard isFresh, connection.url == url else {
      notice = Notice(text: "\(title) not sent: the bot's status went out of date.", tone: .failure)
      return
    }
    do {
      let accepted = try await Container.shared.apiClient(APIClient.Endpoint(baseURL: url)).send(command)
      awaited[accepted.command.commandId] = command.kind
      if let warning = accepted.warning {
        notice = Notice(text: "\(title) queued. \(warning)", tone: .failure)
      } else {
        notice = Notice(text: "\(title) queued for the bot.", tone: .info)
      }
    } catch {
      notice = Notice(text: "\(title) not sent: \(Self.describe(error))", tone: .failure)
    }
    await refresh()
  }

  private func resolveAwaited(_ fresh: StatusResponseV1) {
    for record in fresh.status?.recentCommands ?? [] {
      guard awaited.removeValue(forKey: record.commandId) != nil else { continue }
      let title = Board.commandTitle(record.kind)
      switch record.outcome {
      case .done: notice = Notice(text: "\(title): done.", tone: .success)
      case .refused: notice = Notice(text: "\(title) refused: \(record.cause ?? "no cause given")", tone: .failure)
      }
    }
  }

  static func describe(_ error: Error) -> String {
    (error as? LocalizedError)?.errorDescription ?? String(describing: error)
  }
}
