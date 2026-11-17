import Foundation
import Observation
import TickrDesign
import TickrKit

/// Refresh pacing of the app. The status poll follows the server's `poll_seconds`; the rest are
/// app-side choices, kept together here.
enum Pace {
  /// Status poll before the first answer says the server's poll_seconds.
  static let initialPollSeconds: Double = 3
  /// Day list and today's day document (trades change at most a few times a day).
  static let historySeconds: Double = 30
  /// Bars of the open positions (one new M1 bar a minute).
  static let barsSeconds: Double = 15
  /// Candles of a range beyond one day (GET /chart): the bot keeps them a while, and the
  /// shortest candle there is five minutes long.
  static let chartSeconds: Double = 60
  /// The day's flow (screener chips, stage counts, stops, reconciliation) and the symbols the
  /// strategy is watching closely; both change with every decision.
  static let flowSeconds: Double = 5
  /// The broker account read the bot keeps (GET /account); the API serves the bot's last read.
  static let accountSeconds: Double = 15
  /// The Lab's replay (GET /lab/replay) while the Lab is open: idle or done, and while it runs.
  static let labReplaySeconds: Double = 30
  static let labReplayRunningSeconds: Double = 3
  /// How long a command toast stays on screen.
  static let toastSeconds: Double = 6
}

/// What the API answered to Start.
public enum BotStartOutcome: Equatable, Sendable {
  /// launchd took the start; `stopCleared` says an earlier Stop was removed first.
  case accepted(stopCleared: Bool)
  /// Not started, with the API's cause.
  case refused(String)
}

/// A command the operator sent, followed until the bot reports its outcome.
public struct SentCommand: Identifiable, Equatable, Sendable {
  public let id: String
  public let kind: CommandKind
  public let title: String
  public var outcome: CommandOutcome?
  public var cause: String?
  public var warning: String?
}

/// One open position as the app shows it, one row per position in the bot's status.
/// A position's own facts that its OPEN tag pulses for (`PositionRow.event`).
public struct PositionEvent: Hashable, Sendable {
  let quantity: DecimalString
  let stop: StopState
  let stopPrice: DecimalString?
}

public struct PositionRow: Identifiable, Equatable, Sendable {
  public let position: Position
  /// Close of the latest captured M1 bar, with its start time; nil until bars arrive.
  public let lastBarClose: Decimal?
  public let lastBarAt: Date?
  /// The entry price, then the closes since the entry, for the small chart: it starts at the fill,
  /// so the first bar after the entry already draws a line.
  public let closes: [Decimal]
  /// Close of the newest captured bar however old it is; shown as history when it is not fresh.
  public var latestClose: Decimal?
  /// The live bid of the bot's quotes (`LivePrice`); nil without one, and then the price is the
  /// fresh bar's close.
  public var live: LivePrice?

  /// The position's current price: the live bid, else the close of a fresh captured bar.
  public var price: Decimal? { live?.bid ?? lastBarClose }
  /// The small chart's line: the closes, ending at the live bid when there is one.
  public var line: [Decimal] { closes + (live.map { [$0.bid] } ?? []) }

  public var id: String { position.symbol }
  public var entry: Decimal { position.entryPrice.value }
  public var stop: Decimal? { position.stop.price?.value }
  public var quantity: Decimal { position.quantity.value }

  public var unrealized: Decimal? { price.map { ($0 - entry) * quantity } }
  /// Result at the newest captured bar, fresh or not.
  public var latestUnrealized: Decimal? { latestClose.map { ($0 - entry) * quantity } }
  /// The newest bar is too old to be the current price: figures are shown greyed, as of its time.
  public var isStale: Bool { price == nil && latestClose != nil }
  /// What the bot did to the position, as its OPEN tag's dot marks it: a fill (the quantity), a
  /// stop placed, verified or moved. A change is one pulse; a newer price is not an event.
  public var event: PositionEvent {
    PositionEvent(quantity: position.quantity, stop: position.stop.state, stopPrice: position.stop.price)
  }

  public var resultR: Decimal? {
    guard let last = price else { return nil }
    return Risk.multiple(entry: entry, stop: stop, price: last)
  }
  /// R at the newest captured bar, fresh or not.
  public var latestResultR: Decimal? {
    guard let last = latestClose else { return nil }
    return Risk.multiple(entry: entry, stop: stop, price: last)
  }
}

/// Open positions the bot is not watching, and why.
public struct Unattended: Equatable, Sendable {
  public enum Reason: Equatable, Sendable {
    /// The bot reported itself stopped.
    case stopped
    /// The bot's status went stale: it may have crashed.
    case silent
  }

  public let reason: Reason
  public let count: Int
}

