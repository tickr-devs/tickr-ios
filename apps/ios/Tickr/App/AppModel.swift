import Foundation
import Observation
import TickrKit

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
  /// What runs on its own on the Mac (GET /jobs), read while Settings is on screen.
  private(set) var jobs: JobsV1?
  /// Why the jobs could not be read, if they could not.
  private(set) var jobsError: String?
  /// A start of the bot job is on its way to the Mac.
  private(set) var botStarting = false
  /// The bot's configuration file as on disk (GET /config), read when its page opens.
  private(set) var config: ConfigV1?
  /// Why it could not be read, if it could not.
  private(set) var configError: String?
  /// Today's live flow (GET /flow): stage counts and stops, read while Home is on screen.
  private(set) var flow: FlowV1?
  /// Why the flow could not be read, if it could not.
  private(set) var flowError: String?
  /// Today's skipped signals (GET /skipped), read with the flow: where a refused symbol stopped.
  private(set) var skipped: SkippedV1?
  /// The day the last /flow answer (or failure) was for; until it is today the flow is pending.
  private(set) var flowAnsweredDay: WireDate?
  private(set) var sending = false
  var notice: Notice?
  var selectedTab: AppTab = .home
  /// Centre of Home's bar mark on screen (global coordinates), where the opening animation lands.
  @ObservationIgnored var homeMarkCentre: CGPoint?
  var selectedSymbol: String?
  /// A pairing link opened from outside (AirDrop), waiting for the owner to confirm.
  var pendingPairing: Pairing?

  /// How far the bot's clock is ahead of this phone's, from the last status's `served_at`. The
  /// bot's clock decides what "today" is: the phone's clock can drift, and `tickr demo` plays a
  /// past day on a clock of its own.
  private(set) var botClockOffset: TimeInterval = 0

  @ObservationIgnored private var pollTask: Task<Void, Never>?
  /// The current moment (Container.now; tests pin it).
  @ObservationIgnored @Injected(\.now) private var now
  /// Commands this phone queued whose outcome has not appeared in recent_commands yet.
  @ObservationIgnored private var awaited: [String: CommandKind] = [:]
  /// Seconds between reads until the first answer gives the server's poll_seconds.
  static let initialPollSeconds = 3.0
  /// Shortest wait between two reads, whatever the server asks for.
  static let minimumPollSeconds = 1.0
  /// Seconds between two reads of the live flow (screener passes and decisions change it).
  static let flowSeconds = 15.0
  /// A change of the bot's clock offset smaller than this (network delay) is ignored, in seconds.
  static let clockToleranceSeconds: TimeInterval = 2

  var status: StatusV1? { response?.status }
  /// This moment on the bot's clock.
  var botNow: Date { botTime(now()) }
  /// A moment of this phone's clock (a TimelineView's tick) on the bot's clock.
  func botTime(_ local: Date) -> Date { local.addingTimeInterval(botClockOffset) }
  /// Whether `marks` are current on the bot's clock, within the status stale limit of its
  /// settings; unknown settings prove nothing, so the marks are then not current.
  func isCurrent(_ marks: PositionMarks) -> Bool {
    guard let settings else { return false }
    let limit = NSDecimalNumber(decimal: settings.statusStaleSeconds.value).doubleValue
    return marks.isFresh(now: botNow, staleSeconds: limit)
  }
  /// The bot's trading day: today in New York on the bot's clock.
  var today: WireDate { WireDate(newYorkDateOf: botNow) }
  var isConfigured: Bool { connection.url != nil }

  var headline: Headline {
    guard isConfigured else {
      return Headline(text: String(localized: L10n.Connect.notConnected), severity: .attention)
    }
    return Headline.make(response: response, fetchError: fetchError)
  }

  /// The last read succeeded and the bot's status is current.
  var isFresh: Bool { status != nil && response?.stale == false && fetchError == nil }

  /// The status is fresh and written today on the bot's clock: the app shows the live day.
  var showsLiveStatus: Bool { Self.showsLiveDay(status, fresh: isFresh, today: today) }

  /// Whether `status`, read `fresh`, is of `today`.
  nonisolated static func showsLiveDay(_ status: StatusV1?, fresh: Bool, today: WireDate) -> Bool {
    guard let status else { return false }
    return fresh && WireDate(newYorkDateOf: status.writtenAt.date) == today
  }

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
    botClockOffset = 0
    settings = nil
    settingsError = nil
    account = nil
    accountError = nil
    jobs = nil
    jobsError = nil
    config = nil
    configError = nil
    flow = nil
    flowError = nil
    skipped = nil
    flowAnsweredDay = nil
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
      followBotClock(servedAt: fresh.servedAt.date)
      resolveAwaited(fresh)
    } catch {
      fetchError = Self.describe(error) ?? fetchError
      return
    }
    if settings == nil { await refreshSettings(url) }
  }

  /// Takes the bot's clock from a status served at `servedAt`. Network delay moves the offset by
  /// milliseconds on every poll; only a larger change is taken, so views don't redraw for it.
  private func followBotClock(servedAt: Date) {
    let offset = servedAt.timeIntervalSince(now())
    if abs(offset - botClockOffset) > Self.clockToleranceSeconds { botClockOffset = offset }
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
        accountError = Self.describe(error) ?? accountError
      }
    }
  }

  /// Reads the bot's last broker read at the status poll rate until cancelled; used while a screen
  /// that shows it is open.
  func followAccount() async {
    while !Task.isCancelled {
      await refreshAccount()
      let seconds = response.map { NSDecimalNumber(decimal: $0.pollSeconds.value).doubleValue }
        ?? Self.initialPollSeconds
      try? await Task.sleep(for: .seconds(max(seconds, Self.minimumPollSeconds)))
    }
  }

  func refreshJobs() async {
    guard let url = connection.url else { return }
    do {
      let read = try await Container.shared.apiClient(connection.endpoint(for: url)).jobs()
      guard connection.url == url else { return }
      jobs = read
      jobsError = nil
    } catch is CancellationError {
      return
    } catch {
      if connection.url == url {
        jobs = nil
        jobsError = Self.describe(error) ?? jobsError
      }
    }
  }

  func refreshConfig() async {
    guard let url = connection.url else { return }
    do {
      let read = try await Container.shared.apiClient(connection.endpoint(for: url)).config()
      guard connection.url == url else { return }
      config = read
      configError = nil
    } catch {
      // A cancelled read keeps what was shown.
      if connection.url == url, let described = Self.describe(error) {
        config = nil
        configError = described
      }
    }
  }

  /// Reads the jobs at the status poll rate until cancelled; used while Settings is open.
  func followJobs() async {
    while !Task.isCancelled {
      await refreshJobs()
      let seconds = response.map { NSDecimalNumber(decimal: $0.pollSeconds.value).doubleValue }
        ?? Self.initialPollSeconds
      try? await Task.sleep(for: .seconds(max(seconds, Self.minimumPollSeconds)))
    }
  }

  /// Reads today's live flow; the answer is dropped when the address or the day changed meanwhile.
  func refreshFlow() async {
    guard let url = connection.url else { return }
    let day = today
    let client = Container.shared.apiClient(connection.endpoint(for: url))
    do {
      let read = try await client.flow(day: day)
      guard connection.url == url, day == today else { return }
      flow = read
      flowError = nil
      flowAnsweredDay = day
    } catch is CancellationError {
      return
    } catch {
      // Old counts prove nothing about the day now.
      guard connection.url == url, day == today else { return }
      flow = nil
      flowError = Self.describe(error) ?? flowError
      flowAnsweredDay = day
    }
    // The refusals only place refused symbols on the board; without them they stay where they
    // stopped, so a failed read is not an error of its own.
    let refusals = try? await client.skipped(day: day)
    guard connection.url == url, day == today else { return }
    skipped = refusals
  }

  /// The first /flow answer for today has not come yet (a new address, a new day).
  var flowPending: Bool { flowAnsweredDay != today }

  /// Reads today's live flow every `flowSeconds` until cancelled; used while Home is on screen.
  func followFlow() async {
    while !Task.isCancelled {
      await refreshFlow()
      try? await Task.sleep(for: .seconds(Self.flowSeconds))
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
      if connection.url == url { settingsError = Self.describe(error) ?? settingsError }
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
      // One key per decision: should this very request ever reach the bot twice, it queues once.
      let accepted = try await Container.shared.apiClient(connection.endpoint(for: url))
        .send(command, idempotencyKey: UUID().uuidString)
      awaited[accepted.command.commandId] = command.kind
      if let warning = accepted.warning {
        notice = Notice(L10n.Notice.queuedWarning(title, warning), tone: .failure)
      } else {
        notice = Notice(L10n.Notice.queued(title), tone: .info)
      }
    } catch {
      notice = Notice(L10n.Notice.failed(title, ErrorText.text(error)), tone: .failure)
    }
    await refresh()
  }

  /// Start makes sense when the Mac answers and no current status says the bot is alive (a stale
  /// or missing status proves nothing; the API checks again and launchd never restarts a running job).
  var canStartBot: Bool {
    guard isConfigured, fetchError == nil, response != nil, !botStarting, !sending else { return false }
    guard let status, response?.stale == false else { return true }
    return status.botState == .stopped
  }

  /// Asks the Mac to start the bot job through launchd (POST /commands/start-bot), once, after
  /// the owner's Face ID: Start clears an operator stop and lets the bot trade again.
  func startBot(confirmOwner: () async -> Biometrics.Outcome) async {
    let title = String(localized: L10n.Control.startBot)
    guard canStartBot, let url = connection.url else {
      notice = Notice(L10n.Notice.notCurrent(title), tone: .failure)
      return
    }
    botStarting = true
    defer { botStarting = false }
    switch await confirmOwner() {
    case .confirmed: break
    case .declined: return
    case .unavailable(let cause):
      notice = Notice(L10n.Notice.notConfirmed(title, cause), tone: .failure)
      return
    }
    guard connection.url == url else { return }
    do {
      let answer = try await Container.shared.apiClient(connection.endpoint(for: url)).startBot()
      notice = Notice(answer.stopMarkerCleared ? L10n.Notice.startRequestedCleared : L10n.Notice.startRequested,
        tone: .info)
    } catch {
      notice = Notice(L10n.Notice.failed(title, ErrorText.text(error)), tone: .failure)
    }
    await refresh()
  }

  /// Uses a pairing link: redeems its one-time code at the Mac's HTTPS address for the bearer
  /// token, then that address and token replace the current connection. Refused, with the earlier
  /// connection kept, when the Mac refuses the code (used, expired, or another pairing started) or
  /// the Keychain does not take the token.
  func pair(_ pairing: Pairing) async {
    let redeemed: PairedV1
    do {
      redeemed = try await Container.shared.apiClient(APIClient.Endpoint(baseURL: pairing.url))
        .redeemPairing(code: pairing.code)
    } catch {
      notice = Notice(L10n.Pair.notRedeemed(ErrorText.text(error)), tone: .failure)
      return
    }
    guard Container.shared.keychain().saveToken(redeemed.token) else {
      notice = Notice(L10n.Pair.notSaved, tone: .failure)
      return
    }
    connection = Connection(paired: pairing.url, token: redeemed.token)
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

  /// Nil for a cancelled read: callers keep the error they had (`describe(error) ?? old`), so a read
  /// cancelled by `stop()` never clears a real failure and makes stale data look current.
  static func describe(_ error: Error) -> String? {
    ErrorText.describe(error)
  }
}
