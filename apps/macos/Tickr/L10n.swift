import Foundation
import TickrKit

/// Every text of the macOS app that a person reads, in English, with its Spanish translation in
/// Localizable.xcstrings beside this file (docs/design-system.md, rule 2). Views pass these to
/// `Text` and the components, or read them with `String(localized:)`. Generated keys are
/// `<namespace>.<name>`.
enum L10n {
  /// Where the String Catalog is: the package's resource bundle in a `swift build` (in the
  /// language given at launch, if any: `StringsBundle`), the app bundle in the Xcode build. Read
  /// once, at the first text.
  static let bundle: LocalizedStringResource.BundleDescription = {
    #if SWIFT_PACKAGE
    return StringsBundle.description(of: .module)
    #else
    return .main
    #endif
  }()

  enum About {
    static var tagline: LocalizedStringResource {
      LocalizedStringResource("about.tagline", defaultValue: "Intraday trading bot for US stocks.", bundle: L10n.bundle)
    }
    static var source: LocalizedStringResource {
      LocalizedStringResource("about.source", defaultValue: "Source code on GitHub", bundle: L10n.bundle)
    }
  }

  enum App {
    static var about: LocalizedStringResource {
      LocalizedStringResource("app.about", defaultValue: "About Tickr", bundle: L10n.bundle)
    }
    static var name: LocalizedStringResource {
      LocalizedStringResource("app.name", defaultValue: "Tickr", bundle: L10n.bundle)
    }
    static var dayMenu: LocalizedStringResource {
      LocalizedStringResource("app.dayMenu", defaultValue: "Day", bundle: L10n.bundle)
    }
    static var previousTradingDay: LocalizedStringResource {
      LocalizedStringResource("app.previousTradingDay", defaultValue: "Previous Trading Day", bundle: L10n.bundle)
    }
    static var nextTradingDay: LocalizedStringResource {
      LocalizedStringResource("app.nextTradingDay", defaultValue: "Next Trading Day", bundle: L10n.bundle)
    }
    static var openApp: LocalizedStringResource {
      LocalizedStringResource("app.openApp", defaultValue: "Open Tickr", bundle: L10n.bundle)
    }
    static var settings: LocalizedStringResource {
      LocalizedStringResource("app.settings", defaultValue: "Settings…", bundle: L10n.bundle)
    }
    static var quit: LocalizedStringResource {
      LocalizedStringResource("app.quit", defaultValue: "Quit", bundle: L10n.bundle)
    }
  }

  enum Common {
    /// VoiceOver's name of a skeleton (`Skeleton`) while a card's data is read.
    static var loading: LocalizedStringResource {
      LocalizedStringResource("common.loading", defaultValue: "Loading…", bundle: L10n.bundle)
    }
    /// Hint of a row or chip that opens the Chart on its symbol.
    static func openOnChart(_ symbol: String) -> LocalizedStringResource {
      LocalizedStringResource("common.openOnChart", defaultValue: "Opens \(symbol) on the chart", bundle: L10n.bundle)
    }
    static var today: LocalizedStringResource {
      LocalizedStringResource("common.today", defaultValue: "Today", bundle: L10n.bundle)
    }
    static func recordedDay(_ day: String) -> LocalizedStringResource {
      LocalizedStringResource("common.recordedDay", defaultValue: "Recorded day · \(day)", bundle: L10n.bundle)
    }
    static func strategyVersion(_ name: String, _ version: String) -> LocalizedStringResource {
      LocalizedStringResource("common.strategyVersion", defaultValue: "\(name) v\(version)", bundle: L10n.bundle)
    }
    /// The running strategy and the bot code version (short commit) it runs on.
    static func strategyCode(_ name: String, _ version: String, _ code: String) -> LocalizedStringResource {
      LocalizedStringResource("common.strategyCode", defaultValue: "\(name) v\(version) · code \(code)", bundle: L10n.bundle)
    }
    static var bot: LocalizedStringResource {
      LocalizedStringResource("common.bot", defaultValue: "Bot", bundle: L10n.bundle)
    }
    static var cancel: LocalizedStringResource {
      LocalizedStringResource("common.cancel", defaultValue: "Cancel", bundle: L10n.bundle)
    }
    static var none: LocalizedStringResource {
      LocalizedStringResource("common.none", defaultValue: "none", bundle: L10n.bundle)
    }
    static var on: LocalizedStringResource {
      LocalizedStringResource("common.on", defaultValue: "on", bundle: L10n.bundle)
    }
    static var off: LocalizedStringResource {
      LocalizedStringResource("common.off", defaultValue: "off", bundle: L10n.bundle)
    }
    static var unavailable: LocalizedStringResource {
      LocalizedStringResource("common.unavailable", defaultValue: "unavailable", bundle: L10n.bundle)
    }
    static var noPosition: LocalizedStringResource {
      LocalizedStringResource("common.noPosition", defaultValue: "no position", bundle: L10n.bundle)
    }
    static func fences(_ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("common.fences", defaultValue: "\(count) fences", bundle: L10n.bundle)
    }
    static func countOf(_ count: Int, _ limit: Int) -> LocalizedStringResource {
      LocalizedStringResource("common.countOf", defaultValue: "\(count) of \(limit)", bundle: L10n.bundle)
    }
    static var entriesPaused: LocalizedStringResource {
      LocalizedStringResource("common.entriesPaused", defaultValue: "entries paused", bundle: L10n.bundle)
    }
    static var strategy: LocalizedStringResource {
      LocalizedStringResource("common.strategy", defaultValue: "Strategy", bundle: L10n.bundle)
    }
    static var risk: LocalizedStringResource {
      LocalizedStringResource("common.risk", defaultValue: "Risk", bundle: L10n.bundle)
    }
    static var tradesAndDaysHint: LocalizedStringResource {
      LocalizedStringResource("common.tradesAndDaysHint",
        defaultValue: "The result appears in Trades & days.",
        bundle: L10n.bundle)
    }
  }

  enum Format {
    static var never: LocalizedStringResource {
      LocalizedStringResource("format.never", defaultValue: "never", bundle: L10n.bundle)
    }
    /// Argument: how long ago (TickrKit `Elapsed`, "3 s", "2 d").
    static func ago(_ age: String) -> LocalizedStringResource {
      LocalizedStringResource("format.ago", defaultValue: "\(age) ago", bundle: L10n.bundle)
    }
    static func seconds(_ value: String) -> LocalizedStringResource {
      LocalizedStringResource("format.seconds", defaultValue: "\(value) s", bundle: L10n.bundle)
    }
  }

  enum Stream {
    static var fresh: LocalizedStringResource {
      LocalizedStringResource("stream.fresh", defaultValue: "fresh", bundle: L10n.bundle)
    }
    static var quiet: LocalizedStringResource {
      LocalizedStringResource("stream.quiet", defaultValue: "quiet", bundle: L10n.bundle)
    }
    static var lost: LocalizedStringResource {
      LocalizedStringResource("stream.lost", defaultValue: "lost", bundle: L10n.bundle)
    }
    static var off: LocalizedStringResource {
      LocalizedStringResource("stream.off", defaultValue: "off", bundle: L10n.bundle)
    }
  }

  enum BotState {
    static var starting: LocalizedStringResource {
      LocalizedStringResource("botState.starting", defaultValue: "starting", bundle: L10n.bundle)
    }
    static var running: LocalizedStringResource {
      LocalizedStringResource("botState.running", defaultValue: "running", bundle: L10n.bundle)
    }
    static var stopping: LocalizedStringResource {
      LocalizedStringResource("botState.stopping", defaultValue: "stopping", bundle: L10n.bundle)
    }
    static var stopped: LocalizedStringResource {
      LocalizedStringResource("botState.stopped", defaultValue: "stopped", bundle: L10n.bundle)
    }
  }

  enum Stop {
    static var verified: LocalizedStringResource {
      LocalizedStringResource("stop.verified", defaultValue: "Stop ✓", bundle: L10n.bundle)
    }
    static var pending: LocalizedStringResource {
      LocalizedStringResource("stop.pending", defaultValue: "Stop pending", bundle: L10n.bundle)
    }
    static var missing: LocalizedStringResource {
      LocalizedStringResource("stop.missing", defaultValue: "No stop", bundle: L10n.bundle)
    }
    static var unknown: LocalizedStringResource {
      LocalizedStringResource("stop.unknown", defaultValue: "Stop unknown", bundle: L10n.bundle)
    }
  }

  enum Planned {
    static var backlog: LocalizedStringResource {
      LocalizedStringResource("planned.backlog", defaultValue: "BACKLOG", bundle: L10n.bundle)
    }
    static var backlogHelp: LocalizedStringResource {
      LocalizedStringResource("planned.backlogHelp",
        defaultValue: "Planned, not built yet (docs/backlog.md).",
        bundle: L10n.bundle)
    }
  }

  enum Bot {
    /// A command confirmation's message with where the command goes: the demo day.
    static func confirmToDemo(_ explanation: String) -> LocalizedStringResource {
      LocalizedStringResource("bot.confirmToDemo",
        defaultValue: "\(explanation)\n\nDEMO day: nothing is sent, the app only plays its recording.", bundle: L10n.bundle)
    }
    /// A command confirmation's message with where the command goes: the real bot.
    static func confirmToBot(_ explanation: String) -> LocalizedStringResource {
      LocalizedStringResource("bot.confirmToBot", defaultValue: "\(explanation)\n\nSent to: the bot.", bundle: L10n.bundle)
    }
    static var pauseEntries: LocalizedStringResource {
      LocalizedStringResource("bot.pauseEntries", defaultValue: "Pause entries", bundle: L10n.bundle)
    }
    static var resumeEntries: LocalizedStringResource {
      LocalizedStringResource("bot.resumeEntries", defaultValue: "Resume entries", bundle: L10n.bundle)
    }
    static func flatten(_ symbol: String) -> LocalizedStringResource {
      LocalizedStringResource("bot.flatten", defaultValue: "Close \(symbol) position", bundle: L10n.bundle)
    }
    static var flattenAll: LocalizedStringResource {
      LocalizedStringResource("bot.flattenAll", defaultValue: "Close all", bundle: L10n.bundle)
    }
    static var stopBot: LocalizedStringResource {
      LocalizedStringResource("bot.stopBot", defaultValue: "Stop bot", bundle: L10n.bundle)
    }
    static var pauseQuestion: LocalizedStringResource {
      LocalizedStringResource("bot.pauseQuestion", defaultValue: "Pause new entries?", bundle: L10n.bundle)
    }
    static var resumeQuestion: LocalizedStringResource {
      LocalizedStringResource("bot.resumeQuestion", defaultValue: "Resume new entries?", bundle: L10n.bundle)
    }
    static func flattenQuestion(_ symbol: String) -> LocalizedStringResource {
      LocalizedStringResource("bot.flattenQuestion", defaultValue: "Close the \(symbol) position?", bundle: L10n.bundle)
    }
    static var flattenAllQuestion: LocalizedStringResource {
      LocalizedStringResource("bot.flattenAllQuestion", defaultValue: "Close all positions?", bundle: L10n.bundle)
    }
    static var stopQuestion: LocalizedStringResource {
      LocalizedStringResource("bot.stopQuestion", defaultValue: "Stop the bot?", bundle: L10n.bundle)
    }
    static var pauseExplanation: LocalizedStringResource {
      LocalizedStringResource("bot.pauseExplanation",
        defaultValue: "The bot opens no new positions until you resume. Open positions keep their broker stops.",
        bundle: L10n.bundle)
    }
    static var resumeExplanation: LocalizedStringResource {
      LocalizedStringResource("bot.resumeExplanation",
        defaultValue: "Clears only your entry pause. Other blocks (risk, reconciliation, session) still apply.",
        bundle: L10n.bundle)
    }
    static var flattenExplanation: LocalizedStringResource {
      LocalizedStringResource("bot.flattenExplanation",
        defaultValue: "The bot cancels the stop, reads the held quantity again and sells it through the normal exit.",
        bundle: L10n.bundle)
    }
    /// What Close all does (the API's emergency command), in its confirmation and its hint.
    static var closeAllExplanation: LocalizedStringResource {
      LocalizedStringResource("bot.closeAllExplanation",
        // swiftlint:disable:next line_length
        defaultValue: "The bot pauses entries, cancels its working entry orders and closes every position at market, so it does not enter again. Resume entries when you are ready.",
        bundle: L10n.bundle)
    }
    static var stopExplanation: LocalizedStringResource {
      LocalizedStringResource("bot.stopExplanation",
        // swiftlint:disable:next line_length
        defaultValue: "The bot stops and stays stopped, also tomorrow, until you press Start bot. Refused while a trade is open or entering: close it first.",
        bundle: L10n.bundle)
    }
    /// The pill on every command while commands go to the demo day.
    static var demoTag: LocalizedStringResource {
      LocalizedStringResource("bot.demoTag", defaultValue: "Demo", bundle: L10n.bundle)
    }
    /// Why a close command is off: there is no open position.
    static var noPositions: LocalizedStringResource {
      LocalizedStringResource("bot.noPositions", defaultValue: "No open positions", bundle: L10n.bundle)
    }
    static var stoppedTitle: LocalizedStringResource {
      LocalizedStringResource("bot.stoppedTitle", defaultValue: "Bot Stopped with Open Positions", bundle: L10n.bundle)
    }
    static func stoppedOpen(_ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("bot.stoppedOpen",
        // swiftlint:disable:next line_length
        defaultValue: "Open positions: \(count). Each stays under its broker stop, a DAY order: nothing closes it at the session's end. Close them in Webull, or run tickr clear-stop on this Mac and start the bot to trade again.",
        bundle: L10n.bundle)
    }
    static var silentTitle: LocalizedStringResource {
      LocalizedStringResource("bot.silentTitle", defaultValue: "Bot Not Responding with Open Positions", bundle: L10n.bundle)
    }
    static func silentOpen(_ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("bot.silentOpen",
        // swiftlint:disable:next line_length
        defaultValue: "Open positions: \(count). The bot's status is stale: it may have stopped. Each position stays under its broker stop, a DAY order: nothing closes it at the session's end. Check the bot on this Mac or close the positions in Webull.",
        bundle: L10n.bundle)
    }
    static var ownerNotConfirmed: LocalizedStringResource {
      LocalizedStringResource("bot.ownerNotConfirmed",
        defaultValue: "not sent: Face ID or the passcode did not confirm the owner",
        bundle: L10n.bundle)
    }
    static var alreadySending: LocalizedStringResource {
      LocalizedStringResource("bot.alreadySending",
        defaultValue: "not sent: this command is already being sent",
        bundle: L10n.bundle)
    }
    static var notSentUntrusted: LocalizedStringResource {
      LocalizedStringResource("bot.notSentUntrusted",
        defaultValue: "not sent: the app cannot trust the bot's status right now",
        bundle: L10n.bundle)
    }
    static func notSent(_ reason: String) -> LocalizedStringResource {
      LocalizedStringResource("bot.notSent", defaultValue: "not sent: \(reason)", bundle: L10n.bundle)
    }
    /// The receipt of a send whose answer was lost says it never reached the queue.
    static var notQueued: LocalizedStringResource {
      LocalizedStringResource("bot.notQueued",
        defaultValue: "not queued: the bot's API never received it. Send it again if you still want it.",
        bundle: L10n.bundle)
    }
    /// A send whose answer was lost and whose outcome can no longer be read (too old, or no receipts).
    static var outcomeNotKnown: LocalizedStringResource {
      LocalizedStringResource("bot.outcomeNotKnown",
        defaultValue: "whether it was queued is not known. Check the bot's status before sending it again.",
        bundle: L10n.bundle)
    }
  }

  enum Menu {
    static var noOpenPosition: LocalizedStringResource {
      LocalizedStringResource("menu.noOpenPosition", defaultValue: "No open position", bundle: L10n.bundle)
    }
  }

  enum Section {
    static var overview: LocalizedStringResource {
      LocalizedStringResource("section.overview", defaultValue: "Overview", bundle: L10n.bundle)
    }
    static var chart: LocalizedStringResource {
      LocalizedStringResource("section.chart", defaultValue: "Chart", bundle: L10n.bundle)
    }
    static var trades: LocalizedStringResource {
      LocalizedStringResource("section.trades", defaultValue: "Trades & days", bundle: L10n.bundle)
    }
    static var risk: LocalizedStringResource {
      LocalizedStringResource("section.risk", defaultValue: "Risk & account", bundle: L10n.bundle)
    }
    static var lab: LocalizedStringResource {
      LocalizedStringResource("section.lab", defaultValue: "Model lab", bundle: L10n.bundle)
    }
  }

  enum Root {
    static var apiUnreachable: LocalizedStringResource {
      LocalizedStringResource("root.apiUnreachable", defaultValue: "No connection", bundle: L10n.bundle)
    }
    static var connecting: LocalizedStringResource {
      LocalizedStringResource("root.connecting", defaultValue: "connecting…", bundle: L10n.bundle)
    }
    static func stale(_ state: String) -> LocalizedStringResource {
      LocalizedStringResource("root.stale", defaultValue: "stale (\(state))", bundle: L10n.bundle)
    }
    static func statePaused(_ state: String) -> LocalizedStringResource {
      LocalizedStringResource("root.statePaused", defaultValue: "\(state) · entries paused", bundle: L10n.bundle)
    }
    /// The bot card's time since the bot started ("running for 15h 54m").
    static func uptime(_ duration: String) -> LocalizedStringResource {
      LocalizedStringResource("root.uptime", defaultValue: "running for \(duration)", bundle: L10n.bundle)
    }
    /// The bot card's run: the start of the run's id ("run f17747de").
    static func run(_ id: String) -> LocalizedStringResource {
      LocalizedStringResource("root.run", defaultValue: "run \(id)", bundle: L10n.bundle)
    }
  }

  enum Toolbar {
    /// The iPad navigation bar's gear: the iPad's settings (connection, pairing, notifications).
    static var settings: LocalizedStringResource {
      LocalizedStringResource("toolbar.settings", defaultValue: "Settings", bundle: L10n.bundle)
    }
    /// The title bar's line before the first status.
    static var windowLineEmpty: LocalizedStringResource {
      LocalizedStringResource("toolbar.windowLineEmpty", defaultValue: "tickr", bundle: L10n.bundle)
    }
    /// The day stepper's label on the live day ("Mon, Nov 16 · today").
    static func dayToday(_ day: String) -> LocalizedStringResource {
      LocalizedStringResource("toolbar.dayToday", defaultValue: "\(day) · today", bundle: L10n.bundle)
    }
    /// The demo day's label in the title bar: made up, so never "today"; argument: its date.
    static func dayDemo(_ day: String) -> LocalizedStringResource {
      LocalizedStringResource("toolbar.dayDemo", defaultValue: "\(day) · demo day", bundle: L10n.bundle)
    }
    static var previousDay: LocalizedStringResource {
      LocalizedStringResource("toolbar.previousDay", defaultValue: "Previous Day", bundle: L10n.bundle)
    }
    static var previousDayHelp: LocalizedStringResource {
      LocalizedStringResource("toolbar.previousDayHelp", defaultValue: "Previous trading day (⌘[)", bundle: L10n.bundle)
    }
    static var nextDay: LocalizedStringResource {
      LocalizedStringResource("toolbar.nextDay", defaultValue: "Next Day", bundle: L10n.bundle)
    }
    static var nextDayHelp: LocalizedStringResource {
      LocalizedStringResource("toolbar.nextDayHelp", defaultValue: "Next trading day (⌘])", bundle: L10n.bundle)
    }
    /// The day picker's heading over its days (`TradingDaysPopover`).
    static var tradingDays: LocalizedStringResource {
      LocalizedStringResource("toolbar.tradingDays", defaultValue: "Trading days", bundle: L10n.bundle)
    }
    /// The tag on the newest recorded trading day.
    static var lastDay: LocalizedStringResource {
      LocalizedStringResource("toolbar.lastDay", defaultValue: "Last", bundle: L10n.bundle)
    }
    /// A trading day without a trade, under its date.
    static var noTrades: LocalizedStringResource {
      LocalizedStringResource("toolbar.noTrades", defaultValue: "No trades", bundle: L10n.bundle)
    }
    /// The day picker's footer row, to Trades & days.
    static var showAllDays: LocalizedStringResource {
      LocalizedStringResource("toolbar.showAllDays", defaultValue: "Show all trading days", bundle: L10n.bundle)
    }
    static var pickDayHelp: LocalizedStringResource {
      LocalizedStringResource("toolbar.pickDayHelp", defaultValue: "Pick a recorded trading day", bundle: L10n.bundle)
    }
    static var demoHelp: LocalizedStringResource {
      LocalizedStringResource("toolbar.demoHelp",
        defaultValue: "Demo day: the made-up day only. Turn it off in Settings › General to pick another day.",
        bundle: L10n.bundle)
    }
    static var todayHelp: LocalizedStringResource {
      LocalizedStringResource("toolbar.todayHelp", defaultValue: "Back to the live day (⌘T)", bundle: L10n.bundle)
    }
  }

  enum Toast {
    static func queued(_ title: String) -> LocalizedStringResource {
      LocalizedStringResource("toast.queued", defaultValue: "\(title) queued for the bot", bundle: L10n.bundle)
    }
    static func done(_ title: String) -> LocalizedStringResource {
      LocalizedStringResource("toast.done", defaultValue: "\(title): done", bundle: L10n.bundle)
    }
    static func refused(_ title: String) -> LocalizedStringResource {
      LocalizedStringResource("toast.refused", defaultValue: "\(title): refused", bundle: L10n.bundle)
    }
    static func warning(_ warning: String) -> LocalizedStringResource {
      LocalizedStringResource("toast.warning", defaultValue: "Warning: \(warning)", bundle: L10n.bundle)
    }
    /// A send whose answer was lost (backlog A3).
    static func unknown(_ title: String) -> LocalizedStringResource {
      LocalizedStringResource("toast.unknown", defaultValue: "\(title): no answer from the bot's API", bundle: L10n.bundle)
    }
    static func unknownDetail(_ cause: String) -> LocalizedStringResource {
      LocalizedStringResource("toast.unknownDetail",
        defaultValue: "\(cause). Checking whether it was queued; pressing it again cannot queue it twice.",
        bundle: L10n.bundle)
    }
    static var resultLater: LocalizedStringResource {
      LocalizedStringResource("toast.resultLater",
        defaultValue: "The result appears here when the bot has handled it.",
        bundle: L10n.bundle)
    }
  }

