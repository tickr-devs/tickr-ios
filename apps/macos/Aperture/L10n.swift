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

  enum App {
    static var name: LocalizedStringResource {
      LocalizedStringResource("app.name", defaultValue: "Aperture", bundle: L10n.bundle)
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
      LocalizedStringResource("app.openApp", defaultValue: "Open Aperture", bundle: L10n.bundle)
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
        defaultValue: "Needs a new API command: new entries blocked, working entries cancelled, broker stops left resting.",
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
    static var comingNext: LocalizedStringResource {
      LocalizedStringResource("section.comingNext",
        defaultValue: "This section is being rebuilt to the approved design and arrives in the next update.",
        bundle: L10n.bundle)
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
      LocalizedStringResource("position.openChart", defaultValue: "Open Chart", bundle: L10n.bundle)
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
      LocalizedStringResource("riskRoom.details", defaultValue: "Details", bundle: L10n.bundle)
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
    static var notInAPI: LocalizedStringResource {
      LocalizedStringResource("observers.notInAPI",
        defaultValue: "Observer results are not in the local API yet.",
        bundle: L10n.bundle)
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
        defaultValue: "Show Aperture in the menu bar",
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
}
