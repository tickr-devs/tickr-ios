import Foundation

/// Every text of the iOS app that a person reads, in English, with its Russian translation in
/// Localizable.xcstrings beside this file (docs/design-system.md, rule 2). The Chart tab keeps its
/// own table (`ChartText` at the end of this file, one file per target so Xcode extracts it once).
/// Views pass these to `Text` and the components, or read them with `String(localized:)`. Keys are
/// `<namespace>.<name>`.
enum L10n {
  /// The app bundle, where Xcode compiles the String Catalog.
  static var bundle: LocalizedStringResource.BundleDescription { .main }

  enum App {
    static var name: LocalizedStringResource {
      LocalizedStringResource("app.name", defaultValue: "Aperture", bundle: L10n.bundle)
    }
    static var home: LocalizedStringResource {
      LocalizedStringResource("app.home", defaultValue: "Home", bundle: L10n.bundle)
    }
    static var positions: LocalizedStringResource {
      LocalizedStringResource("app.positions", defaultValue: "Positions", bundle: L10n.bundle)
    }
    static var chart: LocalizedStringResource {
      LocalizedStringResource("app.chart", defaultValue: "Chart", bundle: L10n.bundle)
    }
    static var activity: LocalizedStringResource {
      LocalizedStringResource("app.activity", defaultValue: "Activity", bundle: L10n.bundle)
    }
    static var lab: LocalizedStringResource {
      LocalizedStringResource("app.lab", defaultValue: "Lab", bundle: L10n.bundle)
    }
  }

