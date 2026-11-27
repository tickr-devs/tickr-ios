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
  /// The /status reads that failed in a row since the last answer (`ReadFailures`).
  private(set) var reads = ReadFailures()
  /// Why /status can't be read, once that is more than one passing failure; nil after an answer.
  var readFailure: ReadFailure? { reads.shown }
  /// When /status last answered, on this phone's clock; nil until it answers at this address.
  private(set) var lastReadAt: Date?
  /// The last failure's technical text (Settings, preflight); screens say `connection` instead.
  var fetchError: String? { readFailure?.detail }
  /// The bot's configuration (GET /settings): risk limits and session. Read once per address.
  private(set) var settings: SettingsV1?
  /// Why the settings could not be read, if they could not.
  private(set) var settingsError: String?
  /// The API start (`StatusResponseV1.apiStartedAt`) the settings were read after: a new one reads them again.
  @ObservationIgnored private var settingsReadFor: WireTime?
  /// The bot's last broker read (GET /account), read while Settings is on screen.
  private(set) var account: AccountResponseV1?
  /// Why the broker read could not be fetched, if it could not.
  private(set) var accountError: String?
  /// What runs on its own on the Mac (GET /jobs), read while Settings is on screen.
  private(set) var jobs: JobsV1?
  /// Why the jobs could not be read, if they could not.
  private(set) var jobsError: String?
  /// The System card (GET /system), read with the jobs while Settings is on screen.
  private(set) var system: SystemV1?
  /// Why the System card could not be read, if it could not.
  private(set) var systemError: String?
  /// The bot day whose jobs were read for the headline's countdown (today's session); nil until
  /// they are, so a failed read is tried again at the next status.
  @ObservationIgnored private var jobsReadDay: WireDate?
  /// A start of the bot job is on its way to the Mac.
  private(set) var botStarting = false
  /// The bot's configuration file as on disk (GET /config), read when its page opens.
  private(set) var config: ConfigV1?
  /// Why it could not be read, if it could not.
  private(set) var configError: String?
  /// The day every tab shows: nil = today, live; else a recorded past day. One day for the whole
  /// app, as on the Mac: Home's arrows, Activity's calendar and the Chart's day menu all set it,
  /// and every tab that shows a day's data reads this one (owner report 2026-11-17: Home showed
  /// yesterday's P&L over nothing while every other tab stayed on today).
  var selectedDay: WireDate? {
    didSet {
      guard selectedDay != oldValue else { return }
      dayChanged()
    }
  }
  /// The shown day's flow (GET /flow): stage counts and stops, read while Home is on screen.
  private(set) var flow: FlowV1?
  /// Why the flow could not be read, if it could not.
  private(set) var flowError: String?
  /// Today's skipped signals (GET /skipped), read with the flow: where a refused symbol stopped.
  private(set) var skipped: SkippedV1?
  /// The shown day's watched symbols and latest entry size (GET /watching), read with the flow;
  /// nil until read, so the Risk room never says "no entry" for a day it has not read.
  private(set) var watching: WatchingV1?
  /// Today's symbols by the stage they got to (GET /symbols), read with the flow.
  private(set) var symbols: SymbolsV1?
  /// Why the symbols could not be read, if they could not.
  private(set) var symbolsError: String?
  /// Today's fast movers (GET /movers), read with the flow.
  private(set) var movers: MoversV1?
  /// Why the fast movers could not be read, if they could not.
  private(set) var moversError: String?
  /// The day the last /flow answer (or failure) was for; until it is today the flow is pending.
  private(set) var flowAnsweredDay: WireDate?
  private(set) var sending = false
  /// The command being sent, while it is: its button shows the spinner (`.inFlight`).
  private(set) var inFlight: OperatorCommand?
  /// The close-and-stop the bot reports, followed across reads for its steps' times and its
  /// refusal (`StopWatch`, the bot-control sheet's steps).
  private(set) var stopWatch = StopWatch()
  /// The working entries followed across reads, for "Cancelled at broker" (`EntryCancelWatch`).
  private(set) var entryWatch = EntryCancelWatch()
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
  /// The read of a newly shown day; another day cancels it.
  @ObservationIgnored private var dayRead: Task<Void, Never>?
  @ObservationIgnored private var quotesTask: Task<Void, Never>?
  /// The bot's live quotes (GET /quotes), read every `settings.quotes_poll_seconds` while the app
  /// runs: every live price the app shows comes from here.
  @ObservationIgnored @Injected(\.liveQuotes) var quotes
  /// The current moment (Container.now; tests pin it).
  @ObservationIgnored @Injected(\.now) private var now
  /// Commands this phone queued whose outcome has not appeared in recent_commands yet.
  @ObservationIgnored private var awaited: [String: CommandKind] = [:]
  /// The idempotency key of each command whose send lost its answer (backlog A3), kept until the
  /// API's receipt says whether it was queued and used again if the owner presses it again. In
  /// the app's one store (`CommandKeyStore`): on iPad the Mac screens' model sends from the
  /// same keys, so a press after a lost send is never a second send under a new key.
  @ObservationIgnored @Injected(\.commandKeys) private var keyStore
  private var keys: CommandKeys {
    get { keyStore.keys }
    set { keyStore.keys = newValue }
  }
  /// Counts connections: every answer is applied only while the connection it was asked on is
  /// still this one (backlog A4), so a late answer from the address before never shows as this one's.
  @ObservationIgnored private var link = 0
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
  /// The day every tab shows: the picked past day, else today.
  var shownDay: WireDate { selectedDay ?? today }
  /// Today is shown, live from the status.
  var isLive: Bool { selectedDay == nil }
  var isConfigured: Bool { connection.url != nil }

  var headline: Headline {
    guard isConfigured else {
      return Headline(text: String(localized: L10n.Connect.notConnected), severity: .attention)
    }
    return Headline.make(response: response, readFailed: readFailure != nil)
  }

  /// What every screen says about the link to the bot: last known data under a banner, or an
  /// empty state when nothing was read (TickrKit `ConnectionState`).
  var connectionState: ConnectionState {
    ConnectionState.make(configured: isConfigured, response: response, failure: readFailure, lastSuccess: lastReadAt)
  }

  /// Seconds between two reads of /status: the server's poll_seconds once it answered.
  var pollSeconds: Double {
    let asked = response.map { NSDecimalNumber(decimal: $0.pollSeconds.value).doubleValue } ?? Self.initialPollSeconds
    return max(asked, Self.minimumPollSeconds)
  }

  /// The words of the connection banner: the reads go on every `pollSeconds`.
  var connectionMessage: ConnectionMessage? { connectionState.message(retrySeconds: Int(pollSeconds.rounded())) }

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
        try? await Task.sleep(for: .seconds(self.pollSeconds))
      }
    }
    quotesTask = Task { [weak self] in
      while !Task.isCancelled {
        guard let self else { return }
        await self.refreshQuotes()
        // Until the settings say how often (an older API has no /quotes), wait as the status does.
        try? await Task.sleep(for: .seconds(LiveQuotes.pollSeconds(self.settings) ?? self.pollSeconds))
      }
    }
  }

  func stop() {
    pollTask?.cancel()
    pollTask = nil
    quotesTask?.cancel()
    quotesTask = nil
  }

  /// Reads the bot's live quotes once, when its API has them; nothing without an address.
  func refreshQuotes() async {
    guard let url = connection.url, LiveQuotes.pollSeconds(settings) != nil else { return }
    await quotes.refresh(Container.shared.apiClient(connection.endpoint(for: url)))
  }

  /// The live price of `symbol` now, from the bot's quotes; nil when there is none (`LivePrice`).
  func livePrice(_ symbol: String) -> LivePrice? {
    quotes.price(symbol, now: botNow, settings: settings)
  }

  private func restart() {
    stop()
    link += 1
    // Keys and queued commands of the address before mean nothing at this one.
    if let url = connection.url { keyStore.use(url) }
    awaited = [:]
    entryWatch.forget()
    response = nil
    reads = ReadFailures()
    lastReadAt = nil
    botClockOffset = 0
    settings = nil
    settingsError = nil
    quotes.clear()
    account = nil
    accountError = nil
    jobs = nil
    jobsError = nil
    jobsReadDay = nil
    system = nil
    systemError = nil
    config = nil
    configError = nil
    flow = nil
    flowError = nil
    skipped = nil
    watching = nil
    symbols = nil
    symbolsError = nil
    movers = nil
    moversError = nil
    flowAnsweredDay = nil
    selectedDay = nil
    start()
  }

  /// Another day is shown: what was read of the day before goes at once (the screens show the
  /// new day's loading state, never the old day's figures under the new day), and its flow,
  /// skipped signals, symbols and fast movers are read now.
  private func dayChanged() {
    flow = nil
    flowError = nil
    skipped = nil
    watching = nil
    symbols = nil
    symbolsError = nil
    movers = nil
    moversError = nil
    dayRead?.cancel()
    dayRead = Task { await refreshFlow() }
  }

  func refresh() async {
    await readStatus()
  }

  /// Reads /status once. True only when this very read answered, on the connection still shown,
  /// with a current status: what a command needs right before it is sent (backlog A4). A failed
  /// read is false even while `ReadFailures` still hides it as a passing blip.
  @discardableResult
  private func readStatus() async -> Bool {
    guard let url = connection.url else {
      response = nil
      reads = ReadFailures()
      return false
    }
    let asked = link
    let fresh: StatusResponseV1
    do {
      fresh = try await Container.shared.apiClient(connection.endpoint(for: url)).status()
      guard asked == link else { return false }
      response = fresh
      stopWatch.read(fresh.status)
      entryWatch.read(fresh.status, now: now(), commandMaxAge: keepSeconds)
      reads.answered()
      lastReadAt = now()
      followBotClock(servedAt: fresh.servedAt.date)
      resolveAwaited(fresh)
    } catch {
      if asked == link { reads.failed(error, hadAnswer: lastReadAt != nil) }
      return false
    }
    await settleLost(url)
    if response?.needsSettings(settings, readFor: settingsReadFor) ?? (settings == nil) { await refreshSettings(url) }
    // Today's session and the next one for the headline's countdown: read once per bot day, and
    // again once the next session has opened (it then names the one after).
    if jobsReadDay != today || jobs?.nextSession.map({ $0.regularOpen.date <= botNow }) == true {
      jobsReadDay = today
      await refreshJobs()
      if jobs == nil { jobsReadDay = nil }
    }
    return asked == link && !fresh.stale && fresh.status != nil
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

  /// Reads the System card; a failed read clears it, so an old state never reads as current.
  func refreshSystem() async {
    guard let url = connection.url else { return }
    do {
      let read = try await Container.shared.apiClient(connection.endpoint(for: url)).system()
      guard connection.url == url else { return }
      system = read
      systemError = nil
    } catch is CancellationError {
      return
    } catch {
      if connection.url == url {
        system = nil
        systemError = Self.describe(error) ?? systemError
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

  /// Reads the jobs and the System card at the status poll rate until cancelled; used while
  /// Settings is open.
  func followJobs() async {
    while !Task.isCancelled {
      await refreshJobs()
      await refreshSystem()
      let seconds = response.map { NSDecimalNumber(decimal: $0.pollSeconds.value).doubleValue }
        ?? Self.initialPollSeconds
      try? await Task.sleep(for: .seconds(max(seconds, Self.minimumPollSeconds)))
    }
  }

  /// Reads the shown day's flow, skipped signals, watched symbols, symbols and fast movers, all at
  /// once, and shows them together once every read has answered (owner 2026-11-22: what cannot
  /// show at once shows its loader, then all of it at once, never cards popping in one by one);
  /// the API keeps a past day's answers (api/settled.py), so they normally answer within
  /// milliseconds. The answers are dropped when the address or the shown day changed meanwhile,
  /// and a cancelled read changes nothing.
  func refreshFlow() async {
    guard let url = connection.url else { return }
    let day = shownDay
    let client = Container.shared.apiClient(connection.endpoint(for: url))
    async let flow = Self.outcome { try await client.flow(day: day) }
    async let skipped = Self.outcome { try await client.skipped(day: day) }
    async let watching = Self.outcome { try await client.watching(day: day) }
    async let symbols = Self.outcome { try await client.symbols(day: day) }
    async let movers = Self.outcome { try await client.movers(day: day) }
    let read = await (flow, skipped, watching, symbols, movers)
    guard stillShown(url, day), !Task.isCancelled else { return }
    showFlow(read.0, day: day)
    showSkipped(read.1)
    showWatching(read.2)
    showSymbols(read.3)
    showMovers(read.4)
  }

  /// One read's document, or why it failed; read off the main actor, shown on it.
  nonisolated static func outcome<Document: Sendable>(
    _ read: @Sendable () async throws -> Document
  ) async -> Result<Document, any Error> {
    do { return .success(try await read()) } catch { return .failure(error) }
  }

  /// Whether an answer read for `day` from `url` is still the one to show.
  private func stillShown(_ url: URL, _ day: WireDate) -> Bool { connection.url == url && day == shownDay }

  private func showFlow(_ read: Result<FlowV1, any Error>, day: WireDate) {
    switch read {
    case .success(let document):
      flow = document
      flowError = nil
    case .failure(let error):
      // Old counts prove nothing about the day now.
      flow = nil
      flowError = Self.describe(error) ?? flowError
    }
    flowAnsweredDay = day
  }

  /// The refusals only place refused symbols on the board; without them they stay where they
  /// stopped, so a failed read is not an error of its own.
  private func showSkipped(_ read: Result<SkippedV1, any Error>) {
    skipped = try? read.get()
  }

  /// The latest entry size of the Risk room; a failed read leaves it unknown (nil), never empty.
  private func showWatching(_ read: Result<WatchingV1, any Error>) {
    watching = try? read.get()
  }

  /// The shown day's symbols (the funnel's Quote and Bars, the Symbols screen).
  private func showSymbols(_ read: Result<SymbolsV1, any Error>) {
    switch read {
    case .success(let document):
      symbols = document
      symbolsError = nil
    case .failure(let error):
      symbols = nil
      symbolsError = Self.describe(error) ?? symbolsError
    }
  }

  /// The shown day's fast movers (the Fast movers card), likewise.
  private func showMovers(_ read: Result<MoversV1, any Error>) {
    switch read {
    case .success(let document):
      movers = document
      moversError = nil
    case .failure(let error):
      movers = nil
      moversError = Self.describe(error) ?? moversError
    }
  }

  /// Today's price line of `symbol` for the Symbols detail, against `previousClose`
  /// (`SymbolDayLine`: the bot's stored bars, a chart read only without them); nil unconnected.
  func symbolDayLine(_ symbol: String, previousClose: Decimal?) async -> SymbolDayLine? {
    guard let url = connection.url else { return nil }
    let client = Container.shared.apiClient(connection.endpoint(for: url))
    return await SymbolDayLine.read(symbol, day: symbols?.day ?? shownDay, today: today,
      previousClose: previousClose, client: client)
  }

  /// The first /flow answer for the shown day has not come yet (a new address, a new day).
  var flowPending: Bool { flowAnsweredDay != shownDay }

  /// Reads the shown day's flow every `flowSeconds` until cancelled; used while Home is on screen.
  func followFlow() async {
    while !Task.isCancelled {
      await refreshFlow()
      try? await Task.sleep(for: .seconds(Self.flowSeconds))
    }
  }

  /// Reads the bot's configuration; the answer is dropped when the address changed meanwhile.
  private func refreshSettings(_ url: URL) async {
    let startedAt = response?.apiStartedAt
    do {
      let read = try await Container.shared.apiClient(connection.endpoint(for: url)).settings()
      guard connection.url == url else { return }
      settings = read
      settingsReadFor = startedAt
      settingsError = nil
    } catch {
      if connection.url == url { settingsError = Self.describe(error) ?? settingsError }
    }
  }

  /// Queues a command once. Refused unless the status is fresh when tapped; `confirmOwner`
  /// (Face ID or passcode) runs first when given. Right before the send the status is read again
  /// from the bot (not the last poll), and the command is refused unless that very read answered,
  /// from the same address, with a current status (backlog A4): a bot that went stale during the
  /// dialog or Face ID, or a read that failed, never gets the command. The send carries one
  /// idempotency key per decision; a lost answer keeps it, says the outcome is unknown and is
  /// settled by the API's receipt, never by a send under a new key (backlog A3).
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
    // One send of a command at a time across both iPad layouts' models (`CommandKeyStore`).
    guard keyStore.begin(command) else {
      notice = Notice(L10n.Notice.busy(title), tone: .failure)
      return
    }
    let asked = link
    sending = true
    inFlight = command
    // A new command: an earlier close-and-stop's refusal is no longer the news.
    stopWatch.forget()
    defer {
      sending = false
      inFlight = nil
      keyStore.end(command)
    }
    if let confirmOwner {
      switch await confirmOwner() {
      case .confirmed: break
      case .declined: return
      case .unavailable(let cause):
        notice = Notice(L10n.Notice.notConfirmed(title, cause), tone: .failure)
        return
      }
    }
    guard asked == link, await readStatus(), asked == link, connection.url == url else {
      notice = Notice(L10n.Notice.wentStale(title), tone: .failure)
      return
    }
    let key = keys.key(for: command, now: now(), keepSeconds: keepSeconds)
    let sentAt = now()
    let outcome = await CommandSend.send(command, key: key,
      client: Container.shared.apiClient(connection.endpoint(for: url)))
    guard asked == link else { return }
    switch outcome {
    case .queued(let accepted):
      keys.settled(command)
      queued(accepted, title: title)
    case .refused(let cause):
      keys.settled(command)
      notice = Notice(L10n.Notice.failed(title, cause), tone: .failure)
    case .unknown(let cause):
      keys.lost(command, key: key, at: sentAt)
      notice = Notice(L10n.Notice.outcomeUnknown(title, cause), tone: .failure)
    }
    await refresh()
  }

  /// A queued command: awaited in recent_commands, and said so.
  private func queued(_ accepted: CommandAcceptedV1, title: String) {
    awaited[accepted.command.commandId] = accepted.command.kind
    entryWatch.queued(accepted.command)
    if let warning = accepted.warning {
      notice = Notice(L10n.Notice.queuedWarning(title, warning), tone: .failure)
    } else {
      notice = Notice(L10n.Notice.queued(title), tone: .info)
    }
  }

  /// How long a lost send's key is kept: the bot's command age limit, nil while it is not known.
  private var keepSeconds: Decimal? { settings?.commandMaxAgeSeconds?.value }

  /// Reads the receipt of every send whose answer was lost, after a good status read at `url`:
  /// queued goes on as any queued command, not queued is said so and its key dropped; a receipt
  /// that cannot be read leaves it unknown until the next read. A key past the bot's command age,
  /// or one whose receipt the API cannot serve, is dropped with a notice to check the status
  /// before sending again. Not while a send is under way, which settles its own command.
  private func settleLost(_ url: URL) async {
    guard !sending, keyStore.sending.isEmpty else { return }
    for command in keys.expire(now: now(), keepSeconds: keepSeconds) {
      notice = Notice(L10n.Notice.outcomeNotKnown(Board.commandTitle(command.kind)), tone: .failure)
    }
    let asked = link
    for (command, kept) in keys.unknown {
      let outcome = await CommandSend.receipt(key: kept.key,
        client: Container.shared.apiClient(connection.endpoint(for: url)))
      guard asked == link, keys.unknown[command] == kept else { return }
      let title = Board.commandTitle(command.kind)
      switch outcome {
      case .queued(let accepted):
        keys.settled(command)
        queued(accepted, title: title)
      case .notQueued:
        keys.settled(command)
        notice = Notice(L10n.Notice.notQueued(title), tone: .failure)
      case .unserved:
        keys.settled(command)
        notice = Notice(L10n.Notice.outcomeNotKnown(title), tone: .failure)
      case .unknown:
        continue
      }
    }
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
    stopWatch.forget()
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
        let cause = record.causeText ?? String(localized: L10n.Notice.noCause)
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