/// Everything the windows and the menu bar show. Polls the local API; never talks to the broker.
@MainActor
@Observable
public final class AppModel {
  // Connection.
  /// The bot's own API address (Settings › General). The demo day never replaces it: switched
  /// off, the app is back on this very address.
  public private(set) var address: URL
  /// The "Demo day" switch (Settings › General): the app shows the demo day it carries (TickrKit
  /// `DemoDay`, played from its recording, never the network), and no other day.
  public private(set) var demoDay: Bool
  /// The address the app talks to: `address`, or the demo day's (`DemoDay.address`).
  public var baseURL: URL { DemoDay.address(address, demo: demoDay) }
  @ObservationIgnored private var client: APIClient
  /// The current moment (Container.now; tests pin it).
  @ObservationIgnored @Injected(\.now) private var now
  /// The bot's live quotes (GET /quotes), read every `settings.quotes_poll_seconds`: every live
  /// price the app shows comes from here.
  @ObservationIgnored @Injected(\.liveQuotes) public var quotes
  /// How far the bot's clock is ahead of this Mac's, from the last status's `served_at`. The
  /// bot's clock decides what "today" is and how old its reads are: the Mac's clock can drift,
  /// and `tickr demo` plays a past day on a clock of its own.
  public private(set) var botClockOffset: TimeInterval = 0

  // Live state.
  public private(set) var response: StatusResponseV1?
  /// Why the last read of /status failed; nil after an answer.
  public private(set) var readFailure: ReadFailure?
  /// When /status last answered, on this Mac's clock; nil until it answers at this address.
  public private(set) var lastReadAt: Date?
  /// The last failure's technical text (Settings); screens say `connectionState` instead.
  public var fetchError: String? { readFailure?.detail }
  public private(set) var settings: SettingsV1?
  public private(set) var settingsError: String?
  /// The broker's view of the account at the bot's last read; nil until read.
  public private(set) var account: AccountResponseV1?
  public private(set) var accountError: String?
  /// The Lab's simulated replay of the active strategy (GET /lab/replay), read while the Lab is open.
  public private(set) var labReplay: LabReplayV1?
  /// Why it could not be read, if it could not.
  public private(set) var labReplayError: String?
  /// Why the last start was refused (409): a reason to wait, not a failure.
  public private(set) var labReplayRefusal: String?
  /// The replay as read when the refusal came, as state and run, and when it came: a later read
  /// that differs means the replay moved on, and past `Pace.labReplaySeconds` the reason may no
  /// longer hold (the session closed), so either clears it.
  private var labReplayRefusedAt: (state: LabReplayState?, runId: String?, at: Date)?
  /// A start is on its way to the API.
  public private(set) var labReplayStarting = false
  /// What runs on its own on the Mac (GET /jobs), read while Settings is open.
  public private(set) var jobs: JobsV1?
  /// Why the jobs could not be read, if they could not.
  public private(set) var jobsError: String?
  /// The bot day whose jobs were read for the headline's countdown (today's session); nil until
  /// they are, so a failed read is tried again at the next status.
  private var jobsReadDay: WireDate?
  /// The bot's configuration file as on disk (GET /config), read while Settings is open.
  public private(set) var config: ConfigV1?
  /// Why it could not be read, if it could not.
  public private(set) var configError: String?
  /// A start of the bot job is on its way to the API.
  public private(set) var botStarting = false
  /// The answer to the last Start, until the next one.
  public private(set) var botStart: BotStartOutcome?

  // Navigation (the sidebar selection lives here so any card can jump to a section).
  var section: AppSection = .overview {
    // The Symbols screen belongs to the Overview: another section closes it.
    didSet { if section != .overview { symbolsTab = nil } }
  }
  /// The Symbols screen's tab while it is open over the Overview (a funnel stage or "Show all"
  /// of the fast movers opened it); nil shows the Overview itself.
  var symbolsTab: SymbolsTab?
  /// Whether this launch's opening animation (BrandOpening) has played: once per launch, not on
  /// reopening the window.
  var openingPlayed = false
  /// Whether the opening's mark has left for the header: the screen shows under it from then on,
  /// so Overview's cards rise as it flies, as the design times them.
  var openingFlying = false
  /// Centre of Overview's header mark on screen (global coordinates), where the opening lands.
  /// Observed, so the opening follows the mark while the header settles; only the opening reads it.
  var overviewMarkCentre: CGPoint?

  // History.
  public private(set) var days: [DaySummary] = []
  public private(set) var historyError: String?
  /// nil = today (live). Otherwise a recorded day from `days`. With the demo day on, always nil:
  /// the demo day is the demo API's today, and no other day can be picked.
  public var selectedDay: WireDate? {
    didSet {
      if selectedDay != DemoDay.day(selectedDay, demo: demoDay) {
        selectedDay = nil
        return
      }
      if oldValue != selectedDay { beginDayLoad() }
      withdrawIfCommandsOff()
    }
  }
  /// The picked past day's trades (GET /days/<date>); nil while it is read, after a failed read
  /// and while today is shown. Never another day's document: it is cleared the moment another
  /// day is picked.
  public private(set) var dayDocument: DayV1?
  /// Why the picked past day's trades could not be read, if they could not (its own cause, not
  /// the day list's `historyError`).
  public private(set) var dayError: String?
  /// The read of the picked day that is under way; a newer pick cancels it.
  @ObservationIgnored private var dayLoad: Task<Void, Never>?
  public private(set) var todayDocument: DayV1?
  /// Observers with their decisions on the shown day; nil until read.
  public private(set) var observers: ObserversV1?
  public private(set) var observersError: String?
  /// The active strategy's ENTERs on the shown day that did not become a position; nil until read.
  public private(set) var skipped: SkippedV1?
  public private(set) var skippedError: String?
  /// Gross performance in R over the `performanceDays` days that end on the shown day.
  public private(set) var performance: PerformanceV1?
  public private(set) var performanceError: String?
  /// The shown day's flow and watched symbols (GET /flow, GET /watching).
  public private(set) var flow: FlowV1?
  public private(set) var flowError: String?
  public private(set) var watching: WatchingV1?
  public private(set) var watchingError: String?
  /// The shown day's symbols by the stage they got to, and its fast movers (GET /symbols,
  /// GET /movers): the funnel's counts, the Symbols screen and the Fast movers card.
  public private(set) var symbols: SymbolsV1?
  public private(set) var symbolsError: String?
  public private(set) var movers: MoversV1?
  public private(set) var moversError: String?