  enum Overview {
    /// Under the day's result while it does not count the broker's fees yet.
    static var beforeFees: LocalizedStringResource {
      LocalizedStringResource("overview.beforeFees", defaultValue: "before broker fees", bundle: L10n.bundle)
    }
    static var recordedDetail: LocalizedStringResource {
      LocalizedStringResource("overview.recordedDetail",
        defaultValue: "Read-only view from the bot's records. Commands are off.",
        bundle: L10n.bundle)
    }
    static var dayResult: LocalizedStringResource {
      LocalizedStringResource("overview.dayResult", defaultValue: "Day result", bundle: L10n.bundle)
    }
    /// VoiceOver's day result while it is not known (shown as a dash): no zeros it does not know.
    static var dayResultUnavailable: LocalizedStringResource {
      LocalizedStringResource("overview.dayResultUnavailable", defaultValue: "Day result: no data yet",
        bundle: L10n.bundle)
    }
    static func dayCounts(_ closed: Int, _ wins: Int, _ losses: Int) -> LocalizedStringResource {
      LocalizedStringResource("overview.dayCounts",
        defaultValue: "\(closed) trades · \(wins) W · \(losses) L",
        bundle: L10n.bundle)
    }
    static func openResult(_ result: String) -> LocalizedStringResource {
      LocalizedStringResource("overview.openResult", defaultValue: " · open \(result)", bundle: L10n.bundle)
    }
  }

  enum Flow {
    static func more(_ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("flow.more", defaultValue: "+\(count)", bundle: L10n.bundle)
    }
    /// Accessibility hint of a live-flow stage: a click opens its detail.
    static var stageDetailsHint: LocalizedStringResource {
      // swiftlint:disable:next line_length
      LocalizedStringResource("flow.stageDetailsHint", defaultValue: "Shows every symbol at this stage today", bundle: L10n.bundle)
    }
    /// Pipeline stage: a fresh quote and the strategy's spread rule.
    static var quote: LocalizedStringResource {
      LocalizedStringResource("flow.quote", defaultValue: "Quote", bundle: L10n.bundle)
    }
    /// Pipeline stage: minute bars and the strategy's dollar volume rule.
    static var bars: LocalizedStringResource {
      LocalizedStringResource("flow.bars", defaultValue: "Bars", bundle: L10n.bundle)
    }
    static var title: LocalizedStringResource {
      LocalizedStringResource("flow.title",
        defaultValue: "Live flow · screeners → strategy → risk → order → broker stop",
        bundle: L10n.bundle)
    }
    /// The flow card's title on a recorded day: nothing on it is live.
    static var titleRecorded: LocalizedStringResource {
      LocalizedStringResource("flow.titleRecorded",
        defaultValue: "Flow · screeners → strategy → risk → order → broker stop",
        bundle: L10n.bundle)
    }
    static var recorded: LocalizedStringResource {
      LocalizedStringResource("flow.recorded", defaultValue: "recorded", bundle: L10n.bundle)
    }
    static var quietTag: LocalizedStringResource {
      LocalizedStringResource("flow.quietTag", defaultValue: "QUIET", bundle: L10n.bundle)
    }
    static var nothingYet: LocalizedStringResource {
      LocalizedStringResource("flow.nothingYet", defaultValue: "nothing recorded yet today", bundle: L10n.bundle)
    }
    static var screeners: LocalizedStringResource {
      LocalizedStringResource("flow.screeners", defaultValue: "Screeners", bundle: L10n.bundle)
    }
    static var universe: LocalizedStringResource {
      LocalizedStringResource("flow.universe", defaultValue: "Universe", bundle: L10n.bundle)
    }
    static var order: LocalizedStringResource {
      LocalizedStringResource("flow.order", defaultValue: "Order", bundle: L10n.bundle)
    }
    static var brokerStop: LocalizedStringResource {
      LocalizedStringResource("flow.brokerStop", defaultValue: "Broker stop", bundle: L10n.bundle)
    }
    static var reconcile: LocalizedStringResource {
      LocalizedStringResource("flow.reconcile", defaultValue: "Reconcile", bundle: L10n.bundle)
    }
    static var entriesAllowed: LocalizedStringResource {
      LocalizedStringResource("flow.entriesAllowed", defaultValue: "entries allowed", bundle: L10n.bundle)
    }
    static var blocked: LocalizedStringResource {
      LocalizedStringResource("flow.blocked", defaultValue: "blocked", bundle: L10n.bundle)
    }
    /// Risk stage value while entries wait for an ordinary reason (a trade is open, outside the window).
    static var waiting: LocalizedStringResource {
      LocalizedStringResource("flow.waiting", defaultValue: "not now", bundle: L10n.bundle)
    }
    static func closedCount(_ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("flow.closedCount", defaultValue: "\(count) closed", bundle: L10n.bundle)
    }
    static var match: LocalizedStringResource {
      LocalizedStringResource("flow.match", defaultValue: "match", bundle: L10n.bundle)
    }
    /// A live-flow chip's screener, as the design names it.
    static var chipGainers: LocalizedStringResource {
      LocalizedStringResource("flow.chipGainers", defaultValue: "gainers", bundle: L10n.bundle)
    }
    static var chipLosers: LocalizedStringResource {
      LocalizedStringResource("flow.chipLosers", defaultValue: "losers", bundle: L10n.bundle)
    }
    static var chipActives: LocalizedStringResource {
      LocalizedStringResource("flow.chipActives", defaultValue: "actives", bundle: L10n.bundle)
    }
    /// A live-flow chip the universe left out.
    static var chipSkipped: LocalizedStringResource {
      LocalizedStringResource("flow.chipSkipped", defaultValue: "skipped", bundle: L10n.bundle)
    }
    /// A live-flow chip's screener and change from the previous close: "gainers +21.3%".
    static func chipChange(_ source: String, _ change: String) -> LocalizedStringResource {
      LocalizedStringResource("flow.chipChange", defaultValue: "\(source) \(change)%", bundle: L10n.bundle)
    }
    static var notReported: LocalizedStringResource {
      LocalizedStringResource("flow.notReported",
        defaultValue: "Not reported by the local API yet.",
        bundle: L10n.bundle)
    }
  }

  enum Position {
    static var openChart: LocalizedStringResource {
      LocalizedStringResource("position.openChart", defaultValue: "Open chart", bundle: L10n.bundle)
    }
    static var picker: LocalizedStringResource {
      LocalizedStringResource("position.picker", defaultValue: "Position", bundle: L10n.bundle)
    }
    static func titleOfLimit(_ count: Int, _ limit: Int) -> LocalizedStringResource {
      LocalizedStringResource("position.titleOfLimit",
        defaultValue: "Positions \(count) of \(limit)",
        bundle: L10n.bundle)
    }
    /// The Positions card title while nothing was ever read: no count we do not know.
    static var titleUnknown: LocalizedStringResource {
      LocalizedStringResource("position.titleUnknown", defaultValue: "Positions", bundle: L10n.bundle)
    }
    static func title(_ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("position.title", defaultValue: "Positions \(count)", bundle: L10n.bundle)
    }
    static var unrealized: LocalizedStringResource {
      LocalizedStringResource("position.unrealized", defaultValue: "unrealized", bundle: L10n.bundle)
    }
    static var stop: LocalizedStringResource {
      LocalizedStringResource("position.stop", defaultValue: "stop", bundle: L10n.bundle)
    }
    static var maxLoss: LocalizedStringResource {
      LocalizedStringResource("position.maxLoss", defaultValue: "max loss", bundle: L10n.bundle)
    }
    static func lastBarCloseAt(_ time: String) -> LocalizedStringResource {
      LocalizedStringResource("position.lastBarCloseAt", defaultValue: "last bar close · \(time)", bundle: L10n.bundle)
    }
    static var lastBarClose: LocalizedStringResource {
      LocalizedStringResource("position.lastBarClose", defaultValue: "last bar close", bundle: L10n.bundle)
    }
    static var bid: LocalizedStringResource {
      LocalizedStringResource("position.bid", defaultValue: "bid, live", bundle: L10n.bundle)
    }
    /// Tooltip of a position's price and R when the newest captured bar is not current.
    static func staleHelp(_ time: String) -> LocalizedStringResource {
      LocalizedStringResource("position.staleHelp",
        defaultValue: "No bar since \(time): the price and R are as of then.", bundle: L10n.bundle)
    }
    /// Tooltip of max loss: why it can differ from the daily limit's reservation.
    static var maxLossHelp: LocalizedStringResource {
      LocalizedStringResource("position.maxLossHelp",
        // swiftlint:disable:next line_length
        defaultValue: "At the fill price. The daily loss limit reserves the planned loss at the entry order's limit price, so the reservation can be a little higher.",
        bundle: L10n.bundle)
    }
    static var chartLabel: LocalizedStringResource {
      LocalizedStringResource("position.chartLabel",
        defaultValue: "Price since entry with entry and stop lines",
        bundle: L10n.bundle)
    }
    static func entryLevel(_ price: String) -> LocalizedStringResource {
      LocalizedStringResource("position.entryLevel", defaultValue: "entry \(price)", bundle: L10n.bundle)
    }
    static func stopLevel(_ price: String) -> LocalizedStringResource {
      LocalizedStringResource("position.stopLevel", defaultValue: "stop \(price)", bundle: L10n.bundle)
    }
    static var waitingForBars: LocalizedStringResource {
      LocalizedStringResource("position.waitingForBars",
        defaultValue: "Waiting for the first bars since the entry",
        bundle: L10n.bundle)
    }
    static var noPosition: LocalizedStringResource {
      LocalizedStringResource("position.noPosition", defaultValue: "No position", bundle: L10n.bundle)
    }
    static var recordedDay: LocalizedStringResource {
      LocalizedStringResource("position.recordedDay", defaultValue: "Recorded day", bundle: L10n.bundle)
    }
    static var waitingForSetup: LocalizedStringResource {
      LocalizedStringResource("position.waitingForSetup",
        defaultValue: "The bot is waiting for a setup. A new position appears here with its broker stop.",
        bundle: L10n.bundle)
    }
    static func closedThisDay(_ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("position.closedThisDay",
        defaultValue: "\(count) trades closed this day. Details are in Trades & days.",
        bundle: L10n.bundle)
    }
    static var openTrades: LocalizedStringResource {
      LocalizedStringResource("position.openTrades", defaultValue: "Open Trades & days", bundle: L10n.bundle)
    }
  }

  enum Safety {
    static var brokerStops: LocalizedStringResource {
      LocalizedStringResource("safety.brokerStops", defaultValue: "Broker stops", bundle: L10n.bundle)
    }
    static func verified(_ verified: Int, _ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("safety.verified", defaultValue: "\(verified) of \(count) verified", bundle: L10n.bundle)
    }
    static var reconciliation: LocalizedStringResource {
      LocalizedStringResource("safety.reconciliation", defaultValue: "Broker matches our records", bundle: L10n.bundle)
    }
    static var noFences: LocalizedStringResource {
      LocalizedStringResource("safety.noFences", defaultValue: "no fences", bundle: L10n.bundle)
    }
    static var quoteStream: LocalizedStringResource {
      LocalizedStringResource("safety.quoteStream", defaultValue: "Live prices", bundle: L10n.bundle)
    }
    static var lastBrokerRead: LocalizedStringResource {
      LocalizedStringResource("safety.lastBrokerRead", defaultValue: "Last broker check", bundle: L10n.bundle)
    }
    /// Safety tile: positions or orders at the broker that the bot did not place.
    static var foreignAtBroker: LocalizedStringResource {
      LocalizedStringResource("safety.foreignAtBroker", defaultValue: "Positions or orders not ours", bundle: L10n.bundle)
    }
    static var present: LocalizedStringResource {
      LocalizedStringResource("safety.present", defaultValue: "present", bundle: L10n.bundle)
    }
    static var offWhileRecorded: LocalizedStringResource {
      LocalizedStringResource("safety.offWhileRecorded",
        defaultValue: "Commands are off while a recorded day is shown.",
        bundle: L10n.bundle)
    }
    static var offWhileUntrusted: LocalizedStringResource {
      LocalizedStringResource("safety.offWhileUntrusted",
        defaultValue: "Commands are off while the status cannot be trusted.",
        bundle: L10n.bundle)
    }
  }

  enum RiskRoom {
    static var title: LocalizedStringResource {
      LocalizedStringResource("riskRoom.title", defaultValue: "Risk room today", bundle: L10n.bundle)
    }
    /// The card's title on a recorded day: its own result, not today's room.
    static var recordedTitle: LocalizedStringResource {
      LocalizedStringResource("riskRoom.recordedTitle", defaultValue: "Risk room", bundle: L10n.bundle)
    }
    static var limit: LocalizedStringResource {
      LocalizedStringResource("riskRoom.limit", defaultValue: "daily loss limit", bundle: L10n.bundle)
    }
    /// Foot of the card on a recorded day.
    static var recordedNote: LocalizedStringResource {
      LocalizedStringResource("riskRoom.recordedNote",
        defaultValue: "Room left, reservations and positions are live: Details shows today.", bundle: L10n.bundle)
    }
    static var details: LocalizedStringResource {
      LocalizedStringResource("riskRoom.details", defaultValue: "Details", bundle: L10n.bundle)
    }
    static var netResult: LocalizedStringResource {
      LocalizedStringResource("riskRoom.netResult", defaultValue: "net day result", bundle: L10n.bundle)
    }
    static var recordsAgree: LocalizedStringResource {
      LocalizedStringResource("riskRoom.recordsAgree", defaultValue: "records agree", bundle: L10n.bundle)
    }
    static var reading: LocalizedStringResource {
      LocalizedStringResource("riskRoom.reading", defaultValue: "Reading limits…", bundle: L10n.bundle)
    }
  }

  enum Journal {
    static var title: LocalizedStringResource {
      LocalizedStringResource("journal.title", defaultValue: "Activity", bundle: L10n.bundle)
    }
    static var latestFirst: LocalizedStringResource {
      LocalizedStringResource("journal.latestFirst", defaultValue: "latest first", bundle: L10n.bundle)
    }
    static var nothingYet: LocalizedStringResource {
      LocalizedStringResource("journal.nothingYet", defaultValue: "Nothing recorded yet today.", bundle: L10n.bundle)
    }
    static var seeTrades: LocalizedStringResource {
      LocalizedStringResource("journal.seeTrades", defaultValue: "See Trades & days for this day.", bundle: L10n.bundle)
    }
  }

