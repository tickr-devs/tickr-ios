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
  /// The send's answer was lost: whether it was queued is not known yet (`AppModel.settleLost`).
  public var unknown = false
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
  /// A fixed token for the bot: the iPad Simulator's own (`pair-simulator`); nil otherwise, a
  /// signed-in device's tokens being `BotSession`'s (`signedIn`).
  public private(set) var token: String?
  /// Whether this device is signed in with the bot (`SignInState`): its requests to the bot's
  /// address carry the access token `BotSession` keeps (never in the demo day).
  public private(set) var signedIn: Bool
  /// Whether the Mac's window shows the sign-in (mockup v174, board MacSignIn): the bot's own
  /// address before sign-in; a development address and the demo day need none.
  public var showsSignIn: Bool { !signedIn && !demoDay && address == BotAddress.url }
  /// Proves the owner is the one pressing (Face ID or the passcode on iPad) before a command is
  /// sent, `nil` for starting the bot, with the command's title as the reason; false refuses the
  /// command and sends nothing. Set by the iPad; nil on the Mac, which asks nothing more than the
  /// screens' own questions.
  @ObservationIgnored public var ownerCheck: (@MainActor (OperatorCommand?, String) async -> Bool)?
  /// Where every read and command of the screens goes: the address with its token.
  public var endpoint: APIClient.Endpoint {
    APIClient.Endpoint(baseURL: baseURL, token: token, signedIn: signedIn && !demoDay && address == BotAddress.url)
  }
  @ObservationIgnored private var client: APIClient
  /// The current moment (Container.now; tests pin it).
  @ObservationIgnored @Injected(\.now) private var now
  /// The bot's live quotes (GET /quotes), read every `settings.quotes_poll_seconds`: every live
  /// price the app shows comes from here.
  @ObservationIgnored @Injected(\.liveQuotes) public var quotes
  /// Sends this Mac's push token to the bot once a status read there has answered.
  @ObservationIgnored @Injected(\.pushRegistrar) private var pushRegistrar
  /// How far the bot's clock is ahead of this Mac's, from the last status's `served_at`. The
  /// bot's clock decides what "today" is and how old its reads are: the Mac's clock can drift,
  /// and `tickr demo` plays a past day on a clock of its own.
  public private(set) var botClockOffset: TimeInterval = 0

  // Live state.
  public private(set) var response: StatusResponseV1?
  /// The /status reads that failed in a row since the last answer (`ReadFailures`).
  public private(set) var reads = ReadFailures()
  /// Why /status can't be read, once that is more than one passing failure; nil after an answer.
  public var readFailure: ReadFailure? { reads.shown }
  /// When /status last answered, on this Mac's clock; nil until it answers at this address.
  public private(set) var lastReadAt: Date?
  /// The last failure's technical text (Settings); screens say `connectionState` instead.
  public var fetchError: String? { readFailure?.detail }
  public private(set) var settings: SettingsV1?
  public private(set) var settingsError: String?
  /// The API start (`StatusResponseV1.apiStartedAt`) the settings were read after: a new one reads them again.
  @ObservationIgnored private var settingsReadFor: WireTime?
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
  /// The System card (GET /system), read with the jobs while Settings is open.
  public private(set) var system: SystemV1?
  /// Why the System card could not be read, if it could not.
  public private(set) var systemError: String?
  /// The notification settings (GET /alerts) and the owner's changes on their way, read when
  /// Settings › Notifications opens.
  public let alertRouting = AlertRouting()
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
      if oldValue == nil, selectedDay != nil { todayParts = (today, shownParts) }
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
  /// The day whose cards `readDayCards` is reading together; nil when none is. The periodic
  /// reads leave that day's cards alone meanwhile.
  @ObservationIgnored private var cardsDay: WireDate?
  /// Number of the newest `readDayCards`; only it lifts `cardsDay` when it ends.
  @ObservationIgnored private var cardsRead = 0
  /// What was read of the past days shown last: a day picked again shows at once, then is read
  /// again behind it (`PastDays`).
  @ObservationIgnored private var pastDays = PastDays<DayParts>()
  /// Today's parts as last shown before a past day was picked: back on today they show at once
  /// and are read again behind it, instead of empty cards refilling (owner's live check
  /// 2026-11-17). Only for the New York date they were read on.
  @ObservationIgnored private var todayParts: (day: WireDate, parts: DayParts)?
  public private(set) var todayDocument: DayV1?
  /// The active strategy's ENTERs on the shown day that did not become a position; nil until read.
  /// The shown day's journal (GET /events); nil until read and when the bot cannot serve it (an
  /// older bot: today's card then shows what the status says).
  public private(set) var events: DayEventsV1?
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
  /// The close-and-stop the bot reports, followed across reads for its steps' times and its
  /// refusal (`StopWatch`, the Bot card's steps).
  private(set) var stopWatch = StopWatch()
  /// The working entries followed across reads, for "Cancelled at broker" (`EntryCancelWatch`).
  private(set) var entryWatch = EntryCancelWatch()

  private var tasks: [Task<Void, Never>] = []
  /// Counts connections (`reconnect`): an answer is applied only while the connection it was
  /// asked on is still this one (backlog A4), so a late answer from server A never replaces what
  /// the app shows of server B after a switch, even when B is A again.
  @ObservationIgnored private var link = 0
  /// The idempotency key of each command whose send lost its answer (backlog A3), kept until the
  /// API's receipt says whether it was queued and used again if the operator presses it again. In
  /// the app's one store (`CommandKeyStore`): on iPad the iPhone screens' model sends from the
  /// same keys, so a press after a lost send is never a second send under a new key.
  @ObservationIgnored @Injected(\.commandKeys) private var keyStore
  private var keys: CommandKeys {
    get { keyStore.keys }
    set { keyStore.keys = newValue }
  }
  /// The title each lost send was pressed under ("Close ABCD position"), by its key.
  @ObservationIgnored private var lostTitles: [String: String] = [:]

  public init(baseURL: URL, token: String? = nil, signedIn: Bool = false, demoDay: Bool = false) {
    self.address = baseURL
    self.token = token
    self.signedIn = signedIn
    self.demoDay = demoDay
    let shown = DemoDay.address(baseURL, demo: demoDay)
    self.client = Container.shared.apiClient(APIClient.Endpoint(baseURL: shown, token: demoDay ? nil : token,
      signedIn: signedIn && !demoDay && baseURL == BotAddress.url))
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

  /// A picked past day whose trades are still being read: its result and counts are not known
  /// yet, so the cards show a skeleton, never a zero.
  public var dayPending: Bool { shownDayState == .loading }
  /// The same for the picked day's flow.
  public var flowPending: Bool { !isLive && flow == nil && flowError == nil }

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

  /// Point the screens at `endpoint` as it is, address and token (the iPad's connection after a
  /// sign-in or a change in its Settings). The same endpoint again changes nothing.
  public func connect(to endpoint: APIClient.Endpoint) {
    guard endpoint != self.endpoint else { return }
    address = endpoint.baseURL
    token = endpoint.token
    signedIn = endpoint.signedIn
    demoDay = false
    selectedDay = nil
    reconnect()
  }

  /// This Mac signed in with the bot (`SignInState`), or signed out: the screens read the bot
  /// again from nothing.
  public func use(signedIn: Bool) {
    guard signedIn != self.signedIn else { return }
    self.signedIn = signedIn
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
    link += 1
    // Keys of the server before mean nothing at this one.
    entryWatch.forget()
    let url = baseURL
    keyStore.use(url)
    lostTitles = [:]
    client = Container.shared.apiClient(endpoint)
    response = nil
    reads = ReadFailures()
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
    system = nil
    systemError = nil
    alertRouting.clear()
    config = nil
    configError = nil
    botStart = nil
    labReplay = nil
    labReplayError = nil
    labReplayRefusal = nil
    labReplayRefusedAt = nil
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

  /// Reads /status once. True only when this very read answered, on the connection still shown,
  /// with a current status: what a command needs right before it is sent (backlog A4). A failed
  /// read is false even while `ReadFailures` still hides it as a passing blip.
  @discardableResult
  public func refreshStatus() async -> Bool {
    let asked = link
    var current = false
    do {
      let fresh = try await client.status()
      guard asked == link else { return false }
      current = !fresh.stale && fresh.status != nil
      let dayBefore = today
      response = fresh
      stopWatch.read(fresh.status)
      entryWatch.read(fresh.status, now: now(), commandMaxAge: keepSeconds)
      reads.answered()
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
      pushRegistrar.reached(endpoint)
      await settleLost()
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
      guard asked == link else { return false }
      reads.failed(error, hadAnswer: lastReadAt != nil)
    }
    // A stale status or a failed read turns commands off: an open question goes with them.
    withdrawIfCommandsOff()
    if response?.needsSettings(settings, readFor: settingsReadFor) ?? (settings == nil) { await refreshSettings() }
    return current && asked == link
  }

  /// Takes the bot's clock from a status served at `servedAt`. Network delay moves the offset by
  /// milliseconds on every poll; only a larger change is taken, so views don't redraw for it.
  private func followBotClock(servedAt: Date) {
    let offset = servedAt.timeIntervalSince(now())
    if abs(offset - botClockOffset) > Self.clockToleranceSeconds { botClockOffset = offset }
  }

  public func refreshSettings() async {
    let startedAt = response?.apiStartedAt
    let asked = link
    do {
      let read = try await client.settings()
      guard asked == link else { return }
      settings = read
      settingsReadFor = startedAt
      settingsError = nil
    } catch {
      guard asked == link else { return }
      settingsError = Self.describe(error) ?? settingsError
    }
  }

  public func refreshHistory() async {
    let asked = link
    do {
      let read = try await client.days().days
      guard asked == link else { return }
      days = read
      let document = try await client.day(today)
      guard asked == link else { return }
      todayDocument = document
      historyError = nil
    } catch {
      guard asked == link else { return }
      historyError = Self.describe(error) ?? historyError
    }
    async let skippedRead: Void = refreshSkipped()
    async let performanceRead: Void = refreshPerformance()
    _ = await (skippedRead, performanceRead)
  }

  /// Reads the Lab's replay; a failed read clears it, so an old result never reads as current.
  public func refreshLabReplay() async {
    let asked = link
    do {
      let read = try await client.labReplay()
      guard asked == link else { return }
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
      guard asked == link else { return }
      labReplay = nil
      labReplayError = Self.describe(error) ?? labReplayError
    }
  }

  /// Starts the Lab's replay once, of strategy folder `version` (the active one when nil), then of
  /// `compare` over the same days, over the last sessions or `day` only; a refusal (a run going,
  /// the session open, no data) is kept as the reason, never retried.
  public func startLabReplay(version: String? = nil, compare: String? = nil, day: WireDate? = nil) async {
    let asked = link
    labReplayStarting = true
    defer { labReplayStarting = false }
    do {
      let started = try await client.startLabReplay(version: version, compare: compare, day: day)
      guard asked == link else { return }
      labReplay = started
      labReplayRefusal = nil
      labReplayRefusedAt = nil
      labReplayError = nil
    } catch APIError.refused(_, _, let cause) {
      guard asked == link else { return }
      labReplayRefusal = cause
      labReplayRefusedAt = (labReplay?.state, labReplay?.runId, .now)
    } catch {
      guard asked == link else { return }
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
    let asked = link
    do {
      let read = try await client.jobs()
      guard asked == link else { return }
      jobs = read
      jobsError = nil
    } catch is CancellationError {
      return
    } catch {
      guard asked == link else { return }
      jobs = nil
      jobsError = Self.describe(error) ?? jobsError
    }
  }

  /// Reads the System card; a failed read clears it, so an old state never reads as current.
  public func refreshSystem() async {
    let asked = link
    do {
      let read = try await client.system()
      guard asked == link else { return }
      system = read
      systemError = nil
    } catch is CancellationError {
      return
    } catch {
      guard asked == link else { return }
      system = nil
      systemError = Self.describe(error) ?? systemError
    }
  }

  /// Reads the notification settings.
  public func refreshAlerts() async {
    await alertRouting.refresh(client)
  }

  /// Turns one alert kind on or off on one channel (PUT /alerts/routing): sent once, the answer
  /// shown; a refusal is kept in `alertRouting.changeError`.
  public func setAlertRoute(_ cell: AlertCell, on: Bool) async {
    await alertRouting.set(cell, on: on, client: client)
  }

  public func refreshConfig() async {
    let asked = link
    do {
      let read = try await client.config()
      guard asked == link else { return }
      config = read
      configError = nil
    } catch {
      guard !Task.isCancelled, asked == link else { return }
      config = nil
      configError = Self.describe(error)
    }
  }

  /// Reads the jobs and the System card at the status poll rate until cancelled; used while
  /// Settings is open.
  public func followJobs() async {
    while !Task.isCancelled {
      await refreshJobs()
      await refreshSystem()
      let seconds = response.map { NSDecimalNumber(decimal: $0.pollSeconds.value).doubleValue }
        ?? Pace.initialPollSeconds
      try? await Task.sleep(for: .seconds(max(seconds, 1)))
    }
  }

  public func refreshAccount() async {
    let asked = link
    do {
      let read = try await client.account()
      guard asked == link else { return }
      account = read
      accountError = nil
    } catch {
      guard asked == link else { return }
      // A failed read never shows an older answer as current.
      account = nil
      accountError = Self.describe(error) ?? accountError
    }
  }

  /// Reads the shown day's skipped ENTERs. An answer for a day no longer shown is dropped; a
  /// failed read clears the list, so an old one never reads as current.
  public func refreshSkipped() async {
    let day = shownDay
    let asked = link
    let read = await Self.outcome { [client] in try await client.skipped(day: day) }
    guard shows(day, asked: asked) else { return }
    apply(read, of: day, \.skipped, \.skippedError, kept: \.skipped)
  }

  /// Reads performance over the days that end on the shown day. An answer for a day no longer
  /// shown is dropped; a failed read clears it, so old figures never read as current.
  public func refreshPerformance() async {
    let day = shownDay
    let asked = link
    let read = await Self.outcome { [client] in
      try await client.performance(from: day.adding(days: 1 - Self.performanceDays), to: day)
    }
    guard shows(day, asked: asked) else { return }
    apply(read, of: day, \.performance, \.performanceError, kept: \.performance)
  }

  /// Reads the shown day's flow, watched symbols, symbols, fast movers and journal, all at once.
  /// An answer for a day no longer shown is dropped; a failed read clears its part, so an old one
  /// never reads as current.
  public func refreshFlow() async {
    let day = shownDay
    let asked = link
    async let flow = Self.outcome { [client] in try await client.flow(day: day) }
    async let watching = Self.outcome { [client] in try await client.watching(day: day) }
    async let symbols = Self.outcome { [client] in try await client.symbols(day: day) }
    async let movers = Self.outcome { [client] in try await client.movers(day: day) }
    async let events = Self.outcome { [client] in try await client.events(day: day) }
    let read = await (flow, watching, symbols, movers, events)
    guard shows(day, asked: asked) else { return }
    apply(read.0, of: day, \.flow, \.flowError, kept: \.flow)
    apply(read.1, of: day, \.watching, \.watchingError, kept: \.watching)
    apply(read.2, of: day, \.symbols, \.symbolsError, kept: \.symbols)
    apply(read.3, of: day, \.movers, \.moversError, kept: \.movers)
    applyEvents(read.4, of: day)
  }

  /// Reads every card of the picked day at once (flow, watched symbols, symbols, fast movers,
  /// journal, Not taken, performance) and shows them together once all have answered,
  /// each with its document or its own cause (owner 2026-11-22: what cannot show at once shows
  /// its loader, then all of it at once, never cards popping in one by one). The API keeps a
  /// past day's answers once built (api/settled.py), so they normally all answer within
  /// milliseconds; a day it has not built yet it builds in one pass for all of them, so they
  /// answer together anyway, and a deadline after which some cards show alone would buy
  /// nothing. Until then each card shows what was kept of the day, else its loader. A newer
  /// pick cancels the reads; the periodic reads of the same day leave the cards alone meanwhile.
  func readDayCards() async {
    let day = shownDay
    let from = day.adding(days: 1 - Self.performanceDays)
    cardsRead += 1
    let read = cardsRead
    cardsDay = day
    let asked = link
    defer { if cardsRead == read { cardsDay = nil } }
    async let flow = Self.outcome { [client] in try await client.flow(day: day) }
    async let watching = Self.outcome { [client] in try await client.watching(day: day) }
    async let symbols = Self.outcome { [client] in try await client.symbols(day: day) }
    async let movers = Self.outcome { [client] in try await client.movers(day: day) }
    async let events = Self.outcome { [client] in try await client.events(day: day) }
    async let skipped = Self.outcome { [client] in try await client.skipped(day: day) }
    async let performance = Self.outcome { [client] in try await client.performance(from: from, to: day) }
    let cards = await (flow, watching, symbols, movers, events, skipped, performance)
    guard asked == link, day == shownDay, !Task.isCancelled else { return }
    apply(cards.0, of: day, \.flow, \.flowError, kept: \.flow)
    apply(cards.1, of: day, \.watching, \.watchingError, kept: \.watching)
    apply(cards.2, of: day, \.symbols, \.symbolsError, kept: \.symbols)
    apply(cards.3, of: day, \.movers, \.moversError, kept: \.movers)
    applyEvents(cards.4, of: day)
    apply(cards.5, of: day, \.skipped, \.skippedError, kept: \.skipped)
    apply(cards.6, of: day, \.performance, \.performanceError, kept: \.performance)
  }

  /// Whether a single read's answer for `day` may be shown now: `day` is still shown and its
  /// cards are not being read together (`readDayCards` shows them all at once).
  private func shows(_ day: WireDate, asked: Int) -> Bool { asked == link && day == shownDay && cardsDay != day }

  /// One read's document, or why it failed; read off the main actor, shown on it.
  nonisolated static func outcome<Document: Sendable>(
    _ read: @Sendable () async throws -> Document
  ) async -> Result<Document, any Error> {
    do { return .success(try await read()) } catch { return .failure(error) }
  }

  /// Shows one read of `day`: its document (kept for the day too), or no document and its cause
  /// (a cause without words keeps the earlier one), so an old document never reads as current.
  private func apply<Document>(
    _ read: Result<Document, any Error>, of day: WireDate,
    _ document: ReferenceWritableKeyPath<AppModel, Document?>,
    _ cause: ReferenceWritableKeyPath<AppModel, String?>, kept: WritableKeyPath<DayParts, Document?>
  ) {
    switch read {
    case .success(let value):
      self[keyPath: document] = value
      self[keyPath: cause] = nil
      keep(day) { $0[keyPath: kept] = value }
    case .failure(let error):
      self[keyPath: document] = nil
      self[keyPath: cause] = Self.describe(error) ?? self[keyPath: cause]
    }
  }

  /// Shows the read journal of `day`; a failed read, or another day's, clears it.
  private func applyEvents(_ read: Result<DayEventsV1, any Error>, of day: WireDate) {
    events = (try? read.get()).flatMap { $0.day == day ? $0 : nil }
    if let read = events { keep(day) { $0.events = read } }
  }

  /// Starts reading the picked day. What was shown for the earlier pick goes at once, so the
  /// screen never shows the old day under the new title: a past day read before shows what was
  /// read of it, any other day its loading state, until the reads answer.
  private func beginDayLoad() {
    dayLoad?.cancel()
    let kept: DayParts? = if let selectedDay {
      pastDays.parts(of: selectedDay)
    } else {
      todayParts.flatMap { $0.day == today ? $0.parts : nil }
    }
    show(kept ?? DayParts())
    dayLoad = Task { await loadSelectedDay() }
  }

  /// The shown day's parts as they are now.
  private var shownParts: DayParts {
    DayParts(document: dayDocument, flow: flow, watching: watching, symbols: symbols, movers: movers,
      skipped: skipped, performance: performance)
  }

  /// Shows `parts` as the shown day's, with no read failure.
  private func show(_ parts: DayParts) {
    dayDocument = parts.document
    dayError = nil
    flow = parts.flow
    flowError = nil
    watching = parts.watching
    watchingError = nil
    symbols = parts.symbols
    symbolsError = nil
    movers = parts.movers
    moversError = nil
    skipped = parts.skipped
    skippedError = nil
    events = parts.events
    performance = parts.performance
    performanceError = nil
  }

  /// Reads every part of the picked day at once: its trades, shown as soon as they come (the
  /// document every screen of a past day shows), and its cards, shown together
  /// (`readDayCards`). One after another, each waited for the ones before it, and the last (Not
  /// taken, performance) came seconds after the trades (owner report 2026-11-17).
  private func loadSelectedDay() async {
    async let documentRead: Void = readSelectedDayDocument()
    async let cardsRead: Void = readDayCards()
    _ = await (documentRead, cardsRead)
  }

  /// Keeps `update` applied to what is kept of `day`, when it is a past day.
  private func keep(_ day: WireDate, _ update: (inout DayParts) -> Void) {
    pastDays.keep(day, today: today, empty: DayParts(), update)
  }

  /// Reads the picked past day's document into `dayDocument`, or its cause into `dayError`. An
  /// answer for a day no longer picked, or for another day than asked, is dropped.
  func readSelectedDayDocument() async {
    guard let day = selectedDay, day != today else {
      dayDocument = nil
      dayError = nil
      return
    }
    let asked = link
    do {
      let document = try await client.day(day)
      guard asked == link, day == selectedDay, !Task.isCancelled else { return }
      guard document.day == day else {
        dayDocument = nil
        dayError = String(localized: L10n.Trades.otherDayAnswered(day.text, document.day.text))
        return
      }
      dayDocument = document
      dayError = nil
      keep(day) { $0.document = document }
    } catch {
      guard asked == link, day == selectedDay, !Task.isCancelled else { return }
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

  /// Reads the picked past day again (the Retry of its unavailable state): its trades first, then
  /// the rest of the day. The Retry cancels the pick's read still under way, so it reads the whole
  /// day again; reading only the trades left the day's other cards with a cancelled read's error.
  public func retryShownDay() {
    guard !isLive else { return }
    dayLoad?.cancel()
    dayError = nil
    dayLoad = Task { await loadSelectedDay() }
  }

  /// Reads today's bars of every open position where the Chart reads them (`DayBars`: market
  /// data, else the capture), so the Overview and the Chart show one price for one moment.
  public func refreshPositionBars() async {
    let symbols = status?.positions.map(\.symbol) ?? []
    barsReadFor = symbols
    barsDay = today
    let asked = link
    for symbol in symbols {
      do {
        let fresh = try await DayBars.read(client, symbol: symbol, day: today, today: today)
        guard asked == link else { return }
        // An answer the chart's budget left empty, or an older one, never replaces newer bars.
        if !Self.isOlder(fresh, than: barsBySymbol[symbol]) { barsBySymbol[symbol] = fresh }
      } catch {
        guard asked == link else { return }
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
    if let ownerCheck {
      guard await ownerCheck(nil, String(localized: L10n.Settings.startBotAction)) else {
        botStart = .refused(String(localized: L10n.Bot.ownerNotConfirmed))
        return
      }
      guard canStartBot else { return }
    }
    stopWatch.forget()
    botStarting = true
    defer { botStarting = false }
    let asked = link
    do {
      let answer = try await client.startBot()
      guard asked == link else { return }
      botStart = .accepted(stopCleared: answer.stopMarkerCleared)
    } catch {
      guard asked == link else { return }
      botStart = .refused(ErrorText.text(error))
    }
    await refreshStatus()
  }

  /// A press of a bot command in `place`: a command that asks first only opens its question
  /// (`confirming`); pausing and resuming are sent at once. Nothing is asked or sent while
  /// commands are off.
  func press(_ action: BotAction, in place: CommandPlace) {
    guard commandsEnabled else { return }
    // A new command: an earlier close-and-stop's refusal is no longer the news.
    stopWatch.forget()
    if action.needsConfirmation {
      // Stop bot asks by what is open now: a choice with positions, the plain question without.
      let stop = action == .stopBot ? StopQuestion.asked(positions: status?.positions ?? []) : .confirm
      confirming = PendingConfirmation(action: action, place: place, stop: stop)
    } else {
      Task { await send(action.command, title: action.title) }
    }
  }

  /// The operator's yes to `question`. Only the question still open is accepted: it is closed in
  /// the same step, and its own command (never another) goes to `send`, which checks again that
  /// commands are on. A withdrawn, replaced or already answered question sends nothing, so one
  /// question sends at most once. Returns the send, or nil when nothing is sent.
  /// A Stop bot asked with positions open is answered with a mode (Close and stop, Leave open)
  /// and sends it; without one it sends nothing.
  @discardableResult
  func accept(_ question: PendingConfirmation, mode: StopMode? = nil) -> Task<Void, Never>? {
    guard confirming == question else { return nil }
    let command: OperatorCommand
    switch (question.stop, mode) {
    case (.confirm, _): command = question.action.command
    case (.choose, let mode?): command = .stopBotMode(mode)
    case (.choose, nil): return nil
    }
    confirming = nil
    return Task { await send(command, title: question.action.title) }
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

  /// Sends `command` once. Right before the send the status is read again (not the last poll),
  /// and nothing is sent unless that very read answered, on this connection, with a current
  /// status (backlog A4). The send carries one idempotency key per decision; a lost answer keeps
  /// it, says the outcome is unknown and is settled by the API's receipt, never by a send under a
  /// new key (backlog A3).
  public func send(_ command: OperatorCommand, title: String) async {
    // A confirmation alert can stay open while the status goes stale or the day changes:
    // check again at the moment of sending, never trust the state the alert was opened in.
    guard commandsEnabled else {
      show(SentCommand(id: UUID().uuidString, kind: command.kind, title: title, outcome: .refused,
        cause: String(localized: L10n.Bot.notSentUntrusted), warning: nil))
      return
    }
    // One send of a command at a time across both iPad layouts' models (`CommandKeyStore`).
    guard keyStore.begin(command) else {
      show(SentCommand(id: UUID().uuidString, kind: command.kind, title: title, outcome: .refused,
        cause: String(localized: L10n.Bot.alreadySending), warning: nil))
      return
    }
    let asked = link
    sending = true
    inFlight = command
    withdrawIfCommandsOff()
    defer {
      sending = false
      inFlight = nil
      keyStore.end(command)
    }
    // The owner first (iPad), while the buttons wait; the status read below comes after it, on
    // the connection the command was pressed on.
    if let ownerCheck {
      guard await ownerCheck(command, title) else {
        show(SentCommand(id: UUID().uuidString, kind: command.kind, title: title, outcome: .refused,
          cause: String(localized: L10n.Bot.ownerNotConfirmed), warning: nil))
        return
      }
    }
    guard await refreshStatus(), asked == link else {
      show(SentCommand(id: UUID().uuidString, kind: command.kind, title: title, outcome: .refused,
        cause: String(localized: L10n.Bot.notSentUntrusted), warning: nil))
      return
    }
    let key = keys.key(for: command, now: now(), keepSeconds: keepSeconds)
    // A kept key too old to reuse is left behind: this press is a new decision.
    if let old = keys.unknown[command]?.key, old != key { lostTitles[old] = nil }
    let sentAt = now()
    let outcome = await CommandSend.send(command, key: key, client: client)
    guard asked == link else { return }
    switch outcome {
    case .queued(let accepted):
      keys.settled(command)
      lostTitles[key] = nil
      queued(accepted, title: title)
    case .refused(let cause):
      keys.settled(command)
      lostTitles[key] = nil
      show(SentCommand(id: UUID().uuidString, kind: command.kind, title: title, outcome: .refused,
        cause: String(localized: L10n.Bot.notSent(cause)), warning: nil))
    case .unknown(let cause):
      keys.lost(command, key: key, at: sentAt)
      lostTitles[key] = title
      show(SentCommand(id: key, kind: command.kind, title: title, outcome: nil, cause: cause, warning: nil,
        unknown: true))
    }
    await refreshStatus()
  }

  /// A queued command: kept until its outcome appears in the status, and shown.
  private func queued(_ accepted: CommandAcceptedV1, title: String) {
    let record = SentCommand(id: accepted.command.commandId, kind: accepted.command.kind, title: title,
      outcome: nil, cause: nil, warning: accepted.warning)
    sent.insert(record, at: 0)
    entryWatch.queued(accepted.command)
    show(record)
  }

  /// How long a lost send's key is kept: the bot's command age limit, nil while it is not known.
  private var keepSeconds: Decimal? { settings?.commandMaxAgeSeconds?.value }

  /// Reads the receipt of every send whose answer was lost, after a good status read: queued goes
  /// on as any queued command, not queued is shown and its key dropped; a receipt that cannot be
  /// read leaves it unknown until the next read. A key past the bot's command age, or one whose
  /// receipt the API cannot serve, is dropped and shown as not known, to check the status before
  /// sending again. Not while a send is under way, which settles its own command.
  private func settleLost() async {
    guard !sending, keyStore.sending.isEmpty else { return }
    let before = keys.unknown
    for command in keys.expire(now: now(), keepSeconds: keepSeconds) {
      if let key = before[command]?.key { notKnown(command, key: key) }
    }
    let asked = link
    for (command, kept) in keys.unknown {
      let key = kept.key
      let outcome = await CommandSend.receipt(key: key, client: client)
      guard asked == link, keys.unknown[command] == kept else { return }
      let title = lostTitles[key] ?? Board.commandTitle(command.kind)
      switch outcome {
      case .queued(let accepted):
        keys.settled(command)
        lostTitles[key] = nil
        queued(accepted, title: title)
      case .notQueued:
        keys.settled(command)
        lostTitles[key] = nil
        show(SentCommand(id: key, kind: command.kind, title: title, outcome: .refused,
          cause: String(localized: L10n.Bot.notQueued), warning: nil))
      case .unserved:
        keys.settled(command)
        notKnown(command, key: key)
      case .unknown:
        continue
      }
    }
  }

  /// A lost send whose outcome can no longer be read: shown so, its key already dropped.
  private func notKnown(_ command: OperatorCommand, key: String) {
    let title = lostTitles.removeValue(forKey: key) ?? Board.commandTitle(command.kind)
    show(SentCommand(id: key, kind: command.kind, title: title, outcome: .refused,
      cause: String(localized: L10n.Bot.outcomeNotKnown), warning: nil))
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

/// What the Mac read of one past day: its trades and every other part the screens show of it
/// (`AppModel.pastDays`). A part not read yet is nil.
struct DayParts: Sendable {
  var document: DayV1?
  var flow: FlowV1?
  var watching: WatchingV1?
  var symbols: SymbolsV1?
  var movers: MoversV1?
  var skipped: SkippedV1?
  var events: DayEventsV1?
  var performance: PerformanceV1?
}