  // Positions with their latest bars, from where the Chart reads them too (`DayBars`).
  private var barsBySymbol: [String: DayBars] = [:]
  /// The open positions (symbols, on `barsDay`) the last bars read was for. A status that lists
  /// others has their bars read at once (`refreshStatus`), not at the next bars poll.
  private var barsReadFor: [String] = []
  private var barsDay: WireDate?

  // Commands.
  public private(set) var sending = false
  /// The command being sent, while it is: its button shows the spinner (`.inFlight`).
  public private(set) var inFlight: OperatorCommand?
  public private(set) var sent: [SentCommand] = []
  public private(set) var toast: SentCommand?
  /// The bot command waiting for the operator's yes, and where it was asked (`BotControls`).
  /// Held here, not in the view that asked: SwiftUI drops a view's own state whenever it rebuilds
  /// the view (Overview's cards change columns at a width breakpoint), and the question went with it.
  private(set) var confirming: PendingConfirmation?

  private var tasks: [Task<Void, Never>] = []

  public init(baseURL: URL, demoDay: Bool = false) {
    self.address = baseURL
    self.demoDay = demoDay
    self.client = Container.shared.apiClient(APIClient.Endpoint(baseURL: DemoDay.address(baseURL, demo: demoDay)))
  }

  // MARK: derived

  public var status: StatusV1? { response?.status }
  public var headline: Headline { Headline.make(response: response, readFailed: readFailure != nil) }
  /// The facts beside the live headline (mockup v108): the gate of the status, and the countdown
  /// to the regular close or the next open from /jobs, on the bot's clock.
  public var headlineFacts: HeadlineBanner.Facts {
    let session = jobs?.session
    let next = jobs?.nextSession
    let offset = botClockOffset
    return HeadlineBanner.Facts(gate: EntryGate.make(status, headline: headline)) { local in
      SessionCountdown.make(session: session, next: next, now: local.addingTimeInterval(offset))
    }
  }
  /// What every section says about the link to the bot: last known data under a banner, or a
  /// notice when nothing was read (TickrKit `ConnectionState`).
  public var connectionState: ConnectionState {
    ConnectionState.make(configured: true, response: response, failure: readFailure, lastSuccess: lastReadAt)
  }
  /// Seconds between two reads of /status: the server's poll_seconds once it answered, at least
  /// one second.
  public var pollSeconds: Double {
    max(response.map { NSDecimalNumber(decimal: $0.pollSeconds.value).doubleValue } ?? Pace.initialPollSeconds, 1)
  }
  /// The words of the connection banner: the reads go on every `pollSeconds`.
  public var connectionMessage: ConnectionMessage? {
    connectionState.message(retrySeconds: Int(pollSeconds.rounded()))
  }
  /// This moment on the bot's clock.
  public var botNow: Date { botTime(now()) }
  /// A moment of this Mac's clock (a TimelineView's tick) on the bot's clock.
  public func botTime(_ local: Date) -> Date { local.addingTimeInterval(botClockOffset) }
  /// The bot's trading day: today in New York on the bot's clock.
  public var today: WireDate { WireDate(newYorkDateOf: botNow) }
  public var isLive: Bool { selectedDay == nil || selectedDay == today }
  public var shownDay: WireDate { selectedDay ?? today }

  /// The live day, with a status the app can trust (read without error and not stale).
  public var isCurrent: Bool { isLive && status != nil && response?.stale == false && fetchError == nil }

  /// Today's trading as the Trades calendar's today tile marks it: a change (a trade closed, a
  /// position opened or closed) is one pulse of the tile; nil without a status.
  public var todayEvent: [Int]? {
    guard let status else { return nil }
    return [status.tradesToday.count, status.positions.count]
  }

  /// Commands make sense only for the live day with a status the app can trust.
  public var commandsEnabled: Bool { isCurrent && !sending }

  public var positions: [PositionRow] {
    guard isLive, let status else { return [] }
    return status.positions.map { position in
      let since = position.openedAt.date.addingTimeInterval(-Self.barSeconds)
      let read = barsBySymbol[position.symbol]?.bars ?? []
      let bars = read.filter { $0.start.date >= since }
      let last = read.last
      let fresh = last.map { barIsFresh(start: $0.start.date, now: botNow) } ?? false
      return PositionRow(position: position, lastBarClose: fresh ? last?.close.value : nil, lastBarAt: last?.start.date,
        closes: [position.entryPrice.value] + bars.map(\.close.value), latestClose: last?.close.value,
        live: livePrice(position.symbol))
    }
  }