  enum Settings {
    static var configuration: LocalizedStringResource {
      LocalizedStringResource("settings.configuration", defaultValue: "Configuration", bundle: L10n.bundle)
    }
    static var configTop: LocalizedStringResource {
      LocalizedStringResource("settings.configTop", defaultValue: "Top level", bundle: L10n.bundle)
    }
    static var configChangedHint: LocalizedStringResource {
      LocalizedStringResource("settings.configChangedHint",
        // swiftlint:disable:next line_length
        defaultValue: "The file differs from the one the bot's API loaded: running processes keep the old values until they restart.",
        bundle: L10n.bundle)
    }
    static var configChanged: LocalizedStringResource {
      LocalizedStringResource("settings.configChanged", defaultValue: "Changed", bundle: L10n.bundle)
    }
    static var configSame: LocalizedStringResource {
      LocalizedStringResource("settings.configSame", defaultValue: "Same as running", bundle: L10n.bundle)
    }
    static var configInvalid: LocalizedStringResource {
      LocalizedStringResource("settings.configInvalid", defaultValue: "Invalid", bundle: L10n.bundle)
    }
    static var configValid: LocalizedStringResource {
      LocalizedStringResource("settings.configValid", defaultValue: "Valid", bundle: L10n.bundle)
    }
    static func configFile(_ file: String) -> LocalizedStringResource {
      LocalizedStringResource("settings.configFile", defaultValue: "\(file) · read-only", bundle: L10n.bundle)
    }
    static var serviceStale: LocalizedStringResource {
      LocalizedStringResource("settings.serviceStale",
        defaultValue: "the status is not current, so the bot's state now is unknown",
        bundle: L10n.bundle)
    }
    static var serviceNotReported: LocalizedStringResource {
      LocalizedStringResource("settings.serviceNotReported", defaultValue: "Not reported", bundle: L10n.bundle)
    }
    static var serviceStopping: LocalizedStringResource {
      LocalizedStringResource("settings.serviceStopping",
        defaultValue: "cancelling entries, stops stay at the broker",
        bundle: L10n.bundle)
    }
    static var serviceStarting: LocalizedStringResource {
      LocalizedStringResource("settings.serviceStarting", defaultValue: "preflight running…", bundle: L10n.bundle)
    }
    static var serviceStopped: LocalizedStringResource {
      LocalizedStringResource("settings.serviceStopped",
        defaultValue: "Scheduled starts run; Start runs the preflight now",
        bundle: L10n.bundle)
    }
    static func serviceHolds(_ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("settings.serviceHolds", defaultValue: "\(count) open", bundle: L10n.bundle)
    }
    static var serviceFlat: LocalizedStringResource {
      LocalizedStringResource("settings.serviceFlat", defaultValue: "flat, nothing open", bundle: L10n.bundle)
    }
    static func startRefused(_ cause: String) -> LocalizedStringResource {
      LocalizedStringResource("settings.startRefused", defaultValue: "Not started: \(cause)", bundle: L10n.bundle)
    }
    static var startAcceptedCleared: LocalizedStringResource {
      LocalizedStringResource("settings.startAcceptedCleared",
        defaultValue: "Start requested; your earlier Stop was cleared, so scheduled starts run again.",
        bundle: L10n.bundle)
    }
    static var startAccepted: LocalizedStringResource {
      LocalizedStringResource("settings.startAccepted",
        defaultValue: "Start requested: the bot runs its preflight first.",
        bundle: L10n.bundle)
    }
    /// The question Overview's Start bot asks first (`OverviewStartButton`).
    static var startQuestion: LocalizedStringResource {
      LocalizedStringResource("settings.startQuestion", defaultValue: "Start the bot?", bundle: L10n.bundle)
    }
    /// Its explanation.
    static var startExplanation: LocalizedStringResource {
      LocalizedStringResource("settings.startExplanation",
        // swiftlint:disable:next line_length
        defaultValue: "launchd starts the bot job as on a scheduled morning: preflight first, then trading if every check passes. An earlier Stop is cleared, so scheduled starts run again.",
        bundle: L10n.bundle)
    }
    static var startBotHint: LocalizedStringResource {
      LocalizedStringResource("settings.startBotHint",
        defaultValue: "Runs the morning check, then starts the bot",
        bundle: L10n.bundle)
    }
    static var stopBotAction: LocalizedStringResource {
      LocalizedStringResource("settings.stopBotAction", defaultValue: "Stop bot", bundle: L10n.bundle)
    }
    static var startBotAction: LocalizedStringResource {
      LocalizedStringResource("settings.startBotAction", defaultValue: "Start bot", bundle: L10n.bundle)
    }
    static var general: LocalizedStringResource {
      LocalizedStringResource("settings.general", defaultValue: "General", bundle: L10n.bundle)
    }
    static var trading: LocalizedStringResource {
      LocalizedStringResource("settings.trading", defaultValue: "Trading", bundle: L10n.bundle)
    }
    static var notifications: LocalizedStringResource {
      LocalizedStringResource("settings.notifications", defaultValue: "Notifications", bundle: L10n.bundle)
    }
    static var environment: LocalizedStringResource {
      LocalizedStringResource("settings.environment", defaultValue: "Environment", bundle: L10n.bundle)
    }
    static var storage: LocalizedStringResource {
      LocalizedStringResource("settings.storage", defaultValue: "Storage", bundle: L10n.bundle)
    }
    static var advanced: LocalizedStringResource {
      LocalizedStringResource("settings.advanced", defaultValue: "Advanced", bundle: L10n.bundle)
    }
    static var configFootnote: LocalizedStringResource {
      LocalizedStringResource("settings.configFootnote",
        defaultValue: "Read-only. Change it in the config on the Mac.",
        bundle: L10n.bundle)
    }
    static var notReachable: LocalizedStringResource {
      LocalizedStringResource("settings.notReachable", defaultValue: "Not reachable", bundle: L10n.bundle)
    }
    static func connectedTo(_ address: String) -> LocalizedStringResource {
      LocalizedStringResource("settings.connectedTo", defaultValue: "Connected to \(address).", bundle: L10n.bundle)
    }
    static var menuBar: LocalizedStringResource {
      LocalizedStringResource("settings.menuBar", defaultValue: "Menu bar", bundle: L10n.bundle)
    }
    static var demoDay: LocalizedStringResource {
      LocalizedStringResource("settings.demoDay", defaultValue: "Demo day", bundle: L10n.bundle)
    }
    static var demoDayExplanation: LocalizedStringResource {
      LocalizedStringResource("settings.demoDayExplanation",
        defaultValue: "Shows the made-up demo day this app carries, and only that day; the bot's address stays as it is.",
        bundle: L10n.bundle)
    }
    static var showInMenuBar: LocalizedStringResource {
      LocalizedStringResource("settings.showInMenuBar",
        defaultValue: "Show Tickr in the menu bar",
        bundle: L10n.bundle)
    }
    static var appearance: LocalizedStringResource {
      LocalizedStringResource("settings.appearance", defaultValue: "Appearance", bundle: L10n.bundle)
    }
    static var theme: LocalizedStringResource {
      LocalizedStringResource("settings.theme", defaultValue: "Theme", bundle: L10n.bundle)
    }
    static var ok: LocalizedStringResource {
      LocalizedStringResource("settings.ok", defaultValue: "OK", bundle: L10n.bundle)
    }
    static var activeStrategy: LocalizedStringResource {
      LocalizedStringResource("settings.activeStrategy", defaultValue: "Active strategy", bundle: L10n.bundle)
    }
    static var plannedLoss: LocalizedStringResource {
      LocalizedStringResource("settings.plannedLoss", defaultValue: "Planned loss per trade", bundle: L10n.bundle)
    }
    static var notionalCap: LocalizedStringResource {
      LocalizedStringResource("settings.notionalCap", defaultValue: "Largest position", bundle: L10n.bundle)
    }
    static var dailyLossLimit: LocalizedStringResource {
      LocalizedStringResource("settings.dailyLossLimit", defaultValue: "Daily loss limit", bundle: L10n.bundle)
    }
    static var maxOpenPositions: LocalizedStringResource {
      LocalizedStringResource("settings.maxOpenPositions", defaultValue: "Open positions at most", bundle: L10n.bundle)
    }
    static var maxQuoteAge: LocalizedStringResource {
      LocalizedStringResource("settings.maxQuoteAge", defaultValue: "Quote age at most", bundle: L10n.bundle)
    }
    static var lastEntry: LocalizedStringResource {
      LocalizedStringResource("settings.lastEntry", defaultValue: "Last entry", bundle: L10n.bundle)
    }
    static var flatten: LocalizedStringResource {
      LocalizedStringResource("settings.flatten", defaultValue: "Close all positions", bundle: L10n.bundle)
    }
    static var halfDays: LocalizedStringResource {
      LocalizedStringResource("settings.halfDays", defaultValue: "Half days", bundle: L10n.bundle)
    }
    static var traded: LocalizedStringResource {
      LocalizedStringResource("settings.traded", defaultValue: "traded", bundle: L10n.bundle)
    }
    static var notTraded: LocalizedStringResource {
      LocalizedStringResource("settings.notTraded", defaultValue: "not traded", bundle: L10n.bundle)
    }
    static var session: LocalizedStringResource {
      LocalizedStringResource("settings.session", defaultValue: "Session", bundle: L10n.bundle)
    }
    static var readingSettings: LocalizedStringResource {
      LocalizedStringResource("settings.readingSettings",
        defaultValue: "Reading the bot's settings…",
        bundle: L10n.bundle)
    }
    static func beforeClose(_ minutes: Int) -> LocalizedStringResource {
      LocalizedStringResource("settings.beforeClose", defaultValue: "\(minutes) min before close", bundle: L10n.bundle)
    }
    static var jobs: LocalizedStringResource {
      LocalizedStringResource("settings.jobs", defaultValue: "Scheduled jobs", bundle: L10n.bundle)
    }
    static var jobsFooter: LocalizedStringResource {
      LocalizedStringResource("settings.jobsFooter",
        defaultValue: "launch: Mac local time · other times ET",
        bundle: L10n.bundle)
    }
    static var notRunning: LocalizedStringResource {
      LocalizedStringResource("settings.notRunning", defaultValue: "Not running", bundle: L10n.bundle)
    }
    static var reconcile: LocalizedStringResource {
      LocalizedStringResource("settings.reconcile", defaultValue: "Reconcile", bundle: L10n.bundle)
    }
    static var nextIn: LocalizedStringResource {
      LocalizedStringResource("settings.nextIn", defaultValue: "in", bundle: L10n.bundle)
    }
    static var backup: LocalizedStringResource {
      LocalizedStringResource("settings.backup", defaultValue: "Backup", bundle: L10n.bundle)
    }
    static var notReported: LocalizedStringResource {
      LocalizedStringResource("settings.notReported", defaultValue: "Not reporting", bundle: L10n.bundle)
    }
    static var jobPreflight: LocalizedStringResource {
      LocalizedStringResource("settings.job.preflight", defaultValue: "Preflight", bundle: L10n.bundle)
    }
    static var jobBot: LocalizedStringResource {
      LocalizedStringResource("settings.job.bot", defaultValue: "Bot start", bundle: L10n.bundle)
    }
    static var jobWatchdog: LocalizedStringResource {
      LocalizedStringResource("settings.job.watchdog", defaultValue: "Watchdog", bundle: L10n.bundle)
    }
    /// The nightly job that fetches market data for the Lab's replays.
    static var jobNightlyFetch: LocalizedStringResource {
      LocalizedStringResource("settings.job.nightlyFetch", defaultValue: "Nightly data fetch", bundle: L10n.bundle)
    }
    /// A launchd job this app does not know by name.
    static var jobOther: LocalizedStringResource {
      LocalizedStringResource("settings.job.other", defaultValue: "Other job", bundle: L10n.bundle)
    }
    static func lastAt(_ time: String) -> LocalizedStringResource {
      LocalizedStringResource("settings.lastAt", defaultValue: "last \(time)", bundle: L10n.bundle)
    }
    static func backupFailed(_ time: String) -> LocalizedStringResource {
      LocalizedStringResource("settings.backupFailed", defaultValue: "Failed \(time)", bundle: L10n.bundle)
    }
    static var tradingGate: LocalizedStringResource {
      LocalizedStringResource("settings.tradingGate", defaultValue: "Trading gate", bundle: L10n.bundle)
    }
    static var gateOpen: LocalizedStringResource {
      LocalizedStringResource("settings.gateOpen", defaultValue: "open", bundle: L10n.bundle)
    }
    static var gateClosed: LocalizedStringResource {
      LocalizedStringResource("settings.gateClosed", defaultValue: "closed", bundle: L10n.bundle)
    }
    static var environmentFixed: LocalizedStringResource {
      LocalizedStringResource("settings.environmentFixed",
        defaultValue: "Set in the config on the Mac. The app cannot switch it, by design.",
        bundle: L10n.bundle)
    }
    static var recordedDays: LocalizedStringResource {
      LocalizedStringResource("settings.recordedDays", defaultValue: "Recorded days", bundle: L10n.bundle)
    }
    static var firstRecordedDay: LocalizedStringResource {
      LocalizedStringResource("settings.firstRecordedDay", defaultValue: "First day", bundle: L10n.bundle)
    }
    static var daysWithBars: LocalizedStringResource {
      LocalizedStringResource("settings.daysWithBars", defaultValue: "Days with prices", bundle: L10n.bundle)
    }
    static var history: LocalizedStringResource {
      LocalizedStringResource("settings.history", defaultValue: "History", bundle: L10n.bundle)
    }
    static var statusRefresh: LocalizedStringResource {
      LocalizedStringResource("settings.statusRefresh", defaultValue: "Status refresh", bundle: L10n.bundle)
    }
    static func every(_ interval: String) -> LocalizedStringResource {
      LocalizedStringResource("settings.every", defaultValue: "every \(interval)", bundle: L10n.bundle)
    }
    static var staleAfter: LocalizedStringResource {
      LocalizedStringResource("settings.staleAfter", defaultValue: "Status stale after", bundle: L10n.bundle)
    }
    static var backupVerified: LocalizedStringResource {
      LocalizedStringResource("settings.backupVerified",
        defaultValue: "Backup checked",
        bundle: L10n.bundle)
    }
    static var cleanup: LocalizedStringResource {
      LocalizedStringResource("settings.cleanup",
        // swiftlint:disable:next line_length
        defaultValue: "Clean-up runs on the Mac while the bot is stopped: it compresses finished days and trims caches and old archives.",
        bundle: L10n.bundle)
    }
    static var themeSystem: LocalizedStringResource {
      LocalizedStringResource("settings.themeSystem", defaultValue: "System", bundle: L10n.bundle)
    }
    static var themeLight: LocalizedStringResource {
      LocalizedStringResource("settings.themeLight", defaultValue: "Light", bundle: L10n.bundle)
    }
    static var themeDark: LocalizedStringResource {
      LocalizedStringResource("settings.themeDark", defaultValue: "Dark", bundle: L10n.bundle)
    }
    static var timesET: LocalizedStringResource {
      LocalizedStringResource("settings.timesET", defaultValue: "times ET", bundle: L10n.bundle)
    }
    static var jobApi: LocalizedStringResource {
      LocalizedStringResource("settings.jobApi", defaultValue: "API", bundle: L10n.bundle)
    }
    static var alwaysOn: LocalizedStringResource {
      LocalizedStringResource("settings.alwaysOn", defaultValue: "always on", bundle: L10n.bundle)
    }
    static var whileBotRuns: LocalizedStringResource {
      LocalizedStringResource("settings.whileBotRuns", defaultValue: "while the bot runs", bundle: L10n.bundle)
    }
    static var daily: LocalizedStringResource {
      LocalizedStringResource("settings.daily", defaultValue: "daily", bundle: L10n.bundle)
    }
    static var verified: LocalizedStringResource {
      LocalizedStringResource("settings.verified", defaultValue: "verified", bundle: L10n.bundle)
    }
    static var connected: LocalizedStringResource {
      LocalizedStringResource("settings.connected", defaultValue: "connected", bundle: L10n.bundle)
    }
    static var unreachable: LocalizedStringResource {
      LocalizedStringResource("settings.unreachable", defaultValue: "not reachable", bundle: L10n.bundle)
    }
    static var botStatusInApp: LocalizedStringResource {
      LocalizedStringResource("settings.botStatusInApp", defaultValue: "Status in this app", bundle: L10n.bundle)
    }
    static func since(_ time: String) -> LocalizedStringResource {
      LocalizedStringResource("settings.since", defaultValue: "since \(time)", bundle: L10n.bundle)
    }
    static func sessionTitle(_ day: String) -> LocalizedStringResource {
      LocalizedStringResource("settings.sessionTitle",
        defaultValue: "Today's session · \(day)",
        bundle: L10n.bundle)
    }
    static func markOpen(_ time: String) -> LocalizedStringResource {
      LocalizedStringResource("settings.markOpen", defaultValue: "\(time) open", bundle: L10n.bundle)
    }
    static func markLastEntry(_ time: String) -> LocalizedStringResource {
      LocalizedStringResource("settings.markLastEntry", defaultValue: "\(time) last entry", bundle: L10n.bundle)
    }
    static func markFlatten(_ time: String) -> LocalizedStringResource {
      LocalizedStringResource("settings.markFlatten", defaultValue: "\(time) close all", bundle: L10n.bundle)
    }
    static func markClose(_ time: String) -> LocalizedStringResource {
      LocalizedStringResource("settings.markClose", defaultValue: "\(time) close", bundle: L10n.bundle)
    }
    static func lastShort(_ time: String) -> LocalizedStringResource {
      LocalizedStringResource("settings.lastShort", defaultValue: "last \(time)", bundle: L10n.bundle)
    }
    /// Environment: whether the bot may open new positions.
    static var newEntries: LocalizedStringResource {
      LocalizedStringResource("settings.newEntries", defaultValue: "New entries", bundle: L10n.bundle)
    }
    static var entriesAllowed: LocalizedStringResource {
      LocalizedStringResource("settings.entriesAllowed", defaultValue: "allowed", bundle: L10n.bundle)
    }
    static var entriesPaused: LocalizedStringResource {
      LocalizedStringResource("settings.entriesPaused", defaultValue: "paused", bundle: L10n.bundle)
    }
    static var entriesOff: LocalizedStringResource {
      LocalizedStringResource("settings.entriesOff", defaultValue: "off", bundle: L10n.bundle)
    }
    /// Session strip: why the stretches before and after the regular session are marked.
    static var notTradedHint: LocalizedStringResource {
      LocalizedStringResource("settings.notTradedHint",
        defaultValue: "Pre-market and after-hours are not traded yet",
        bundle: L10n.bundle)
    }
    /// Morning check: every check passed.
    static func morningAllPassed(_ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("settings.morningAllPassed", defaultValue: "All \(count) passed", bundle: L10n.bundle)
    }
    /// Morning check: how many checks failed, of all.
    static func morningFailed(_ failed: Int, _ total: Int) -> LocalizedStringResource {
      LocalizedStringResource("settings.morningFailed", defaultValue: "Failed: \(failed) of \(total)", bundle: L10n.bundle)
    }
    static var showAllChecks: LocalizedStringResource {
      LocalizedStringResource("settings.showAllChecks", defaultValue: "Show all checks", bundle: L10n.bundle)
    }
    /// Morning check: a check that passed or failed, spoken.
    static var checkPassed: LocalizedStringResource {
      LocalizedStringResource("settings.checkPassed", defaultValue: "passed", bundle: L10n.bundle)
    }
    static var checkFailed: LocalizedStringResource {
      LocalizedStringResource("settings.checkFailed", defaultValue: "failed", bundle: L10n.bundle)
    }
  }

