import Foundation

/// Every text of the macOS app that a person reads, in English, with its Russian translation in
/// Localizable.xcstrings beside this file (docs/design-system.md, rule 2). Views pass these to
/// `Text` and the components, or read them with `String(localized:)`. Generated keys are
/// `<namespace>.<name>`.
enum L10n {
  /// Where the String Catalog is: the package's resource bundle in a `swift build`, the app
  /// bundle in the Xcode build.
  static var bundle: LocalizedStringResource.BundleDescription {
    #if SWIFT_PACKAGE
    return .atURL(Bundle.module.bundleURL)
    #else
    return .main
    #endif
  }

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
    static var today: LocalizedStringResource {
      LocalizedStringResource("common.today", defaultValue: "Today", bundle: L10n.bundle)
    }
    static func todayDay(_ day: String) -> LocalizedStringResource {
      LocalizedStringResource("common.todayDay", defaultValue: "Today · \(day)", bundle: L10n.bundle)
    }
    static func recordedDay(_ day: String) -> LocalizedStringResource {
      LocalizedStringResource("common.recordedDay", defaultValue: "Recorded day · \(day)", bundle: L10n.bundle)
    }
    static func strategyVersion(_ name: String, _ version: String) -> LocalizedStringResource {
      LocalizedStringResource("common.strategyVersion", defaultValue: "\(name) v\(version)", bundle: L10n.bundle)
    }
    static var operatorTitle: LocalizedStringResource {
      LocalizedStringResource("common.operatorTitle", defaultValue: "Operator", bundle: L10n.bundle)
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
    static func secondsAgo(_ seconds: Int) -> LocalizedStringResource {
      LocalizedStringResource("format.secondsAgo", defaultValue: "\(seconds) s ago", bundle: L10n.bundle)
    }
    static func minutesAgo(_ minutes: Int) -> LocalizedStringResource {
      LocalizedStringResource("format.minutesAgo", defaultValue: "\(minutes) min ago", bundle: L10n.bundle)
    }
    static func seconds(_ value: String) -> LocalizedStringResource {
      LocalizedStringResource("format.seconds", defaultValue: "\(value) s", bundle: L10n.bundle)
    }
    static func usd(_ amount: String) -> LocalizedStringResource {
      LocalizedStringResource("format.usd", defaultValue: "\(amount) USD", bundle: L10n.bundle)
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
    static var needsAPI: LocalizedStringResource {
      LocalizedStringResource("planned.needsAPI", defaultValue: "NEEDS API", bundle: L10n.bundle)
    }
    static var backlogHelp: LocalizedStringResource {
      LocalizedStringResource("planned.backlogHelp",
        defaultValue: "Planned, not built yet (docs/backlog.md).",
        bundle: L10n.bundle)
    }
    static var needsAPIHelp: LocalizedStringResource {
      LocalizedStringResource("planned.needsAPIHelp",
        defaultValue: "Needs a new local-API read or command.",
        bundle: L10n.bundle)
    }
  }

  enum Bot {
    static var pauseEntries: LocalizedStringResource {
      LocalizedStringResource("bot.pauseEntries", defaultValue: "Pause Entries", bundle: L10n.bundle)
    }
    static var resumeEntries: LocalizedStringResource {
      LocalizedStringResource("bot.resumeEntries", defaultValue: "Resume Entries", bundle: L10n.bundle)
    }
    static var cancelOrders: LocalizedStringResource {
      LocalizedStringResource("bot.cancelOrders", defaultValue: "Cancel Orders", bundle: L10n.bundle)
    }
    static func flatten(_ symbol: String) -> LocalizedStringResource {
      LocalizedStringResource("bot.flatten", defaultValue: "Flatten \(symbol)", bundle: L10n.bundle)
    }
    static var flattenAll: LocalizedStringResource {
      LocalizedStringResource("bot.flattenAll", defaultValue: "Flatten All", bundle: L10n.bundle)
    }
    static var stopBot: LocalizedStringResource {
      LocalizedStringResource("bot.stopBot", defaultValue: "Stop Bot", bundle: L10n.bundle)
    }
    static var pauseQuestion: LocalizedStringResource {
      LocalizedStringResource("bot.pauseQuestion", defaultValue: "Pause new entries?", bundle: L10n.bundle)
    }
    static var resumeQuestion: LocalizedStringResource {
      LocalizedStringResource("bot.resumeQuestion", defaultValue: "Resume new entries?", bundle: L10n.bundle)
    }
    static var cancelQuestion: LocalizedStringResource {
      LocalizedStringResource("bot.cancelQuestion",
        defaultValue: "Cancel the bot's working entry orders?",
        bundle: L10n.bundle)
    }
    static func flattenQuestion(_ symbol: String) -> LocalizedStringResource {
      LocalizedStringResource("bot.flattenQuestion", defaultValue: "Flatten \(symbol)?", bundle: L10n.bundle)
    }
    static var flattenAllQuestion: LocalizedStringResource {
      LocalizedStringResource("bot.flattenAllQuestion", defaultValue: "Flatten all positions?", bundle: L10n.bundle)
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
    static var cancelExplanation: LocalizedStringResource {
      LocalizedStringResource("bot.cancelExplanation",
        defaultValue: "Cancels the bot's own working entry orders. Protective stops are never cancelled.",
        bundle: L10n.bundle)
    }
    static var flattenExplanation: LocalizedStringResource {
      LocalizedStringResource("bot.flattenExplanation",
        defaultValue: "The bot cancels the stop, reads the held quantity again and sells it through the normal exit.",
        bundle: L10n.bundle)
    }
    static var flattenAllExplanation: LocalizedStringResource {
      LocalizedStringResource("bot.flattenAllExplanation",
        defaultValue: "Every own position closes through the normal exit. Positions the bot did not open are not touched.",
        bundle: L10n.bundle)
    }
    static var stopExplanation: LocalizedStringResource {
      LocalizedStringResource("bot.stopExplanation",
        defaultValue: "The bot stops and stays stopped until you run aperture clear-stop on this Mac; the app cannot start it again. Working entry orders are cancelled. Open positions stay open under their broker stop, a DAY order: nothing closes them at the session's end. Flatten first to be flat.",
        bundle: L10n.bundle)
    }
    static var emergency: LocalizedStringResource {
      LocalizedStringResource("bot.emergency", defaultValue: "Emergency Stop", bundle: L10n.bundle)
    }
    static var emergencyQuestion: LocalizedStringResource {
      LocalizedStringResource("bot.emergencyQuestion", defaultValue: "Run the emergency stop?", bundle: L10n.bundle)
    }
    static var emergencyExplanation: LocalizedStringResource {
      LocalizedStringResource("bot.emergencyExplanation",
        defaultValue: "Three steps in order: pause new entries, cancel the bot's working entry orders, flatten every own position. Each broker stop stays until its closing sale is sent. The bot keeps running.",
        bundle: L10n.bundle)
    }
    static var stoppedTitle: LocalizedStringResource {
      LocalizedStringResource("bot.stoppedTitle", defaultValue: "Bot Stopped with Open Positions", bundle: L10n.bundle)
    }
    static func stoppedOpen(_ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("bot.stoppedOpen",
        defaultValue: "Open positions: \(count). Each stays under its broker stop, a DAY order: nothing closes it at the session's end. Flatten from Webull, or run aperture clear-stop on this Mac and start the bot to trade again.",
        bundle: L10n.bundle)
    }
    static var silentTitle: LocalizedStringResource {
      LocalizedStringResource("bot.silentTitle", defaultValue: "Bot Not Responding with Open Positions", bundle: L10n.bundle)
    }
    static func silentOpen(_ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("bot.silentOpen",
        defaultValue: "Open positions: \(count). The bot's status is stale: it may have stopped. Each position stays under its broker stop, a DAY order: nothing closes it at the session's end. Check the bot on this Mac or flatten from Webull.",
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
      LocalizedStringResource("section.lab", defaultValue: "Strategy lab", bundle: L10n.bundle)
    }
  }

  enum Root {
    static func run(_ id: String) -> LocalizedStringResource {
      LocalizedStringResource("root.run", defaultValue: "run \(id)", bundle: L10n.bundle)
    }
    static var apiUnreachable: LocalizedStringResource {
      LocalizedStringResource("root.apiUnreachable", defaultValue: "API unreachable", bundle: L10n.bundle)
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
  }

  enum Toolbar {
    /// The window subtitle's count of open positions.
    static func positions(_ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("toolbar.positions", defaultValue: "positions: \(count)", bundle: L10n.bundle)
    }
    /// The bot's address and the age of its status ("127.0.0.1 · 3 s ago").
    static func connection(_ host: String, _ age: String) -> LocalizedStringResource {
      LocalizedStringResource("toolbar.connection", defaultValue: "\(host) · \(age)", bundle: L10n.bundle)
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
    static func dayRow(_ day: String, _ result: String, _ trades: Int) -> LocalizedStringResource {
      LocalizedStringResource("toolbar.dayRow",
        defaultValue: "\(day)   \(result)   \(trades) trades",
        bundle: L10n.bundle)
    }
    static var pickDayHelp: LocalizedStringResource {
      LocalizedStringResource("toolbar.pickDayHelp", defaultValue: "Pick a recorded trading day", bundle: L10n.bundle)
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
    static var resultLater: LocalizedStringResource {
      LocalizedStringResource("toast.resultLater",
        defaultValue: "The result appears here when the bot has handled it.",
        bundle: L10n.bundle)
    }
  }

  enum Overview {
    static var fixtures: LocalizedStringResource {
      LocalizedStringResource("overview.fixtures", defaultValue: "Fixtures", bundle: L10n.bundle)
    }
    static var fixturesHelp: LocalizedStringResource {
      LocalizedStringResource("overview.fixturesHelp",
        defaultValue: "Debug build reading the recorded contract fixtures, not a running bot.",
        bundle: L10n.bundle)
    }
    static var gateOpen: LocalizedStringResource {
      LocalizedStringResource("overview.gateOpen", defaultValue: "Gate open", bundle: L10n.bundle)
    }
    static var gateClosed: LocalizedStringResource {
      LocalizedStringResource("overview.gateClosed", defaultValue: "Gate closed", bundle: L10n.bundle)
    }
    static var recordedDetail: LocalizedStringResource {
      LocalizedStringResource("overview.recordedDetail",
        defaultValue: "Read-only view from the bot's records. Commands are off.",
        bundle: L10n.bundle)
    }
    static var noOpenPosition: LocalizedStringResource {
      LocalizedStringResource("overview.noOpenPosition", defaultValue: "No open position.", bundle: L10n.bundle)
    }
    static func protectedPositions(_ count: Int, _ protected: Int) -> LocalizedStringResource {
      LocalizedStringResource("overview.protectedPositions",
        defaultValue: "\(count) positions · \(protected) protected by a verified broker stop",
        bundle: L10n.bundle)
    }
    static var dayResult: LocalizedStringResource {
      LocalizedStringResource("overview.dayResult", defaultValue: "Day result · gross", bundle: L10n.bundle)
    }
    static func dayCounts(_ closed: Int, _ wins: Int, _ losses: Int) -> LocalizedStringResource {
      LocalizedStringResource("overview.dayCounts",
        defaultValue: "\(closed) closed · \(wins) W · \(losses) L",
        bundle: L10n.bundle)
    }
    static func openResult(_ result: String) -> LocalizedStringResource {
      LocalizedStringResource("overview.openResult", defaultValue: " · open \(result)", bundle: L10n.bundle)
    }
  }

  enum Flow {
    static var title: LocalizedStringResource {
      LocalizedStringResource("flow.title",
        defaultValue: "Live flow · screeners → strategy → risk → order → broker stop",
        bundle: L10n.bundle)
    }
    static var live: LocalizedStringResource {
      LocalizedStringResource("flow.live", defaultValue: "live", bundle: L10n.bundle)
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
    static func closedCount(_ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("flow.closedCount", defaultValue: "\(count) closed", bundle: L10n.bundle)
    }
    static var match: LocalizedStringResource {
      LocalizedStringResource("flow.match", defaultValue: "match", bundle: L10n.bundle)
    }
    static var notReported: LocalizedStringResource {
      LocalizedStringResource("flow.notReported",
        defaultValue: "Not reported by the local API yet.",
        bundle: L10n.bundle)
    }
  }

  enum Position {
    static var openChart: LocalizedStringResource {
      LocalizedStringResource("position.openChart", defaultValue: "Open chart →", bundle: L10n.bundle)
    }
    static var picker: LocalizedStringResource {
      LocalizedStringResource("position.picker", defaultValue: "Position", bundle: L10n.bundle)
    }
    static func titleOfLimit(_ count: Int, _ limit: Int) -> LocalizedStringResource {
      LocalizedStringResource("position.titleOfLimit",
        defaultValue: "Positions \(count) of \(limit)",
        bundle: L10n.bundle)
    }
    static func title(_ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("position.title", defaultValue: "Positions \(count)", bundle: L10n.bundle)
    }
    static var unrealized: LocalizedStringResource {
      LocalizedStringResource("position.unrealized", defaultValue: "unrealized", bundle: L10n.bundle)
    }
    static var quantity: LocalizedStringResource {
      LocalizedStringResource("position.quantity", defaultValue: "quantity", bundle: L10n.bundle)
    }
    static var entry: LocalizedStringResource {
      LocalizedStringResource("position.entry", defaultValue: "entry", bundle: L10n.bundle)
    }
    static var stop: LocalizedStringResource {
      LocalizedStringResource("position.stop", defaultValue: "stop", bundle: L10n.bundle)
    }
    static var maxLoss: LocalizedStringResource {
      LocalizedStringResource("position.maxLoss", defaultValue: "max loss", bundle: L10n.bundle)
    }
    static var rNow: LocalizedStringResource {
      LocalizedStringResource("position.rNow", defaultValue: "R now", bundle: L10n.bundle)
    }
    static var opened: LocalizedStringResource {
      LocalizedStringResource("position.opened", defaultValue: "opened", bundle: L10n.bundle)
    }
    static func lastBarCloseAt(_ time: String) -> LocalizedStringResource {
      LocalizedStringResource("position.lastBarCloseAt", defaultValue: "last bar close · \(time)", bundle: L10n.bundle)
    }
    static var lastBarClose: LocalizedStringResource {
      LocalizedStringResource("position.lastBarClose", defaultValue: "last bar close", bundle: L10n.bundle)
    }
    static var old: LocalizedStringResource {
      LocalizedStringResource("position.old", defaultValue: "old", bundle: L10n.bundle)
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
    static var title: LocalizedStringResource {
      LocalizedStringResource("safety.title", defaultValue: "Safety", bundle: L10n.bundle)
    }
    static var recordedDay: LocalizedStringResource {
      LocalizedStringResource("safety.recordedDay", defaultValue: "recorded day", bundle: L10n.bundle)
    }
    static var status: LocalizedStringResource {
      LocalizedStringResource("safety.status", defaultValue: "Status", bundle: L10n.bundle)
    }
    static var brokerStops: LocalizedStringResource {
      LocalizedStringResource("safety.brokerStops", defaultValue: "Broker stops", bundle: L10n.bundle)
    }
    static func verified(_ verified: Int, _ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("safety.verified", defaultValue: "\(verified) of \(count) verified", bundle: L10n.bundle)
    }
    static var reconciliation: LocalizedStringResource {
      LocalizedStringResource("safety.reconciliation", defaultValue: "Reconciliation", bundle: L10n.bundle)
    }
    static var noFences: LocalizedStringResource {
      LocalizedStringResource("safety.noFences", defaultValue: "no fences", bundle: L10n.bundle)
    }
    static var quoteStream: LocalizedStringResource {
      LocalizedStringResource("safety.quoteStream", defaultValue: "Quote stream", bundle: L10n.bundle)
    }
    static var lastBrokerRead: LocalizedStringResource {
      LocalizedStringResource("safety.lastBrokerRead", defaultValue: "Last broker read", bundle: L10n.bundle)
    }
    static var foreignPositions: LocalizedStringResource {
      LocalizedStringResource("safety.foreignPositions", defaultValue: "Foreign positions", bundle: L10n.bundle)
    }
    static var present: LocalizedStringResource {
      LocalizedStringResource("safety.present", defaultValue: "present", bundle: L10n.bundle)
    }
    static var entryPause: LocalizedStringResource {
      LocalizedStringResource("safety.entryPause", defaultValue: "Entry pause", bundle: L10n.bundle)
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
    static var details: LocalizedStringResource {
      LocalizedStringResource("riskRoom.details", defaultValue: "Details →", bundle: L10n.bundle)
    }
    static func left(_ limit: String) -> LocalizedStringResource {
      LocalizedStringResource("riskRoom.left", defaultValue: "of \(limit) USD left", bundle: L10n.bundle)
    }
    static var netResult: LocalizedStringResource {
      LocalizedStringResource("riskRoom.netResult", defaultValue: "net day result", bundle: L10n.bundle)
    }
    static var positions: LocalizedStringResource {
      LocalizedStringResource("riskRoom.positions", defaultValue: "positions", bundle: L10n.bundle)
    }
    static var plannedLoss: LocalizedStringResource {
      LocalizedStringResource("riskRoom.plannedLoss", defaultValue: "planned loss / trade", bundle: L10n.bundle)
    }
    static var notionalCap: LocalizedStringResource {
      LocalizedStringResource("riskRoom.notionalCap", defaultValue: "notional cap", bundle: L10n.bundle)
    }
    static var reservations: LocalizedStringResource {
      LocalizedStringResource("riskRoom.reservations", defaultValue: "open reservations", bundle: L10n.bundle)
    }
    static var reading: LocalizedStringResource {
      LocalizedStringResource("riskRoom.reading", defaultValue: "Reading limits…", bundle: L10n.bundle)
    }
  }

  enum Observers {
    static var title: LocalizedStringResource {
      LocalizedStringResource("observers.title", defaultValue: "Observers · shadow", bundle: L10n.bundle)
    }
    static var none: LocalizedStringResource {
      LocalizedStringResource("observers.none", defaultValue: "No observer strategies configured.", bundle: L10n.bundle)
    }
    static var advisor: LocalizedStringResource {
      LocalizedStringResource("observers.advisor", defaultValue: "AI advisor proposals", bundle: L10n.bundle)
    }
  }

  enum Journal {
    static var title: LocalizedStringResource {
      LocalizedStringResource("journal.title", defaultValue: "Journal", bundle: L10n.bundle)
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
        defaultValue: "Read from the bot's local API. Change it in config/bot.toml and restart the bot.",
        bundle: L10n.bundle)
    }
    static var apiAddress: LocalizedStringResource {
      LocalizedStringResource("settings.apiAddress", defaultValue: "Local API address", bundle: L10n.bundle)
    }
    static var useDefault: LocalizedStringResource {
      LocalizedStringResource("settings.useDefault", defaultValue: "Use Default", bundle: L10n.bundle)
    }
    static var connect: LocalizedStringResource {
      LocalizedStringResource("settings.connect", defaultValue: "Connect", bundle: L10n.bundle)
    }
    static var botConnection: LocalizedStringResource {
      LocalizedStringResource("settings.botConnection", defaultValue: "Bot connection", bundle: L10n.bundle)
    }
    static func notReachable(_ error: String) -> LocalizedStringResource {
      LocalizedStringResource("settings.notReachable", defaultValue: "Not reachable: \(error)", bundle: L10n.bundle)
    }
    static func connectedTo(_ address: String) -> LocalizedStringResource {
      LocalizedStringResource("settings.connectedTo", defaultValue: "Connected to \(address).", bundle: L10n.bundle)
    }
    static var menuBar: LocalizedStringResource {
      LocalizedStringResource("settings.menuBar", defaultValue: "Menu bar", bundle: L10n.bundle)
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
    static var followsSystem: LocalizedStringResource {
      LocalizedStringResource("settings.followsSystem",
        defaultValue: "Follows the system appearance",
        bundle: L10n.bundle)
    }
    static var invalidAddress: LocalizedStringResource {
      LocalizedStringResource("settings.invalidAddress", defaultValue: "Invalid address", bundle: L10n.bundle)
    }
    static var ok: LocalizedStringResource {
      LocalizedStringResource("settings.ok", defaultValue: "OK", bundle: L10n.bundle)
    }
    static func enterAddress(_ example: String) -> LocalizedStringResource {
      LocalizedStringResource("settings.enterAddress",
        defaultValue: "Enter an http address of the bot's local API, such as \(example).",
        bundle: L10n.bundle)
    }
    static var activeStrategy: LocalizedStringResource {
      LocalizedStringResource("settings.activeStrategy", defaultValue: "Active strategy", bundle: L10n.bundle)
    }
    static var observers: LocalizedStringResource {
      LocalizedStringResource("settings.observers", defaultValue: "Observers", bundle: L10n.bundle)
    }
    static var plannedLoss: LocalizedStringResource {
      LocalizedStringResource("settings.plannedLoss", defaultValue: "Planned loss per trade", bundle: L10n.bundle)
    }
    static var notionalCap: LocalizedStringResource {
      LocalizedStringResource("settings.notionalCap", defaultValue: "Position notional cap", bundle: L10n.bundle)
    }
    static var dailyLossLimit: LocalizedStringResource {
      LocalizedStringResource("settings.dailyLossLimit", defaultValue: "Daily loss limit (net)", bundle: L10n.bundle)
    }
    static var maxOpenPositions: LocalizedStringResource {
      LocalizedStringResource("settings.maxOpenPositions", defaultValue: "Open positions at most", bundle: L10n.bundle)
    }
    static var maxQuoteAge: LocalizedStringResource {
      LocalizedStringResource("settings.maxQuoteAge", defaultValue: "Quote age at most", bundle: L10n.bundle)
    }
    static var marketTimezone: LocalizedStringResource {
      LocalizedStringResource("settings.marketTimezone", defaultValue: "Market timezone", bundle: L10n.bundle)
    }
    static var lastEntry: LocalizedStringResource {
      LocalizedStringResource("settings.lastEntry", defaultValue: "Last entry", bundle: L10n.bundle)
    }
    static var flatten: LocalizedStringResource {
      LocalizedStringResource("settings.flatten", defaultValue: "Flatten", bundle: L10n.bundle)
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
    static var alertPosition: LocalizedStringResource {
      LocalizedStringResource("settings.alertPosition", defaultValue: "Position opened or closed", bundle: L10n.bundle)
    }
    static var alertStop: LocalizedStringResource {
      LocalizedStringResource("settings.alertStop", defaultValue: "Broker stop not verified", bundle: L10n.bundle)
    }
    static var alertFence: LocalizedStringResource {
      LocalizedStringResource("settings.alertFence", defaultValue: "Reconciliation fence", bundle: L10n.bundle)
    }
    static var alertLossLimit: LocalizedStringResource {
      LocalizedStringResource("settings.alertLossLimit", defaultValue: "Daily loss limit reached", bundle: L10n.bundle)
    }
    static var alertBotDown: LocalizedStringResource {
      LocalizedStringResource("settings.alertBotDown",
        defaultValue: "Bot stopped or API unreachable",
        bundle: L10n.bundle)
    }
    static var macNotifications: LocalizedStringResource {
      LocalizedStringResource("settings.macNotifications", defaultValue: "macOS notifications", bundle: L10n.bundle)
    }
    static var notificationsLater: LocalizedStringResource {
      LocalizedStringResource("settings.notificationsLater",
        defaultValue: "System notifications arrive in a later update. Until then the menu-bar icon shows the state.",
        bundle: L10n.bundle)
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
    static var gateCause: LocalizedStringResource {
      LocalizedStringResource("settings.gateCause", defaultValue: "Gate cause", bundle: L10n.bundle)
    }
    static var apiVersion: LocalizedStringResource {
      LocalizedStringResource("settings.apiVersion", defaultValue: "Local API version", bundle: L10n.bundle)
    }
    static var brokerEnvironment: LocalizedStringResource {
      LocalizedStringResource("settings.brokerEnvironment", defaultValue: "Broker environment", bundle: L10n.bundle)
    }
    static var environmentFixed: LocalizedStringResource {
      LocalizedStringResource("settings.environmentFixed",
        defaultValue: "The environment is set in config/bot.toml. The app cannot switch it, by design.",
        bundle: L10n.bundle)
    }
    static var recordedDays: LocalizedStringResource {
      LocalizedStringResource("settings.recordedDays", defaultValue: "Recorded days", bundle: L10n.bundle)
    }
    static var firstRecordedDay: LocalizedStringResource {
      LocalizedStringResource("settings.firstRecordedDay", defaultValue: "First recorded day", bundle: L10n.bundle)
    }
    static var daysWithBars: LocalizedStringResource {
      LocalizedStringResource("settings.daysWithBars", defaultValue: "Days with captured bars", bundle: L10n.bundle)
    }
    static var history: LocalizedStringResource {
      LocalizedStringResource("settings.history", defaultValue: "History", bundle: L10n.bundle)
    }
    static var historySource: LocalizedStringResource {
      LocalizedStringResource("settings.historySource",
        defaultValue: "History is read from the bot's database and bar captures, read-only.",
        bundle: L10n.bundle)
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
    static var run: LocalizedStringResource {
      LocalizedStringResource("settings.run", defaultValue: "Run", bundle: L10n.bundle)
    }
    static var notAvailableYet: LocalizedStringResource {
      LocalizedStringResource("settings.notAvailableYet", defaultValue: "Not available yet", bundle: L10n.bundle)
    }
    static var startStop: LocalizedStringResource {
      LocalizedStringResource("settings.startStop",
        defaultValue: "Start and stop the bot from the app",
        bundle: L10n.bundle)
    }
    static var editConfig: LocalizedStringResource {
      LocalizedStringResource("settings.editConfig", defaultValue: "Edit the bot's configuration", bundle: L10n.bundle)
    }
  }

  // MARK: Screens: Chart, Trades & days, Risk & account, Lab
  enum Chart {
    /// Label of the chart's symbol picker.
    static var symbol: LocalizedStringResource {
      LocalizedStringResource("chart.symbol", defaultValue: "Symbol", bundle: L10n.bundle)
    }
    /// Label of the timeframe picker.
    static var timeframeLabel: LocalizedStringResource {
      LocalizedStringResource("chart.timeframeLabel", defaultValue: "Timeframe", bundle: L10n.bundle)
    }
    /// A timeframe segment: candle length in minutes.
    static func timeframe(_ minutes: Int) -> LocalizedStringResource {
      LocalizedStringResource("chart.timeframe", defaultValue: "M\(minutes)", bundle: L10n.bundle)
    }
    /// Tooltip of the timeframe picker.
    static var timeframeHelp: LocalizedStringResource {
      LocalizedStringResource("chart.timeframeHelp", defaultValue: "Candle length in minutes", bundle: L10n.bundle)
    }
    /// The VWAP line toggle and readout.
    static var vwap: LocalizedStringResource {
      LocalizedStringResource("chart.vwap", defaultValue: "VWAP", bundle: L10n.bundle)
    }
    /// An EMA line toggle and readout.
    static func ema(_ period: Int) -> LocalizedStringResource {
      LocalizedStringResource("chart.ema", defaultValue: "EMA \(period)", bundle: L10n.bundle)
    }
    /// The volume pane toggle.
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
      LocalizedStringResource("chart.noSymbolsDetail", defaultValue: "The bot has no open position, recorded bars or trades on this day.", bundle: L10n.bundle)
    }
    /// The bars read failed.
    static var barsUnavailable: LocalizedStringResource {
      LocalizedStringResource("chart.barsUnavailable", defaultValue: "Bars Unavailable", bundle: L10n.bundle)
    }
    /// Why the bars read failed.
    static func barsUnavailableDetail(_ cause: String) -> LocalizedStringResource {
      LocalizedStringResource("chart.barsUnavailableDetail", defaultValue: "The bot's API did not return bars: \(cause)", bundle: L10n.bundle)
    }
    /// While bars load.
    static var loading: LocalizedStringResource {
      LocalizedStringResource("chart.loading", defaultValue: "Loading Bars…", bundle: L10n.bundle)
    }
    /// The symbol has no bars on the day.
    static var noBars: LocalizedStringResource {
      LocalizedStringResource("chart.noBars", defaultValue: "No Bars", bundle: L10n.bundle)
    }
    /// No bars detail.
    static var noBarsDetail: LocalizedStringResource {
      LocalizedStringResource("chart.noBarsDetail", defaultValue: "No M1 bars were recorded for this symbol on this day.", bundle: L10n.bundle)
    }
    /// Entry mark of a trade with its quantity.
    static func buyMark(_ quantity: String) -> LocalizedStringResource {
      LocalizedStringResource("chart.buyMark", defaultValue: "Buy \(quantity)", bundle: L10n.bundle)
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
      LocalizedStringResource("chart.decisionsHelp", defaultValue: "Show why the strategies entered, watched or skipped this symbol, and mark their entries and exits on the candles (⌥⌘I)", bundle: L10n.bundle)
    }
    /// Chart mark of an observer's (shadow strategy's) decision.
    static func observerMark(_ action: String) -> LocalizedStringResource {
      LocalizedStringResource("chart.observerMark", defaultValue: "\(action) · observer", bundle: L10n.bundle)
    }
    /// Chart mark of the strategy's ENTER that was not taken (refused by risk or the gate).
    static func skippedMark(_ action: String) -> LocalizedStringResource {
      LocalizedStringResource("chart.skippedMark", defaultValue: "\(action) · skipped", bundle: L10n.bundle)
    }
    /// Decisions inspector is empty.
    static var noDecisions: LocalizedStringResource {
      LocalizedStringResource("chart.noDecisions", defaultValue: "No decisions were recorded for this symbol on this day.", bundle: L10n.bundle)
    }
    /// Why the decisions read failed.
    static func decisionsUnavailable(_ cause: String) -> LocalizedStringResource {
      LocalizedStringResource("chart.decisionsUnavailable", defaultValue: "The bot's API did not return decisions: \(cause)", bundle: L10n.bundle)
    }
    /// Badge: an observer (shadow strategy, never trades) made the decision.
    static var observerTag: LocalizedStringResource {
      LocalizedStringResource("chart.observerTag", defaultValue: "Observer", bundle: L10n.bundle)
    }
    /// A strategy name with its version.
    static func strategyVersion(_ name: String, _ version: String) -> LocalizedStringResource {
      LocalizedStringResource("chart.strategyVersion", defaultValue: "\(name) v\(version)", bundle: L10n.bundle)
    }
    /// What-if entry and stop of an ENTER that was not taken (refused, or an observer's).
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
      LocalizedStringResource("trades.daysUnavailable", defaultValue: "The day list is unavailable; the bot's API did not answer.", bundle: L10n.bundle)
    }
    /// Plotted value name of a day bar (VoiceOver).
    static var day: LocalizedStringResource {
      LocalizedStringResource("trades.day", defaultValue: "Day", bundle: L10n.bundle)
    }
    /// A trade's or day's gross result.
    static var result: LocalizedStringResource {
      LocalizedStringResource("trades.result", defaultValue: "Result", bundle: L10n.bundle)
    }
    /// Trades of a day with wins and losses.
    static func closedWinsLosses(_ trades: Int, _ wins: Int, _ losses: Int) -> LocalizedStringResource {
      LocalizedStringResource("trades.closedWinsLosses", defaultValue: "\(trades) · \(wins) W · \(losses) L", bundle: L10n.bundle)
    }
    /// Tooltip: a day without bars.
    static var noBarsHelp: LocalizedStringResource {
      LocalizedStringResource("trades.noBarsHelp", defaultValue: "No bars were recorded on this day, so the Chart has nothing to show.", bundle: L10n.bundle)
    }
    /// Stat card: the day's gross result.
    static var resultGross: LocalizedStringResource {
      LocalizedStringResource("trades.resultGross", defaultValue: "Result · gross", bundle: L10n.bundle)
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
      LocalizedStringResource("trades.notTakenEmpty", defaultValue: "Every entry signal of this day became a position.", bundle: L10n.bundle)
    }
    /// Skipped read failed.
    static func notTakenUnavailable(_ cause: String) -> LocalizedStringResource {
      LocalizedStringResource("trades.notTakenUnavailable", defaultValue: "The bot's API did not return the skipped signals: \(cause)", bundle: L10n.bundle)
    }
    /// Badge: the platform refused the entry (risk, gate or limit).
    static var refused: LocalizedStringResource {
      LocalizedStringResource("trades.refused", defaultValue: "Refused", bundle: L10n.bundle)
    }
    /// Badge: the entry was never put to the platform's checks.
    static var notEvaluated: LocalizedStringResource {
      LocalizedStringResource("trades.notEvaluated", defaultValue: "Not evaluated", bundle: L10n.bundle)
    }
    /// What-if entry and stop of a skipped signal.
    static func whatIfLevels(_ entry: String, _ stop: String) -> LocalizedStringResource {
      LocalizedStringResource("trades.whatIfLevels", defaultValue: "What-if entry \(entry) · stop \(stop)", bundle: L10n.bundle)
    }
    /// Card title: the selected trade's risk, excursion and stop timing.
    static func tradeDetail(_ symbol: String) -> LocalizedStringResource {
      LocalizedStringResource("trades.tradeDetail", defaultValue: "Trade \(symbol)", bundle: L10n.bundle)
    }
    /// Card title before a trade is selected.
    static var selectedTrade: LocalizedStringResource {
      LocalizedStringResource("trades.selectedTrade", defaultValue: "Selected Trade", bundle: L10n.bundle)
    }
    /// Trade detail card before a trade is selected.
    static var selectTrade: LocalizedStringResource {
      LocalizedStringResource("trades.selectTrade", defaultValue: "Select a trade to see its risk, price excursion and how fast its stop was confirmed.", bundle: L10n.bundle)
    }
    /// Detail: what the trade risked at entry, the unit of R.
    static var oneR: LocalizedStringResource {
      LocalizedStringResource("trades.oneR", defaultValue: "1 R · planned loss", bundle: L10n.bundle)
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
      LocalizedStringResource("trades.excursionLowerBound", defaultValue: "MAE and MFE count only prices proven to come while the shares were held, so the real excursion can be larger.", bundle: L10n.bundle)
    }
    /// Detail value the bot could not compute (MAE/MFE without captured bars).
    static var unknown: LocalizedStringResource {
      LocalizedStringResource("trades.unknown", defaultValue: "Unknown", bundle: L10n.bundle)
    }
    /// Tooltip of the stop confirmation time.
    static var stopConfirmedHelp: LocalizedStringResource {
      LocalizedStringResource("trades.stopConfirmedHelp", defaultValue: "Counted from when the bot saw the entry fill to when the broker confirmed the stop.", bundle: L10n.bundle)
    }
    /// Detail value the bot did not record.
    static var notRecorded: LocalizedStringResource {
      LocalizedStringResource("trades.notRecorded", defaultValue: "Not recorded", bundle: L10n.bundle)
    }
    /// Card title: gross performance over the days that end on the shown day.
    static func performance(_ days: Int) -> LocalizedStringResource {
      LocalizedStringResource("trades.performance", defaultValue: "Performance in R · \(days) days", bundle: L10n.bundle)
    }
    /// Performance figure: average result per trade, in R.
    static var expectancy: LocalizedStringResource {
      LocalizedStringResource("trades.expectancy", defaultValue: "Expectancy", bundle: L10n.bundle)
    }
    /// Performance figure: share of winning trades.
    static var winRate: LocalizedStringResource {
      LocalizedStringResource("trades.winRate", defaultValue: "Win rate", bundle: L10n.bundle)
    }
    /// Performance figure: gross profit over gross loss.
    static var profitFactor: LocalizedStringResource {
      LocalizedStringResource("trades.profitFactor", defaultValue: "Profit factor", bundle: L10n.bundle)
    }
    /// Performance figure: deepest fall from a running peak, in R.
    static var maxDrawdown: LocalizedStringResource {
      LocalizedStringResource("trades.maxDrawdown", defaultValue: "Max drawdown", bundle: L10n.bundle)
    }
    /// Performance figure: sum of results, in R.
    static var totalR: LocalizedStringResource {
      LocalizedStringResource("trades.totalR", defaultValue: "Total", bundle: L10n.bundle)
    }
    /// A percentage.
    static func percent(_ value: String) -> LocalizedStringResource {
      LocalizedStringResource("trades.percent", defaultValue: "\(value)%", bundle: L10n.bundle)
    }
    /// Counts under the performance figures.
    static func performanceCounts(_ trades: Int, _ wins: Int, _ losses: Int, _ scratches: Int) -> LocalizedStringResource {
      LocalizedStringResource("trades.performanceCounts", defaultValue: "\(trades) trades · \(wins) W · \(losses) L · \(scratches) flat", bundle: L10n.bundle)
    }
    /// Trades left out of every performance figure, with why.
    static func excluded(_ trades: Int, _ cause: String) -> LocalizedStringResource {
      LocalizedStringResource("trades.excluded", defaultValue: "Left out: \(trades) · \(cause)", bundle: L10n.bundle)
    }
    /// Performance read failed.
    static func performanceUnavailable(_ cause: String) -> LocalizedStringResource {
      LocalizedStringResource("trades.performanceUnavailable", defaultValue: "The bot's API did not return performance: \(cause)", bundle: L10n.bundle)
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
    static var grossNote: LocalizedStringResource {
      LocalizedStringResource("trades.grossNote", defaultValue: "Gross: before fees. 1 R is each trade's planned loss.", bundle: L10n.bundle)
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
    /// Stat card: average result in R.
    static var averageR: LocalizedStringResource {
      LocalizedStringResource("trades.averageR", defaultValue: "Average R", bundle: L10n.bundle)
    }
    /// Stat card: best and worst trade.
    static var bestWorst: LocalizedStringResource {
      LocalizedStringResource("trades.bestWorst", defaultValue: "Best · worst", bundle: L10n.bundle)
    }
    /// Card title: the day's trade table.
    static var tradesOfDay: LocalizedStringResource {
      LocalizedStringResource("trades.tradesOfDay", defaultValue: "Closed trades", bundle: L10n.bundle)
    }
    /// Trade table empty on the live day.
    static var noTradesToday: LocalizedStringResource {
      LocalizedStringResource("trades.noTradesToday", defaultValue: "No closed trades yet today.", bundle: L10n.bundle)
    }
    /// Trade table empty on a recorded day.
    static var noTrades: LocalizedStringResource {
      LocalizedStringResource("trades.noTrades", defaultValue: "No closed trades on this day.", bundle: L10n.bundle)
    }
    /// Column: time the trade closed (New York).
    static var closed: LocalizedStringResource {
      LocalizedStringResource("trades.closed", defaultValue: "Closed", bundle: L10n.bundle)
    }
    /// Column: symbol.
    static var symbol: LocalizedStringResource {
      LocalizedStringResource("trades.symbol", defaultValue: "Symbol", bundle: L10n.bundle)
    }
    /// Column: shares.
    static var quantity: LocalizedStringResource {
      LocalizedStringResource("trades.quantity", defaultValue: "Qty", bundle: L10n.bundle)
    }
    /// Column: entry price.
    static var entry: LocalizedStringResource {
      LocalizedStringResource("trades.entry", defaultValue: "Entry", bundle: L10n.bundle)
    }
    /// Column: exit price.
    static var exit: LocalizedStringResource {
      LocalizedStringResource("trades.exit", defaultValue: "Exit", bundle: L10n.bundle)
    }
    /// Column: stop price.
    static var stop: LocalizedStringResource {
      LocalizedStringResource("trades.stop", defaultValue: "Stop", bundle: L10n.bundle)
    }
    /// Column: exit reason.
    static var reason: LocalizedStringResource {
      LocalizedStringResource("trades.reason", defaultValue: "Reason", bundle: L10n.bundle)
    }
    /// Column: result in R.
    static var resultR: LocalizedStringResource {
      LocalizedStringResource("trades.resultR", defaultValue: "R", bundle: L10n.bundle)
    }
    /// Context menu: open the trade's symbol on the Chart.
    static var showOnChart: LocalizedStringResource {
      LocalizedStringResource("trades.showOnChart", defaultValue: "Show on Chart", bundle: L10n.bundle)
    }
    /// Card title: what-if replays.
    static var whatIf: LocalizedStringResource {
      LocalizedStringResource("trades.whatIf", defaultValue: "What if", bundle: L10n.bundle)
    }
    /// What-if card text.
    static var whatIfDetail: LocalizedStringResource {
      LocalizedStringResource("trades.whatIfDetail", defaultValue: "Replay a skipped signal as if the bot had entered, or the day under another strategy.", bundle: L10n.bundle)
    }
    /// Planned button: replay a skipped signal.
    static var whatIfEntered: LocalizedStringResource {
      LocalizedStringResource("trades.whatIfEntered", defaultValue: "If We Had Entered…", bundle: L10n.bundle)
    }
    /// Planned button: replay with another strategy.
    static var whatIfStrategy: LocalizedStringResource {
      LocalizedStringResource("trades.whatIfStrategy", defaultValue: "Another Strategy…", bundle: L10n.bundle)
    }
  }
  enum Risk {
    /// Card title: room left before the daily loss limit.
    static var lossRoom: LocalizedStringResource {
      LocalizedStringResource("risk.lossRoom", defaultValue: "Daily loss room · net", bundle: L10n.bundle)
    }
    /// Under the ring: room left.
    static var roomLeft: LocalizedStringResource {
      LocalizedStringResource("risk.roomLeft", defaultValue: "Left today", bundle: L10n.bundle)
    }
    /// The configured daily loss limit.
    static var limit: LocalizedStringResource {
      LocalizedStringResource("risk.limit", defaultValue: "Daily loss limit", bundle: L10n.bundle)
    }
    /// Today's net result.
    static var resultToday: LocalizedStringResource {
      LocalizedStringResource("risk.resultToday", defaultValue: "Result today · net", bundle: L10n.bundle)
    }
    /// How the daily limit works.
    static var lossRoomNote: LocalizedStringResource {
      LocalizedStringResource("risk.lossRoomNote", defaultValue: "Profits offset losses but never raise the room above the limit. Open reservations, the worst case of entries in flight, count against it. Near the limit the bot sizes trades down to the room left; below the minimum room it stops entering.", bundle: L10n.bundle)
    }
    /// Loss counted against the daily limit so far.
    static var realizedLoss: LocalizedStringResource {
      LocalizedStringResource("risk.realizedLoss", defaultValue: "Realized loss today", bundle: L10n.bundle)
    }
    /// Worst-case loss reserved by entries in flight.
    static var reservations: LocalizedStringResource {
      LocalizedStringResource("risk.reservations", defaultValue: "Open reservations", bundle: L10n.bundle)
    }
    /// The status has no daily room value.
    static var roomNotReported: LocalizedStringResource {
      LocalizedStringResource("risk.roomNotReported", defaultValue: "The bot did not report the room left.", bundle: L10n.bundle)
    }
    /// Configured minimum daily room for an entry.
    static var minRoom: LocalizedStringResource {
      LocalizedStringResource("risk.minRoom", defaultValue: "No entries below room of", bundle: L10n.bundle)
    }
    /// Entry gate when the status is unknown.
    static var statusUnknown: LocalizedStringResource {
      LocalizedStringResource("risk.statusUnknown", defaultValue: "The bot's status is unknown, so it is not known whether entries are allowed.", bundle: L10n.bundle)
    }
    /// Card title: may the bot enter now.
    static var entryGate: LocalizedStringResource {
      LocalizedStringResource("risk.entryGate", defaultValue: "New entries", bundle: L10n.bundle)
    }
    /// Badge: entries allowed.
    static var allowed: LocalizedStringResource {
      LocalizedStringResource("risk.allowed", defaultValue: "ALLOWED", bundle: L10n.bundle)
    }
    /// Badge: entries blocked.
    static var blocked: LocalizedStringResource {
      LocalizedStringResource("risk.blocked", defaultValue: "BLOCKED", bundle: L10n.bundle)
    }
    /// Entry stop set by the operator.
    static var operatorPause: LocalizedStringResource {
      LocalizedStringResource("risk.operatorPause", defaultValue: "Operator pause", bundle: L10n.bundle)
    }
    /// The configured trading gate.
    static var tradingGate: LocalizedStringResource {
      LocalizedStringResource("risk.tradingGate", defaultValue: "Trading gate", bundle: L10n.bundle)
    }
    /// Trading gate open.
    static var gateOpen: LocalizedStringResource {
      LocalizedStringResource("risk.gateOpen", defaultValue: "open", bundle: L10n.bundle)
    }
    /// Trading gate closed.
    static var gateClosed: LocalizedStringResource {
      LocalizedStringResource("risk.gateClosed", defaultValue: "closed", bundle: L10n.bundle)
    }
    /// Card title: blocks the bot raised itself.
    static var fences: LocalizedStringResource {
      LocalizedStringResource("risk.fences", defaultValue: "Fences", bundle: L10n.bundle)
    }
    /// No fences.
    static var noFences: LocalizedStringResource {
      LocalizedStringResource("risk.noFences", defaultValue: "No fences: nothing the bot noticed blocks entries.", bundle: L10n.bundle)
    }
    /// A fence's kind and start time (New York).
    static func fenceSince(_ kind: String, _ time: String) -> LocalizedStringResource {
      LocalizedStringResource("risk.fenceSince", defaultValue: "\(kind) · since \(time)", bundle: L10n.bundle)
    }
    /// Card title: configured risk limits.
    static var limits: LocalizedStringResource {
      LocalizedStringResource("risk.limits", defaultValue: "Limits", bundle: L10n.bundle)
    }
    /// Configured planned loss.
    static var plannedLoss: LocalizedStringResource {
      LocalizedStringResource("risk.plannedLoss", defaultValue: "Planned loss per trade (1 R)", bundle: L10n.bundle)
    }
    /// Configured notional cap.
    static var notionalCap: LocalizedStringResource {
      LocalizedStringResource("risk.notionalCap", defaultValue: "Position size cap", bundle: L10n.bundle)
    }
    /// Configured daily loss limit.
    static var dailyLoss: LocalizedStringResource {
      LocalizedStringResource("risk.dailyLoss", defaultValue: "Daily loss limit", bundle: L10n.bundle)
    }
    /// Configured position count.
    static var openPositions: LocalizedStringResource {
      LocalizedStringResource("risk.openPositions", defaultValue: "Open positions at most", bundle: L10n.bundle)
    }
    /// Configured quote age.
    static var quoteAge: LocalizedStringResource {
      LocalizedStringResource("risk.quoteAge", defaultValue: "Oldest quote to trade on", bundle: L10n.bundle)
    }
    /// A duration in seconds.
    static func seconds(_ value: String) -> LocalizedStringResource {
      LocalizedStringResource("risk.seconds", defaultValue: "\(value) s", bundle: L10n.bundle)
    }
    /// Settings read failed.
    static var settingsUnavailable: LocalizedStringResource {
      LocalizedStringResource("risk.settingsUnavailable", defaultValue: "Settings are unavailable; the bot's API did not answer.", bundle: L10n.bundle)
    }
    /// The market clock on the Session card: "14:46:17 ET", 24-hour New York time.
    static func clock(_ time: String) -> LocalizedStringResource {
      LocalizedStringResource("risk.clock", defaultValue: "\(time) ET", bundle: L10n.bundle)
    }
    /// Card title: the trading session.
    static var session: LocalizedStringResource {
      LocalizedStringResource("risk.session", defaultValue: "Session · New York", bundle: L10n.bundle)
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
      LocalizedStringResource("risk.brokerOrders", defaultValue: "Broker orders", bundle: L10n.bundle)
    }
    /// Why equity and buying power are empty.
    static var balanceNote: LocalizedStringResource {
      LocalizedStringResource("risk.balanceNote", defaultValue: "The bot does not read equity and buying power from the broker yet.", bundle: L10n.bundle)
    }
    /// Badge: the broker's view matches the bot's records.
    static var matches: LocalizedStringResource {
      LocalizedStringResource("risk.matches", defaultValue: "MATCHES", bundle: L10n.bundle)
    }
    /// Badge: the broker's view differs from the bot's records.
    static var mismatch: LocalizedStringResource {
      LocalizedStringResource("risk.mismatch", defaultValue: "MISMATCH", bundle: L10n.bundle)
    }
    /// Badge: the account read is older than the API allows.
    static var stale: LocalizedStringResource {
      LocalizedStringResource("risk.stale", defaultValue: "STALE", bundle: L10n.bundle)
    }
    /// When the bot last read the broker (New York time) and how long ago.
    static func readAt(_ time: String, _ age: String) -> LocalizedStringResource {
      LocalizedStringResource("risk.readAt", defaultValue: "Broker read at \(time) · \(age) s ago", bundle: L10n.bundle)
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
      LocalizedStringResource("risk.accountUnavailable", defaultValue: "The account read is unavailable; the bot's API did not answer it.", bundle: L10n.bundle)
    }
    /// Before the first account answer.
    static var accountReading: LocalizedStringResource {
      LocalizedStringResource("risk.accountReading", defaultValue: "Reading the account…", bundle: L10n.bundle)
    }
  }
  enum Lab {
    /// Card title: the strategy the bot trades with.
    static var activeStrategy: LocalizedStringResource {
      LocalizedStringResource("lab.activeStrategy", defaultValue: "Active strategy", bundle: L10n.bundle)
    }
    /// The shown day's trades.
    static var shownDayTrades: LocalizedStringResource {
      LocalizedStringResource("lab.shownDayTrades", defaultValue: "Trades", bundle: L10n.bundle)
    }
    /// Trades with wins and losses.
    static func closedWinsLosses(_ trades: Int, _ wins: Int, _ losses: Int) -> LocalizedStringResource {
      LocalizedStringResource("lab.closedWinsLosses", defaultValue: "\(trades) · \(wins) W · \(losses) L", bundle: L10n.bundle)
    }
    /// The shown day's gross result.
    static var shownDayResult: LocalizedStringResource {
      LocalizedStringResource("lab.shownDayResult", defaultValue: "Result · gross", bundle: L10n.bundle)
    }
    /// How strategies are swapped.
    static var swapNote: LocalizedStringResource {
      LocalizedStringResource("lab.swapNote", defaultValue: "Strategies are swappable modules: the active one is set in the bot's config and never loosens platform risk.", bundle: L10n.bundle)
    }
    /// Card title: shadow strategies.
    static var observers: LocalizedStringResource {
      LocalizedStringResource("lab.observers", defaultValue: "Observers", bundle: L10n.bundle)
    }
    /// No observers in the config.
    static var observersEmpty: LocalizedStringResource {
      LocalizedStringResource("lab.observersEmpty", defaultValue: "No observer strategies configured.", bundle: L10n.bundle)
    }
    /// The observers read failed.
    static var observersUnavailable: LocalizedStringResource {
      LocalizedStringResource("lab.observersUnavailable", defaultValue: "Observers are unavailable; the bot's API did not answer.", bundle: L10n.bundle)
    }
    /// How many decisions an observer recorded on the shown day.
    static func decisionCount(_ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("lab.decisionCount", defaultValue: "\(count) decisions", bundle: L10n.bundle)
    }
    /// An observer's latest decision (New York time).
    static func lastDecision(_ action: String, _ symbol: String, _ time: String) -> LocalizedStringResource {
      LocalizedStringResource("lab.lastDecision", defaultValue: "Last: \(action) \(symbol) at \(time)", bundle: L10n.bundle)
    }
    /// An observer's hypothetical result is not served yet.
    static var resultPending: LocalizedStringResource {
      LocalizedStringResource("lab.resultPending", defaultValue: "Result not computed yet", bundle: L10n.bundle)
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
    /// What observers do.
    static var observersNote: LocalizedStringResource {
      LocalizedStringResource("lab.observersNote", defaultValue: "Shadow versions see the same data live and record their decisions without trading.", bundle: L10n.bundle)
    }
    /// Card title: replaying recorded days.
    static var replay: LocalizedStringResource {
      LocalizedStringResource("lab.replay", defaultValue: "Replay", bundle: L10n.bundle)
    }
    /// What replay does.
    static var replayNote: LocalizedStringResource {
      LocalizedStringResource("lab.replayNote", defaultValue: "Replay a recorded day: skipped signals as if the bot had entered, or the whole day under another strategy.", bundle: L10n.bundle)
    }
    /// Planned button: replay a day.
    static var replayDay: LocalizedStringResource {
      LocalizedStringResource("lab.replayDay", defaultValue: "Replay Day", bundle: L10n.bundle)
    }
    /// Planned button: skipped signals.
    static var skippedSignals: LocalizedStringResource {
      LocalizedStringResource("lab.skippedSignals", defaultValue: "Skipped Signals", bundle: L10n.bundle)
    }
    /// Planned button: compare strategies.
    static var compare: LocalizedStringResource {
      LocalizedStringResource("lab.compare", defaultValue: "Compare", bundle: L10n.bundle)
    }
    /// Card title: the AI advisor.
    static var advisor: LocalizedStringResource {
      LocalizedStringResource("lab.advisor", defaultValue: "Advisor", bundle: L10n.bundle)
    }
    /// What the advisor does.
    static var advisorNote: LocalizedStringResource {
      LocalizedStringResource("lab.advisorNote", defaultValue: "Proposes new strategy versions from recorded days, with the evidence, for you to accept or reject.", bundle: L10n.bundle)
    }
  }
  enum MenuBar {
    /// Menu bar: label over today's result.
    static var today: LocalizedStringResource {
      LocalizedStringResource("menuBar.today", defaultValue: "Today", bundle: L10n.bundle)
    }
    /// Today's closed trades with wins and losses.
    static func trades(_ closed: Int, _ wins: Int, _ losses: Int) -> LocalizedStringResource {
      LocalizedStringResource("menuBar.trades", defaultValue: "\(closed) closed · \(wins) W · \(losses) L", bundle: L10n.bundle)
    }
    /// Today's trades and the room under the daily loss limit.
    static func tradesAndRoom(_ closed: Int, _ wins: Int, _ losses: Int, _ room: String, _ limit: String) -> LocalizedStringResource {
      LocalizedStringResource("menuBar.tradesAndRoom", defaultValue: "\(closed) closed · \(wins) W · \(losses) L · room \(room) of \(limit)", bundle: L10n.bundle)
    }
    /// A position's size in shares.
    static func shares(_ quantity: String) -> LocalizedStringResource {
      LocalizedStringResource("menuBar.shares", defaultValue: "\(quantity) sh", bundle: L10n.bundle)
    }
    /// A position's entry price.
    static func entry(_ price: String) -> LocalizedStringResource {
      LocalizedStringResource("menuBar.entry", defaultValue: "entry \(price)", bundle: L10n.bundle)
    }
    /// The last bar's close.
    static func last(_ price: String) -> LocalizedStringResource {
      LocalizedStringResource("menuBar.last", defaultValue: "last \(price)", bundle: L10n.bundle)
    }
    /// How long ago the bot last read the broker.
    static func brokerRead(_ age: String) -> LocalizedStringResource {
      LocalizedStringResource("menuBar.brokerRead", defaultValue: "broker read \(age)", bundle: L10n.bundle)
    }
  }
  enum Screener {
    /// Pipeline stage value: symbols that reached the stage on the day.
    static func symbols(_ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("screener.symbols", defaultValue: "\(count) symbols", bundle: L10n.bundle)
    }
    /// Pipeline stop stage: trades whose broker-side stop the broker confirmed.
    static func stopsVerified(_ verified: Int, _ total: Int) -> LocalizedStringResource {
      LocalizedStringResource("screener.stopsVerified", defaultValue: "\(verified) of \(total) verified", bundle: L10n.bundle)
    }
    /// Pipeline reconcile stage: the broker and the bot's records disagree.
    static var mismatch: LocalizedStringResource {
      LocalizedStringResource("screener.mismatch", defaultValue: "Mismatch", bundle: L10n.bundle)
    }
    /// Screener name: top gainers.
    static var gainers: LocalizedStringResource {
      LocalizedStringResource("screener.gainers", defaultValue: "Gainers", bundle: L10n.bundle)
    }
    /// Screener name: top losers.
    static var losers: LocalizedStringResource {
      LocalizedStringResource("screener.losers", defaultValue: "Losers", bundle: L10n.bundle)
    }
    /// Screener name: most traded.
    static var topActives: LocalizedStringResource {
      LocalizedStringResource("screener.topActives", defaultValue: "Most active", bundle: L10n.bundle)
    }
    /// Tooltip of a screener chip the universe left out.
    static func excluded(_ cause: String) -> LocalizedStringResource {
      LocalizedStringResource("screener.excluded", defaultValue: "Left out of the universe: \(cause)", bundle: L10n.bundle)
    }
    /// No screener chips.
    static var none: LocalizedStringResource {
      LocalizedStringResource("screener.none", defaultValue: "The screeners returned nothing on this day.", bundle: L10n.bundle)
    }
    /// Flow read failed.
    static func unavailable(_ cause: String) -> LocalizedStringResource {
      LocalizedStringResource("screener.unavailable", defaultValue: "The bot's API did not return the flow: \(cause)", bundle: L10n.bundle)
    }
  }
  enum Watching {
    /// Card title: symbols the strategy is closest to entering.
    static var title: LocalizedStringResource {
      LocalizedStringResource("watching.title", defaultValue: "Watching Closely", bundle: L10n.bundle)
    }
    /// Card trailing: rows shown of all watched symbols.
    static func count(_ shown: Int, _ total: Int) -> LocalizedStringResource {
      LocalizedStringResource("watching.count", defaultValue: "\(shown) of \(total)", bundle: L10n.bundle)
    }
    /// Watching card is empty.
    static var none: LocalizedStringResource {
      LocalizedStringResource("watching.none", defaultValue: "The strategy is not watching any symbol on this day.", bundle: L10n.bundle)
    }
    /// Watching read failed.
    static func unavailable(_ cause: String) -> LocalizedStringResource {
      LocalizedStringResource("watching.unavailable", defaultValue: "The bot's API did not return the watched symbols: \(cause)", bundle: L10n.bundle)
    }
    /// Bar and VoiceOver name: how close the deciding check is to passing.
    static var closeness: LocalizedStringResource {
      LocalizedStringResource("watching.closeness", defaultValue: "Closeness to entry", bundle: L10n.bundle)
    }
    /// Row without a deciding check.
    static var noCheck: LocalizedStringResource {
      LocalizedStringResource("watching.noCheck", defaultValue: "No deciding check recorded", bundle: L10n.bundle)
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
      LocalizedStringResource("entrySent.breach", defaultValue: "\(symbol): \(count) sends", bundle: L10n.bundle)
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
  // END Screens
}