  enum Common {
    static var cancel: LocalizedStringResource {
      LocalizedStringResource("common.cancel", defaultValue: "Cancel", bundle: L10n.bundle)
    }
    static func strategyVersion(_ name: String, _ version: String) -> LocalizedStringResource {
      LocalizedStringResource("common.strategyVersion", defaultValue: "\(name) v\(version)", bundle: L10n.bundle)
    }
    static func quantityAt(_ quantity: String, _ price: String) -> LocalizedStringResource {
      LocalizedStringResource("common.quantityAt", defaultValue: "\(quantity) @ \(price)", bundle: L10n.bundle)
    }
    static func winsLosses(_ wins: Int, _ losses: Int) -> LocalizedStringResource {
      LocalizedStringResource("common.winsLosses", defaultValue: "\(wins) W · \(losses) L", bundle: L10n.bundle)
    }
    static func today(_ day: String) -> LocalizedStringResource {
      LocalizedStringResource("common.today", defaultValue: "\(day) · today", bundle: L10n.bundle)
    }
    static var unknown: LocalizedStringResource {
      LocalizedStringResource("common.unknown", defaultValue: "unknown", bundle: L10n.bundle)
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

  enum Age {
    static var none: LocalizedStringResource {
      LocalizedStringResource("age.none", defaultValue: "no status yet", bundle: L10n.bundle)
    }
    static func stale(_ seconds: Int) -> LocalizedStringResource {
      LocalizedStringResource("age.stale", defaultValue: "stale · written \(seconds) s ago", bundle: L10n.bundle)
    }
    static func updated(_ seconds: Int) -> LocalizedStringResource {
      LocalizedStringResource("age.updated", defaultValue: "updated \(seconds) s ago", bundle: L10n.bundle)
    }
  }

  enum Connect {
    static var title: LocalizedStringResource {
      LocalizedStringResource("connect.title", defaultValue: "Connect to your Mac", bundle: L10n.bundle)
    }
    static var body: LocalizedStringResource {
      LocalizedStringResource("connect.body",
        defaultValue: "Enter the address of the bot's API in Settings.",
        bundle: L10n.bundle)
    }
    static var openSettings: LocalizedStringResource {
      LocalizedStringResource("connect.openSettings", defaultValue: "Open Settings", bundle: L10n.bundle)
    }
    static var noStatus: LocalizedStringResource {
      LocalizedStringResource("connect.noStatus", defaultValue: "No status from the bot", bundle: L10n.bundle)
    }
    static func environment(_ name: String) -> LocalizedStringResource {
      LocalizedStringResource("connect.environment", defaultValue: "Environment \(name)", bundle: L10n.bundle)
    }
    static var notConnected: LocalizedStringResource {
      LocalizedStringResource("connect.notConnected",
        defaultValue: "Not connected. Add your Mac's address in Settings.",
        bundle: L10n.bundle)
    }
    static var faceIDUnavailable: LocalizedStringResource {
      LocalizedStringResource("connect.faceIDUnavailable",
        defaultValue: "Face ID and passcode are not available",
        bundle: L10n.bundle)
    }
  }

  enum Notice {
    static func busy(_ command: String) -> LocalizedStringResource {
      LocalizedStringResource("notice.busy",
        defaultValue: "\(command) not sent: another command is being sent.",
        bundle: L10n.bundle)
    }
    static func notCurrent(_ command: String) -> LocalizedStringResource {
      LocalizedStringResource("notice.notCurrent",
        defaultValue: "\(command) not sent: the bot's status is not current.",
        bundle: L10n.bundle)
    }
    static func notConfirmed(_ command: String, _ cause: String) -> LocalizedStringResource {
      LocalizedStringResource("notice.notConfirmed",
        defaultValue: "\(command) not sent: owner not confirmed (\(cause)).",
        bundle: L10n.bundle)
    }
    static func wentStale(_ command: String) -> LocalizedStringResource {
      LocalizedStringResource("notice.wentStale",
        defaultValue: "\(command) not sent: the bot's status went out of date.",
        bundle: L10n.bundle)
    }
    static func queuedWarning(_ command: String, _ warning: String) -> LocalizedStringResource {
      LocalizedStringResource("notice.queuedWarning",
        defaultValue: "\(command) queued. \(warning)",
        bundle: L10n.bundle)
    }
    static func queued(_ command: String) -> LocalizedStringResource {
      LocalizedStringResource("notice.queued", defaultValue: "\(command) queued for the bot.", bundle: L10n.bundle)
    }
    static func failed(_ command: String, _ cause: String) -> LocalizedStringResource {
      LocalizedStringResource("notice.failed", defaultValue: "\(command) not sent: \(cause)", bundle: L10n.bundle)
    }
    static func done(_ command: String) -> LocalizedStringResource {
      LocalizedStringResource("notice.done", defaultValue: "\(command): done.", bundle: L10n.bundle)
    }
    static func refused(_ command: String, _ cause: String) -> LocalizedStringResource {
      LocalizedStringResource("notice.refused", defaultValue: "\(command) refused: \(cause)", bundle: L10n.bundle)
    }
    static var noCause: LocalizedStringResource {
      LocalizedStringResource("notice.noCause", defaultValue: "no cause given", bundle: L10n.bundle)
    }
  }

  enum Control {
    static var resume: LocalizedStringResource {
      LocalizedStringResource("control.resume", defaultValue: "Resume Entries", bundle: L10n.bundle)
    }
    static var pause: LocalizedStringResource {
      LocalizedStringResource("control.pause", defaultValue: "Pause Entries", bundle: L10n.bundle)
    }
    static var cancelOrders: LocalizedStringResource {
      LocalizedStringResource("control.cancelOrders", defaultValue: "Cancel Own Orders", bundle: L10n.bundle)
    }
    static var flattenAll: LocalizedStringResource {
      LocalizedStringResource("control.flattenAll", defaultValue: "Flatten All Positions", bundle: L10n.bundle)
    }
    static var message: LocalizedStringResource {
      LocalizedStringResource("control.message",
        defaultValue: "Pausing and cancelling never touch broker stops. Flatten closes the bot's own positions through the normal exit. Each command is queued once; the bot reports the result.",
        bundle: L10n.bundle)
    }
    static var unknown: LocalizedStringResource {
      LocalizedStringResource("control.unknown", defaultValue: "Bot status unknown", bundle: L10n.bundle)
    }
    static func state(_ state: String) -> LocalizedStringResource {
      LocalizedStringResource("control.state", defaultValue: "Bot is \(state)", bundle: L10n.bundle)
    }
    static func statePaused(_ state: String) -> LocalizedStringResource {
      LocalizedStringResource("control.statePaused",
        defaultValue: "Bot is \(state) · entries paused",
        bundle: L10n.bundle)
    }
    static func reason(_ command: String) -> LocalizedStringResource {
      LocalizedStringResource("control.reason", defaultValue: "\(command) on the trading bot", bundle: L10n.bundle)
    }
    static var title: LocalizedStringResource {
      LocalizedStringResource("control.title", defaultValue: "Bot control", bundle: L10n.bundle)
    }
  }

  enum Home {
    static var noPosition: LocalizedStringResource {
      LocalizedStringResource("home.noPosition", defaultValue: "No open position.", bundle: L10n.bundle)
    }
    static var settings: LocalizedStringResource {
      LocalizedStringResource("home.settings", defaultValue: "Settings", bundle: L10n.bundle)
    }
    static var day: LocalizedStringResource {
      LocalizedStringResource("home.day", defaultValue: "day", bundle: L10n.bundle)
    }
    static func dayResult(_ result: String, _ wins: Int, _ losses: Int) -> LocalizedStringResource {
      LocalizedStringResource("home.dayResult",
        defaultValue: "Day result \(result), \(wins) wins, \(losses) losses",
        bundle: L10n.bundle)
    }
    static func protected(_ symbol: String) -> LocalizedStringResource {
      LocalizedStringResource("home.protected",
        defaultValue: "\(symbol) protected by a broker stop.",
        bundle: L10n.bundle)
    }
    static func stopIs(_ symbol: String, _ state: String) -> LocalizedStringResource {
      LocalizedStringResource("home.stopIs", defaultValue: "\(symbol) stop is \(state).", bundle: L10n.bundle)
    }
    static func strategy(_ name: String, _ version: String) -> LocalizedStringResource {
      LocalizedStringResource("home.strategy", defaultValue: "Strategy \(name) v\(version).", bundle: L10n.bundle)
    }
    static func gateClosed(_ cause: String) -> LocalizedStringResource {
      LocalizedStringResource("home.gateClosed", defaultValue: "Trading gate closed: \(cause).", bundle: L10n.bundle)
    }
    static func since(_ time: String) -> LocalizedStringResource {
      LocalizedStringResource("home.since", defaultValue: "since \(time)", bundle: L10n.bundle)
    }
    static func stopVerified(_ price: String) -> LocalizedStringResource {
      LocalizedStringResource("home.stopVerified", defaultValue: "stop ✓ \(price)", bundle: L10n.bundle)
    }
    static var stopPending: LocalizedStringResource {
      LocalizedStringResource("home.stopPending", defaultValue: "stop pending", bundle: L10n.bundle)
    }
    static var noStop: LocalizedStringResource {
      LocalizedStringResource("home.noStop", defaultValue: "NO STOP", bundle: L10n.bundle)
    }
    static var stopUnknown: LocalizedStringResource {
      LocalizedStringResource("home.stopUnknown", defaultValue: "stop unknown", bundle: L10n.bundle)
    }
    static var inputs: LocalizedStringResource {
      LocalizedStringResource("home.inputs", defaultValue: "Bot inputs", bundle: L10n.bundle)
    }
    static var broker: LocalizedStringResource {
      LocalizedStringResource("home.broker", defaultValue: "broker", bundle: L10n.bundle)
    }
    static var quotes: LocalizedStringResource {
      LocalizedStringResource("home.quotes", defaultValue: "quotes", bundle: L10n.bundle)
    }
    static var gate: LocalizedStringResource {
      LocalizedStringResource("home.gate", defaultValue: "gate", bundle: L10n.bundle)
    }
    static var entries: LocalizedStringResource {
      LocalizedStringResource("home.entries", defaultValue: "entries", bundle: L10n.bundle)
    }
    static var gateOpen: LocalizedStringResource {
      LocalizedStringResource("home.gateOpen", defaultValue: "open", bundle: L10n.bundle)
    }
    static var gateShut: LocalizedStringResource {
      LocalizedStringResource("home.gateShut", defaultValue: "closed", bundle: L10n.bundle)
    }
    static var entriesAllowed: LocalizedStringResource {
      LocalizedStringResource("home.entriesAllowed", defaultValue: "allowed", bundle: L10n.bundle)
    }
    static var entriesBlocked: LocalizedStringResource {
      LocalizedStringResource("home.entriesBlocked", defaultValue: "blocked", bundle: L10n.bundle)
    }
  }

  enum Positions {
    static func slots(_ used: Int, _ limit: Int) -> LocalizedStringResource {
      LocalizedStringResource("positions.slots", defaultValue: "\(used) of \(limit) slots", bundle: L10n.bundle)
    }
    static var freeSlot: LocalizedStringResource {
      LocalizedStringResource("positions.freeSlot", defaultValue: "free", bundle: L10n.bundle)
    }
    static var none: LocalizedStringResource {
      LocalizedStringResource("positions.none", defaultValue: "No open position", bundle: L10n.bundle)
    }
    static var watching: LocalizedStringResource {
      LocalizedStringResource("positions.watching",
        defaultValue: "Entries are allowed; the bot is watching for signals.",
        bundle: L10n.bundle)
    }
    static var protected: LocalizedStringResource {
      LocalizedStringResource("positions.protected", defaultValue: "protected", bundle: L10n.bundle)
    }
    static func shares(_ quantity: String, _ price: String, _ time: String) -> LocalizedStringResource {
      LocalizedStringResource("positions.shares",
        defaultValue: "\(quantity) shares @ \(price) · \(time)",
        bundle: L10n.bundle)
    }
    static var maxLoss: LocalizedStringResource {
      LocalizedStringResource("positions.maxLoss", defaultValue: "max loss", bundle: L10n.bundle)
    }
    static var stop: LocalizedStringResource {
      LocalizedStringResource("positions.stop", defaultValue: "stop", bundle: L10n.bundle)
    }
    static var toStop: LocalizedStringResource {
      LocalizedStringResource("positions.toStop", defaultValue: "to stop", bundle: L10n.bundle)
    }
    static func flattenEllipsis(_ symbol: String) -> LocalizedStringResource {
      LocalizedStringResource("positions.flattenEllipsis", defaultValue: "Flatten \(symbol)…", bundle: L10n.bundle)
    }
    static func closeNow(_ symbol: String) -> LocalizedStringResource {
      LocalizedStringResource("positions.closeNow", defaultValue: "Close \(symbol) now?", bundle: L10n.bundle)
    }
    static func flatten(_ symbol: String) -> LocalizedStringResource {
      LocalizedStringResource("positions.flatten", defaultValue: "Flatten \(symbol)", bundle: L10n.bundle)
    }
    static var flattenMessage: LocalizedStringResource {
      LocalizedStringResource("positions.flattenMessage",
        defaultValue: "The bot cancels the stop, re-reads the quantity and sells at market through the normal exit. Flatten closes every position the bot holds; positions not opened by the bot are not touched.",
        bundle: L10n.bundle)
    }
    static var riskBand: LocalizedStringResource {
      LocalizedStringResource("positions.riskBand", defaultValue: "Risk band", bundle: L10n.bundle)
    }
    static var priceLineLater: LocalizedStringResource {
      LocalizedStringResource("positions.priceLineLater",
        defaultValue: "price line comes with chart data",
        bundle: L10n.bundle)
    }
    static func entryLevel(_ price: String) -> LocalizedStringResource {
      LocalizedStringResource("positions.entryLevel", defaultValue: "entry \(price)", bundle: L10n.bundle)
    }
    static func stopLevel(_ price: String) -> LocalizedStringResource {
      LocalizedStringResource("positions.stopLevel", defaultValue: "broker stop \(price)", bundle: L10n.bundle)
    }
    static func levels(_ entry: String, _ stop: String) -> LocalizedStringResource {
      LocalizedStringResource("positions.levels", defaultValue: "Entry \(entry), stop \(stop)", bundle: L10n.bundle)
    }
    static var chain: LocalizedStringResource {
      LocalizedStringResource("positions.chain", defaultValue: "Protection chain", bundle: L10n.bundle)
    }
    static func filled(_ quantity: String, _ price: String) -> LocalizedStringResource {
      LocalizedStringResource("positions.filled", defaultValue: "Filled \(quantity) @ \(price)", bundle: L10n.bundle)
    }
    static func stopSent(_ price: String) -> LocalizedStringResource {
      LocalizedStringResource("positions.stopSent", defaultValue: "Stop \(price) sent once", bundle: L10n.bundle)
    }
    static var stopWorking: LocalizedStringResource {
      LocalizedStringResource("positions.stopWorking", defaultValue: "Stop working at broker", bundle: L10n.bundle)
    }
  }

  enum Risk {
    static var title: LocalizedStringResource {
      LocalizedStringResource("risk.title", defaultValue: "Risk", bundle: L10n.bundle)
    }
    static var room: LocalizedStringResource {
      LocalizedStringResource("risk.room", defaultValue: "Daily loss room", bundle: L10n.bundle)
    }
    static var left: LocalizedStringResource {
      LocalizedStringResource("risk.left", defaultValue: "left", bundle: L10n.bundle)
    }
    static var limit: LocalizedStringResource {
      LocalizedStringResource("risk.limit", defaultValue: "Daily loss limit", bundle: L10n.bundle)
    }
    static var realizedLoss: LocalizedStringResource {
      LocalizedStringResource("risk.realizedLoss", defaultValue: "Realized loss", bundle: L10n.bundle)
    }
    static var reservations: LocalizedStringResource {
      LocalizedStringResource("risk.reservations", defaultValue: "Reserved by open trades", bundle: L10n.bundle)
    }
    static var resultToday: LocalizedStringResource {
      LocalizedStringResource("risk.resultToday", defaultValue: "Net result today", bundle: L10n.bundle)
    }
    static func roomNote(_ amount: String) -> LocalizedStringResource {
      LocalizedStringResource("risk.roomNote",
        defaultValue: "The limit counts the net day result: profits offset losses. Open trades reserve their planned loss. Below \(amount) of room the bot opens nothing new.",
        bundle: L10n.bundle)
    }
    static var entries: LocalizedStringResource {
      LocalizedStringResource("risk.entries", defaultValue: "New entries", bundle: L10n.bundle)
    }
    static var allowed: LocalizedStringResource {
      LocalizedStringResource("risk.allowed", defaultValue: "Allowed", bundle: L10n.bundle)
    }
    static var blocked: LocalizedStringResource {
      LocalizedStringResource("risk.blocked", defaultValue: "Blocked", bundle: L10n.bundle)
    }
    static var pausedByYou: LocalizedStringResource {
      LocalizedStringResource("risk.pausedByYou", defaultValue: "Operator pause", bundle: L10n.bundle)
    }
    static var tradingGate: LocalizedStringResource {
      LocalizedStringResource("risk.tradingGate", defaultValue: "Trading gate", bundle: L10n.bundle)
    }
    static var gateOpen: LocalizedStringResource {
      LocalizedStringResource("risk.gateOpen", defaultValue: "open", bundle: L10n.bundle)
    }
    static var gateClosed: LocalizedStringResource {
      LocalizedStringResource("risk.gateClosed", defaultValue: "closed", bundle: L10n.bundle)
    }
    static var yes: LocalizedStringResource {
      LocalizedStringResource("risk.yes", defaultValue: "yes", bundle: L10n.bundle)
    }
    static var no: LocalizedStringResource {
      LocalizedStringResource("risk.no", defaultValue: "no", bundle: L10n.bundle)
    }
    static var fences: LocalizedStringResource {
      LocalizedStringResource("risk.fences", defaultValue: "Fences", bundle: L10n.bundle)
    }
    static var noFences: LocalizedStringResource {
      LocalizedStringResource("risk.noFences", defaultValue: "No fences: the bot raised no blocks.", bundle: L10n.bundle)
    }
    static func since(_ time: String) -> LocalizedStringResource {
      LocalizedStringResource("risk.since", defaultValue: "since \(time)", bundle: L10n.bundle)
    }
    static var limits: LocalizedStringResource {
      LocalizedStringResource("risk.limits", defaultValue: "Limits", bundle: L10n.bundle)
    }
    static var plannedLoss: LocalizedStringResource {
      LocalizedStringResource("risk.plannedLoss", defaultValue: "Planned loss per trade", bundle: L10n.bundle)
    }
    static var notionalCap: LocalizedStringResource {
      LocalizedStringResource("risk.notionalCap", defaultValue: "Position size cap", bundle: L10n.bundle)
    }
    static var minRoom: LocalizedStringResource {
      LocalizedStringResource("risk.minRoom", defaultValue: "No entries below room", bundle: L10n.bundle)
    }
    static var openPositions: LocalizedStringResource {
      LocalizedStringResource("risk.openPositions", defaultValue: "Open positions at most", bundle: L10n.bundle)
    }
    static var quoteAge: LocalizedStringResource {
      LocalizedStringResource("risk.quoteAge", defaultValue: "Oldest usable quote", bundle: L10n.bundle)
    }
    static func seconds(_ value: String) -> LocalizedStringResource {
      LocalizedStringResource("risk.seconds", defaultValue: "\(value) s", bundle: L10n.bundle)
    }
    static var settingsFailed: LocalizedStringResource {
      LocalizedStringResource("risk.settingsFailed", defaultValue: "Couldn't read the bot's settings", bundle: L10n.bundle)
    }
    static var session: LocalizedStringResource {
      LocalizedStringResource("risk.session", defaultValue: "Session · New York", bundle: L10n.bundle)
    }
    static var lastEntry: LocalizedStringResource {
      LocalizedStringResource("risk.lastEntry", defaultValue: "Last entry", bundle: L10n.bundle)
    }
    static var flatten: LocalizedStringResource {
      LocalizedStringResource("risk.flatten", defaultValue: "Close everything", bundle: L10n.bundle)
    }
    static var halfDays: LocalizedStringResource {
      LocalizedStringResource("risk.halfDays", defaultValue: "Half days", bundle: L10n.bundle)
    }
    static func beforeClose(_ minutes: Int) -> LocalizedStringResource {
      LocalizedStringResource("risk.beforeClose", defaultValue: "\(minutes) min before close", bundle: L10n.bundle)
    }
  }

  enum Activity {
    static var calendar: LocalizedStringResource {
      LocalizedStringResource("activity.calendar", defaultValue: "Calendar", bundle: L10n.bundle)
    }
    static func pastDay(_ day: String) -> LocalizedStringResource {
      LocalizedStringResource("activity.pastDay", defaultValue: "\(day) · read-only", bundle: L10n.bundle)
    }
    static var backToToday: LocalizedStringResource {
      LocalizedStringResource("activity.backToToday", defaultValue: "Today", bundle: L10n.bundle)
    }
    static var previousMonth: LocalizedStringResource {
      LocalizedStringResource("activity.previousMonth", defaultValue: "Previous month", bundle: L10n.bundle)
    }
    static var nextMonth: LocalizedStringResource {
      LocalizedStringResource("activity.nextMonth", defaultValue: "Next month", bundle: L10n.bundle)
    }
    static var noTradesThatDay: LocalizedStringResource {
      LocalizedStringResource("activity.noTradesThatDay", defaultValue: "No trades that day", bundle: L10n.bundle)
    }
    static var noTradesThatDayBody: LocalizedStringResource {
      LocalizedStringResource("activity.noTradesThatDayBody",
        defaultValue: "The bot closed no trades on this day.",
        bundle: L10n.bundle)
    }
    static var pastJournalTitle: LocalizedStringResource {
      LocalizedStringResource("activity.pastJournalTitle", defaultValue: "Journal of past days", bundle: L10n.bundle)
    }
    static var pastJournalBody: LocalizedStringResource {
      LocalizedStringResource("activity.pastJournalBody",
        defaultValue: "A past day's journal appears here once the bot's API can replay a day.",
        bundle: L10n.bundle)
    }
    static var loadingDay: LocalizedStringResource {
      LocalizedStringResource("activity.loadingDay", defaultValue: "Loading the day…", bundle: L10n.bundle)
    }
    static var dayFailed: LocalizedStringResource {
      LocalizedStringResource("activity.dayFailed", defaultValue: "Couldn't load the day", bundle: L10n.bundle)
    }
    static var retry: LocalizedStringResource {
      LocalizedStringResource("activity.retry", defaultValue: "Try Again", bundle: L10n.bundle)
    }
    static var daysFailed: LocalizedStringResource {
      LocalizedStringResource("activity.daysFailed", defaultValue: "Couldn't list the recorded days", bundle: L10n.bundle)
    }
    static var noRecords: LocalizedStringResource {
      LocalizedStringResource("activity.noRecords", defaultValue: "no records", bundle: L10n.bundle)
    }
    static func pastCounts(_ closed: Int, _ wins: Int, _ losses: Int) -> LocalizedStringResource {
      LocalizedStringResource("activity.pastCounts", defaultValue: "\(closed) closed · \(wins) W · \(losses) L",
        bundle: L10n.bundle)
    }
    static var trades: LocalizedStringResource {
      LocalizedStringResource("activity.trades", defaultValue: "Trades", bundle: L10n.bundle)
    }
    static var notTaken: LocalizedStringResource {
      LocalizedStringResource("activity.notTaken", defaultValue: "Not taken", bundle: L10n.bundle)
    }
    static var journal: LocalizedStringResource {
      LocalizedStringResource("activity.journal", defaultValue: "Journal", bundle: L10n.bundle)
    }
    static var show: LocalizedStringResource {
      LocalizedStringResource("activity.show", defaultValue: "Show", bundle: L10n.bundle)
    }
    static func counts(_ closed: Int, _ wins: Int, _ losses: Int, _ open: Int) -> LocalizedStringResource {
      LocalizedStringResource("activity.counts",
        defaultValue: "\(closed) closed · \(wins) W · \(losses) L · \(open) open",
        bundle: L10n.bundle)
    }
    static func openSince(_ time: String) -> LocalizedStringResource {
      LocalizedStringResource("activity.openSince", defaultValue: "open \(time)", bundle: L10n.bundle)
    }
    static var openTag: LocalizedStringResource {
      LocalizedStringResource("activity.openTag", defaultValue: "OPEN", bundle: L10n.bundle)
    }
    static func stopDetail(_ price: String, _ state: String) -> LocalizedStringResource {
      LocalizedStringResource("activity.stopDetail", defaultValue: "stop \(price) · \(state)", bundle: L10n.bundle)
    }
    static var noTrades: LocalizedStringResource {
      LocalizedStringResource("activity.noTrades", defaultValue: "No trades yet today", bundle: L10n.bundle)
    }
    static var noTradesBody: LocalizedStringResource {
      LocalizedStringResource("activity.noTradesBody",
        defaultValue: "Closed trades appear here with their result.",
        bundle: L10n.bundle)
    }
    static var notTakenTitle: LocalizedStringResource {
      LocalizedStringResource("activity.notTakenTitle", defaultValue: "Signals not taken", bundle: L10n.bundle)
    }
    static var notTakenBody: LocalizedStringResource {
      LocalizedStringResource("activity.notTakenBody",
        defaultValue: "Refused signals with their cause and a what-if result appear here once the bot's API publishes them.",
        bundle: L10n.bundle)
    }
    static var nothingYet: LocalizedStringResource {
      LocalizedStringResource("activity.nothingYet", defaultValue: "Nothing recorded yet today.", bundle: L10n.bundle)
    }
  }

  enum Lab {
    static var title: LocalizedStringResource {
      LocalizedStringResource("lab.title", defaultValue: "Strategy lab", bundle: L10n.bundle)
    }
    static var active: LocalizedStringResource {
      LocalizedStringResource("lab.active", defaultValue: "Active strategy", bundle: L10n.bundle)
    }
    static var trades: LocalizedStringResource {
      LocalizedStringResource("lab.trades", defaultValue: "trades", bundle: L10n.bundle)
    }
    static var observers: LocalizedStringResource {
      LocalizedStringResource("lab.observers", defaultValue: "Observers and replays", bundle: L10n.bundle)
    }
    static var observersBody: LocalizedStringResource {
      LocalizedStringResource("lab.observersBody",
        defaultValue: "How each observer version would have traded today, replays of past days and why signals were refused appear here once the bot's API publishes them. Approving a new version stays on the Mac.",
        bundle: L10n.bundle)
    }
  }

  enum Pair {
    static var title: LocalizedStringResource {
      LocalizedStringResource("pair.title", defaultValue: "Pair with Mac", bundle: L10n.bundle)
    }
    static var start: LocalizedStringResource {
      LocalizedStringResource("pair.start", defaultValue: "Pair with Mac…", bundle: L10n.bundle)
    }
    static var pair: LocalizedStringResource {
      LocalizedStringResource("pair.pair", defaultValue: "Pair", bundle: L10n.bundle)
    }
    static var forget: LocalizedStringResource {
      LocalizedStringResource("pair.forget", defaultValue: "Forget Pairing", bundle: L10n.bundle)
    }
    static var forgetTitle: LocalizedStringResource {
      LocalizedStringResource("pair.forgetTitle", defaultValue: "Forget the pairing?", bundle: L10n.bundle)
    }
    static var forgetMessage: LocalizedStringResource {
      LocalizedStringResource("pair.forgetMessage",
        defaultValue: "The phone deletes its token and can no longer reach the bot remotely until you pair again.",
        bundle: L10n.bundle)
    }
    static func ask(_ host: String) -> LocalizedStringResource {
      LocalizedStringResource("pair.ask", defaultValue: "Pair with \(host)?", bundle: L10n.bundle)
    }
    static var askMessage: LocalizedStringResource {
      LocalizedStringResource("pair.askMessage",
        defaultValue: "The phone will read the bot's status from this address and can send commands. Any earlier pairing is replaced.",
        bundle: L10n.bundle)
    }
    static var thisMac: LocalizedStringResource {
      LocalizedStringResource("pair.thisMac", defaultValue: "this Mac", bundle: L10n.bundle)
    }
    static func paired(_ host: String) -> LocalizedStringResource {
      LocalizedStringResource("pair.paired", defaultValue: "Paired with \(host).", bundle: L10n.bundle)
    }
    static var notALink: LocalizedStringResource {
      LocalizedStringResource("pair.notALink",
        defaultValue: "That link is not an Aperture pairing link.",
        bundle: L10n.bundle)
    }
    static var notSaved: LocalizedStringResource {
      LocalizedStringResource("pair.notSaved",
        defaultValue: "Not paired: the phone could not keep the token in its Keychain.",
        bundle: L10n.bundle)
    }
    static var invalid: LocalizedStringResource {
      LocalizedStringResource("pair.invalid",
        defaultValue: "This is not a pairing link.",
        bundle: L10n.bundle)
    }
    static var prompt: LocalizedStringResource {
      LocalizedStringResource("pair.prompt", defaultValue: "aperture://pair?…", bundle: L10n.bundle)
    }
    static var sheetFooter: LocalizedStringResource {
      LocalizedStringResource("pair.sheetFooter",
        defaultValue: "On the Mac run `python -m aperture.api --config config/bot.toml pair`, then AirDrop the pairing file it names to this phone and paste the link here.",
        bundle: L10n.bundle)
    }
    static var mac: LocalizedStringResource {
      LocalizedStringResource("pair.mac", defaultValue: "Mac", bundle: L10n.bundle)
    }
    static var address: LocalizedStringResource {
      LocalizedStringResource("pair.address", defaultValue: "Address", bundle: L10n.bundle)
    }
    static var notPaired: LocalizedStringResource {
      LocalizedStringResource("pair.notPaired", defaultValue: "Not paired", bundle: L10n.bundle)
    }
  }

  enum Settings {
    static var title: LocalizedStringResource {
      LocalizedStringResource("settings.title", defaultValue: "Settings", bundle: L10n.bundle)
    }
    static var saveAddress: LocalizedStringResource {
      LocalizedStringResource("settings.saveAddress", defaultValue: "Save Address", bundle: L10n.bundle)
    }
    static var status: LocalizedStringResource {
      LocalizedStringResource("settings.status", defaultValue: "Status", bundle: L10n.bundle)
    }
    static var botOnMac: LocalizedStringResource {
      LocalizedStringResource("settings.botOnMac", defaultValue: "Bot on your Mac", bundle: L10n.bundle)
    }
    static var addressFooter: LocalizedStringResource {
      LocalizedStringResource("settings.addressFooter",
        defaultValue: "In the Simulator the Mac's own address works. On the phone, pair with the link that `python -m aperture.api pair` leaves on the Mac; it reaches the Mac through Tailscale over HTTPS. The token stays in this phone's Keychain and goes only to the paired address.",
        bundle: L10n.bundle)
    }
    static var bot: LocalizedStringResource {
      LocalizedStringResource("settings.bot", defaultValue: "Bot", bundle: L10n.bundle)
    }
    static var state: LocalizedStringResource {
      LocalizedStringResource("settings.state", defaultValue: "State", bundle: L10n.bundle)
    }
    static var environment: LocalizedStringResource {
      LocalizedStringResource("settings.environment", defaultValue: "Environment", bundle: L10n.bundle)
    }
    static var gate: LocalizedStringResource {
      LocalizedStringResource("settings.gate", defaultValue: "Trading gate", bundle: L10n.bundle)
    }
    static var gateOpen: LocalizedStringResource {
      LocalizedStringResource("settings.gateOpen", defaultValue: "open", bundle: L10n.bundle)
    }
    static var gateClosed: LocalizedStringResource {
      LocalizedStringResource("settings.gateClosed", defaultValue: "closed", bundle: L10n.bundle)
    }
    static var strategy: LocalizedStringResource {
      LocalizedStringResource("settings.strategy", defaultValue: "Strategy", bundle: L10n.bundle)
    }
    static var run: LocalizedStringResource {
      LocalizedStringResource("settings.run", defaultValue: "Run", bundle: L10n.bundle)
    }
    static var lockScreen: LocalizedStringResource {
      LocalizedStringResource("settings.lockScreen", defaultValue: "Lock-screen alerts", bundle: L10n.bundle)
    }
    static var notYet: LocalizedStringResource {
      LocalizedStringResource("settings.notYet", defaultValue: "Not yet", bundle: L10n.bundle)
    }
    static var notifications: LocalizedStringResource {
      LocalizedStringResource("settings.notifications", defaultValue: "Notifications", bundle: L10n.bundle)
    }
    static var notificationsFooter: LocalizedStringResource {
      LocalizedStringResource("settings.notificationsFooter",
        defaultValue: "Alerts for stops, fills, paused entries and broker mismatches arrive when push notifications are set up. Environment and limits are set in the bot's config on the Mac; the phone only shows them.",
        bundle: L10n.bundle)
    }
    static var about: LocalizedStringResource {
      LocalizedStringResource("settings.about", defaultValue: "About", bundle: L10n.bundle)
    }
    static var app: LocalizedStringResource {
      LocalizedStringResource("settings.app", defaultValue: "App", bundle: L10n.bundle)
    }
    static var contract: LocalizedStringResource {
      LocalizedStringResource("settings.contract", defaultValue: "API contract", bundle: L10n.bundle)
    }
    static func contractVersion(_ version: Int) -> LocalizedStringResource {
      LocalizedStringResource("settings.contractVersion", defaultValue: "v\(version)", bundle: L10n.bundle)
    }
    static var noAddress: LocalizedStringResource {
      LocalizedStringResource("settings.noAddress", defaultValue: "No address", bundle: L10n.bundle)
    }
    static var notReachable: LocalizedStringResource {
      LocalizedStringResource("settings.notReachable", defaultValue: "Not reachable", bundle: L10n.bundle)
    }
    static var connecting: LocalizedStringResource {
      LocalizedStringResource("settings.connecting", defaultValue: "Connecting…", bundle: L10n.bundle)
    }
    static var notCurrent: LocalizedStringResource {
      LocalizedStringResource("settings.notCurrent", defaultValue: "Reached, status not current", bundle: L10n.bundle)
    }
    static var connected: LocalizedStringResource {
      LocalizedStringResource("settings.connected", defaultValue: "Connected", bundle: L10n.bundle)
    }
  }
}

/// Every text of the Chart tab. Translations live in Chart/chart.xcstrings.
enum ChartText {
  static let title = LocalizedStringResource("chart.title", defaultValue: "Chart", table: ChartText.table)
  static let loading = LocalizedStringResource("chart.loading",
    defaultValue: "Loading the chart…", table: ChartText.table)
  static let noDaysTitle = LocalizedStringResource("chart.noDays.title",
    defaultValue: "No recorded days yet", table: ChartText.table)
  static let noDaysBody = LocalizedStringResource("chart.noDays.body",
    defaultValue: "The bot records bars and trades while it runs. Days appear here once there is something to show.",
    table: ChartText.table)
  static let noBarsTitle = LocalizedStringResource("chart.noBars.title",
    defaultValue: "No captured bars", table: ChartText.table)
  static let noBarsBody = LocalizedStringResource("chart.noBars.body",
    defaultValue: "The bot captured no bars on this day.", table: ChartText.table)
  static let failedTitle = LocalizedStringResource("chart.failed.title",
    defaultValue: "Could not load the chart", table: ChartText.table)
  static let retry = LocalizedStringResource("chart.retry", defaultValue: "Try Again", table: ChartText.table)
  static let previousDay = LocalizedStringResource("chart.previousDay",
    defaultValue: "Previous day", table: ChartText.table)
  static let nextDay = LocalizedStringResource("chart.nextDay", defaultValue: "Next day", table: ChartText.table)
  static let day = LocalizedStringResource("chart.day", defaultValue: "Day", table: ChartText.table)
  static let live = LocalizedStringResource("chart.live", defaultValue: "Live", table: ChartText.table)
  static let timeframe = LocalizedStringResource("chart.timeframe", defaultValue: "Timeframe", table: ChartText.table)
  static let m1 = LocalizedStringResource("chart.timeframe.m1", defaultValue: "M1", table: ChartText.table)
  static let m5 = LocalizedStringResource("chart.timeframe.m5", defaultValue: "M5", table: ChartText.table)
  static let m15 = LocalizedStringResource("chart.timeframe.m15", defaultValue: "M15", table: ChartText.table)
  static let vwap = LocalizedStringResource("chart.indicator.vwap", defaultValue: "VWAP", table: ChartText.table)
  static let volume = LocalizedStringResource("chart.indicator.volume",
    defaultValue: "Volume", table: ChartText.table)
  static let zoomIn = LocalizedStringResource("chart.zoomIn", defaultValue: "Zoom in", table: ChartText.table)
  static let zoomOut = LocalizedStringResource("chart.zoomOut", defaultValue: "Zoom out", table: ChartText.table)
  static let hint = LocalizedStringResource("chart.hint",
    defaultValue: "Touch and hold the chart to read a candle.", table: ChartText.table)
  static let trades = LocalizedStringResource("chart.trades", defaultValue: "Trades", table: ChartText.table)
  static let noTrades = LocalizedStringResource("chart.noTrades",
    defaultValue: "No closed trades on this symbol this day.", table: ChartText.table)
  static let entry = LocalizedStringResource("chart.entry", defaultValue: "Entry", table: ChartText.table)
  static let exit = LocalizedStringResource("chart.exit", defaultValue: "Exit", table: ChartText.table)
  static let stop = LocalizedStringResource("chart.stop", defaultValue: "Stop", table: ChartText.table)
  static let axisTime = LocalizedStringResource("chart.axis.time", defaultValue: "Time", table: ChartText.table)
  static let axisPrice = LocalizedStringResource("chart.axis.price", defaultValue: "Price", table: ChartText.table)
  static let axisLine = LocalizedStringResource("chart.axis.line", defaultValue: "Line", table: ChartText.table)

  /// The fast or slow EMA toggle, with its period in bars.
  static func ema(_ period: Int) -> LocalizedStringResource {
    LocalizedStringResource("chart.indicator.ema", defaultValue: "EMA \(period)", table: ChartText.table)
  }

  /// The ATR pane toggle and label, with its period in bars.
  static func atr(_ period: Int) -> LocalizedStringResource {
    LocalizedStringResource("chart.indicator.atr", defaultValue: "ATR \(period)", table: ChartText.table)
  }

  /// The crosshair readout of one candle: open, high, low, close, volume (already formatted).
  static func readout(_ open: String, _ high: String, _ low: String, _ close: String, _ volume: String)
    -> LocalizedStringResource {
    LocalizedStringResource("chart.readout",
      defaultValue: "O \(open)  H \(high)  L \(low)  C \(close)  V \(volume)", table: ChartText.table)
  }
}