  // MARK: Screens: Chart, Trades & days, Risk & account, Lab
  enum Chart {
    /// Label of the chart's symbol picker.
    static var symbol: LocalizedStringResource {
      LocalizedStringResource("chart.symbol", defaultValue: "Symbol", bundle: L10n.bundle)
    }
    /// Label of the interval (candle length) picker.
    static var timeframeLabel: LocalizedStringResource {
      LocalizedStringResource("chart.timeframeLabel", defaultValue: "Interval", bundle: L10n.bundle)
    }
    /// An interval segment: candle length in minutes.
    static func intervalMinutes(_ minutes: Int) -> LocalizedStringResource {
      LocalizedStringResource("chart.intervalMinutes", defaultValue: "\(minutes)m", bundle: L10n.bundle)
    }
    /// An interval segment: candle length in hours.
    static func intervalHours(_ hours: Int) -> LocalizedStringResource {
      LocalizedStringResource("chart.intervalHours", defaultValue: "\(hours)h", bundle: L10n.bundle)
    }
    /// An interval segment: one candle a day, a week or a month.
    static var intervalDay: LocalizedStringResource {
      LocalizedStringResource("chart.intervalDay", defaultValue: "D", bundle: L10n.bundle)
    }
    static var intervalWeek: LocalizedStringResource {
      LocalizedStringResource("chart.intervalWeek", defaultValue: "W", bundle: L10n.bundle)
    }
    static var intervalMonth: LocalizedStringResource {
      LocalizedStringResource("chart.intervalMonth", defaultValue: "M", bundle: L10n.bundle)
    }
    /// Label of the range picker (how far back the chart reaches).
    static var rangeLabel: LocalizedStringResource {
      LocalizedStringResource("chart.rangeLabel", defaultValue: "Range", bundle: L10n.bundle)
    }
    /// Tooltip of the range picker.
    static var rangeHelp: LocalizedStringResource {
      LocalizedStringResource("chart.rangeHelp",
        defaultValue: "How far back the chart reaches: the shown day, five sessions, or months of daily candles",
        bundle: L10n.bundle)
    }
    /// Range segments: the shown day, five sessions, one and three months, one year.
    static var rangeDay: LocalizedStringResource {
      LocalizedStringResource("chart.range.day", defaultValue: "Day", bundle: L10n.bundle)
    }
    static var rangeFiveDays: LocalizedStringResource {
      LocalizedStringResource("chart.range.fiveDays", defaultValue: "5D", bundle: L10n.bundle)
    }
    static var rangeOneMonth: LocalizedStringResource {
      LocalizedStringResource("chart.range.oneMonth", defaultValue: "1M", bundle: L10n.bundle)
    }
    static var rangeThreeMonths: LocalizedStringResource {
      LocalizedStringResource("chart.range.threeMonths", defaultValue: "3M", bundle: L10n.bundle)
    }
    static var rangeOneYear: LocalizedStringResource {
      LocalizedStringResource("chart.range.oneYear", defaultValue: "1Y", bundle: L10n.bundle)
    }
    /// Market data (GET /chart) could not be read for a range beyond one day.
    static var candlesUnavailableDetail: LocalizedStringResource {
      LocalizedStringResource("chart.candlesUnavailableDetail", defaultValue: "Market data is not available",
        bundle: L10n.bundle)
    }
    /// Market data answered with no candles for the range.
    static func noCandlesDetail(_ cause: String) -> LocalizedStringResource {
      LocalizedStringResource("chart.noCandlesDetail",
        defaultValue: "Market data has no candles for this symbol and range: \(cause)",
        bundle: L10n.bundle)
    }
    /// Tooltip of the interval picker.
    static var timeframeHelp: LocalizedStringResource {
      LocalizedStringResource("chart.timeframeHelp", defaultValue: "Candle length", bundle: L10n.bundle)
    }
    /// Label of the candles / line picker.
    static var styleLabel: LocalizedStringResource {
      LocalizedStringResource("chart.styleLabel", defaultValue: "Chart Type", bundle: L10n.bundle)
    }
    /// Chart type: candles.
    static var candles: LocalizedStringResource {
      LocalizedStringResource("chart.candles", defaultValue: "Candles", bundle: L10n.bundle)
    }
    /// Chart type: a filled line of closes.
    static var lineStyle: LocalizedStringResource {
      LocalizedStringResource("chart.lineStyle", defaultValue: "Line", bundle: L10n.bundle)
    }
    /// Tooltip of the chart type picker.
    static var styleHelp: LocalizedStringResource {
      LocalizedStringResource("chart.styleHelp", defaultValue: "Draw candles or a line of closes", bundle: L10n.bundle)
    }
    /// Plotted series name of the close line (VoiceOver).
    static var closeLine: LocalizedStringResource {
      LocalizedStringResource("chart.closeLine", defaultValue: "Close", bundle: L10n.bundle)
    }
    /// Readout: change from the previous close in price and percent.
    static func change(_ amount: String, _ percent: String) -> LocalizedStringResource {
      LocalizedStringResource("chart.change", defaultValue: "\(amount) (\(percent))", bundle: L10n.bundle)
    }
    /// Toggle of the moving-average lines.
    static var movingAverageChip: LocalizedStringResource {
      LocalizedStringResource("chart.movingAverageChip", defaultValue: "MA", bundle: L10n.bundle)
    }
    /// A moving-average line in the readout.
    static func movingAverage(_ period: Int) -> LocalizedStringResource {
      LocalizedStringResource("chart.movingAverage", defaultValue: "MA \(period)", bundle: L10n.bundle)
    }
    /// Tooltip of the MA toggle.
    static var movingAverageHelp: LocalizedStringResource {
      LocalizedStringResource("chart.movingAverageHelp", defaultValue: "Simple moving averages of the candles",
        bundle: L10n.bundle)
    }
    /// Toggle of the Bollinger bands.
    static var bollinger: LocalizedStringResource {
      LocalizedStringResource("chart.bollinger", defaultValue: "BOLL", bundle: L10n.bundle)
    }
    /// Tooltip of the BOLL toggle.
    static func bollingerHelp(_ period: Int) -> LocalizedStringResource {
      LocalizedStringResource("chart.bollingerHelp", defaultValue: "Bollinger bands around the \(period)-candle average",
        bundle: L10n.bundle)
    }
    /// Readout: upper Bollinger band.
    static var bollingerUpper: LocalizedStringResource {
      LocalizedStringResource("chart.bollingerUpper", defaultValue: "UB", bundle: L10n.bundle)
    }
    /// Readout: middle Bollinger line.
    static var bollingerMiddle: LocalizedStringResource {
      LocalizedStringResource("chart.bollingerMiddle", defaultValue: "MB", bundle: L10n.bundle)
    }
    /// Readout: lower Bollinger band.
    static var bollingerLower: LocalizedStringResource {
      LocalizedStringResource("chart.bollingerLower", defaultValue: "LB", bundle: L10n.bundle)
    }
    /// Toggle of the MACD pane, and the MACD line.
    static var macd: LocalizedStringResource {
      LocalizedStringResource("chart.macd", defaultValue: "MACD", bundle: L10n.bundle)
    }
    /// Readout: MACD signal line.
    static var macdSignal: LocalizedStringResource {
      LocalizedStringResource("chart.macdSignal", defaultValue: "Signal", bundle: L10n.bundle)
    }
    /// Readout: MACD histogram.
    static var macdHistogram: LocalizedStringResource {
      LocalizedStringResource("chart.macdHistogram", defaultValue: "Hist", bundle: L10n.bundle)
    }
    /// Tooltip of the MACD toggle.
    static func macdHelp(_ fast: Int, _ slow: Int, _ signal: Int) -> LocalizedStringResource {
      LocalizedStringResource("chart.macdHelp", defaultValue: "MACD (\(fast), \(slow), \(signal)) pane", bundle: L10n.bundle)
    }
    /// Toggle of the RSI pane.
    static var rsiChip: LocalizedStringResource {
      LocalizedStringResource("chart.rsiChip", defaultValue: "RSI", bundle: L10n.bundle)
    }
    /// The RSI line in the readout.
    static func rsi(_ period: Int) -> LocalizedStringResource {
      LocalizedStringResource("chart.rsi", defaultValue: "RSI \(period)", bundle: L10n.bundle)
    }
    /// Tooltip of the RSI toggle.
    static func rsiHelp(_ period: Int) -> LocalizedStringResource {
      LocalizedStringResource("chart.rsiHelp", defaultValue: "RSI (\(period)) pane with overbought and oversold bands",
        bundle: L10n.bundle)
    }
    /// Toggle of the slow stochastic pane.
    static var stochastic: LocalizedStringResource {
      LocalizedStringResource("chart.stochastic", defaultValue: "Stoch", bundle: L10n.bundle)
    }
    /// Readout: stochastic %K line.
    static var stochasticK: LocalizedStringResource {
      LocalizedStringResource("chart.stochasticK", defaultValue: "K", bundle: L10n.bundle)
    }
    /// Readout: stochastic %D line.
    static var stochasticD: LocalizedStringResource {
      LocalizedStringResource("chart.stochasticD", defaultValue: "D", bundle: L10n.bundle)
    }
    /// Tooltip of the Stoch toggle.
    static func stochasticHelp(_ period: Int, _ smoothing: Int) -> LocalizedStringResource {
      LocalizedStringResource("chart.stochasticHelp", defaultValue: "Slow stochastic (\(period), \(smoothing)) pane",
        bundle: L10n.bundle)
    }
    /// The VWAP line toggle and readout.
    static var vwap: LocalizedStringResource {
      LocalizedStringResource("chart.vwap", defaultValue: "VWAP", bundle: L10n.bundle)
    }
    /// An EMA line toggle and readout.
    static func ema(_ period: Int) -> LocalizedStringResource {
      LocalizedStringResource("chart.ema", defaultValue: "EMA \(period)", bundle: L10n.bundle)
    }
    /// Toggle of the volume bars along the bottom of the price pane.
    static var volume: LocalizedStringResource {
      LocalizedStringResource("chart.volume", defaultValue: "Volume", bundle: L10n.bundle)
    }
    /// Readout label of a candle's volume.
    static var volumeShort: LocalizedStringResource {
      LocalizedStringResource("chart.volumeShort", defaultValue: "V", bundle: L10n.bundle)
    }
    /// The ATR pane toggle and readout.
    static func atr(_ period: Int) -> LocalizedStringResource {
      LocalizedStringResource("chart.atr", defaultValue: "ATR \(period)", bundle: L10n.bundle)
    }
    /// ATR pane before the line has a value.
    static func atrWaiting(_ period: Int) -> LocalizedStringResource {
      LocalizedStringResource("chart.atrWaiting", defaultValue: "ATR \(period): not enough candles yet", bundle: L10n.bundle)
    }
    /// A study pane (MACD, RSI, stochastic) before its line has a value.
    static var studyWaiting: LocalizedStringResource {
      LocalizedStringResource("chart.studyWaiting", defaultValue: "Not enough candles yet", bundle: L10n.bundle)
    }
    /// Zoom-in button.
    static var zoomIn: LocalizedStringResource {
      LocalizedStringResource("chart.zoomIn", defaultValue: "Zoom In", bundle: L10n.bundle)
    }
    /// Zoom-out button.
    static var zoomOut: LocalizedStringResource {
      LocalizedStringResource("chart.zoomOut", defaultValue: "Zoom Out", bundle: L10n.bundle)
    }
    /// Button that shows the whole day.
    static var fit: LocalizedStringResource {
      LocalizedStringResource("chart.fit", defaultValue: "Show Whole Day", bundle: L10n.bundle)
    }
    /// Tooltip of zoom in.
    static var zoomInHelp: LocalizedStringResource {
      LocalizedStringResource("chart.zoomInHelp", defaultValue: "Show fewer candles (⌘=)", bundle: L10n.bundle)
    }
    /// Tooltip of zoom out.
    static var zoomOutHelp: LocalizedStringResource {
      LocalizedStringResource("chart.zoomOutHelp", defaultValue: "Show more candles (⌘−)", bundle: L10n.bundle)
    }
    /// Tooltip of show whole day.
    static var fitHelp: LocalizedStringResource {
      LocalizedStringResource("chart.fitHelp", defaultValue: "Show the whole day (⌘0)", bundle: L10n.bundle)
    }
    /// Empty chart: no symbol has data.
    static var noSymbols: LocalizedStringResource {
      LocalizedStringResource("chart.noSymbols", defaultValue: "Nothing to Chart", bundle: L10n.bundle)
    }
    /// Empty chart detail.
    static var noSymbolsDetail: LocalizedStringResource {
      LocalizedStringResource("chart.noSymbolsDetail",
        defaultValue: "The bot has no open position, recorded bars or trades on this day.",
        bundle: L10n.bundle)
    }
    /// The bars read failed.
    static var barsUnavailable: LocalizedStringResource {
      LocalizedStringResource("chart.barsUnavailable", defaultValue: "Bars Unavailable", bundle: L10n.bundle)
    }
    /// Why the bars read failed.
    static var barsUnavailableDetail: LocalizedStringResource {
      LocalizedStringResource("chart.barsUnavailableDetail", defaultValue: "The bot's API did not return bars",
        bundle: L10n.bundle)
    }
    /// The loader's caption while a symbol's bars load: the symbol and the interval ("1m").
    static func loadingBars(_ symbol: String, interval: String) -> LocalizedStringResource {
      LocalizedStringResource("chart.loadingBars", defaultValue: "Loading \(symbol) · \(interval) bars", bundle: L10n.bundle)
    }
    /// The symbol has no bars on the day.
    static var noBars: LocalizedStringResource {
      LocalizedStringResource("chart.noBars", defaultValue: "No Bars", bundle: L10n.bundle)
    }
    /// No bars detail.
    static var noBarsDetail: LocalizedStringResource {
      LocalizedStringResource("chart.noBarsDetail", defaultValue: "No M1 bars were recorded for this symbol on this day.",
        bundle: L10n.bundle)
    }
    /// Entry mark of a trade with its quantity.
    static func buyMark(_ quantity: String, _ price: String) -> LocalizedStringResource {
      LocalizedStringResource("chart.buyMark", defaultValue: "Buy \(quantity) @ \(price)", bundle: L10n.bundle)
    }
    /// The volume pane's name: the newest candle's volume and the relative volume (the newest
    /// volume over the average).
    static func volumePane(_ volume: String, _ ratio: String) -> LocalizedStringResource {
      LocalizedStringResource("chart.volumePane",
        defaultValue: "Volume \(volume) · rel. volume \(ratio)×", bundle: L10n.bundle)
    }
    /// The volume pane's name before its average has a value.
    static func volumePaneShort(_ volume: String) -> LocalizedStringResource {
      LocalizedStringResource("chart.volumePaneShort", defaultValue: "Volume \(volume)", bundle: L10n.bundle)
    }
    /// Tooltip of the VWAP chip.
    static var vwapHelp: LocalizedStringResource {
      LocalizedStringResource("chart.vwapHelp", defaultValue: "Volume-weighted average price of the session",
        bundle: L10n.bundle)
    }
    /// Tooltip of an EMA chip; argument: its candles.
    static func emaHelp(_ period: Int) -> LocalizedStringResource {
      LocalizedStringResource("chart.emaHelp", defaultValue: "Exponential moving average of \(period) candles",
        bundle: L10n.bundle)
    }
    /// Name of the volume pane's average line (VoiceOver).
    static func volumeAverage(_ period: Int) -> LocalizedStringResource {
      LocalizedStringResource("chart.volumeAverage", defaultValue: "Average volume \(period)", bundle: L10n.bundle)
    }
    /// Name of the study chips drawn over the price.
    static var onPrice: LocalizedStringResource {
      LocalizedStringResource("chart.onPrice", defaultValue: "On price", bundle: L10n.bundle)
    }
    static var onPriceHelp: LocalizedStringResource {
      LocalizedStringResource("chart.onPriceHelp", defaultValue: "Lines drawn over the price", bundle: L10n.bundle)
    }
    /// Name of the study chips with a pane of their own.
    static var panes: LocalizedStringResource {
      LocalizedStringResource("chart.panes", defaultValue: "Panes", bundle: L10n.bundle)
    }
    static var panesHelp: LocalizedStringResource {
      LocalizedStringResource("chart.panesHelp", defaultValue: "Indicators with a pane of their own under the price",
        bundle: L10n.bundle)
    }
    /// Chip of the ATR pane.
    static var atrChip: LocalizedStringResource {
      LocalizedStringResource("chart.atrChip", defaultValue: "ATR", bundle: L10n.bundle)
    }
    /// Label of the slider that scrolls a zoomed chart through its history.
    static var scrollHistory: LocalizedStringResource {
      LocalizedStringResource("chart.scrollHistory", defaultValue: "scroll history", bundle: L10n.bundle)
    }
    static var scrollHistoryHelp: LocalizedStringResource {
      LocalizedStringResource("chart.scrollHistoryHelp",
        defaultValue: "Zoom in, then slide to move through the earlier candles", bundle: L10n.bundle)
    }
    /// The pill shown while the chart follows the live day.
    static var live: LocalizedStringResource {
      LocalizedStringResource("chart.live", defaultValue: "Live", bundle: L10n.bundle)
    }
    static var liveHelp: LocalizedStringResource {
      LocalizedStringResource("chart.liveHelp", defaultValue: "Live: new bars are added as they arrive",
        bundle: L10n.bundle)
    }
    /// Chip that shows or hides the trades and the decisions on the price pane.
    static var tradesChip: LocalizedStringResource {
      LocalizedStringResource("chart.tradesChip", defaultValue: "Trades", bundle: L10n.bundle)
    }
    static var tradesChipHelp: LocalizedStringResource {
      LocalizedStringResource("chart.tradesChipHelp",
        defaultValue: "Show the bot's trades, its open position's levels and its decisions on the chart",
        bundle: L10n.bundle)
    }
    /// Help of the symbol menu in the header.
    static var symbolHelp: LocalizedStringResource {
      LocalizedStringResource("chart.symbolHelp", defaultValue: "Pick the symbol to chart", bundle: L10n.bundle)
    }
    /// Help of the change beside the last price.
    static var dayChangeHelp: LocalizedStringResource {
      LocalizedStringResource("chart.dayChangeHelp", defaultValue: "Change from the previous close, as the screeners report it",
        bundle: L10n.bundle)
    }
    /// The right rail's symbol list: the open positions, the waiting symbols and the screeners'.
    static var rail: LocalizedStringResource {
      LocalizedStringResource("chart.rail", defaultValue: "Symbols", bundle: L10n.bundle)
    }
    /// Count of open positions in the rail's header.
    static func railCount(_ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("chart.railCount", defaultValue: "\(count) positions", bundle: L10n.bundle)
    }
    static var railPosition: LocalizedStringResource {
      LocalizedStringResource("chart.railPosition", defaultValue: "Open", bundle: L10n.bundle)
    }
    static var railWatch: LocalizedStringResource {
      LocalizedStringResource("chart.railWatch", defaultValue: "Waiting", bundle: L10n.bundle)
    }
    static var railCandidate: LocalizedStringResource {
      LocalizedStringResource("chart.railCandidate", defaultValue: "Screener", bundle: L10n.bundle)
    }
    /// A position's stop in the rail; ✓ once the broker confirmed it.
    static func railStop(_ price: String) -> LocalizedStringResource {
      LocalizedStringResource("chart.railStop", defaultValue: "stop \(price) ✓", bundle: L10n.bundle)
    }
    static func railStopUnverified(_ price: String) -> LocalizedStringResource {
      LocalizedStringResource("chart.railStopUnverified", defaultValue: "stop \(price) ?", bundle: L10n.bundle)
    }
    /// Since when the symbol waits for its entry.
    static func railSince(_ time: String) -> LocalizedStringResource {
      LocalizedStringResource("chart.railSince", defaultValue: "since \(time)", bundle: L10n.bundle)
    }
    /// A candidate's screener and change, "gainers +16.6%".
    static func railScreener(_ screener: String, _ change: String) -> LocalizedStringResource {
      LocalizedStringResource("chart.railScreener", defaultValue: "\(screener) \(change)", bundle: L10n.bundle)
    }
    static var sourceGainers: LocalizedStringResource {
      LocalizedStringResource("chart.sourceGainers", defaultValue: "gainers", bundle: L10n.bundle)
    }
    static var sourceLosers: LocalizedStringResource {
      LocalizedStringResource("chart.sourceLosers", defaultValue: "losers", bundle: L10n.bundle)
    }
    static var sourceActives: LocalizedStringResource {
      LocalizedStringResource("chart.sourceActives", defaultValue: "actives", bundle: L10n.bundle)
    }
    static var railEmpty: LocalizedStringResource {
      LocalizedStringResource("chart.railEmpty", defaultValue: "No open, waiting or screened symbols yet",
        bundle: L10n.bundle)
    }
    /// Title of the decision card: the time of the decision shown.
    static func explain(_ time: String) -> LocalizedStringResource {
      LocalizedStringResource("chart.explain", defaultValue: "Decision · \(time)", bundle: L10n.bundle)
    }
    /// The decision card's disclosure of every check behind the decision.
    static var explainWhy: LocalizedStringResource {
      LocalizedStringResource("chart.explainWhy", defaultValue: "Why", bundle: L10n.bundle)
    }
    /// How many of the decision's checks passed; arguments: passed, all.
    static func checksPassed(_ passed: Int, _ total: Int) -> LocalizedStringResource {
      LocalizedStringResource("chart.checksPassed", defaultValue: "\(passed) of \(total) passed", bundle: L10n.bundle)
    }
    /// The decision card's title in a candle of several minutes; arguments: the decision's minute,
    /// the candle's start.
    static func explainInCandle(_ time: String, _ candle: String) -> LocalizedStringResource {
      LocalizedStringResource("chart.explainInCandle", defaultValue: "Decision · \(time), last in the \(candle) candle",
        bundle: L10n.bundle)
    }
    /// The explain card under a pointed candle the strategy made no decision in; argument: its start.
    static func noDecisionInCandle(_ time: String) -> LocalizedStringResource {
      LocalizedStringResource("chart.noDecisionInCandle", defaultValue: "No decision in the \(time) candle.",
        bundle: L10n.bundle)
    }
    /// The decision card's title while there is no decision to show.
    static var explainSymbol: LocalizedStringResource {
      LocalizedStringResource("chart.explainSymbol", defaultValue: "Decision", bundle: L10n.bundle)
    }
    /// The card with the shown symbol's open position.
    static var positionOnChart: LocalizedStringResource {
      LocalizedStringResource("chart.positionOnChart", defaultValue: "Open position", bundle: L10n.bundle)
    }
    static var positionEntry: LocalizedStringResource {
      LocalizedStringResource("chart.positionEntry", defaultValue: "Entry", bundle: L10n.bundle)
    }
    /// "10:42 · 12.34 × 10": when, at what price and how many shares.
    static func positionEntryValue(_ time: String, _ price: String, _ quantity: String) -> LocalizedStringResource {
      LocalizedStringResource("chart.positionEntryValue", defaultValue: "\(time) · \(price) × \(quantity)",
        bundle: L10n.bundle)
    }
    static var positionStop: LocalizedStringResource {
      LocalizedStringResource("chart.positionStop", defaultValue: "Stop", bundle: L10n.bundle)
    }
    static var positionNoStop: LocalizedStringResource {
      LocalizedStringResource("chart.positionNoStop", defaultValue: "none", bundle: L10n.bundle)
    }
    /// Under the position card's R: the R is the latest price's.
    static var positionRNow: LocalizedStringResource {
      LocalizedStringResource("chart.positionRNow", defaultValue: "now", bundle: L10n.bundle)
    }
    /// Exit mark of a trade with its result.
    static func exitMark(_ result: String) -> LocalizedStringResource {
      LocalizedStringResource("chart.exitMark", defaultValue: "Exit \(result)", bundle: L10n.bundle)
    }
    /// Entry level of the open position.
    static func entryLevel(_ price: String) -> LocalizedStringResource {
      LocalizedStringResource("chart.entryLevel", defaultValue: "Entry \(price)", bundle: L10n.bundle)
    }
    /// Verified broker-side stop level.
    static func stopLevel(_ price: String) -> LocalizedStringResource {
      LocalizedStringResource("chart.stopLevel", defaultValue: "Stop \(price) ✓", bundle: L10n.bundle)
    }
    /// Stop level the broker has not confirmed.
    static func stopUnverified(_ price: String) -> LocalizedStringResource {
      LocalizedStringResource("chart.stopUnverified", defaultValue: "Stop \(price) unverified", bundle: L10n.bundle)
    }
    /// Readout: open.
    static var open: LocalizedStringResource {
      LocalizedStringResource("chart.open", defaultValue: "O", bundle: L10n.bundle)
    }
    /// Readout: high.
    static var high: LocalizedStringResource {
      LocalizedStringResource("chart.high", defaultValue: "H", bundle: L10n.bundle)
    }
    /// Readout: low.
    static var low: LocalizedStringResource {
      LocalizedStringResource("chart.low", defaultValue: "L", bundle: L10n.bundle)
    }
    /// The highest high on screen, on the price axis.
    static func highTag(_ price: String) -> LocalizedStringResource {
      LocalizedStringResource("chart.highTag", defaultValue: "H \(price)", bundle: L10n.bundle)
    }
    /// The lowest low on screen, on the price axis.
    static func lowTag(_ price: String) -> LocalizedStringResource {
      LocalizedStringResource("chart.lowTag", defaultValue: "L \(price)", bundle: L10n.bundle)
    }
    /// Readout: close.
    static var close: LocalizedStringResource {
      LocalizedStringResource("chart.close", defaultValue: "C", bundle: L10n.bundle)
    }
    /// Plotted value name (VoiceOver).
    static var axisTime: LocalizedStringResource {
      LocalizedStringResource("chart.axisTime", defaultValue: "Time", bundle: L10n.bundle)
    }
    /// Plotted value name (VoiceOver).
    static var axisPrice: LocalizedStringResource {
      LocalizedStringResource("chart.axisPrice", defaultValue: "Price", bundle: L10n.bundle)
    }
    /// Plotted series name (VoiceOver).
    static var axisSeries: LocalizedStringResource {
      LocalizedStringResource("chart.axisSeries", defaultValue: "Line", bundle: L10n.bundle)
    }
    /// Inspector title and toolbar toggle: the strategy decisions for the shown symbol.
    static var decisions: LocalizedStringResource {
      LocalizedStringResource("chart.decisions", defaultValue: "Decisions", bundle: L10n.bundle)
    }
    /// Tooltip of the decisions toggle.
    static var decisionsHelp: LocalizedStringResource {
      LocalizedStringResource("chart.decisionsHelp",
        // swiftlint:disable:next line_length
        defaultValue: "Show why the bot entered, waited or skipped this symbol, and mark its entries and exits on the candles (⌥⌘I)",
        bundle: L10n.bundle)
    }
    /// Chart mark of the strategy's ENTER that was not taken (refused by risk or the gate).
    static func skippedMark(_ action: String) -> LocalizedStringResource {
      LocalizedStringResource("chart.skippedMark", defaultValue: "\(action) · skipped", bundle: L10n.bundle)
    }
    /// Decisions inspector is empty.
    static var noDecisions: LocalizedStringResource {
      LocalizedStringResource("chart.noDecisions", defaultValue: "No decisions were recorded for this symbol on this day.",
        bundle: L10n.bundle)
    }
    /// Decisions inspector over a range beyond one day.
    static var decisionsDayOnly: LocalizedStringResource {
      LocalizedStringResource("chart.decisionsDayOnly", defaultValue: "Decisions are recorded per day. Choose Day to see them.",
        bundle: L10n.bundle)
    }
    /// Why the decisions read failed.
    static var decisionsUnavailable: LocalizedStringResource {
      LocalizedStringResource("chart.decisionsUnavailable", defaultValue: "The bot's API did not return decisions",
        bundle: L10n.bundle)
    }
    /// A strategy name with its version.
    static func strategyVersion(_ name: String, _ version: String) -> LocalizedStringResource {
      LocalizedStringResource("chart.strategyVersion", defaultValue: "\(name) v\(version)", bundle: L10n.bundle)
    }
    /// What-if entry and stop of an ENTER that was not taken (refused by the platform).
    static func entryStop(_ entry: String, _ stop: String) -> LocalizedStringResource {
      LocalizedStringResource("chart.entryStop", defaultValue: "Skipped entry \(entry) · stop \(stop)", bundle: L10n.bundle)
    }
    /// VoiceOver and tooltip: a check passed.
    static var checkPassed: LocalizedStringResource {
      LocalizedStringResource("chart.checkPassed", defaultValue: "Passed", bundle: L10n.bundle)
    }
    /// VoiceOver and tooltip: a check did not pass.
    static var checkFailed: LocalizedStringResource {
      LocalizedStringResource("chart.checkFailed", defaultValue: "Not passed", bundle: L10n.bundle)
    }
  }
  enum Trades {
    /// Card title: the list of recorded days.
    static var days: LocalizedStringResource {
      LocalizedStringResource("trades.days", defaultValue: "Days", bundle: L10n.bundle)
    }