  /// Open positions with no running bot behind them: the bot reported itself stopped (stop-bot
  /// from any device, a graceful shutdown), or its status went stale (a crash leaves the last
  /// status saying "running"). nil while a fresh status shows it running, or it holds nothing.
  /// Nothing closes such positions at the session's end, so the app keeps saying so.
  public var unattendedPositions: Unattended? {
    guard let response, let status = response.status, !status.positions.isEmpty else { return nil }
    if status.botState == .stopped { return Unattended(reason: .stopped, count: status.positions.count) }
    if response.stale { return Unattended(reason: .silent, count: status.positions.count) }
    return nil
  }

  /// What is left of today's daily loss limit after realized losses and open reservations, as
  /// the bot computes it; nil while the status is unknown or the bot cannot compute it.
  public var dailyRoom: Decimal? { status?.dailyRoomUsd?.value }

  /// A captured M1 bar is current while it can still be the newest completed bar: the bot keeps
  /// completed bars only, so the next one closes a full bar after it. It stays current for one bar
  /// plus the server's `status_stale_seconds` after its close. Without settings nothing is current.
  func barIsFresh(start: Date, now: Date) -> Bool {
    guard let settings else { return false }
    return Self.barIsCurrent(start: start, now: now,
      staleSeconds: NSDecimalNumber(decimal: settings.statusStaleSeconds.value).doubleValue)
  }

  static func barIsCurrent(start: Date, now: Date, staleSeconds: TimeInterval) -> Bool {
    let barClose = start.addingTimeInterval(barSeconds)
    return now.timeIntervalSince(barClose) <= barSeconds + staleSeconds
  }

  /// Length of one captured bar (M1).
  static let barSeconds: TimeInterval = 60
  /// A change of the bot's clock offset smaller than this (network delay) is ignored, in seconds.
  static let clockToleranceSeconds: TimeInterval = 2
  /// Calendar days of the performance card, counting the shown day (the design's "30 days").
  static let performanceDays = 30

  /// Trades of the shown day: live from status for today, else from the day document.
  public var shownTrades: [DayTrade] {
    if isLive { return todayDocument?.trades ?? [] }
    return dayDocument?.trades ?? []
  }

  public var shownResult: Decimal {
    if isLive { return status?.resultTodayUsd.value ?? 0 }
    return dayDocument?.resultUsd.value ?? 0
  }

  /// The shown result does not count the broker's fees yet: today before the bot has read every
  /// fill's fees, or a recorded day with a trade whose fees are not recorded (its result is gross).
  public var shownResultBeforeFees: Bool {
    if isLive { return status?.resultBeforeFees ?? false }
    guard let dayDocument else { return false }
    return !dayDocument.trades.isEmpty && dayDocument.resultNetUsd == nil
  }

  /// Running sum of trade results through the day, starting at 0, for the sparkline.
  public var cumulativeResults: [Double] {
    var sum: Decimal = 0
    var values: [Double] = [0]
    let results: [Decimal] = isLive
      ? (status?.tradesToday.map(\.resultUsd.value) ?? [])
      : shownTrades.map(\.resultUsd.value)
    for value in results {
      sum += value
      values.append(NSDecimalNumber(decimal: sum).doubleValue)
    }
    return values
  }

  public var shownTradeCount: Int {
    isLive ? (status?.tradesToday.count ?? 0) : shownTrades.count
  }

  public var shownWins: Int {
    let results = isLive ? (status?.tradesToday.map(\.resultUsd.value) ?? []) : shownTrades.map(\.resultUsd.value)
    return results.filter { $0 > 0 }.count
  }

  public var shownLosses: Int {
    let results = isLive ? (status?.tradesToday.map(\.resultUsd.value) ?? []) : shownTrades.map(\.resultUsd.value)
    return results.filter { $0 < 0 }.count
  }

  /// The day picker stands still: the demo day is the only day while its switch is on.
  public var dayLocked: Bool { demoDay }

  /// Previous and next recorded days around the shown one (days are newest first); none while
  /// the day is locked.
  public var previousDay: WireDate? { dayLocked ? nil : days.map(\.day).first { $0 < shownDay } }
  public var nextDay: WireDate? { days.map(\.day).reversed().first { $0 > shownDay } }

  // MARK: lifecycle

  public func start() {
    guard tasks.isEmpty else { return }
    tasks.append(Task { [weak self] in
      while !Task.isCancelled {
        guard let self else { return }
        await self.refreshStatus()
        try? await Task.sleep(for: .seconds(self.pollSeconds))
      }
    })
    tasks.append(Task { [weak self] in
      while !Task.isCancelled {
        guard let self else { return }
        await self.refreshHistory()
        try? await Task.sleep(for: .seconds(Pace.historySeconds))
      }
    })
    tasks.append(Task { [weak self] in
      while !Task.isCancelled {
        guard let self else { return }
        await self.refreshPositionBars()
        try? await Task.sleep(for: .seconds(Pace.barsSeconds))
      }
    })
    tasks.append(Task { [weak self] in
      while !Task.isCancelled {
        guard let self else { return }
        await self.refreshFlow()
        try? await Task.sleep(for: .seconds(Pace.flowSeconds))
      }
    })
    tasks.append(Task { [weak self] in
      while !Task.isCancelled {
        guard let self else { return }
        await self.refreshAccount()
        try? await Task.sleep(for: .seconds(Pace.accountSeconds))
      }
    })
    tasks.append(Task { [weak self] in
      while !Task.isCancelled {
        guard let self else { return }
        // Until the settings say how often (an older API has no /quotes), wait as the status does.
        let seconds = LiveQuotes.pollSeconds(self.settings)
        if seconds != nil { await self.quotes.refresh(self.client) }
        try? await Task.sleep(for: .seconds(seconds ?? self.pollSeconds))
      }
    })
  }