    /// Days list is empty.
    static var noDays: LocalizedStringResource {
      LocalizedStringResource("trades.noDays", defaultValue: "No recorded days yet.", bundle: L10n.bundle)
    }
    /// Days read failed.
    static var daysUnavailable: LocalizedStringResource {
      LocalizedStringResource("trades.daysUnavailable",
        defaultValue: "The day list is unavailable; the bot's API did not answer.",
        bundle: L10n.bundle)
    }
    /// Plotted value name of a day bar (VoiceOver).
    static var day: LocalizedStringResource {
      LocalizedStringResource("trades.day", defaultValue: "Day", bundle: L10n.bundle)
    }
    /// A trade's or day's gross result.
    static var result: LocalizedStringResource {
      LocalizedStringResource("trades.result", defaultValue: "Result", bundle: L10n.bundle)
    }
    /// Wins and losses beside the shown day's trade count.
    static func winsLosses(_ wins: Int, _ losses: Int) -> LocalizedStringResource {
      LocalizedStringResource("trades.winsLosses", defaultValue: "\(wins) W · \(losses) L", bundle: L10n.bundle)
    }
    /// Tooltip: a day without bars.
    static var noBarsHelp: LocalizedStringResource {
      LocalizedStringResource("trades.noBarsHelp",
        defaultValue: "No bars were recorded on this day, so the Chart has nothing to show.",
        bundle: L10n.bundle)
    }
    /// Stat card: the day's result after the broker's fees (before them while fees are unread).
    static var resultGross: LocalizedStringResource {
      LocalizedStringResource("trades.resultGross", defaultValue: "Result", bundle: L10n.bundle)
    }
    /// Stat card: number of trades.
    static var trades: LocalizedStringResource {
      LocalizedStringResource("trades.trades", defaultValue: "Trades", bundle: L10n.bundle)
    }
    /// Card title: the strategy's ENTERs that did not become a position.
    static var notTaken: LocalizedStringResource {
      LocalizedStringResource("trades.notTaken", defaultValue: "Not Taken", bundle: L10n.bundle)
    }
    /// Not taken list is empty.
    static var notTakenEmpty: LocalizedStringResource {
      LocalizedStringResource("trades.notTakenEmpty", defaultValue: "Every entry signal of this day became a position.",
        bundle: L10n.bundle)
    }
    /// Skipped read failed.
    static var notTakenUnavailable: LocalizedStringResource {
      LocalizedStringResource("trades.notTakenUnavailable",
        defaultValue: "The bot's API did not return the skipped signals",
        bundle: L10n.bundle)
    }
    /// Badge of a position still open, listed above the day's closed trades.
    static var open: LocalizedStringResource {
      LocalizedStringResource("trades.open", defaultValue: "Open", bundle: L10n.bundle)
    }
    /// VoiceOver label of an open position's OPEN tag in the trades table.
    static func openPosition(_ symbol: String) -> LocalizedStringResource {
      LocalizedStringResource("trades.openPosition", defaultValue: "Open position \(symbol): show on Chart",
        bundle: L10n.bundle)
    }
    /// A signal not taken that was never put to the platform's checks (its row's title).
    static var notEvaluated: LocalizedStringResource {
      LocalizedStringResource("trades.notEvaluated", defaultValue: "Not evaluated", bundle: L10n.bundle)
    }
    /// What-if entry and stop of a skipped signal.
    static func whatIfLevels(_ entry: String, _ stop: String) -> LocalizedStringResource {
      LocalizedStringResource("trades.whatIfLevels", defaultValue: "What-if entry \(entry) · stop \(stop)", bundle: L10n.bundle)
    }
    /// Card title before a trade is selected.
    static var selectedTrade: LocalizedStringResource {
      LocalizedStringResource("trades.selectedTrade", defaultValue: "Selected Trade", bundle: L10n.bundle)
    }
    /// Trade detail card before a trade is selected.
    static var selectTrade: LocalizedStringResource {
      LocalizedStringResource("trades.selectTrade",
        defaultValue: "Select a trade to see its risk, price excursion and how fast its stop was confirmed.",
        bundle: L10n.bundle)
    }
    /// Detail: seconds from the entry fill to the broker confirming the stop.
    static var stopConfirmedAfter: LocalizedStringResource {
      LocalizedStringResource("trades.stopConfirmedAfter", defaultValue: "Stop confirmed after", bundle: L10n.bundle)
    }
    /// Detail: maximum adverse excursion, a lower bound.
    static var maeAtLeast: LocalizedStringResource {
      LocalizedStringResource("trades.maeAtLeast", defaultValue: "Worst open result (MAE), at least", bundle: L10n.bundle)
    }
    /// Detail: maximum favourable excursion, a lower bound.
    static var mfeAtLeast: LocalizedStringResource {
      LocalizedStringResource("trades.mfeAtLeast", defaultValue: "Best open result (MFE), at least", bundle: L10n.bundle)
    }
    /// Footnote: why MAE and MFE are lower bounds.
    static var excursionLowerBound: LocalizedStringResource {
      LocalizedStringResource("trades.excursionLowerBound",
        // swiftlint:disable:next line_length
        defaultValue: "MAE and MFE count only prices proven to come while the shares were held, so the real excursion can be larger.",
        bundle: L10n.bundle)
    }
    /// Detail value the bot could not compute (MAE/MFE without captured bars).
    static var unknown: LocalizedStringResource {
      LocalizedStringResource("trades.unknown", defaultValue: "Unknown", bundle: L10n.bundle)
    }
    /// Tooltip of the stop confirmation time.
    static var stopConfirmedHelp: LocalizedStringResource {
      LocalizedStringResource("trades.stopConfirmedHelp",
        defaultValue: "Counted from when the bot saw the entry fill to when the broker confirmed the stop.",
        bundle: L10n.bundle)
    }
    /// Detail value the bot did not record.
    static var notRecorded: LocalizedStringResource {
      LocalizedStringResource("trades.notRecorded", defaultValue: "Not recorded", bundle: L10n.bundle)
    }
    /// Detail: the bot code version (short git commit) the trade was opened by.
    static var codeVersion: LocalizedStringResource {
      LocalizedStringResource("trades.codeVersion", defaultValue: "Bot code version", bundle: L10n.bundle)
    }
    /// Tooltip of the code version: what it is, and the full commit.
    static func codeVersionHelp(_ full: String) -> LocalizedStringResource {
      LocalizedStringResource("trades.codeVersionHelp",
        defaultValue: "The git commit the bot ran on when it opened this trade (-dirty: files had changed since it): \(full)",
        bundle: L10n.bundle)
    }
    /// Card title: gross performance over the days that end on the shown day.
    static func performance(_ days: Int) -> LocalizedStringResource {
      LocalizedStringResource("trades.performance", defaultValue: "Performance in R · \(days) days", bundle: L10n.bundle)
    }
    /// Under the result per trade: "profit factor 1.7 · max drawdown −3.1 R · 18 W · 12 L · 1 flat ·
    /// gross, before fees".
    static func performanceLine(_ factor: String, _ fall: String, _ won: Int, _ lost: Int, _ flat: Int)
      -> LocalizedStringResource {
      LocalizedStringResource("trades.performanceLine",
        defaultValue: "profit factor \(factor) · max drawdown \(fall) · \(won) W · \(lost) L · \(flat) flat · gross, before fees",
        bundle: L10n.bundle)
    }
    /// Beside the performance title: "31 trades · 58% won".
    static func performanceSub(_ trades: Int, _ winRate: String) -> LocalizedStringResource {
      LocalizedStringResource("trades.performanceSub", defaultValue: "\(trades) trades · \(winRate) won", bundle: L10n.bundle)
    }
    /// After the result per trade.
    static var perTrade: LocalizedStringResource {
      LocalizedStringResource("trades.perTrade", defaultValue: "per trade", bundle: L10n.bundle)
    }
    /// Trades left out of every performance figure, with why.
    static func excluded(_ trades: Int, _ cause: String) -> LocalizedStringResource {
      LocalizedStringResource("trades.excluded", defaultValue: "Left out: \(trades) · \(cause)", bundle: L10n.bundle)
    }
    /// Performance read failed.
    static var performanceUnavailable: LocalizedStringResource {
      LocalizedStringResource("trades.performanceUnavailable", defaultValue: "The bot's API did not return performance",
        bundle: L10n.bundle)
    }
    /// Performance card with no trades.
    static var noPerformance: LocalizedStringResource {
      LocalizedStringResource("trades.noPerformance", defaultValue: "No closed trades in these days.", bundle: L10n.bundle)
    }
    /// Plotted value name of the performance curve (VoiceOver).
    static var cumulativeR: LocalizedStringResource {
      LocalizedStringResource("trades.cumulativeR", defaultValue: "Cumulative R", bundle: L10n.bundle)
    }
    /// Footnote of the performance card.
    /// The performance card's note on what 1 R is.
    static var oneRNote: LocalizedStringResource {
      LocalizedStringResource("trades.oneRNote", defaultValue: "1 R = planned loss", bundle: L10n.bundle)
    }
    /// The heading of the live day.
    static func dayTitleToday(_ day: String) -> LocalizedStringResource {
      LocalizedStringResource("trades.dayTitleToday", defaultValue: "\(day) · today", bundle: L10n.bundle)
    }
    /// The calendar card's label: the month, then what its tiles show.
    static func monthLabel(_ month: String) -> LocalizedStringResource {
      LocalizedStringResource("trades.monthLabel", defaultValue: "\(month) · day result", bundle: L10n.bundle)
    }
    /// The month's total result beside the calendar's label.
    static func monthTotal(_ result: String) -> LocalizedStringResource {
      LocalizedStringResource("trades.monthTotal", defaultValue: "month \(result)", bundle: L10n.bundle)
    }
    /// A calendar day's closed trades.
    static func tradeCount(_ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("trades.tradeCount", defaultValue: "\(count) trades", bundle: L10n.bundle)
    }
    /// Calendar button and VoiceOver: show the month before.
    static var previousMonth: LocalizedStringResource {
      LocalizedStringResource("trades.previousMonth", defaultValue: "Previous Month", bundle: L10n.bundle)
    }
    /// Calendar button and VoiceOver: show the month after.
    static var nextMonth: LocalizedStringResource {
      LocalizedStringResource("trades.nextMonth", defaultValue: "Next Month", bundle: L10n.bundle)
    }
    /// VoiceOver value of a calendar day the bot did not record.
    static var noRecords: LocalizedStringResource {
      LocalizedStringResource("trades.noRecords", defaultValue: "No records", bundle: L10n.bundle)
    }
    /// Repeats of one refusal on one symbol: first and last time, and how many.
    static func repeatRange(_ first: String, _ last: String, _ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("trades.repeatRange", defaultValue: "\(first)–\(last) · ×\(count)", bundle: L10n.bundle)
    }
    /// Repeats of one refusal on one symbol, all within one minute: the time and how many.
    static func repeatAt(_ time: String, _ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("trades.repeatAt", defaultValue: "\(time) · ×\(count)", bundle: L10n.bundle)
    }
    /// Tooltip of a clean day's mark.
    static var cleanDay: LocalizedStringResource {
      LocalizedStringResource("trades.cleanDay",
        defaultValue: "Clean day: the broker and the bot's records agreed, every position had its stop, and the day ended flat.",
        bundle: L10n.bundle)
    }
    /// Tooltip of a day that was not clean, with what made it so.
    static func notCleanDay(_ causes: String) -> LocalizedStringResource {
      LocalizedStringResource("trades.notCleanDay", defaultValue: "Not clean: \(causes)", bundle: L10n.bundle)
    }
    /// Tooltip of a day whose clean-day verdict is unknown.
    static func cleanUnknown(_ cause: String) -> LocalizedStringResource {
      LocalizedStringResource("trades.cleanUnknown", defaultValue: "Verdict unknown: \(cause)", bundle: L10n.bundle)
    }
    /// Day header badge: the journal, the broker and the bot's records agreed.
    static var cleanBadge: LocalizedStringResource {
      LocalizedStringResource("trades.cleanBadge", defaultValue: "Clean day", bundle: L10n.bundle)
    }
    /// Note after the clean-day badge on Trades & days.
    static var recordsAgree: LocalizedStringResource {
      LocalizedStringResource("trades.recordsAgree", defaultValue: "records agree", bundle: L10n.bundle)
    }
    /// Note after the needs-a-look badge on Trades & days.
    static var recordsDiffer: LocalizedStringResource {
      LocalizedStringResource("trades.recordsDiffer", defaultValue: "records differ", bundle: L10n.bundle)
    }
    /// Day header badge: the day was not clean.
    static var needsLookBadge: LocalizedStringResource {
      LocalizedStringResource("trades.needsLookBadge", defaultValue: "Needs a look", bundle: L10n.bundle)
    }
    /// Calendar legend of the green dot.
    static var cleanLegend: LocalizedStringResource {
      LocalizedStringResource("trades.cleanLegend", defaultValue: "clean day: broker and records agree", bundle: L10n.bundle)
    }
    /// Calendar legend of the amber dot.
    static var needsLook: LocalizedStringResource {
      LocalizedStringResource("trades.needsLook", defaultValue: "needs a look", bundle: L10n.bundle)
    }
    /// A refusal with the end of its window (a cooldown), New York time.
    static func refusedUntil(_ message: String, _ time: String) -> LocalizedStringResource {
      LocalizedStringResource("trades.refusedUntil", defaultValue: "\(message) · until \(time)", bundle: L10n.bundle)
    }
    /// Not taken row: what the bot's replay says the signal would have made, and how it ended.
    static func whatIfResult(_ r: String, _ usd: String, _ exit: String) -> LocalizedStringResource {
      LocalizedStringResource("trades.whatIfResult", defaultValue: "If entered: \(r) · \(usd) · \(exit)", bundle: L10n.bundle)
    }
    /// Not taken row: the replay could not run, with why.
    static func whatIfNoResult(_ cause: String) -> LocalizedStringResource {
      LocalizedStringResource("trades.whatIfNoResult", defaultValue: "If entered: not replayed · \(cause)", bundle: L10n.bundle)
    }
    /// How a replay ended: the stop was hit.
    static var exitStop: LocalizedStringResource {
      LocalizedStringResource("trades.exitStop", defaultValue: "stop", bundle: L10n.bundle)
    }
    /// How a replay ended: the strategy's own exit.
    static var exitStrategy: LocalizedStringResource {
      LocalizedStringResource("trades.exitStrategy", defaultValue: "strategy exit", bundle: L10n.bundle)
    }
    /// How a replay ended: flattened before the market close.
    static var exitFlatten: LocalizedStringResource {
      LocalizedStringResource("trades.exitFlatten", defaultValue: "end-of-day close", bundle: L10n.bundle)
    }
    /// How a replay ended: the captured bars ran out with it still open.
    static var exitEndOfData: LocalizedStringResource {
      LocalizedStringResource("trades.exitEndOfData", defaultValue: "bars ran out", bundle: L10n.bundle)
    }
    /// Price change per share at set minutes after an exit or a skipped signal.
    static func afterPrices(_ items: String) -> LocalizedStringResource {
      LocalizedStringResource("trades.afterPrices", defaultValue: "Price after: \(items)", bundle: L10n.bundle)
    }
    /// One point of the price after: minutes and the change per share.
    static func afterMinutes(_ minutes: Int, _ change: String) -> LocalizedStringResource {
      LocalizedStringResource("trades.afterMinutes", defaultValue: "\(minutes) min \(change)", bundle: L10n.bundle)
    }
    /// What if card: label before the replays' sum in R and USD.
    static var whatIfSummary: LocalizedStringResource {
      LocalizedStringResource("trades.whatIfSummary", defaultValue: "If taken:", bundle: L10n.bundle)
    }
    /// What if card: replays that won, lost, or could not run.
    static func whatIfCounts(_ wins: Int, _ losses: Int, _ unknown: Int) -> LocalizedStringResource {
      LocalizedStringResource("trades.whatIfCounts", defaultValue: "\(wins) W · \(losses) L · not replayed: \(unknown)",
        bundle: L10n.bundle)
    }
    /// Footnote of the What if card.
    static var whatIfHelp: LocalizedStringResource {
      LocalizedStringResource("trades.whatIfHelp",
        // swiftlint:disable:next line_length
        defaultValue: "The bot replays each skipped setup on the captured bars from its first signal, with the strategy's stop and exits. Gross, before fees.",
        bundle: L10n.bundle)
    }
    /// Trade detail label: how far the price went on in the trade's favour after the exit.
    static var overshoot: LocalizedStringResource {
      LocalizedStringResource("trades.overshoot", defaultValue: "Went on after exit", bundle: L10n.bundle)
    }
    /// Tooltip of the overshoot row.
    static var overshootHelp: LocalizedStringResource {
      LocalizedStringResource("trades.overshootHelp",
        defaultValue: "How far the price went on in the trade's favour after the exit, from the captured bars.",
        bundle: L10n.bundle)
    }
    /// Overshoot in USD and in R.
    static func overshootValue(_ usd: String, _ r: String) -> LocalizedStringResource {
      LocalizedStringResource("trades.overshootValue", defaultValue: "\(usd) · \(r)", bundle: L10n.bundle)
    }
    /// Trade detail label: the price change at set minutes after the exit.
    static var priceAfterExit: LocalizedStringResource {
      LocalizedStringResource("trades.priceAfterExit", defaultValue: "Price after exit", bundle: L10n.bundle)
    }
    /// Stat card: average result in R.
    static var averageR: LocalizedStringResource {
      LocalizedStringResource("trades.averageR", defaultValue: "Average R", bundle: L10n.bundle)
    }
    /// Card title: the day's trade table.
    static var tradesOfDay: LocalizedStringResource {
      LocalizedStringResource("trades.tradesOfDay", defaultValue: "Trades of the day", bundle: L10n.bundle)
    }
    /// Trade table empty on the live day.
    static var noTradesToday: LocalizedStringResource {
      LocalizedStringResource("trades.noTradesToday", defaultValue: "No closed trades yet today.", bundle: L10n.bundle)
    }
    /// Trade table empty on a picked past day, naming the day ("Mon Nov 16"), so a pick of a day
    /// without trades visibly lands on that day.
    static func noTradesOn(_ day: String) -> LocalizedStringResource {
      LocalizedStringResource("trades.noTradesOn", defaultValue: "No trades on \(day)", bundle: L10n.bundle)
    }
    /// Under `noTradesOn`: what an empty past day means.
    static var noTradesOnDetail: LocalizedStringResource {
      LocalizedStringResource("trades.noTradesOnDetail",
        defaultValue: "The bot closed no trades that day.", bundle: L10n.bundle)
    }
    /// Shown while a picked past day's trades are read (the skeleton's VoiceOver label).
    static func loadingDay(_ day: String) -> LocalizedStringResource {
      LocalizedStringResource("trades.loadingDay", defaultValue: "Reading \(day)…", bundle: L10n.bundle)
    }
    /// A picked past day's trades could not be read: the unavailable state's title.
    static func dayUnavailable(_ day: String) -> LocalizedStringResource {
      LocalizedStringResource("trades.dayUnavailable", defaultValue: "\(day) is unavailable", bundle: L10n.bundle)
    }
    /// Its plain line when no cause is known.
    static var dayUnavailableDetail: LocalizedStringResource {
      LocalizedStringResource("trades.dayUnavailableDetail",
        defaultValue: "The bot's API did not send this day's trades.", bundle: L10n.bundle)
    }
    /// The API answered a day document of another day than the one asked for.
    static func otherDayAnswered(_ asked: String, _ answered: String) -> LocalizedStringResource {
      LocalizedStringResource("trades.otherDayAnswered",
        defaultValue: "Asked for \(asked), the API answered \(answered).", bundle: L10n.bundle)
    }
    /// Button: read the unavailable day again.
    static var retryDay: LocalizedStringResource {
      LocalizedStringResource("trades.retryDay", defaultValue: "Try again", bundle: L10n.bundle)
    }
    /// Column: time the trade closed (New York).
    static var closed: LocalizedStringResource {
      LocalizedStringResource("trades.closed", defaultValue: "Closed", bundle: L10n.bundle)
    }
    /// Column: symbol.
    static var symbol: LocalizedStringResource {
      LocalizedStringResource("trades.symbol", defaultValue: "Symbol", bundle: L10n.bundle)
    }
    /// Column and the selected trade: how the trade exited.
    static var exit: LocalizedStringResource {
      LocalizedStringResource("trades.exit", defaultValue: "Exit", bundle: L10n.bundle)
    }
    /// Context menu: open the trade's symbol on the Chart.
    static var showOnChart: LocalizedStringResource {
      LocalizedStringResource("trades.showOnChart", defaultValue: "Show on Chart", bundle: L10n.bundle)
    }
    /// Planned button: replay with another strategy.
    static var whatIfStrategy: LocalizedStringResource {
      LocalizedStringResource("trades.whatIfStrategy", defaultValue: "Other versions", bundle: L10n.bundle)
    }
    /// Tooltip of the Another Strategy button.
    static var anotherHelp: LocalizedStringResource {
      LocalizedStringResource("trades.anotherHelp",
        defaultValue: "How other versions would have traded this symbol that day (simulated on past days, not live trades)",
        bundle: L10n.bundle)
    }
    /// Title of the Another Strategy popover.
    static func anotherTitle(_ symbol: String) -> LocalizedStringResource {
      LocalizedStringResource("trades.anotherTitle", defaultValue: "If another version traded \(symbol)", bundle: L10n.bundle)
    }
    /// Another Strategy: the API offered no version.
    static var anotherNoVersions: LocalizedStringResource {
      LocalizedStringResource("trades.anotherNoVersions",
        defaultValue: "No strategy version to replay: the bot lists none.",
        bundle: L10n.bundle)
    }
    /// Another Strategy: the row of what the bot actually did.
    static var anotherBot: LocalizedStringResource {
      LocalizedStringResource("trades.anotherBot", defaultValue: "The bot", bundle: L10n.bundle)
    }
    /// Another Strategy: how the result was made.
    static var anotherNote: LocalizedStringResource {
      LocalizedStringResource("trades.anotherNote",
        // swiftlint:disable:next line_length
        defaultValue: "Simulated on that day's captured bars with the version's own stop, exit and size, gross before fees. Outside the session only.",
        bundle: L10n.bundle)
    }
    /// Another Strategy: one simulated trade, its times and how it ended.
    static func anotherLeg(_ opened: String, _ closed: String, _ reason: String) -> LocalizedStringResource {
      LocalizedStringResource("trades.anotherLeg", defaultValue: "\(opened) → \(closed) · \(reason)", bundle: L10n.bundle)
    }
    /// Another Strategy: the version never entered.
    static var anotherNoEntry: LocalizedStringResource {
      LocalizedStringResource("trades.anotherNoEntry",
        defaultValue: "No entry that day: its rules never said enter.",
        bundle: L10n.bundle)
    }
    /// Another Strategy: what the simulation did with each entry decision.
    static func anotherSignals(_ filled: Int, _ missed: Int, _ rejected: Int, _ ignored: Int) -> LocalizedStringResource {
      LocalizedStringResource("trades.anotherSignals",
        // swiftlint:disable:next line_length
        defaultValue: "Entries: \(filled) filled · \(missed) missed the window · \(rejected) too late · \(ignored) while in a trade",
        bundle: L10n.bundle)
    }
    /// The selected trade in one line: size, entry → exit, stop and its planned loss (1 R):
    /// "10 @ 12.34 → 12.98 · stop 11.90 · 1 R $3.90".
    static func fillLine(_ quantity: String, _ entry: String, _ exit: String, _ stop: String, _ oneR: String)
      -> LocalizedStringResource {
      LocalizedStringResource("trades.fillLine",
        defaultValue: "\(quantity) @ \(entry) → \(exit) · stop \(stop) · 1 R \(oneR)", bundle: L10n.bundle)
    }
    /// The same once the broker confirmed the stop: "… · stop 11.90 ✓ · 1 R $3.90".
    static func fillLineVerified(_ quantity: String, _ entry: String, _ exit: String, _ stop: String, _ oneR: String)
      -> LocalizedStringResource {
      LocalizedStringResource("trades.fillLineVerified",
        defaultValue: "\(quantity) @ \(entry) → \(exit) · stop \(stop) ✓ · 1 R \(oneR)", bundle: L10n.bundle)
    }
    /// An open position in the trades table: "10 @ 12.34 · stop 11.90".
    static func openLine(_ quantity: String, _ entry: String, _ stop: String) -> LocalizedStringResource {
      LocalizedStringResource("trades.openLine", defaultValue: "\(quantity) @ \(entry) · stop \(stop)", bundle: L10n.bundle)
    }
    /// The selected trade's line that opens the rest of its figures.
    static var details: LocalizedStringResource {
      LocalizedStringResource("trades.details", defaultValue: "Details", bundle: L10n.bundle)
    }
  }