  /// The live price of `symbol` now, from the bot's quotes; nil when there is none (`LivePrice`).
  public func livePrice(_ symbol: String) -> LivePrice? {
    quotes.price(symbol, now: botNow, settings: settings)
  }

  public func stop() {
    tasks.forEach { $0.cancel() }
    tasks = []
  }

  /// Point the app at another API address (Settings › General). With the demo day on, the
  /// demo day behind the new address is shown.
  public func connect(to url: URL) {
    guard url != address else { return }
    address = url
    reconnect()
  }

  /// Turn the demo day on or off (Settings › General). On: the demo day, and the day picker
  /// stays on it. Off: back to the bot at `address`, on today.
  public func setDemoDay(_ on: Bool) {
    guard on != demoDay else { return }
    demoDay = on
    selectedDay = nil
    reconnect()
  }

  /// Start again from nothing on `baseURL`: nothing read from the other address stays on screen.
  private func reconnect() {
    // A question asked of the other address (or the other side of the demo switch) is never
    // answered here: it names a command for where the app no longer points.
    confirming = nil
    let url = baseURL
    client = Container.shared.apiClient(APIClient.Endpoint(baseURL: url))
    response = nil
    readFailure = nil
    lastReadAt = nil
    settings = nil
    quotes.clear()
    days = []
    dayDocument = nil
    todayDocument = nil
    barsBySymbol = [:]
    barsReadFor = []
    account = nil
    jobs = nil
    jobsError = nil
    jobsReadDay = nil
    config = nil
    configError = nil
    botStart = nil
    labReplay = nil
    labReplayError = nil
    labReplayRefusal = nil
    labReplayRefusedAt = nil
    observers = nil
    skipped = nil
    performance = nil
    flow = nil
    watching = nil
    symbols = nil
    movers = nil
    Task {
      await refreshStatus()
      await refreshHistory()
      await refreshAccount()
    }
  }

  // MARK: reads

  public func refreshStatus() async {
    do {
      let fresh = try await client.status()
      let dayBefore = today
      response = fresh
      readFailure = nil
      lastReadAt = now()
      followBotClock(servedAt: fresh.servedAt.date)
      if today != dayBefore {
        // The bot's day is not the one assumed so far (the first status, a demo day, a new
        // session): today's trades and bars belong to the new day.
        todayDocument = nil
        barsBySymbol = [:]
        await refreshHistory()
      }
      resolveSentCommands()
      // Today's session and the next one for the headline's countdown: read once per bot day,
      // and again once the next session has opened (it then names the one after).
      if jobsReadDay != today || jobs?.nextSession.map({ $0.regularOpen.date <= botNow }) == true {
        jobsReadDay = today
        await refreshJobs()
        if jobs == nil { jobsReadDay = nil }
      }
      // Open positions whose bars were not read yet (the first status after launch, a new
      // position, a new day): read them now. Waiting for the bars poll left a position card
      // without its price rows for up to `Pace.barsSeconds`, and the rows then arriving grew the
      // card and moved the Safety card's commands under the operator's pointer.
      if let symbols = status?.positions.map(\.symbol), symbols != barsReadFor || barsDay != today {
        await refreshPositionBars()
      }
      // A start answer stays until the bot is seen alive; then its status says the rest.
      if !fresh.stale, let state = status?.botState, state != .stopped { botStart = nil }
      // Counts come from status, the trade list from /days/<today>: when status shows a
      // trade the list lacks, read the list now instead of waiting for the history poll.
      if let count = status?.tradesToday.count, let document = todayDocument, count != document.trades.count {
        await refreshHistory()
      }
    } catch {
      readFailure = ReadFailure(error) ?? readFailure
    }
    // A stale status or a failed read turns commands off: an open question goes with them.
    withdrawIfCommandsOff()
    if settings == nil { await refreshSettings() }
  }

  /// Takes the bot's clock from a status served at `servedAt`. Network delay moves the offset by
  /// milliseconds on every poll; only a larger change is taken, so views don't redraw for it.
  private func followBotClock(servedAt: Date) {
    let offset = servedAt.timeIntervalSince(now())
    if abs(offset - botClockOffset) > Self.clockToleranceSeconds { botClockOffset = offset }
  }

  public func refreshSettings() async {
    do {
      settings = try await client.settings()
      settingsError = nil
    } catch {
      settingsError = Self.describe(error) ?? settingsError
    }
  }

  public func refreshHistory() async {
    do {
      days = try await client.days().days
      todayDocument = try await client.day(today)
      historyError = nil
    } catch {
      historyError = Self.describe(error) ?? historyError
    }
    await refreshObservers()
    await refreshSkipped()
    await refreshPerformance()
  }