  /// A refused entry in words: the rule behind its code, and the detail of a pause after a loss.
  enum Cause {
    /// Title of a refusal whose code this app has no words for; the bot's detail follows it.
    static var other: LocalizedStringResource {
      LocalizedStringResource("cause.other", defaultValue: "Other reason", bundle: L10n.bundle)
    }
    /// What the rule behind `code` is.
    static func title(_ code: RefusalCode) -> LocalizedStringResource {
      switch code {
      case .gateClosed: LocalizedStringResource("cause.gateClosed",
        defaultValue: "Trading gate closed", bundle: L10n.bundle)
      case .clockInvalid: LocalizedStringResource("cause.clockInvalid",
        defaultValue: "Clock check failed", bundle: L10n.bundle)
      case .notReconciled: LocalizedStringResource("cause.notReconciled",
        defaultValue: "Not yet reconciled with the broker", bundle: L10n.bundle)
      case .brokerReadMissing: LocalizedStringResource("cause.brokerReadMissing",
        defaultValue: "No broker read yet", bundle: L10n.bundle)
      case .brokerReadStale: LocalizedStringResource("cause.brokerReadStale",
        defaultValue: "Broker read too old", bundle: L10n.bundle)
      case .unresolvedExposure: LocalizedStringResource("cause.unresolvedExposure",
        defaultValue: "Unresolved exposure", bundle: L10n.bundle)
      case .foreignExposure: LocalizedStringResource("cause.foreignExposure",
        defaultValue: "Someone else's position or order at the broker", bundle: L10n.bundle)
      case .entryStop: LocalizedStringResource("cause.entryStop",
        defaultValue: "Entries paused by you", bundle: L10n.bundle)
      case .calendarUnknown: LocalizedStringResource("cause.calendarUnknown",
        defaultValue: "Market calendar unknown", bundle: L10n.bundle)
      case .calendarDayMismatch: LocalizedStringResource("cause.calendarDayMismatch",
        defaultValue: "Market calendar is for another day", bundle: L10n.bundle)
      case .halfDay: LocalizedStringResource("cause.halfDay",
        defaultValue: "Half day: entries off", bundle: L10n.bundle)
      case .outsideSession: LocalizedStringResource("cause.outsideSession",
        defaultValue: "Outside regular hours", bundle: L10n.bundle)
      case .beforeFirstEntry: LocalizedStringResource("cause.beforeFirstEntry",
        defaultValue: "Before the first entry time", bundle: L10n.bundle)
      case .sessionTimesInvalid: LocalizedStringResource("cause.sessionTimesInvalid",
        defaultValue: "Session hours invalid", bundle: L10n.bundle)
      case .afterLastEntry: LocalizedStringResource("cause.afterLastEntry",
        defaultValue: "After the last entry time", bundle: L10n.bundle)
      case .countInvalid: LocalizedStringResource("cause.countInvalid",
        defaultValue: "Position or order count invalid", bundle: L10n.bundle)
      case .ownPosition: LocalizedStringResource("cause.ownPosition",
        defaultValue: "Already holding this symbol", bundle: L10n.bundle)
      case .ownOrder: LocalizedStringResource("cause.ownOrder",
        defaultValue: "An order on this symbol is working", bundle: L10n.bundle)
      case .positionLimit: LocalizedStringResource("cause.positionLimit",
        defaultValue: "All position slots taken", bundle: L10n.bundle)
      case .workingEntryLimit: LocalizedStringResource("cause.workingEntryLimit",
        defaultValue: "Too many entries working at once", bundle: L10n.bundle)
      case .cooldown: LocalizedStringResource("cause.cooldown",
        defaultValue: "Pause after a loss", bundle: L10n.bundle)
      case .decisionNotEnter: LocalizedStringResource("cause.decisionNotEnter",
        defaultValue: "Signal is not an entry", bundle: L10n.bundle)
      case .decisionNotActive: LocalizedStringResource("cause.decisionNotActive",
        defaultValue: "Signal from a strategy not in use", bundle: L10n.bundle)
      case .strategyNotExtended: LocalizedStringResource("cause.strategyNotExtended",
        defaultValue: "Strategy may not enter outside regular hours", bundle: L10n.bundle)
      case .decisionIncomplete: LocalizedStringResource("cause.decisionIncomplete",
        defaultValue: "Signal missing prices or size", bundle: L10n.bundle)
      case .decisionInvalid: LocalizedStringResource("cause.decisionInvalid",
        defaultValue: "Signal prices or size invalid", bundle: L10n.bundle)
      case .orderPricesMissing: LocalizedStringResource("cause.orderPricesMissing",
        defaultValue: "Order prices not computed", bundle: L10n.bundle)
      case .orderPricesInvalid: LocalizedStringResource("cause.orderPricesInvalid",
        defaultValue: "Order prices invalid", bundle: L10n.bundle)
      case .setupInvalidated: LocalizedStringResource("cause.setupInvalidated",
        defaultValue: "Setup no longer valid", bundle: L10n.bundle)
      case .quoteMissing: LocalizedStringResource("cause.quoteMissing",
        defaultValue: "No quote", bundle: L10n.bundle)
      case .quoteSymbolMismatch: LocalizedStringResource("cause.quoteSymbolMismatch",
        defaultValue: "Quote for another symbol", bundle: L10n.bundle)
      case .quoteInvalid: LocalizedStringResource("cause.quoteInvalid",
        defaultValue: "Quote prices unusable", bundle: L10n.bundle)
      case .quoteTimeInvalid: LocalizedStringResource("cause.quoteTimeInvalid",
        defaultValue: "Quote time invalid", bundle: L10n.bundle)
      case .quoteStale: LocalizedStringResource("cause.quoteStale",
        defaultValue: "Quote too old", bundle: L10n.bundle)
      case .spreadTooWide: LocalizedStringResource("cause.spreadTooWide",
        defaultValue: "Spread too wide", bundle: L10n.bundle)
      case .priceOutside: LocalizedStringResource("cause.priceOutside",
        defaultValue: "Price left the entry window", bundle: L10n.bundle)
      case .quantityBelowOne: LocalizedStringResource("cause.quantityBelowOne",
        defaultValue: "Size under one share", bundle: L10n.bundle)
      case .quantityNotWhole: LocalizedStringResource("cause.quantityNotWhole",
        defaultValue: "Size not whole shares", bundle: L10n.bundle)
      case .notionalOverCap: LocalizedStringResource("cause.notionalOverCap",
        defaultValue: "Position value over the cap", bundle: L10n.bundle)
      case .plannedLossOver: LocalizedStringResource("cause.plannedLossOver",
        defaultValue: "Planned loss over the limit", bundle: L10n.bundle)
      case .dailyMoneyUnknown: LocalizedStringResource("cause.dailyMoneyUnknown",
        defaultValue: "Today's loss figures unknown", bundle: L10n.bundle)
      case .dailyMoneyInvalid: LocalizedStringResource("cause.dailyMoneyInvalid",
        defaultValue: "Today's loss figures invalid", bundle: L10n.bundle)
      case .dailyCeiling: LocalizedStringResource("cause.dailyCeiling",
        defaultValue: "Daily loss limit reached", bundle: L10n.bundle)
      case .weeklyMoneyUnknown: LocalizedStringResource("cause.weeklyMoneyUnknown",
        defaultValue: "This week's loss figures unknown", bundle: L10n.bundle)
      case .weeklyMoneyInvalid: LocalizedStringResource("cause.weeklyMoneyInvalid",
        defaultValue: "This week's loss figures invalid", bundle: L10n.bundle)
      case .weeklyCeiling: LocalizedStringResource("cause.weeklyCeiling",
        defaultValue: "Weekly loss limit reached", bundle: L10n.bundle)
      case .stopOutStreak: LocalizedStringResource("cause.stopOutStreak",
        defaultValue: "Too many stop-outs in a row today", bundle: L10n.bundle)
      case .buyingPowerUnknown: LocalizedStringResource("cause.buyingPowerUnknown",
        defaultValue: "Buying power not read", bundle: L10n.bundle)
      case .buyingPowerShort: LocalizedStringResource("cause.buyingPowerShort",
        defaultValue: "Not enough buying power", bundle: L10n.bundle)
      case .equityUnknown: LocalizedStringResource("cause.equityUnknown",
        defaultValue: "Equity not read", bundle: L10n.bundle)
      case .entryBudget: LocalizedStringResource("cause.entryBudget",
        defaultValue: "No request budget for the entry", bundle: L10n.bundle)
      case .stopBudget: LocalizedStringResource("cause.stopBudget",
        defaultValue: "No request budget for the stop", bundle: L10n.bundle)
      case .priceCollarUnknown: LocalizedStringResource("cause.priceCollarUnknown",
        defaultValue: "Price collar prices missing", bundle: L10n.bundle)
      case .priceCollarBreach: LocalizedStringResource("cause.priceCollarBreach",
        defaultValue: "Limit too far from the last price", bundle: L10n.bundle)
      case .tradabilityBudget: LocalizedStringResource("cause.tradabilityBudget",
        defaultValue: "No request budget for the tradability check", bundle: L10n.bundle)
      case .tradabilityUnknown: LocalizedStringResource("cause.tradabilityUnknown",
        defaultValue: "Tradability not known", bundle: L10n.bundle)
      case .instrumentHalted: LocalizedStringResource("cause.instrumentHalted",
        defaultValue: "Trading halted", bundle: L10n.bundle)
      case .instrumentCloseOnly: LocalizedStringResource("cause.instrumentCloseOnly",
        defaultValue: "Broker allows closing only", bundle: L10n.bundle)
      case .instrumentDenied: LocalizedStringResource("cause.instrumentDenied",
        defaultValue: "Broker denies trading this stock", bundle: L10n.bundle)
      case .instrumentNotTradable: LocalizedStringResource("cause.instrumentNotTradable",
        defaultValue: "Stock not tradable now", bundle: L10n.bundle)
      case .engineRefused: LocalizedStringResource("cause.engineRefused",
        defaultValue: "Refused when opening the trade", bundle: L10n.bundle)
      }
    }
    /// Detail of a pause after a loss: when the losing trade closed and when entries may resume.
    static func cooldownDetail(_ loss: String, _ until: String) -> LocalizedStringResource {
      LocalizedStringResource("cause.cooldownDetail", defaultValue: "loss at \(loss) · no entry before \(until)",
        bundle: L10n.bundle)
    }
  }

  enum Risk {
    /// Over the loss limit while a recorded day is picked: this screen stays on today.
    static func liveOnly(_ day: String) -> LocalizedStringResource {
      LocalizedStringResource("risk.liveOnly",
        defaultValue: "Live: today's limits and the broker now. \(day) is a recorded day.", bundle: L10n.bundle)
    }
    /// Card title: room left before the daily loss limit.
    static var lossRoom: LocalizedStringResource {
      LocalizedStringResource("risk.lossRoom", defaultValue: "Room left today", bundle: L10n.bundle)
    }
    /// Under the room left: "of $300.00", the daily loss limit.
    static func ofLimit(_ limit: String) -> LocalizedStringResource {
      LocalizedStringResource("risk.ofLimit", defaultValue: "of \(limit)", bundle: L10n.bundle)
    }
    /// The gauge's name for VoiceOver.
    static var roomLeft: LocalizedStringResource {
      LocalizedStringResource("risk.roomLeft", defaultValue: "room left today", bundle: L10n.bundle)
    }
    /// Today's net result.
    static var resultToday: LocalizedStringResource {
      LocalizedStringResource("risk.resultToday", defaultValue: "Day result", bundle: L10n.bundle)
    }
    /// How the daily limit works.
    static var lossRoomNote: LocalizedStringResource {
      LocalizedStringResource("risk.lossRoomNote",
        // swiftlint:disable:next line_length
        defaultValue: "Profits offset losses but never raise the room above the limit. Open reservations, the worst case of entries in flight, count against it. Near the limit the bot sizes trades down to the room left; below the minimum room it stops entering.",
        bundle: L10n.bundle)
    }
    /// Loss counted against the daily limit so far (net of fees: the same money as the day's
    /// result when the day is down, so the label says what it is for, not a second total).
    static var realizedLoss: LocalizedStringResource {
      LocalizedStringResource("risk.realizedLoss", defaultValue: "Lost on losers", bundle: L10n.bundle)
    }
    /// What open orders hold of the daily room, and how many positions are open.
    static func reservations(_ positions: Int) -> LocalizedStringResource {
      LocalizedStringResource("risk.reservations", defaultValue: "Held for open orders · \(positions) open",
        bundle: L10n.bundle)
    }
    /// Configured minimum daily room for an entry.
    static var minRoom: LocalizedStringResource {
      LocalizedStringResource("risk.minRoom", defaultValue: "Stop entering below room of", bundle: L10n.bundle)
    }
    /// When a fence was raised (New York time).
    static func fenceSince(_ time: String) -> LocalizedStringResource {
      LocalizedStringResource("risk.fenceSince", defaultValue: "since \(time)", bundle: L10n.bundle)
    }
    /// Card title: configured risk limits.
    static var limits: LocalizedStringResource {
      LocalizedStringResource("risk.limits", defaultValue: "Limits", bundle: L10n.bundle)
    }
    /// Configured planned loss.
    static var plannedLoss: LocalizedStringResource {
      LocalizedStringResource("risk.plannedLoss", defaultValue: "Planned loss per trade", bundle: L10n.bundle)
    }
    /// Configured notional cap.
    static var notionalCap: LocalizedStringResource {
      LocalizedStringResource("risk.notionalCap", defaultValue: "Position size cap", bundle: L10n.bundle)
    }
    /// The position slots card: open positions of the most allowed ("Positions · 2 of 3").
    static func slots(_ count: Int, _ limit: String) -> LocalizedStringResource {
      LocalizedStringResource("risk.slots", defaultValue: "Positions · \(count) of \(limit)", bundle: L10n.bundle)
    }
    /// A free position slot.
    static var freeSlot: LocalizedStringResource {
      LocalizedStringResource("risk.freeSlot", defaultValue: "Free", bundle: L10n.bundle)
    }
    /// A taken slot's size, entry and what it loses at its stop: "10 at 12.34 · max loss $4.40".
    static func slotSize(_ quantity: String, _ entry: String, _ maxLoss: String) -> LocalizedStringResource {
      LocalizedStringResource("risk.slotSize", defaultValue: "\(quantity) at \(entry) · max loss \(maxLoss)",
        bundle: L10n.bundle)
    }
    /// An open position's stop in its slot.
    static func slotStop(_ price: String) -> LocalizedStringResource {
      LocalizedStringResource("risk.slotStop", defaultValue: "stop \(price)", bundle: L10n.bundle)
    }
    /// Configured quote age.
    static var quoteAge: LocalizedStringResource {
      LocalizedStringResource("risk.quoteAge", defaultValue: "Oldest price to trade on", bundle: L10n.bundle)
    }
    /// A duration in seconds.
    static func seconds(_ value: String) -> LocalizedStringResource {
      LocalizedStringResource("risk.seconds", defaultValue: "\(value) s", bundle: L10n.bundle)
    }
    /// Settings read failed.
    static var settingsUnavailable: LocalizedStringResource {
      LocalizedStringResource("risk.settingsUnavailable", defaultValue: "Settings are unavailable; the bot's API did not answer.",
        bundle: L10n.bundle)
    }
    /// The market clock on the Session card: "14:46:17 ET", 24-hour New York time.
    static func clock(_ time: String) -> LocalizedStringResource {
      LocalizedStringResource("risk.clock", defaultValue: "\(time) ET", bundle: L10n.bundle)
    }
    /// Last entry time.
    static var lastEntry: LocalizedStringResource {
      LocalizedStringResource("risk.lastEntry", defaultValue: "Last entry", bundle: L10n.bundle)
    }
    /// Flatten time.
    static var flatten: LocalizedStringResource {
      LocalizedStringResource("risk.flatten", defaultValue: "Close all", bundle: L10n.bundle)
    }
    /// Half-day handling.
    static var halfDays: LocalizedStringResource {
      LocalizedStringResource("risk.halfDays", defaultValue: "Half days", bundle: L10n.bundle)
    }
    /// Minutes before the close.
    static func minutesBeforeClose(_ minutes: Int) -> LocalizedStringResource {
      LocalizedStringResource("risk.minutesBeforeClose", defaultValue: "\(minutes) min before close", bundle: L10n.bundle)
    }
    /// Card title: broker account.
    static var account: LocalizedStringResource {
      LocalizedStringResource("risk.account", defaultValue: "Account", bundle: L10n.bundle)
    }
    /// Account equity.
    static var equity: LocalizedStringResource {
      LocalizedStringResource("risk.equity", defaultValue: "Equity", bundle: L10n.bundle)
    }
    /// Account buying power.
    static var buyingPower: LocalizedStringResource {
      LocalizedStringResource("risk.buyingPower", defaultValue: "Buying power", bundle: L10n.bundle)
    }
    /// Positions the broker reports.
    static var brokerPositions: LocalizedStringResource {
      LocalizedStringResource("risk.brokerPositions", defaultValue: "Broker positions", bundle: L10n.bundle)
    }
    /// Orders the broker reports.
    static var brokerOrders: LocalizedStringResource {
      LocalizedStringResource("risk.brokerOrders", defaultValue: "Open orders at broker", bundle: L10n.bundle)
    }
    /// Why equity and buying power are empty.
    static var balanceNote: LocalizedStringResource {
      LocalizedStringResource("risk.balanceNote",
        defaultValue: "The bot has not read the balance from the broker yet.",
        bundle: L10n.bundle)
    }
    /// Account cash.
    static var cash: LocalizedStringResource {
      LocalizedStringResource("risk.cash", defaultValue: "Cash", bundle: L10n.bundle)
    }
    /// Buying power held overnight.
    static var overnightBuyingPower: LocalizedStringResource {
      LocalizedStringResource("risk.overnightBuyingPower", defaultValue: "Buying power · overnight", bundle: L10n.bundle)
    }
    /// Positions at market value.
    static var positionsValue: LocalizedStringResource {
      LocalizedStringResource("risk.positionsValue", defaultValue: "Positions value", bundle: L10n.bundle)
    }
    /// Unrealized profit or loss of open positions.
    static var unrealized: LocalizedStringResource {
      LocalizedStringResource("risk.unrealized", defaultValue: "Unrealized P&L", bundle: L10n.bundle)
    }
    /// The broker's profit or loss for today, open positions' unrealized P&L included: it can
    /// differ in sign from the bot's closed-trade result, so the label says so.
    static var dayResult: LocalizedStringResource {
      LocalizedStringResource("risk.dayResult", defaultValue: "Day P&L", bundle: L10n.bundle)
    }
    /// Day trades left when the broker sets no limit.
    static var noLimit: LocalizedStringResource {
      LocalizedStringResource("risk.noLimit", defaultValue: "no limit", bundle: L10n.bundle)
    }
    /// Help on the account kind badge.
    static var accountKindHelp: LocalizedStringResource {
      LocalizedStringResource("risk.accountKindHelp",
        defaultValue: "The account kind as the broker names it. The account id is never shown or stored.",
        bundle: L10n.bundle)
    }
    /// Today's fills the broker lists.
    static var fillsToday: LocalizedStringResource {
      LocalizedStringResource("risk.fillsToday", defaultValue: "Fills today", bundle: L10n.bundle)
    }
    /// Badge: the broker's view matches the bot's records.
    static var matches: LocalizedStringResource {
      LocalizedStringResource("risk.matches", defaultValue: "All match", bundle: L10n.bundle)
    }
    /// Badge: the broker's view differs from the bot's records.
    static var mismatch: LocalizedStringResource {
      LocalizedStringResource("risk.mismatch", defaultValue: "Records differ", bundle: L10n.bundle)
    }
    /// Badge: the account read is older than the API allows.
    static var stale: LocalizedStringResource {
      LocalizedStringResource("risk.stale", defaultValue: "STALE", bundle: L10n.bundle)
    }
    /// When the broker was read, beside the account kind: "at 10:48:03 ET".
    static func readAt(_ time: String) -> LocalizedStringResource {
      LocalizedStringResource("risk.readAt", defaultValue: "at \(time) ET", bundle: L10n.bundle)
    }
    /// An empty list of broker positions or orders.
    static var none: LocalizedStringResource {
      LocalizedStringResource("risk.none", defaultValue: "None", bundle: L10n.bundle)
    }
    /// Badge: a broker order or position the bot did not place.
    static var notOurs: LocalizedStringResource {
      LocalizedStringResource("risk.notOurs", defaultValue: "NOT OURS", bundle: L10n.bundle)
    }
    /// The account read failed.
    static var accountUnavailable: LocalizedStringResource {
      LocalizedStringResource("risk.accountUnavailable",
        defaultValue: "The account read is unavailable; the bot's API did not answer it.",
        bundle: L10n.bundle)
    }
    /// Before the first account answer.
    static var accountReading: LocalizedStringResource {
      LocalizedStringResource("risk.accountReading", defaultValue: "Reading the account…", bundle: L10n.bundle)
    }
    /// Loss card pill: the bot may open a position now.
    static var entriesOpen: LocalizedStringResource {
      LocalizedStringResource("risk.entriesOpen", defaultValue: "Entries open", bundle: L10n.bundle)
    }
    /// Loss card pill: entries wait for an ordinary reason that passes on its own.
    static var entriesWaiting: LocalizedStringResource {
      LocalizedStringResource("risk.entriesWaiting", defaultValue: "Entries wait", bundle: L10n.bundle)
    }
    /// Loss card pill: entries are blocked for a reason to look at.
    static var entriesBlocked: LocalizedStringResource {
      LocalizedStringResource("risk.entriesBlocked", defaultValue: "Entries blocked", bundle: L10n.bundle)
    }
    /// Card: broker reconciliation and every kind of fence.
    static var reconciliation: LocalizedStringResource {
      LocalizedStringResource("risk.reconciliation", defaultValue: "Broker check", bundle: L10n.bundle)
    }
    /// Fence group: a position or order the bot did not open.
    static var fenceForeign: LocalizedStringResource {
      LocalizedStringResource("risk.fenceForeign", defaultValue: "Foreign exposure", bundle: L10n.bundle)
    }
    /// Fence group: quantities differ from the broker.
    static var fenceQuantity: LocalizedStringResource {
      LocalizedStringResource("risk.fenceQuantity", defaultValue: "Quantity mismatch", bundle: L10n.bundle)
    }
    /// Fence group: an order whose state the bot cannot read.
    static var fenceOrderStatus: LocalizedStringResource {
      LocalizedStringResource("risk.fenceOrderStatus", defaultValue: "Unknown order status", bundle: L10n.bundle)
    }
    /// Fence group: a position without a working stop.
    static var fenceProtection: LocalizedStringResource {
      LocalizedStringResource("risk.fenceProtection", defaultValue: "Stop protection", bundle: L10n.bundle)
    }
    /// Fence group: a close or cancel that failed.
    static var fenceExits: LocalizedStringResource {
      LocalizedStringResource("risk.fenceExits", defaultValue: "Exits and cancels", bundle: L10n.bundle)
    }
    /// Fence group: the bot cannot read the broker.
    static var fenceBrokerReads: LocalizedStringResource {
      LocalizedStringResource("risk.fenceBrokerReads", defaultValue: "Broker reads", bundle: L10n.bundle)
    }
    /// Fence group: the session closed, shutdown or the operator stop.
    static var fenceSession: LocalizedStringResource {
      LocalizedStringResource("risk.fenceSession", defaultValue: "Session and operator stop", bundle: L10n.bundle)
    }
    /// A fence group with an active fence.
    static var fenceActive: LocalizedStringResource {
      LocalizedStringResource("risk.fenceActive", defaultValue: "active", bundle: L10n.bundle)
    }
    /// A fence group with no active fence.
    static var fenceNone: LocalizedStringResource {
      LocalizedStringResource("risk.fenceNone", defaultValue: "none", bundle: L10n.bundle)
    }
    /// Countdown ring: seconds to the next broker read.
    static var nextRead: LocalizedStringResource {
      LocalizedStringResource("risk.nextRead", defaultValue: "Next broker read", bundle: L10n.bundle)
    }
    /// Check: positions whose stop the broker confirmed.
    static func stopsCover(_ covered: Int, _ total: Int) -> LocalizedStringResource {
      LocalizedStringResource("risk.stopsCover",
        defaultValue: "\(covered) of \(total) stops confirmed at the broker",
        bundle: L10n.bundle)
    }
    /// When the bot reads the broker next (New York time).
    static func nextReadAt(_ time: String) -> LocalizedStringResource {
      LocalizedStringResource("risk.nextReadAt", defaultValue: "Next read at \(time)", bundle: L10n.bundle)
    }
    /// The bot does not run, so no broker read is planned.
    static var nextReadUnknown: LocalizedStringResource {
      LocalizedStringResource("risk.nextReadUnknown",
        defaultValue: "No next read: the bot is not running",
        bundle: L10n.bundle)
    }
    /// GET /jobs failed.
    static var jobsUnavailable: LocalizedStringResource {
      LocalizedStringResource("risk.jobsUnavailable",
        defaultValue: "Next read unknown: jobs unavailable",
        bundle: L10n.bundle)
    }
    /// Planned card: broker calls per route.
    static var budget: LocalizedStringResource {
      LocalizedStringResource("risk.budget", defaultValue: "Request budget · per route", bundle: L10n.bundle)
    }
    /// Planned card: what the request budget will show.
    static var budgetNote: LocalizedStringResource {
      LocalizedStringResource("risk.budgetNote",
        // swiftlint:disable:next line_length
        defaultValue: "Calls per broker route in the last minute, and the entry and stop budget kept before every order. Hitting the budget will be shown, never a silent cut.",
        bundle: L10n.bundle)
    }
    /// Planned card: quote freshness per symbol.
    static var stream: LocalizedStringResource {
      LocalizedStringResource("risk.stream", defaultValue: "Quote stream · per symbol", bundle: L10n.bundle)
    }
    /// Planned card: what the quote stream card will show.
    static var streamNote: LocalizedStringResource {
      LocalizedStringResource("risk.streamNote",
        // swiftlint:disable:next line_length
        defaultValue: "Fresh, quiet or lost quotes for every watched symbol, and the quote latency from the provider. Today the app shows one stream state and the quote age.",
        bundle: L10n.bundle)
    }
    /// Planned card chip: the bot does not serve this yet.
    static var notServed: LocalizedStringResource {
      LocalizedStringResource("risk.notServed", defaultValue: "Not in /status yet", bundle: L10n.bundle)
    }
    /// Loss card pill while the bot status is unknown.
    static var entriesUnknown: LocalizedStringResource {
      LocalizedStringResource("risk.entriesUnknown", defaultValue: "Status unknown", bundle: L10n.bundle)
    }
    /// Fence row: the operator stopped new entries.
    static var fenceOperator: LocalizedStringResource {
      LocalizedStringResource("risk.fenceOperator", defaultValue: "Operator entry stop", bundle: L10n.bundle)
    }
    /// Where the limits come from.
    static var limitsSource: LocalizedStringResource {
      LocalizedStringResource("risk.limitsSource", defaultValue: "config/bot.toml · read only", bundle: L10n.bundle)
    }
    /// Configured daily loss limit.
    static var dailyLoss: LocalizedStringResource {
      LocalizedStringResource("risk.dailyLoss", defaultValue: "Daily loss limit", bundle: L10n.bundle)
    }
    /// Configured limit of open positions.
    static var openPositions: LocalizedStringResource {
      LocalizedStringResource("risk.openPositions", defaultValue: "Open positions at most", bundle: L10n.bundle)
    }
    /// After the session clock: New York time.
    static var timeZone: LocalizedStringResource {
      LocalizedStringResource("risk.timeZone", defaultValue: "ET", bundle: L10n.bundle)
    }
    /// The regular session is open, with its hours.
    static func sessionOpen(_ hours: String) -> LocalizedStringResource {
      LocalizedStringResource("risk.sessionOpen", defaultValue: "open · \(hours)", bundle: L10n.bundle)
    }
    /// The regular session is closed, with its hours.
    static func sessionClosed(_ hours: String) -> LocalizedStringResource {
      LocalizedStringResource("risk.sessionClosed", defaultValue: "closed · \(hours)", bundle: L10n.bundle)
    }
    /// The session card's title.
    static var market: LocalizedStringResource {
      LocalizedStringResource("risk.market", defaultValue: "Market", bundle: L10n.bundle)
    }
    /// What the broker check covers, under its verdict.
    static var checkCovers: LocalizedStringResource {
      LocalizedStringResource("risk.checkCovers", defaultValue: "Positions, orders and stops", bundle: L10n.bundle)
    }
    /// The line that opens every kind of safety stop (fence).
    static var safetyStops: LocalizedStringResource {
      LocalizedStringResource("risk.safetyStops", defaultValue: "Safety stops", bundle: L10n.bundle)
    }
    /// No safety stop is up.
    static var noneActive: LocalizedStringResource {
      LocalizedStringResource("risk.noneActive", defaultValue: "None active", bundle: L10n.bundle)
    }
    /// The line that opens the other balances.
    static var moreBalances: LocalizedStringResource {
      LocalizedStringResource("risk.moreBalances", defaultValue: "More balances", bundle: L10n.bundle)
    }
    /// Day trades the broker still allows today.
    static var dayTradesLeft: LocalizedStringResource {
      LocalizedStringResource("risk.dayTradesLeft", defaultValue: "Day trades left", bundle: L10n.bundle)
    }
    /// Open margin calls and the maintenance margin.
    static var marginCalls: LocalizedStringResource {
      LocalizedStringResource("risk.marginCalls", defaultValue: "Margin calls · maintenance", bundle: L10n.bundle)
    }
    /// Their values: "0 · $0.00".
    static func marginValue(_ calls: String, _ maintenance: String) -> LocalizedStringResource {
      LocalizedStringResource("risk.marginValue", defaultValue: "\(calls) · \(maintenance)", bundle: L10n.bundle)
    }
  }