  /// Reads the Lab's replay; a failed read clears it, so an old result never reads as current.
  public func refreshLabReplay() async {
    let url = baseURL
    do {
      let read = try await client.labReplay()
      guard url == baseURL else { return }
      labReplay = read
      labReplayError = nil
      if let refused = labReplayRefusedAt, refused.state != read.state || refused.runId != read.runId
        || Date.now.timeIntervalSince(refused.at) >= Pace.labReplaySeconds {
        labReplayRefusal = nil
        labReplayRefusedAt = nil
      }
    } catch is CancellationError {
      return
    } catch {
      guard url == baseURL else { return }
      labReplay = nil
      labReplayError = Self.describe(error) ?? labReplayError
    }
  }

  /// Starts the Lab's replay once, of strategy folder `version` (the active one when nil), then of
  /// `compare` over the same days, over the last sessions or `day` only; a refusal (a run going,
  /// the session open, no data) is kept as the reason, never retried.
  public func startLabReplay(version: String? = nil, compare: String? = nil, day: WireDate? = nil) async {
    let url = baseURL
    labReplayStarting = true
    defer { labReplayStarting = false }
    do {
      let started = try await client.startLabReplay(version: version, compare: compare, day: day)
      guard url == baseURL else { return }
      labReplay = started
      labReplayRefusal = nil
      labReplayRefusedAt = nil
      labReplayError = nil
    } catch APIError.refused(_, _, let cause) {
      guard url == baseURL else { return }
      labReplayRefusal = cause
      labReplayRefusedAt = (labReplay?.state, labReplay?.runId, .now)
    } catch {
      guard url == baseURL else { return }
      labReplayError = Self.describe(error) ?? labReplayError
    }
  }

  /// What strategy folder `version` would have done on `symbol`'s `day` (simulated, read-only):
  /// the document, or the API's refusal (the session is open) or the failed read in words.
  public func tradeWhatIf(symbol: String, day: WireDate, version: String) async -> TradeWhatIfAnswer {
    do {
      return .found(try await client.tradeWhatIf(symbol: symbol, day: day, version: version))
    } catch APIError.refused(_, _, let cause) {
      return .refused(cause)
    } catch {
      return .refused(ErrorText.text(error))
    }
  }

  /// Reads the replay until cancelled, more often while it runs; used while the Lab is open.
  public func followLabReplay() async {
    while !Task.isCancelled {
      await refreshLabReplay()
      let seconds = labReplay?.state == .running ? Pace.labReplayRunningSeconds : Pace.labReplaySeconds
      try? await Task.sleep(for: .seconds(seconds))
    }
  }

  /// Reads the jobs; a failed read clears them, so old times never read as current.
  public func refreshJobs() async {
    let url = baseURL
    do {
      let read = try await client.jobs()
      guard url == baseURL else { return }
      jobs = read
      jobsError = nil
    } catch is CancellationError {
      return
    } catch {
      guard url == baseURL else { return }
      jobs = nil
      jobsError = Self.describe(error) ?? jobsError
    }
  }

  public func refreshConfig() async {
    let url = baseURL
    do {
      let read = try await client.config()
      guard url == baseURL else { return }
      config = read
      configError = nil
    } catch {
      guard !Task.isCancelled, url == baseURL else { return }
      config = nil
      configError = Self.describe(error)
    }
  }

  /// Reads the jobs at the status poll rate until cancelled; used while Settings is open.
  public func followJobs() async {
    while !Task.isCancelled {
      await refreshJobs()
      let seconds = response.map { NSDecimalNumber(decimal: $0.pollSeconds.value).doubleValue }
        ?? Pace.initialPollSeconds
      try? await Task.sleep(for: .seconds(max(seconds, 1)))
    }
  }

  public func refreshAccount() async {
    do {
      account = try await client.account()
      accountError = nil
    } catch {
      // A failed read never shows an older answer as current.
      account = nil
      accountError = Self.describe(error) ?? accountError
    }
  }

  /// Observers of the shown day. An answer for a day no longer shown is dropped.
  public func refreshObservers() async {
    let day = shownDay
    do {
      let document = try await client.observers(day: day)
      guard day == shownDay else { return }
      observers = document
      observersError = nil
    } catch {
      guard day == shownDay else { return }
      observers = nil
      observersError = Self.describe(error) ?? observersError
    }
  }

  /// Reads the shown day's skipped ENTERs. An answer for a day no longer shown is dropped; a
  /// failed read clears the list, so an old one never reads as current.
  public func refreshSkipped() async {
    let day = shownDay
    do {
      let document = try await client.skipped(day: day)
      guard day == shownDay else { return }
      skipped = document
      skippedError = nil
    } catch {
      guard day == shownDay else { return }
      skipped = nil
      skippedError = Self.describe(error) ?? skippedError
    }
  }

  /// Reads performance over the days that end on the shown day. An answer for a day no longer
  /// shown is dropped; a failed read clears it, so old figures never read as current.
  public func refreshPerformance() async {
    let day = shownDay
    do {
      let document = try await client.performance(from: day.adding(days: 1 - Self.performanceDays), to: day)
      guard day == shownDay else { return }
      performance = document
      performanceError = nil
    } catch {
      guard day == shownDay else { return }
      performance = nil
      performanceError = Self.describe(error) ?? performanceError
    }
  }