  enum Lab {
    /// Card: the entries the platform's limits refused on the shown day, counted by cause.
    static var refusals: LocalizedStringResource {
      LocalizedStringResource("lab.refusals", defaultValue: "Blocked by safety rules", bundle: L10n.bundle)
    }
    static var noRefusals: LocalizedStringResource {
      LocalizedStringResource("lab.noRefusals", defaultValue: "No signal was refused.", bundle: L10n.bundle)
    }
    static var noCause: LocalizedStringResource {
      LocalizedStringResource("lab.noCause", defaultValue: "No cause recorded", bundle: L10n.bundle)
    }
    /// How strategies are swapped.
    static var swapNote: LocalizedStringResource {
      LocalizedStringResource("lab.swapNote",
        // swiftlint:disable:next line_length
        defaultValue: "Strategies are swappable modules: the active one is set in the bot's config and never loosens platform risk.",
        bundle: L10n.bundle)
    }
    /// Decision: ignore the symbol.
    static var verdictIgnore: LocalizedStringResource {
      LocalizedStringResource("lab.verdictIgnore", defaultValue: "ignore", bundle: L10n.bundle)
    }
    /// Decision: watch the symbol.
    static var verdictWatch: LocalizedStringResource {
      LocalizedStringResource("lab.verdictWatch", defaultValue: "watch", bundle: L10n.bundle)
    }
    /// Decision: enter.
    static var verdictEnter: LocalizedStringResource {
      LocalizedStringResource("lab.verdictEnter", defaultValue: "enter", bundle: L10n.bundle)
    }
    /// Decision: hold the position.
    static var verdictHold: LocalizedStringResource {
      LocalizedStringResource("lab.verdictHold", defaultValue: "hold", bundle: L10n.bundle)
    }
    /// Decision: exit.
    static var verdictExit: LocalizedStringResource {
      LocalizedStringResource("lab.verdictExit", defaultValue: "exit", bundle: L10n.bundle)
    }
    /// Card title: the replay that compares two versions.
    static var replay: LocalizedStringResource {
      LocalizedStringResource("lab.replay", defaultValue: "Compare two versions", bundle: L10n.bundle)
    }
    /// Replay card before any run.
    static var replayIdle: LocalizedStringResource {
      LocalizedStringResource("lab.replayIdle", defaultValue: "No replay yet.", bundle: L10n.bundle)
    }
    /// Replay result label: trades taken.
    static var replayTrades: LocalizedStringResource {
      LocalizedStringResource("lab.replayTrades", defaultValue: "trades", bundle: L10n.bundle)
    }
    /// Replay result label: share of winning trades.
    static var replayWinRate: LocalizedStringResource {
      LocalizedStringResource("lab.replayWinRate", defaultValue: "win rate", bundle: L10n.bundle)
    }
    /// Replay result label: mean result in R.
    static var replayMeanR: LocalizedStringResource {
      LocalizedStringResource("lab.replayMeanR", defaultValue: "mean R", bundle: L10n.bundle)
    }
    /// Replay result label: profit factor.
    static var replayProfitFactor: LocalizedStringResource {
      LocalizedStringResource("lab.replayProfitFactor", defaultValue: "profit factor", bundle: L10n.bundle)
    }
    /// Replay result label: largest drawdown in R.
    static var replayMaxDrawdown: LocalizedStringResource {
      LocalizedStringResource("lab.replayMaxDrawdown", defaultValue: "max drawdown", bundle: L10n.bundle)
    }
    /// Why the replay button rests: the regular session is open until this New York time.
    static func replayAvailableAfter(_ time: String) -> LocalizedStringResource {
      LocalizedStringResource("lab.replayAvailableAfter", defaultValue: "Available after \(time) ET", bundle: L10n.bundle)
    }
    /// Before the countdown to the time the replay is available again.
    static var replayAvailableIn: LocalizedStringResource {
      LocalizedStringResource("lab.replayAvailableIn", defaultValue: "in", bundle: L10n.bundle)
    }
    /// Replay running, with its start time.
    static func replayRunningSince(_ time: String) -> LocalizedStringResource {
      LocalizedStringResource("lab.replayRunningSince", defaultValue: "Running since \(time)", bundle: L10n.bundle)
    }
    /// Replay mean R with its confidence interval.
    static func replayMeanRInterval(_ confidence: String, _ low: String, _ high: String) -> LocalizedStringResource {
      LocalizedStringResource("lab.replayMeanRInterval", defaultValue: "mean R · \(confidence)%: \(low) … \(high)",
        bundle: L10n.bundle)
    }
    /// Replay data range and its session count.
    static func replayData(_ first: String, _ last: String, _ sessions: Int) -> LocalizedStringResource {
      LocalizedStringResource("lab.replayData", defaultValue: "Data \(first) – \(last) (\(sessions) sessions) · ends \(last)",
        bundle: L10n.bundle)
    }
    /// Replay choice: the version to replay.
    static var replayVersion: LocalizedStringResource {
      LocalizedStringResource("lab.replayVersion", defaultValue: "Version", bundle: L10n.bundle)
    }
    /// Replay choice: a second version over the same days.
    static var replayCompare: LocalizedStringResource {
      LocalizedStringResource("lab.replayCompare", defaultValue: "Compare with", bundle: L10n.bundle)
    }
    /// Replay choice: no second version.
    static var replayCompareNone: LocalizedStringResource {
      LocalizedStringResource("lab.replayCompareNone", defaultValue: "No comparison", bundle: L10n.bundle)
    }
    /// Replay choice: which days.
    static var replayDays: LocalizedStringResource {
      LocalizedStringResource("lab.replayDays", defaultValue: "Days", bundle: L10n.bundle)
    }
    /// Replay days: the latest sessions of the fetched data.
    static func replayLastSessions(_ sessions: Int) -> LocalizedStringResource {
      LocalizedStringResource("lab.replayLastSessions", defaultValue: "Last \(sessions) sessions", bundle: L10n.bundle)
    }
    /// Replay days: one day of the fetched data.
    static var replayOneDay: LocalizedStringResource {
      LocalizedStringResource("lab.replayOneDay", defaultValue: "One day", bundle: L10n.bundle)
    }
    /// Replay button.
    static var replayRun: LocalizedStringResource {
      LocalizedStringResource("lab.replayRun", defaultValue: "Replay", bundle: L10n.bundle)
    }
    /// Replay button with a second version chosen.
    static var replayRunCompare: LocalizedStringResource {
      LocalizedStringResource("lab.replayRunCompare", defaultValue: "Replay and Compare", bundle: L10n.bundle)
    }
    /// A strategy version: its name and version.
    static func versionName(_ name: String, _ version: String) -> LocalizedStringResource {
      LocalizedStringResource("lab.versionName", defaultValue: "\(name) v\(version)", bundle: L10n.bundle)
    }
    /// A strategy version in a picker, with its role.
    static func versionWithRole(_ name: String, _ role: String) -> LocalizedStringResource {
      LocalizedStringResource("lab.versionWithRole", defaultValue: "\(name) · \(role)", bundle: L10n.bundle)
    }
    /// Role of the version that trades.
    static var roleActive: LocalizedStringResource {
      LocalizedStringResource("lab.roleActive", defaultValue: "active", bundle: L10n.bundle)
    }
    /// Role of a version that decides live but never trades.
    static var roleObserver: LocalizedStringResource {
      LocalizedStringResource("lab.roleObserver", defaultValue: "observer", bundle: L10n.bundle)
    }
    /// Role of any other strategy folder.
    static var roleCandidate: LocalizedStringResource {
      LocalizedStringResource("lab.roleCandidate", defaultValue: "candidate", bundle: L10n.bundle)
    }
    /// Replay running: the second version waits for the first.
    static func replayThen(_ name: String) -> LocalizedStringResource {
      LocalizedStringResource("lab.replayThen", defaultValue: "Then \(name), over the same days", bundle: L10n.bundle)
    }
    /// Replay of one day: how to read it.
    static func replayOneDayNote(_ day: String) -> LocalizedStringResource {
      LocalizedStringResource("lab.replayOneDayNote",
        defaultValue: "\(day) only: one day proves nothing, read it as an example.",
        bundle: L10n.bundle)
    }
    /// Comparison column: the second version minus the first.
    static var replayDifference: LocalizedStringResource {
      LocalizedStringResource("lab.replayDifference", defaultValue: "difference", bundle: L10n.bundle)
    }
    /// Comparison row: the net result under the bot's risk limits, USD.
    static var replayWithBotLimits: LocalizedStringResource {
      LocalizedStringResource("lab.replayWithBotLimits", defaultValue: "net with bot limits", bundle: L10n.bundle)
    }
    /// A difference of two percentages, in points.
    static func replayPoints(_ value: String) -> LocalizedStringResource {
      LocalizedStringResource("lab.replayPoints", defaultValue: "\(value) pt", bundle: L10n.bundle)
    }
    /// Comparison: the second version failed, with the cause.
    static func replayCompareFailed(_ name: String, _ cause: String) -> LocalizedStringResource {
      LocalizedStringResource("lab.replayCompareFailed", defaultValue: "\(name) was not replayed: \(cause)", bundle: L10n.bundle)
    }
    /// What the replay does.
    static var replayNote: LocalizedStringResource {
      LocalizedStringResource("lab.replayNote",
        // swiftlint:disable:next line_length
        defaultValue: "Replays a strategy version over the data fetched on the Mac, at low priority. Simulated: the bot never reads it.",
        bundle: L10n.bundle)
    }
    /// Card: every model version and its role.
    static var versions: LocalizedStringResource {
      LocalizedStringResource("lab.versions", defaultValue: "Model versions", bundle: L10n.bundle)
    }
    /// Role tag: the version that trades.
    static var tagActive: LocalizedStringResource {
      LocalizedStringResource("lab.tagActive", defaultValue: "Active", bundle: L10n.bundle)
    }
    /// Role tag: a version only the replay runs.
    static var tagCandidate: LocalizedStringResource {
      LocalizedStringResource("lab.tagCandidate", defaultValue: "Candidate", bundle: L10n.bundle)
    }
    /// After a version name: its version.
    static func versionSuffix(_ version: String) -> LocalizedStringResource {
      LocalizedStringResource("lab.versionSuffix", defaultValue: " · v\(version)", bundle: L10n.bundle)
    }
    /// Beside the refusals' total on the live day.
    static var refusalsToday: LocalizedStringResource {
      LocalizedStringResource("lab.refusalsToday", defaultValue: "today", bundle: L10n.bundle)
    }
    /// How the replay runs.
    static var replayPriority: LocalizedStringResource {
      LocalizedStringResource("lab.replayPriority",
        // swiftlint:disable:next line_length
        defaultValue: "Replays on the Mac at low priority, one version after the other over the same days. Outside the session only; during it the button rests with the reason.",
        bundle: L10n.bundle)
    }
    /// Replay button once a run has a result.
    static var replayRunAgain: LocalizedStringResource {
      LocalizedStringResource("lab.replayRunAgain", defaultValue: "Run Again", bundle: L10n.bundle)
    }
    /// Between the two version chips.
    static var replayVersus: LocalizedStringResource {
      LocalizedStringResource("lab.replayVersus", defaultValue: "vs", bundle: L10n.bundle)
    }
    /// Replay choice: the one day to replay (the day chip's menu).
    static var replayDay: LocalizedStringResource {
      LocalizedStringResource("lab.replayDay", defaultValue: "Day", bundle: L10n.bundle)
    }
    /// Replay on one day while the fetched data holds no day to pick: why there is no day chip.
    static var replayNoDays: LocalizedStringResource {
      LocalizedStringResource("lab.replayNoDays", defaultValue: "No fetched day to replay yet.", bundle: L10n.bundle)
    }
    /// Card: one symbol's decision, check by check.
    static var explain: LocalizedStringResource {
      LocalizedStringResource("lab.explain", defaultValue: "Why did the bot decide that?", bundle: L10n.bundle)
    }
    /// Placeholder of the symbol field.
    static var explainPrompt: LocalizedStringResource {
      LocalizedStringResource("lab.explainPrompt", defaultValue: "Symbol", bundle: L10n.bundle)
    }
    /// Label of the symbol field.
    static var explainSymbol: LocalizedStringResource {
      LocalizedStringResource("lab.explainSymbol", defaultValue: "Symbol to explain", bundle: L10n.bundle)
    }
    /// Button: read the decisions on the symbol.
    static var explainRun: LocalizedStringResource {
      LocalizedStringResource("lab.explainRun", defaultValue: "Explain", bundle: L10n.bundle)
    }
    /// Footer link of Explain a symbol when its card shows only some of the decision's checks.
    static var explainShowAll: LocalizedStringResource {
      LocalizedStringResource("lab.explainShowAll", defaultValue: "All checks", bundle: L10n.bundle)
    }
    /// The Explain button while the decisions are read (its spinner beside it).
    static var explainReading: LocalizedStringResource {
      LocalizedStringResource("lab.explainReading", defaultValue: "Reading decisions", bundle: L10n.bundle)
    }
    /// No decision recorded for the symbol.
    static var explainNone: LocalizedStringResource {
      LocalizedStringResource("lab.explainNone",
        defaultValue: "No decision on this symbol on the shown day.",
        bundle: L10n.bundle)
    }
    /// Before a symbol is typed.
    static var explainHint: LocalizedStringResource {
      LocalizedStringResource("lab.explainHint",
        defaultValue: "Type a symbol to see why the strategy decided what it did.",
        bundle: L10n.bundle)
    }
    /// Decision line without a cause.
    static func explainHead(_ head: String) -> LocalizedStringResource {
      LocalizedStringResource("lab.explainHead", defaultValue: "\(head)", bundle: L10n.bundle)
    }
    /// Explain card: the platform admission.
    static var admission: LocalizedStringResource {
      LocalizedStringResource("lab.admission", defaultValue: "Admission", bundle: L10n.bundle)
    }
    /// Admission: the entry was taken.
    static var admissionTaken: LocalizedStringResource {
      LocalizedStringResource("lab.admissionTaken", defaultValue: "taken", bundle: L10n.bundle)
    }
    /// Admission: the platform refused the entry.
    static var admissionRefused: LocalizedStringResource {
      LocalizedStringResource("lab.admissionRefused", defaultValue: "refused", bundle: L10n.bundle)
    }
    /// Admission: the entry was never put to the checks.
    static var admissionNotEvaluated: LocalizedStringResource {
      LocalizedStringResource("lab.admissionNotEvaluated", defaultValue: "not evaluated", bundle: L10n.bundle)
    }
    /// Admission: the decision was not an entry.
    static var admissionNotReached: LocalizedStringResource {
      LocalizedStringResource("lab.admissionNotReached", defaultValue: "not reached", bundle: L10n.bundle)
    }
    /// Card: the version that trades and its day.
    static var active: LocalizedStringResource {
      LocalizedStringResource("lab.active", defaultValue: "Which version trades", bundle: L10n.bundle)
    }
    /// Under the active version's day result: the day, then its closed trades, won and lost.
    static func daySummary(_ day: String, _ closed: Int, _ won: Int, _ lost: Int) -> LocalizedStringResource {
      LocalizedStringResource("lab.daySummary", defaultValue: "\(day) · \(closed) closed, \(won) won, \(lost) lost",
        bundle: L10n.bundle)
    }
    /// The active version's latest replay over the last sessions, before its net with the bot's limits.
    static func testedOn(_ sessions: Int) -> LocalizedStringResource {
      LocalizedStringResource("lab.testedOn", defaultValue: "Tested on the last \(sessions) sessions", bundle: L10n.bundle)
    }
    /// The versions card's "i": how versions swap.
    static var versionsAbout: LocalizedStringResource {
      LocalizedStringResource("lab.versionsAbout", defaultValue: "How versions swap", bundle: L10n.bundle)
    }
    /// The compare card's "i": how the comparison runs.
    static var compareAbout: LocalizedStringResource {
      LocalizedStringResource("lab.compareAbout", defaultValue: "How the comparison runs", bundle: L10n.bundle)
    }
    /// Footer link of the compare card: every figure of the run, with the difference.
    static var replayAllFigures: LocalizedStringResource {
      LocalizedStringResource("lab.replayAllFigures", defaultValue: "All figures", bundle: L10n.bundle)
    }
    /// The second version earned more over the last sessions, with how much.
    static func verdictMore(_ name: String, _ amount: String) -> LocalizedStringResource {
      LocalizedStringResource("lab.verdictMore", defaultValue: "\(name) earned \(amount) more · not proven yet",
        bundle: L10n.bundle)
    }
    /// The second version earned less over the last sessions, with how much.
    static func verdictLess(_ name: String, _ amount: String) -> LocalizedStringResource {
      LocalizedStringResource("lab.verdictLess", defaultValue: "\(name) earned \(amount) less", bundle: L10n.bundle)
    }
    /// Both versions earned the same over the last sessions.
    static var verdictSame: LocalizedStringResource {
      LocalizedStringResource("lab.verdictSame", defaultValue: "Both earned the same", bundle: L10n.bundle)
    }
    /// The refusals card's "i": what it counts.
    static var refusalsAbout: LocalizedStringResource {
      LocalizedStringResource("lab.refusalsAbout", defaultValue: "What this counts", bundle: L10n.bundle)
    }
    /// What the refusals card counts.
    static var refusalsInfo: LocalizedStringResource {
      LocalizedStringResource("lab.refusalsInfo",
        defaultValue: "Times the active version wanted to enter and the platform's limits said no.", bundle: L10n.bundle)
    }
    /// Under the decision: why it was decided.
    static func explainCause(_ cause: String) -> LocalizedStringResource {
      LocalizedStringResource("lab.explainCause", defaultValue: "Cause: \(cause)", bundle: L10n.bundle)
    }
    /// At the end of the explained decision: the version that decided.
    static func decidedBy(_ name: String) -> LocalizedStringResource {
      LocalizedStringResource("lab.decidedBy", defaultValue: "Decided by \(name)", bundle: L10n.bundle)
    }
  }
  enum MenuBar {
    static var demoTitle: LocalizedStringResource {
      LocalizedStringResource("menuBar.demoTitle", defaultValue: "Demo day: commands are not sent to the bot",
        bundle: L10n.bundle)
    }
    static var demoDetail: LocalizedStringResource {
      LocalizedStringResource("menuBar.demoDetail", defaultValue: "Turn it off in Settings › General before trading.",
        bundle: L10n.bundle)
    }
    /// Menu bar: the line under Pause entries, its only command.
    static var moreInApp: LocalizedStringResource {
      LocalizedStringResource("menuBar.moreInApp", defaultValue: "To close positions or stop the bot, open Tickr.",
        bundle: L10n.bundle)
    }
    /// Menu bar: label over today's result.
    static var dayResult: LocalizedStringResource {
      LocalizedStringResource("menuBar.dayResult", defaultValue: "Day result", bundle: L10n.bundle)
    }
    /// Today's closed trades with wins and losses.
    static func trades(_ closed: Int, _ wins: Int, _ losses: Int) -> LocalizedStringResource {
      LocalizedStringResource("menuBar.trades", defaultValue: "\(closed) closed · \(wins) won · \(losses) lost",
        bundle: L10n.bundle)
    }
    /// A position's size in shares.
    static func shares(_ quantity: String) -> LocalizedStringResource {
      LocalizedStringResource("menuBar.shares", defaultValue: "\(quantity) sh", bundle: L10n.bundle)
    }
    /// A position's entry price; the full words are the hint.
    static func entry(_ price: String) -> LocalizedStringResource {
      LocalizedStringResource("menuBar.entry", defaultValue: "Entry \(price)", bundle: L10n.bundle)
    }
    /// The room under the daily loss limit.
    static func room(_ room: String, _ limit: String) -> LocalizedStringResource {
      LocalizedStringResource("menuBar.room", defaultValue: "Loss room left \(room) of \(limit)", bundle: L10n.bundle)
    }
    /// A position's stop price; its words are the hint.
    static func stop(_ price: String) -> LocalizedStringResource {
      LocalizedStringResource("menuBar.stop", defaultValue: "Stop \(price)", bundle: L10n.bundle)
    }
    /// A position's last price.
    static func now(_ price: String) -> LocalizedStringResource {
      LocalizedStringResource("menuBar.now", defaultValue: "Now \(price)", bundle: L10n.bundle)
    }
    /// Under the panel's one command: where the others are.
    static var moreHint: LocalizedStringResource {
      LocalizedStringResource("menuBar.moreHint",
        defaultValue: "To close positions or stop the bot, open Tickr.",
        bundle: L10n.bundle)
    }
  }
  enum Screener {
    /// Pipeline reconcile stage: the broker and the bot's records disagree.
    static var mismatch: LocalizedStringResource {
      LocalizedStringResource("screener.mismatch", defaultValue: "Mismatch", bundle: L10n.bundle)
    }
    /// Flow read failed.
    static func unavailable(_ cause: String) -> LocalizedStringResource {
      LocalizedStringResource("screener.unavailable", defaultValue: "The bot's API did not return the flow: \(cause)",
        bundle: L10n.bundle)
    }
  }
  enum Watching {
    /// Card title: symbols the strategy is closest to entering.
    static var title: LocalizedStringResource {
      LocalizedStringResource("watching.title", defaultValue: "Watching Closely", bundle: L10n.bundle)
    }
    /// The card's footer link (`CardFooterLink`): opens every row the bot sent; the count stands beside it.
    static var showAll: LocalizedStringResource {
      LocalizedStringResource("watching.showAll", defaultValue: "Show all", bundle: L10n.bundle)
    }
    /// Caption beside "Show all": the card shows the closest `shown` of `total` watched symbols.
    static func closestOf(_ shown: Int, _ total: Int) -> LocalizedStringResource {
      LocalizedStringResource("watching.closestOf", defaultValue: "closest \(shown) of \(total)", bundle: L10n.bundle)
    }
    /// VoiceOver name of the full list.
    static var panelLabel: LocalizedStringResource {
      LocalizedStringResource("watching.panelLabel", defaultValue: "Watching closely, all symbols", bundle: L10n.bundle)
    }
    /// The full list's caption: how many symbols it holds.
    static func symbols(_ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("watching.symbols", defaultValue: "\(count) symbols", bundle: L10n.bundle)
    }
    /// The full list's caption on the live day: rows follow the bot's decisions.
    static var live: LocalizedStringResource {
      LocalizedStringResource("watching.live", defaultValue: "live", bundle: L10n.bundle)
    }
    /// VoiceOver name of the sort switch.
    static var sortLabel: LocalizedStringResource {
      LocalizedStringResource("watching.sortLabel", defaultValue: "Sort", bundle: L10n.bundle)
    }
    /// Sort segment: closest to entering first.
    static var sortClosest: LocalizedStringResource {
      LocalizedStringResource("watching.sortClosest", defaultValue: "Closest", bundle: L10n.bundle)
    }
    /// Sort segment: by symbol, A to Z.
    static var sortSymbol: LocalizedStringResource {
      LocalizedStringResource("watching.sortSymbol", defaultValue: "Symbol", bundle: L10n.bundle)
    }
    /// Sort segment: oldest quote first.
    static var sortQuoteAge: LocalizedStringResource {
      LocalizedStringResource("watching.sortQuoteAge", defaultValue: "Quote age", bundle: L10n.bundle)
    }
    /// Sort segment: latest decision first.
    static var sortLatest: LocalizedStringResource {
      LocalizedStringResource("watching.sortLatest", defaultValue: "Latest", bundle: L10n.bundle)
    }
    /// VoiceOver name of the full list's close button.
    static var close: LocalizedStringResource {
      LocalizedStringResource("watching.close", defaultValue: "Close", bundle: L10n.bundle)
    }
    /// Tooltip of the full list's close button.
    static var closeHelp: LocalizedStringResource {
      LocalizedStringResource("watching.closeHelp", defaultValue: "Close (Esc)", bundle: L10n.bundle)
    }
    /// Button under a list's first rows (a stage's details): shows the rows beyond them.
    static func more(_ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("watching.more", defaultValue: "\(count) more", bundle: L10n.bundle)
    }
    /// Watching card is empty.
    static var none: LocalizedStringResource {
      LocalizedStringResource("watching.none",
        defaultValue: "Nothing armed right now. A symbol shows here while the strategy waits for its setup.",
        bundle: L10n.bundle)
    }
    /// Watching read failed.
    static func unavailable(_ cause: String) -> LocalizedStringResource {
      LocalizedStringResource("watching.unavailable", defaultValue: "The bot's API did not return the watched symbols: \(cause)",
        bundle: L10n.bundle)
    }
    /// Bar and VoiceOver name: how close the deciding check is to passing.
    static var closeness: LocalizedStringResource {
      LocalizedStringResource("watching.closeness", defaultValue: "Closeness to entry", bundle: L10n.bundle)
    }
    /// The card's caption: what each row shows besides the symbol.
    static var columns: LocalizedStringResource {
      LocalizedStringResource("watching.columns", defaultValue: "decisive check · quote age", bundle: L10n.bundle)
    }
    /// Tooltip of a row's quote age.
    static func quoteAgeHelp(_ time: String) -> LocalizedStringResource {
      LocalizedStringResource("watching.quoteAgeHelp", defaultValue: "Age of the quote when the strategy decided at \(time) ET",
        bundle: L10n.bundle)
    }
    /// When the strategy decided, for a row without a quote age.
    static func decidedAt(_ time: String) -> LocalizedStringResource {
      LocalizedStringResource("watching.decidedAt", defaultValue: "Decided at \(time) ET", bundle: L10n.bundle)
    }
  }
  enum EntrySent {
    /// Label: how the entry order of a position or trade was sent.
    static var title: LocalizedStringResource {
      LocalizedStringResource("entrySent.title", defaultValue: "Entry sent", bundle: L10n.bundle)
    }
    /// Safety row: every entry today was sent exactly once (one send per decision).
    static var safetyRow: LocalizedStringResource {
      LocalizedStringResource("entrySent.safetyRow", defaultValue: "Entries sent once", bundle: L10n.bundle)
    }
    /// The entry was sent exactly once.
    static var once: LocalizedStringResource {
      LocalizedStringResource("entrySent.once", defaultValue: "Once", bundle: L10n.bundle)
    }
    /// Alarm: the entry was sent other than once.
    static func times(_ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("entrySent.times", defaultValue: "\(count) sends", bundle: L10n.bundle)
    }
    /// The bot has no send record for the entry.
    static var notRecorded: LocalizedStringResource {
      LocalizedStringResource("entrySent.notRecorded", defaultValue: "Not recorded", bundle: L10n.bundle)
    }
    /// Sends and the send's latest state.
    static func withOutcome(_ sent: String, _ outcome: String) -> LocalizedStringResource {
      LocalizedStringResource("entrySent.withOutcome", defaultValue: "\(sent) · \(outcome)", bundle: L10n.bundle)
    }
    /// Safety row value: every entry today was sent once.
    static func allOnce(_ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("entrySent.allOnce", defaultValue: "All \(count) once", bundle: L10n.bundle)
    }
    /// Safety row alarm: an entry sent other than once.
    static func breach(_ symbol: String, _ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("entrySent.breach", defaultValue: "\(symbol): sent \(count) times", bundle: L10n.bundle)
    }
    /// Safety row: entries without a send record.
    static func unrecorded(_ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("entrySent.unrecorded", defaultValue: "Not recorded: \(count)", bundle: L10n.bundle)
    }
    /// Safety row: entries sent once whose outcome the broker has not confirmed yet.
    static func awaiting(_ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("entrySent.awaiting", defaultValue: "\(count) awaiting the broker", bundle: L10n.bundle)
    }
    /// Send outcome: recorded, not sent yet.
    static var intent: LocalizedStringResource {
      LocalizedStringResource("entrySent.intent", defaultValue: "not sent yet", bundle: L10n.bundle)
    }
    /// Send outcome: sent, no broker answer.
    static var attempted: LocalizedStringResource {
      LocalizedStringResource("entrySent.attempted", defaultValue: "no answer", bundle: L10n.bundle)
    }
    /// Send outcome: the broker acknowledged the order.
    static var acknowledged: LocalizedStringResource {
      LocalizedStringResource("entrySent.acknowledged", defaultValue: "acknowledged", bundle: L10n.bundle)
    }
    /// Send outcome: the broker refused the order.
    static var refused: LocalizedStringResource {
      LocalizedStringResource("entrySent.refused", defaultValue: "refused", bundle: L10n.bundle)
    }
    /// Send outcome: unknown; the broker is read, never resent.
    static var unknown: LocalizedStringResource {
      LocalizedStringResource("entrySent.unknown", defaultValue: "outcome unknown", bundle: L10n.bundle)
    }
    /// Send outcome: no send was recorded.
    static var absent: LocalizedStringResource {
      LocalizedStringResource("entrySent.absent", defaultValue: "no send", bundle: L10n.bundle)
    }
  }
  enum Symbols {
    /// Screen title: every symbol of the day by the stage it got to.
    static var title: LocalizedStringResource {
      LocalizedStringResource("symbols.title", defaultValue: "Symbols", bundle: L10n.bundle)
    }
    /// Back capsule: returns to the Overview.
    static var back: LocalizedStringResource {
      LocalizedStringResource("symbols.back", defaultValue: "Overview", bundle: L10n.bundle)
    }
    /// Under the title: day, end of the latest discovery pass, the tab's one-line caption.
    static func context(_ day: String, _ time: String, _ caption: String) -> LocalizedStringResource {
      LocalizedStringResource("symbols.context", defaultValue: "\(day) · \(time) ET · \(caption)", bundle: L10n.bundle)
    }
    /// A failed read of the symbols or movers; argument: the error.
    static func unavailable(_ error: String) -> LocalizedStringResource {
      LocalizedStringResource("symbols.unavailable", defaultValue: "Unavailable: \(error)", bundle: L10n.bundle)
    }
    /// Search field: filters the rows by symbol.
    static var search: LocalizedStringResource {
      LocalizedStringResource("symbols.search", defaultValue: "Search symbol", bundle: L10n.bundle)
    }
    /// Accessibility: the row of stage tabs.
    static var stages: LocalizedStringResource {
      LocalizedStringResource("symbols.stages", defaultValue: "Stages", bundle: L10n.bundle)
    }
    /// Accessibility: the All / Passed / Dropped here control.
    static var show: LocalizedStringResource {
      LocalizedStringResource("symbols.show", defaultValue: "Show", bundle: L10n.bundle)
    }
    /// Accessibility: the list of symbols.
    static var listLabel: LocalizedStringResource {
      LocalizedStringResource("symbols.listLabel", defaultValue: "Symbol list", bundle: L10n.bundle)
    }
    /// Accessibility: the selected symbol's path.
    static var detailLabel: LocalizedStringResource {
      LocalizedStringResource("symbols.detailLabel", defaultValue: "Symbol detail", bundle: L10n.bundle)
    }
    /// Under the list: every row is shown, never capped.
    static func showingAll(_ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("symbols.showingAll", defaultValue: "Showing all \(count)", bundle: L10n.bundle)
    }
    /// Footer of the Fast movers tab: the flagged symbols, and the open positions and waiting
    /// symbols pinned above them that no fast-mover rule flagged.
    static func showingMovers(_ flagged: Int, _ pinned: Int) -> LocalizedStringResource {
      // swiftlint:disable:next line_length
      LocalizedStringResource("symbols.showingMovers", defaultValue: "Showing all \(flagged) fast movers, plus \(pinned) open or waiting on top", bundle: L10n.bundle)
    }
    /// The search left no row.
    static func noMatch(_ query: String) -> LocalizedStringResource {
      LocalizedStringResource("symbols.noMatch", defaultValue: "No symbol matches “\(query)” here.", bundle: L10n.bundle)
    }
    /// A stage tab with no rows.
    static var noneHere: LocalizedStringResource {
      LocalizedStringResource("symbols.noneHere", defaultValue: "No symbol got to this stage.", bundle: L10n.bundle)
    }
    /// The fast movers tab with no rows.
    static var noMovers: LocalizedStringResource {
      LocalizedStringResource("symbols.noMovers", defaultValue: "No fast movers yet.", bundle: L10n.bundle)
    }
    /// Detail link: the Chart on this symbol.
    static var openChart: LocalizedStringResource {
      LocalizedStringResource("symbols.openChart", defaultValue: "Open chart", bundle: L10n.bundle)
    }
    /// Detail link: the Trades & days screen.
    static var tradesAndDays: LocalizedStringResource {
      LocalizedStringResource("symbols.tradesAndDays", defaultValue: "Trades & days", bundle: L10n.bundle)
    }
    /// Detail with no symbol selected.
    static var selectHint: LocalizedStringResource {
      LocalizedStringResource("symbols.selectHint", defaultValue: "Select a symbol to see its steps today.", bundle: L10n.bundle)
    }
  }
  enum FastMovers {
    /// Card title: symbols with a sudden jump against the bars before.
    static var title: LocalizedStringResource {
      LocalizedStringResource("fastMovers.title", defaultValue: "Fast Movers", bundle: L10n.bundle)
    }
    /// Link under the rows: opens the Symbols screen on its Fast movers tab.
    static var showAll: LocalizedStringResource {
      LocalizedStringResource("fastMovers.showAll", defaultValue: "Show all", bundle: L10n.bundle)
    }
    /// The card with no fast mover.
    static var none: LocalizedStringResource {
      LocalizedStringResource("fastMovers.none", defaultValue: "No fast movers yet today.", bundle: L10n.bundle)
    }
    /// A failed read of GET /movers; argument: the error.
    static func unavailable(_ error: String) -> LocalizedStringResource {
      LocalizedStringResource("fastMovers.unavailable", defaultValue: "Fast movers unavailable: \(error)", bundle: L10n.bundle)
    }
  }
  // END Screens

  /// A read of one card's data that failed while the link to the bot is up (its cause is behind
  /// Details).
  enum ReadFailed {
    static var settings: LocalizedStringResource {
      LocalizedStringResource("readFailed.settings", defaultValue: "Couldn't read the bot's settings",
        bundle: L10n.bundle)
    }
    static var replay: LocalizedStringResource {
      LocalizedStringResource("readFailed.replay", defaultValue: "Couldn't read the replay", bundle: L10n.bundle)
    }
    static var explain: LocalizedStringResource {
      LocalizedStringResource("readFailed.explain", defaultValue: "Couldn't read the explanation", bundle: L10n.bundle)
    }
    static var config: LocalizedStringResource {
      LocalizedStringResource("readFailed.config", defaultValue: "Couldn't read the configuration file",
        bundle: L10n.bundle)
    }
    static var jobs: LocalizedStringResource {
      LocalizedStringResource("readFailed.jobs", defaultValue: "Couldn't read the jobs", bundle: L10n.bundle)
    }
    static var history: LocalizedStringResource {
      LocalizedStringResource("readFailed.history", defaultValue: "Couldn't read the recorded days", bundle: L10n.bundle)
    }
  }
}