  /// Reads the shown day's flow, watched symbols, symbols and fast movers. An answer for a day
  /// no longer shown is dropped; a failed read clears its part, so an old one never reads as current.
  public func refreshFlow() async {
    let day = shownDay
    do {
      let document = try await client.flow(day: day)
      guard day == shownDay else { return }
      flow = document
      flowError = nil
    } catch {
      guard day == shownDay else { return }
      flow = nil
      flowError = Self.describe(error) ?? flowError
    }
    do {
      let document = try await client.watching(day: day)
      guard day == shownDay else { return }
      watching = document
      watchingError = nil
    } catch {
      guard day == shownDay else { return }
      watching = nil
      watchingError = Self.describe(error) ?? watchingError
    }
    do {
      let document = try await client.symbols(day: day)
      guard day == shownDay else { return }
      symbols = document
      symbolsError = nil
    } catch {
      guard day == shownDay else { return }
      symbols = nil
      symbolsError = Self.describe(error) ?? symbolsError
    }
    do {
      let document = try await client.movers(day: day)
      guard day == shownDay else { return }
      movers = document
      moversError = nil
    } catch {
      guard day == shownDay else { return }
      movers = nil
      moversError = Self.describe(error) ?? moversError
    }
  }

  /// Starts reading the picked day: what was shown for the earlier pick goes at once, so the
  /// screen says the new day is being read instead of showing the old one under its title.
  private func beginDayLoad() {
    dayLoad?.cancel()
    dayDocument = nil
    dayError = nil
    dayLoad = Task { await loadSelectedDay() }
  }

  /// Reads the picked day: its trades first, the document every screen of a past day shows, then
  /// the rest of the day (flow, symbols, observers, skipped signals, performance). Those reads
  /// can take the API seconds each for a busy day; read first, they held the trades back for
  /// over a minute (owner report 2026-11-17), and the screen looked as if the pick did nothing.
  private func loadSelectedDay() async {
    await readSelectedDayDocument()
    guard !Task.isCancelled else { return }
    observers = nil
    skipped = nil
    skippedError = nil
    performance = nil
    performanceError = nil
    flow = nil
    flowError = nil
    watching = nil
    watchingError = nil
    symbols = nil
    symbolsError = nil
    movers = nil
    moversError = nil
    await refreshFlow()
    await refreshObservers()
    await refreshSkipped()
    await refreshPerformance()
  }

  /// Reads the picked past day's document into `dayDocument`, or its cause into `dayError`. An
  /// answer for a day no longer picked, or for another day than asked, is dropped.
  func readSelectedDayDocument() async {
    guard let day = selectedDay, day != today else {
      dayDocument = nil
      dayError = nil
      return
    }
    do {
      let document = try await client.day(day)
      guard day == selectedDay, !Task.isCancelled else { return }
      guard document.day == day else {
        dayDocument = nil
        dayError = String(localized: L10n.Trades.otherDayAnswered(day.text, document.day.text))
        return
      }
      dayDocument = document
      dayError = nil
    } catch {
      guard day == selectedDay, !Task.isCancelled else { return }
      dayDocument = nil
      dayError = Self.describe(error) ?? String(localized: L10n.Common.unavailable)
    }
  }

  /// What the shown day's trades are: today's (live), or the picked past day's being read,
  /// unavailable with a cause, or read.
  public enum ShownDayState: Equatable, Sendable {
    case live
    case loading
    case failed(String)
    case loaded(DayV1)
  }

  public var shownDayState: ShownDayState {
    if isLive { return .live }
    if let dayDocument { return .loaded(dayDocument) }
    if let dayError { return .failed(dayError) }
    return .loading
  }

  /// Reads the picked past day's trades again (the Retry of its unavailable state).
  public func retryShownDay() {
    guard !isLive else { return }
    dayLoad?.cancel()
    dayError = nil
    dayLoad = Task { await readSelectedDayDocument() }
  }

  /// Reads today's bars of every open position where the Chart reads them (`DayBars`: market
  /// data, else the capture), so the Overview and the Chart show one price for one moment.
  public func refreshPositionBars() async {
    let symbols = status?.positions.map(\.symbol) ?? []
    barsReadFor = symbols
    barsDay = today
    for symbol in symbols {
      do {
        let fresh = try await DayBars.read(client, symbol: symbol, day: today, today: today)
        // An answer the chart's budget left empty, or an older one, never replaces newer bars.
        if !Self.isOlder(fresh, than: barsBySymbol[symbol]) { barsBySymbol[symbol] = fresh }
      } catch {
        // The position still shows its entry and stop; only "last" stays empty.
        barsBySymbol[symbol] = nil
      }
    }
    // Bars of closed positions are not kept.
    barsBySymbol = barsBySymbol.filter { symbols.contains($0.key) }
  }

  /// The price line of `symbol` on the Symbols screen's day, against `previousClose`
  /// (`SymbolDayLine`: the bot's stored bars, a chart read only without them).
  public func symbolDayLine(_ symbol: String, previousClose: Decimal?) async -> SymbolDayLine? {
    await SymbolDayLine.read(symbol, day: symbols?.day ?? shownDay, today: today,
      previousClose: previousClose, client: client)
  }

  /// Today's bars of an open position's symbol as the Overview last read them; nil for any other
  /// symbol.
  public func positionBars(_ symbol: String) -> DayBars? { barsBySymbol[symbol] }

  /// Whether `bars` end before `other` does (by their newest bar's start).
  static func isOlder(_ bars: DayBars, than other: DayBars?) -> Bool {
    guard let other, let theirs = other.newestStart else { return false }
    guard let ours = bars.newestStart else { return true }
    return ours < theirs
  }

  // MARK: day navigation

  public func showPreviousDay() { if let day = previousDay { selectedDay = day } }
  public func showNextDay() { selectedDay = nextDay.flatMap { $0 == today ? nil : $0 } }
  public func showToday() { selectedDay = nil }

  // MARK: commands

  /// Start makes sense when the API answers and no current status says the bot is alive (a stale
  /// or missing status proves nothing; the API checks again and launchd never restarts a running job).
  public var canStartBot: Bool {
    guard fetchError == nil, response != nil, !botStarting, !sending else { return false }
    guard let status, response?.stale == false else { return true }
    return status.botState == .stopped
  }

  /// Stop is the stop-bot command: the bot drains itself and refuses while a trade is open.
  public var canStopBot: Bool { commandsEnabled && status?.botState == .running }

  /// Asks the API to start the bot job through launchd (POST /commands/start-bot), once.
  public func startBot() async {
    guard canStartBot else { return }
    botStarting = true
    defer { botStarting = false }
    do {
      let answer = try await client.startBot()
      botStart = .accepted(stopCleared: answer.stopMarkerCleared)
    } catch {
      botStart = .refused(ErrorText.text(error))
    }
    await refreshStatus()
  }

  /// A press of a bot command in `place`: a command that asks first only opens its question
  /// (`confirming`); pausing and resuming are sent at once. Nothing is asked or sent while
  /// commands are off.
  func press(_ action: BotAction, in place: CommandPlace) {
    guard commandsEnabled else { return }
    if action.needsConfirmation {
      confirming = PendingConfirmation(action: action, place: place)
    } else {
      Task { await send(action.command, title: action.title) }
    }
  }

  /// The operator's yes to `question`. Only the question still open is accepted: it is closed in
  /// the same step, and its own command (never another) goes to `send`, which checks again that
  /// commands are on. A withdrawn, replaced or already answered question sends nothing, so one
  /// question sends at most once. Returns the send, or nil when nothing is sent.
  @discardableResult
  func accept(_ question: PendingConfirmation) -> Task<Void, Never>? {
    guard confirming == question else { return nil }
    confirming = nil
    return Task { await send(question.action.command, title: question.action.title) }
  }

  /// Closes `question` unanswered (Cancel or Escape); a newer question stays.
  func withdraw(_ question: PendingConfirmation) {
    if confirming == question { confirming = nil }
  }

  /// Closes the question asked in `place`, if one is open: its window or panel closed, so it can
  /// no longer be answered there and must not come back when that place opens again.
  func withdrawQuestion(in place: CommandPlace) {
    if confirming?.place == place { confirming = nil }
  }

  /// Closes an open question once commands are off (a stale or failed status read, a recorded
  /// day, a command being sent): it was asked in a state that no longer holds.
  private func withdrawIfCommandsOff() {
    if !commandsEnabled { confirming = nil }
  }

  public func send(_ command: OperatorCommand, title: String) async {
    // A confirmation alert can stay open while the status goes stale or the day changes:
    // check again at the moment of sending, never trust the state the alert was opened in.
    guard commandsEnabled else {
      show(SentCommand(id: UUID().uuidString, kind: command.kind, title: title, outcome: .refused,
        cause: String(localized: L10n.Bot.notSentUntrusted), warning: nil))
      return
    }
    sending = true
    inFlight = command
    withdrawIfCommandsOff()
    defer {
      sending = false
      inFlight = nil
    }
    do {
      // One key per operator action: a repeat of this exact send answers the first, never queues twice.
      let accepted = try await client.send(command, idempotencyKey: UUID().uuidString)
      let record = SentCommand(id: accepted.command.commandId, kind: command.kind, title: title,
        outcome: nil, cause: nil, warning: accepted.warning)
      sent.insert(record, at: 0)
      show(record)
    } catch {
      show(SentCommand(id: UUID().uuidString, kind: command.kind, title: title, outcome: .refused,
        cause: String(localized: L10n.Bot.notSent(ErrorText.text(error))), warning: nil))
    }
    await refreshStatus()
  }

  private func resolveSentCommands() {
    guard let records = status?.recentCommands else { return }
    for index in sent.indices where sent[index].outcome == nil {
      if let record = records.first(where: { $0.commandId == sent[index].id }) {
        sent[index].outcome = record.outcome
        sent[index].cause = record.causeText
        show(sent[index])
      }
    }
  }

  private func show(_ command: SentCommand) {
    toast = command
    let id = command.id
    Task {
      try? await Task.sleep(for: .seconds(Pace.toastSeconds))
      if toast?.id == id && toast?.outcome == command.outcome { toast = nil }
    }
  }

  /// Nil for a cancelled read: callers keep the error they had (`describe(error) ?? old`), so a read
  /// cancelled by `stop()` never clears a real failure and makes stale data look current.
  static func describe(_ error: Error) -> String? {
    ErrorText.describe(error)
  }
}

/// The answer of another version on one trade: the simulated document, or why there is none.
public enum TradeWhatIfAnswer: Sendable, Equatable {
  case found(TradeWhatIfV1)
  case refused(String)
}
