import Foundation
import TickrKit

/// Every text of the iOS app that a person reads, in English, with its Russian translation in
/// Localizable.xcstrings beside this file (docs/design-system.md, rule 2). The Chart tab's texts are
/// `ChartText` at the end of this file.
/// Views pass these to `Text` and the components, or read them with `String(localized:)`. Keys are
/// `<namespace>.<name>`.
enum L10n {
  /// The app bundle, where Xcode compiles the String Catalog.
  static var bundle: LocalizedStringResource.BundleDescription { .main }

  enum App {
    static var name: LocalizedStringResource {
      LocalizedStringResource("app.name", defaultValue: "Tickr", bundle: L10n.bundle)
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
    /// A strategy version on its own, as on Home's badge: "v1".
    static func version(_ version: String) -> LocalizedStringResource {
      LocalizedStringResource("common.version", defaultValue: "v\(version)", bundle: L10n.bundle)
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
    static var stopTitle: LocalizedStringResource {
      LocalizedStringResource("control.stopTitle",
        defaultValue: "Stop the bot?",
        bundle: L10n.bundle)
    }
    static var stopWarning: LocalizedStringResource {
      LocalizedStringResource("control.stopWarning",
        // swiftlint:disable:next line_length
        defaultValue: "The bot ends gracefully: entry orders are cancelled and broker stops stay. Open positions stay open under DAY stops, and nothing closes them at the session's end. The phone cannot start the bot again: start it on the Mac.",
        bundle: L10n.bundle)
    }
    static var emergencyTitle: LocalizedStringResource {
      LocalizedStringResource("control.emergencyTitle",
        defaultValue: "Emergency stop?",
        bundle: L10n.bundle)
    }
    static var emergencyWarning: LocalizedStringResource {
      LocalizedStringResource("control.emergencyWarning",
        // swiftlint:disable:next line_length
        defaultValue: "The bot pauses entries, cancels its entry orders and sells every position it holds at market through the normal exit. Each stop is cancelled only right before its sale. Entries stay paused until you resume them.",
        bundle: L10n.bundle)
    }
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
    static var stopBot: LocalizedStringResource {
      LocalizedStringResource("control.stopBot", defaultValue: "Stop the Bot", bundle: L10n.bundle)
    }
    static var emergency: LocalizedStringResource {
      LocalizedStringResource("control.emergency", defaultValue: "Emergency: Pause, Cancel, Flatten", bundle: L10n.bundle)
    }
    /// A command confirmation's message with where the command goes: the demo day.
    static func toDemo(_ message: String) -> LocalizedStringResource {
      LocalizedStringResource("control.toDemo", defaultValue: "\(message)\n\nSent to: the DEMO day, not the bot.",
        bundle: L10n.bundle)
    }
    /// A command confirmation's message with where the command goes: the real bot.
    static func toBot(_ message: String) -> LocalizedStringResource {
      LocalizedStringResource("control.toBot", defaultValue: "\(message)\n\nSent to: the bot.", bundle: L10n.bundle)
    }
    static var short: LocalizedStringResource {
      LocalizedStringResource("control.short",
        // swiftlint:disable:next line_length
        defaultValue: "Pausing and cancelling never touch broker stops; flattening cancels each stop only right before its sale. Each command is sent once.",
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
    /// The latest event's New York time on Home: "14:06:09 ET".
    static func clockET(_ time: String) -> LocalizedStringResource {
      LocalizedStringResource("home.clockET", defaultValue: "\(time) ET", bundle: L10n.bundle)
    }
    static var previousDay: LocalizedStringResource {
      LocalizedStringResource("home.previousDay", defaultValue: "Previous trading day", bundle: L10n.bundle)
    }
    static var nextDay: LocalizedStringResource {
      LocalizedStringResource("home.nextDay", defaultValue: "Next trading day", bundle: L10n.bundle)
    }
    static var backToToday: LocalizedStringResource {
      LocalizedStringResource("home.backToToday", defaultValue: "Today", bundle: L10n.bundle)
    }
    static var demoTitle: LocalizedStringResource {
      LocalizedStringResource("home.demoTitle", defaultValue: "Demo day: commands go to the demo, not the bot",
        bundle: L10n.bundle)
    }
    static var demoDetail: LocalizedStringResource {
      LocalizedStringResource("home.demoDetail", defaultValue: "Turn it off in Settings before trading.", bundle: L10n.bundle)
    }
    /// The chip next to the day while the demo day is on.
    static var demoChip: LocalizedStringResource {
      LocalizedStringResource("home.demoChip", defaultValue: "DEMO", bundle: L10n.bundle)
    }
    static var recordedDay: LocalizedStringResource {
      LocalizedStringResource("home.recordedDay", defaultValue: "Recorded day", bundle: L10n.bundle)
    }
    static var cleanDay: LocalizedStringResource {
      LocalizedStringResource("home.cleanDay", defaultValue: "Clean day: records agree with the broker", bundle: L10n.bundle)
    }
    static func notClean(_ first: String, _ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("home.notClean", defaultValue: "Not a clean day (reasons: \(count)): \(first)", bundle: L10n.bundle)
    }
    static func cleanUnknown(_ cause: String) -> LocalizedStringResource {
      LocalizedStringResource("home.cleanUnknown", defaultValue: "Clean day unknown: \(cause)", bundle: L10n.bundle)
    }
    static var recordedNote: LocalizedStringResource {
      LocalizedStringResource("home.recordedNote",
        defaultValue: "Read-only from the bot's records. Commands are off for past days.", bundle: L10n.bundle)
    }
    static func pastDayNote(_ day: String) -> LocalizedStringResource {
      LocalizedStringResource("home.pastDayNote",
        defaultValue: "\(day) is a recorded day. Its trades are on the Activity tab.", bundle: L10n.bundle)
    }
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
        defaultValue: "Day result \(result), wins: \(wins), losses: \(losses)",
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
    static var entriesAllowed: LocalizedStringResource {
      LocalizedStringResource("home.entriesAllowed", defaultValue: "Entries allowed.", bundle: L10n.bundle)
    }
    static var entriesPaused: LocalizedStringResource {
      LocalizedStringResource("home.entriesPaused", defaultValue: "Entries paused by you.", bundle: L10n.bundle)
    }
    /// Entries wait for an expected reason (outside the session, after the last entry time).
    static func entriesNotNow(_ cause: String) -> LocalizedStringResource {
      LocalizedStringResource("home.entriesNotNow", defaultValue: "No entries now: \(cause).", bundle: L10n.bundle)
    }
    static func entriesBlocked(_ cause: String) -> LocalizedStringResource {
      LocalizedStringResource("home.entriesBlocked", defaultValue: "Entries blocked: \(cause).", bundle: L10n.bundle)
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
  }

  enum Flow {
    /// The event line's tag for a signal risk refused: "REFUSED".
    /// VoiceOver label of a stage's refused tray: "2 refused".
    static func refusedCount(_ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("flow.refusedCount", defaultValue: "\(count) refused", bundle: L10n.bundle)
    }
    /// Card title on Home: the stages a setup passes through.
    static var title: LocalizedStringResource {
      LocalizedStringResource("flow.title", defaultValue: "Live flow", bundle: L10n.bundle)
    }
    static var screen: LocalizedStringResource {
      LocalizedStringResource("flow.screen", defaultValue: "screen", bundle: L10n.bundle)
    }
    static var stocks: LocalizedStringResource {
      LocalizedStringResource("flow.stocks", defaultValue: "stocks", bundle: L10n.bundle)
    }
    static var strategy: LocalizedStringResource {
      LocalizedStringResource("flow.strategy", defaultValue: "strategy", bundle: L10n.bundle)
    }
    static var risk: LocalizedStringResource {
      LocalizedStringResource("flow.risk", defaultValue: "risk", bundle: L10n.bundle)
    }
    static var order: LocalizedStringResource {
      LocalizedStringResource("flow.order", defaultValue: "order", bundle: L10n.bundle)
    }
    static var stop: LocalizedStringResource {
      LocalizedStringResource("flow.stop", defaultValue: "stop", bundle: L10n.bundle)
    }
    /// The risk stage when new entries are blocked.
    static var blocked: LocalizedStringResource {
      LocalizedStringResource("flow.blocked", defaultValue: "blocked", bundle: L10n.bundle)
    }
    /// Verified broker stops of all open positions, under the stop stage: "2/3 ✓".
    static func stopsVerified(_ verified: Int, _ total: Int) -> LocalizedStringResource {
      LocalizedStringResource("flow.stopsVerified", defaultValue: "\(verified)/\(total) ✓", bundle: L10n.bundle)
    }
    /// The Stop stage while some stop is not verified: "0/1", without the check mark.
    static func stopsCount(_ verified: Int, _ total: Int) -> LocalizedStringResource {
      LocalizedStringResource("flow.stopsCount", defaultValue: "\(verified)/\(total)", bundle: L10n.bundle)
    }
    /// Symbols at a live-flow stage beyond the dots shown: "+5".
    static func more(_ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("flow.more", defaultValue: "+\(count)", bundle: L10n.bundle)
    }
    /// In place of the slots when the status is stale, failed or from an earlier session.
    static var notCurrent: LocalizedStringResource {
      LocalizedStringResource("flow.notCurrent", defaultValue: "not current", bundle: L10n.bundle)
    }
    /// The quote stream's state under the stages: "quotes fresh".
    static func quotes(_ state: String) -> LocalizedStringResource {
      LocalizedStringResource("flow.quotes", defaultValue: "quotes \(state)", bundle: L10n.bundle)
    }
    /// The bot's last broker read under the stages: "broker read 14:06:02".
    static func brokerRead(_ time: String) -> LocalizedStringResource {
      LocalizedStringResource("flow.brokerRead", defaultValue: "broker read \(time)", bundle: L10n.bundle)
    }
    /// Open positions against the configured limit: "slots 2 of 3".
    static func slots(_ used: Int, _ limit: Int) -> LocalizedStringResource {
      LocalizedStringResource("flow.slots", defaultValue: "slots \(used) of \(limit)", bundle: L10n.bundle)
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
        // swiftlint:disable:next line_length
        defaultValue: "The bot cancels this position's stop, re-reads the quantity and sells at market through the normal exit. Only this symbol closes; the bot's other positions and positions not opened by the bot are not touched.",
        bundle: L10n.bundle)
    }
    static var openChart: LocalizedStringResource {
      LocalizedStringResource("positions.openChart", defaultValue: "open full chart →", bundle: L10n.bundle)
    }
    static var riskBand: LocalizedStringResource {
      LocalizedStringResource("positions.riskBand", defaultValue: "Risk band", bundle: L10n.bundle)
    }
    static var waitingForBars: LocalizedStringResource {
      LocalizedStringResource("positions.waitingForBars", defaultValue: "price line waits for bars", bundle: L10n.bundle)
    }
    static var excursion: LocalizedStringResource {
      LocalizedStringResource("positions.excursion", defaultValue: "MAE / MFE", bundle: L10n.bundle)
    }
    static var reconciled: LocalizedStringResource {
      LocalizedStringResource("positions.reconciled", defaultValue: "Reconciled with broker", bundle: L10n.bundle)
    }
    static func asOf(_ time: String) -> LocalizedStringResource {
      LocalizedStringResource("positions.asOf", defaultValue: "as of \(time)", bundle: L10n.bundle)
    }
    static func last(_ price: String) -> LocalizedStringResource {
      LocalizedStringResource("positions.last", defaultValue: "last \(price)", bundle: L10n.bundle)
    }
    static func lastAndR(_ price: String, _ r: String) -> LocalizedStringResource {
      LocalizedStringResource("positions.lastAndR", defaultValue: "last \(price) · \(r) now", bundle: L10n.bundle)
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
    static var entrySent: LocalizedStringResource {
      LocalizedStringResource("positions.entrySent", defaultValue: "Entry sent once", bundle: L10n.bundle)
    }
    static func entrySends(_ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("positions.entrySends", defaultValue: "sent \(count) times", bundle: L10n.bundle)
    }
    static var entryConfirmedLater: LocalizedStringResource {
      LocalizedStringResource("positions.entryConfirmedLater",
        defaultValue: "unknown at send, confirmed by the broker", bundle: L10n.bundle)
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
        // swiftlint:disable:next line_length
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
    static var notNow: LocalizedStringResource {
      LocalizedStringResource("risk.notNow", defaultValue: "Not now", bundle: L10n.bundle)
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
    static var hintQuantity: LocalizedStringResource {
      LocalizedStringResource("activity.hintQuantity", defaultValue: "Quantity", bundle: L10n.bundle)
    }
    static var hintEntryExit: LocalizedStringResource {
      LocalizedStringResource("activity.hintEntryExit", defaultValue: "Entry → exit", bundle: L10n.bundle)
    }
    static var hintResultR: LocalizedStringResource {
      LocalizedStringResource("activity.hintResultR", defaultValue: "Result in R", bundle: L10n.bundle)
    }
    static var hintStopAfter: LocalizedStringResource {
      LocalizedStringResource("activity.hintStopAfter", defaultValue: "Stop confirmed after the fill", bundle: L10n.bundle)
    }
    static var hintMae: LocalizedStringResource {
      LocalizedStringResource("activity.hintMae", defaultValue: "MAE: worst move against, at least", bundle: L10n.bundle)
    }
    static var hintMfe: LocalizedStringResource {
      LocalizedStringResource("activity.hintMfe", defaultValue: "MFE: best move in favour, at least", bundle: L10n.bundle)
    }
    static var hintWhatIfEntry: LocalizedStringResource {
      LocalizedStringResource("activity.hintWhatIfEntry", defaultValue: "What-if entry", bundle: L10n.bundle)
    }
    static var hintWhatIfStop: LocalizedStringResource {
      LocalizedStringResource("activity.hintWhatIfStop", defaultValue: "What-if stop", bundle: L10n.bundle)
    }
    static var hintWhen: LocalizedStringResource {
      LocalizedStringResource("activity.hintWhen", defaultValue: "When, and how many times", bundle: L10n.bundle)
    }
    static var hintStop: LocalizedStringResource {
      LocalizedStringResource("activity.hintStop", defaultValue: "Broker stop", bundle: L10n.bundle)
    }
    static var hintEntry: LocalizedStringResource {
      LocalizedStringResource("activity.hintEntry", defaultValue: "Entry", bundle: L10n.bundle)
    }
    static var whatIfTag: LocalizedStringResource {
      LocalizedStringResource("activity.whatIfTag", defaultValue: "what-if", bundle: L10n.bundle)
    }
    static var calendar: LocalizedStringResource {
      LocalizedStringResource("activity.calendar", defaultValue: "Calendar", bundle: L10n.bundle)
    }
    static func pastDay(_ day: String) -> LocalizedStringResource {
      LocalizedStringResource("activity.pastDay", defaultValue: "\(day) · read-only", bundle: L10n.bundle)
    }
    static func lastSession(_ day: String) -> LocalizedStringResource {
      LocalizedStringResource("activity.lastSession", defaultValue: "\(day) · last session", bundle: L10n.bundle)
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
    static var notTakenNone: LocalizedStringResource {
      LocalizedStringResource("activity.notTakenNone",
        defaultValue: "Every entry the strategy signalled that day was taken, or it signalled none.",
        bundle: L10n.bundle)
    }
    static var notTakenFailed: LocalizedStringResource {
      LocalizedStringResource("activity.notTakenFailed", defaultValue: "Couldn't read the skipped signals",
        bundle: L10n.bundle)
    }
    /// Signals not taken in a row, for one row.
    static func repeats(_ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("activity.repeats", defaultValue: "×\(count)", bundle: L10n.bundle)
    }
    static var refusedTag: LocalizedStringResource {
      LocalizedStringResource("activity.refusedTag", defaultValue: "REFUSED", bundle: L10n.bundle)
    }
    static var tooLateTag: LocalizedStringResource {
      LocalizedStringResource("activity.tooLateTag", defaultValue: "TOO LATE", bundle: L10n.bundle)
    }
    static func notTakenStale(_ cause: String) -> LocalizedStringResource {
      LocalizedStringResource("activity.notTakenStale", defaultValue: "Last read shown; refresh failed: \(cause)",
        bundle: L10n.bundle)
    }
    static func stopAfter(_ seconds: String) -> LocalizedStringResource {
      LocalizedStringResource("activity.stopAfter", defaultValue: "stop confirmed in \(seconds) s", bundle: L10n.bundle)
    }
    static func excursion(_ mae: String, _ mfe: String) -> LocalizedStringResource {
      LocalizedStringResource("activity.excursion", defaultValue: "MAE \(mae) · MFE \(mfe) (at least)",
        bundle: L10n.bundle)
    }
    /// Leads the prices after a signal: "after 1m +0.12 · 5m −0.30".
    static var after: LocalizedStringResource {
      LocalizedStringResource("activity.after", defaultValue: "after", bundle: L10n.bundle)
    }
    /// Minutes after a signal, short: "5m".
    static func minutesAfter(_ minutes: Int) -> LocalizedStringResource {
      LocalizedStringResource("activity.minutesAfter", defaultValue: "\(minutes)m", bundle: L10n.bundle)
    }
    /// What a skipped signal would have made, from the bot's replay: "would have made +$12.30 · +0.8 R".
    static func wouldHaveMade(_ result: String) -> LocalizedStringResource {
      LocalizedStringResource("activity.wouldHaveMade", defaultValue: "would have made \(result)", bundle: L10n.bundle)
    }
    /// The replay of a skipped signal could not run; the bot's cause follows as sent.
    static func noReplay(_ cause: String) -> LocalizedStringResource {
      LocalizedStringResource("activity.noReplay", defaultValue: "no replay: \(cause)", bundle: L10n.bundle)
    }
    static var replayStop: LocalizedStringResource {
      LocalizedStringResource("activity.replay.stop", defaultValue: "hit the stop", bundle: L10n.bundle)
    }
    static var replayStrategyExit: LocalizedStringResource {
      LocalizedStringResource("activity.replay.strategyExit", defaultValue: "strategy exit", bundle: L10n.bundle)
    }
    static var replayFlatten: LocalizedStringResource {
      LocalizedStringResource("activity.replay.flatten", defaultValue: "flat at close", bundle: L10n.bundle)
    }
    static var replayEndOfData: LocalizedStringResource {
      LocalizedStringResource("activity.replay.endOfData", defaultValue: "still open when data ran out", bundle: L10n.bundle)
    }
    static func whatIf(_ entry: String, _ stop: String) -> LocalizedStringResource {
      LocalizedStringResource("activity.whatIf", defaultValue: "what-if entry \(entry) · stop \(stop)",
        bundle: L10n.bundle)
    }
    static var nothingYet: LocalizedStringResource {
      LocalizedStringResource("activity.nothingYet", defaultValue: "Nothing recorded yet today.", bundle: L10n.bundle)
    }
    /// Button on a closed trade that opens what another version would have done.
    static var anotherHelp: LocalizedStringResource {
      LocalizedStringResource("activity.anotherHelp", defaultValue: "Another strategy on this trade", bundle: L10n.bundle)
    }
    /// Title of the Another strategy sheet.
    static func anotherTitle(_ symbol: String) -> LocalizedStringResource {
      LocalizedStringResource("activity.anotherTitle", defaultValue: "If another version traded \(symbol)", bundle: L10n.bundle)
    }
    /// The bot offers no version to replay.
    static var anotherNoVersions: LocalizedStringResource {
      LocalizedStringResource("activity.anotherNoVersions",
        defaultValue: "No strategy version to replay: the bot lists none.",
        bundle: L10n.bundle)
    }
    /// Row of what the bot did.
    static var anotherBot: LocalizedStringResource {
      LocalizedStringResource("activity.anotherBot", defaultValue: "The bot", bundle: L10n.bundle)
    }
    /// What the sheet's numbers are.
    static var anotherNote: LocalizedStringResource {
      LocalizedStringResource("activity.anotherNote",
        // swiftlint:disable:next line_length
        defaultValue: "Simulated on that day's captured bars with the version's own stop, exit and size, gross before fees. Outside the session only.",
        bundle: L10n.bundle)
    }
    /// One simulated trade: its times and how it ended.
    static func anotherLeg(_ opened: String, _ closed: String, _ exit: String) -> LocalizedStringResource {
      LocalizedStringResource("activity.anotherLeg", defaultValue: "\(opened) → \(closed) · \(exit)", bundle: L10n.bundle)
    }
    /// The version decided no entry that day.
    static var anotherNoEntry: LocalizedStringResource {
      LocalizedStringResource("activity.anotherNoEntry",
        defaultValue: "No entry that day: its rules never said enter.",
        bundle: L10n.bundle)
    }
    /// What became of the version's entries.
    static func anotherSignals(_ filled: Int, _ missed: Int, _ late: Int, _ busy: Int) -> LocalizedStringResource {
      LocalizedStringResource("activity.anotherSignals",
        defaultValue: "Entries: \(filled) filled · \(missed) missed the window · \(late) too late · \(busy) while in a trade",
        bundle: L10n.bundle)
    }
  }

  /// Refusal causes in words (src/tickr/risk/causes.py). A code the app does not know is shown
  /// as the bot wrote it.
  enum Cause {
    /// Title of a refusal whose code this app has no words for; the bot's detail follows it.
    static var other: LocalizedStringResource {
      LocalizedStringResource("cause.other", defaultValue: "Other reason", bundle: L10n.bundle)
    }
    static func until(_ time: String) -> LocalizedStringResource {
      LocalizedStringResource("cause.until", defaultValue: "until \(time)", bundle: L10n.bundle)
    }
    /// What the rule behind `code` is.
    static func title(_ code: RefusalCode) -> LocalizedStringResource {
      switch code {
      case .gateClosed: LocalizedStringResource("cause.gateClosed",
        defaultValue: "Trading gate closed", bundle: L10n.bundle)
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
      case .halfDay: LocalizedStringResource("cause.halfDay",
        defaultValue: "Half day: entries off", bundle: L10n.bundle)
      case .outsideSession: LocalizedStringResource("cause.outsideSession",
        defaultValue: "Outside regular hours", bundle: L10n.bundle)
      case .afterLastEntry: LocalizedStringResource("cause.afterLastEntry",
        defaultValue: "After the last entry time", bundle: L10n.bundle)
      case .ownPosition: LocalizedStringResource("cause.ownPosition",
        defaultValue: "Already holding this symbol", bundle: L10n.bundle)
      case .ownOrder: LocalizedStringResource("cause.ownOrder",
        defaultValue: "An order on this symbol is working", bundle: L10n.bundle)
      case .positionLimit: LocalizedStringResource("cause.positionLimit",
        defaultValue: "All position slots taken", bundle: L10n.bundle)
      case .cooldown: LocalizedStringResource("cause.cooldown",
        defaultValue: "Pause after a loss", bundle: L10n.bundle)
      case .setupInvalidated: LocalizedStringResource("cause.setupInvalidated",
        defaultValue: "Setup no longer valid", bundle: L10n.bundle)
      case .quoteMissing: LocalizedStringResource("cause.quoteMissing",
        defaultValue: "No quote", bundle: L10n.bundle)
      case .quoteStale: LocalizedStringResource("cause.quoteStale",
        defaultValue: "Quote too old", bundle: L10n.bundle)
      case .priceOutside: LocalizedStringResource("cause.priceOutside",
        defaultValue: "Price left the entry window", bundle: L10n.bundle)
      case .quantityBelowOne: LocalizedStringResource("cause.quantityBelowOne",
        defaultValue: "Size under one share", bundle: L10n.bundle)
      case .notionalOverCap: LocalizedStringResource("cause.notionalOverCap",
        defaultValue: "Position value over the cap", bundle: L10n.bundle)
      case .plannedLossOver: LocalizedStringResource("cause.plannedLossOver",
        defaultValue: "Planned loss over the limit", bundle: L10n.bundle)
      case .dailyCeiling: LocalizedStringResource("cause.dailyCeiling",
        defaultValue: "Daily loss limit reached", bundle: L10n.bundle)
      case .entryBudget: LocalizedStringResource("cause.entryBudget",
        defaultValue: "No request budget for the entry", bundle: L10n.bundle)
      case .stopBudget: LocalizedStringResource("cause.stopBudget",
        defaultValue: "No request budget for the stop", bundle: L10n.bundle)
      }
    }
    /// Detail of a pause after a loss: when the losing trade closed and when entries may resume.
    static func cooldownDetail(_ loss: String, _ until: String) -> LocalizedStringResource {
      LocalizedStringResource("cause.cooldownDetail", defaultValue: "loss at \(loss) · no entry before \(until)",
        bundle: L10n.bundle)
    }
  }

  /// What VoiceOver says for states the screen shows only by colour or symbol.
  enum Access {
    static var proven: LocalizedStringResource {
      LocalizedStringResource("access.proven", defaultValue: "proven", bundle: L10n.bundle)
    }
    static var notProven: LocalizedStringResource {
      LocalizedStringResource("access.notProven", defaultValue: "not proven", bundle: L10n.bundle)
    }
    static var passed: LocalizedStringResource {
      LocalizedStringResource("access.passed", defaultValue: "passed", bundle: L10n.bundle)
    }
    static var failed: LocalizedStringResource {
      LocalizedStringResource("access.failed", defaultValue: "failed", bundle: L10n.bundle)
    }
    static var checking: LocalizedStringResource {
      LocalizedStringResource("access.checking", defaultValue: "not checked yet", bundle: L10n.bundle)
    }
  }

  /// The "Watching closely" card (GET /watching).
  enum Watching {
    static var title: LocalizedStringResource {
      LocalizedStringResource("watching.title", defaultValue: "Watching closely", bundle: L10n.bundle)
    }
    static var none: LocalizedStringResource {
      LocalizedStringResource("watching.none", defaultValue: "The strategy is not watching any symbol closely.",
        bundle: L10n.bundle)
    }
    static var closeness: LocalizedStringResource {
      LocalizedStringResource("watching.closeness", defaultValue: "How close the deciding check is to passing",
        bundle: L10n.bundle)
    }
    static func shown(_ shown: Int, _ total: Int) -> LocalizedStringResource {
      LocalizedStringResource("watching.shown", defaultValue: "\(shown) of \(total)", bundle: L10n.bundle)
    }
    static func failed(_ cause: String) -> LocalizedStringResource {
      LocalizedStringResource("watching.failed", defaultValue: "Couldn't read the watched symbols: \(cause)",
        bundle: L10n.bundle)
    }
    static func stale(_ cause: String) -> LocalizedStringResource {
      LocalizedStringResource("watching.stale", defaultValue: "Last read shown; refresh failed: \(cause)",
        bundle: L10n.bundle)
    }
  }

  enum Lab {
    static var noCause: LocalizedStringResource {
      LocalizedStringResource("lab.noCause", defaultValue: "No cause recorded", bundle: L10n.bundle)
    }
    static func noTrades(_ name: String, _ version: String, _ cause: String) -> LocalizedStringResource {
      LocalizedStringResource("lab.noTrades", defaultValue: "\(name) v\(version): no simulated trades (\(cause))",
        bundle: L10n.bundle)
    }
    static var versions: LocalizedStringResource {
      LocalizedStringResource("lab.versions", defaultValue: "Today if each version traded", bundle: L10n.bundle)
    }
    static var noOrders: LocalizedStringResource {
      LocalizedStringResource("lab.noOrders", defaultValue: "observers place no orders", bundle: L10n.bundle)
    }
    static var result: LocalizedStringResource {
      LocalizedStringResource("lab.result", defaultValue: "Result", bundle: L10n.bundle)
    }
    static var time: LocalizedStringResource {
      LocalizedStringResource("lab.time", defaultValue: "Time", bundle: L10n.bundle)
    }
    static var version: LocalizedStringResource {
      LocalizedStringResource("lab.version", defaultValue: "Version", bundle: L10n.bundle)
    }
    static var noClosed: LocalizedStringResource {
      LocalizedStringResource("lab.noClosed", defaultValue: "No version has closed a trade yet.", bundle: L10n.bundle)
    }
    static var observerRole: LocalizedStringResource {
      LocalizedStringResource("lab.observerRole", defaultValue: "observer", bundle: L10n.bundle)
    }
    static var partial: LocalizedStringResource {
      LocalizedStringResource("lab.partial", defaultValue: "incomplete", bundle: L10n.bundle)
    }
    static var refusals: LocalizedStringResource {
      LocalizedStringResource("lab.refusals", defaultValue: "Why signals were refused today", bundle: L10n.bundle)
    }
    static var noRefusals: LocalizedStringResource {
      LocalizedStringResource("lab.noRefusals", defaultValue: "No signal was refused.", bundle: L10n.bundle)
    }
    static func refusalsFailed(_ cause: String) -> LocalizedStringResource {
      LocalizedStringResource("lab.refusalsFailed", defaultValue: "Couldn't read the refused signals: \(cause)",
        bundle: L10n.bundle)
    }
    static var title: LocalizedStringResource {
      LocalizedStringResource("lab.title", defaultValue: "Strategy lab", bundle: L10n.bundle)
    }
    static var active: LocalizedStringResource {
      LocalizedStringResource("lab.active", defaultValue: "Active strategy", bundle: L10n.bundle)
    }
    static var trades: LocalizedStringResource {
      LocalizedStringResource("lab.trades", defaultValue: "trades", bundle: L10n.bundle)
    }
    static var board: LocalizedStringResource {
      LocalizedStringResource("lab.board", defaultValue: "Observers · never trade", bundle: L10n.bundle)
    }
    static var noObservers: LocalizedStringResource {
      LocalizedStringResource("lab.noObservers", defaultValue: "No observers configured.", bundle: L10n.bundle)
    }
    static var noEntries: LocalizedStringResource {
      LocalizedStringResource("lab.noEntries", defaultValue: "would not have entered", bundle: L10n.bundle)
    }
    static var noResult: LocalizedStringResource {
      LocalizedStringResource("lab.noResult", defaultValue: "no simulated P&L", bundle: L10n.bundle)
    }
    /// Replay card title with the number of recent sessions it covers.
    static func replayLast(_ sessions: Int) -> LocalizedStringResource {
      LocalizedStringResource("lab.replayLast", defaultValue: "Replay last \(sessions) days", bundle: L10n.bundle)
    }
    /// Replay card title before the number of sessions is known.
    static var replayRecent: LocalizedStringResource {
      LocalizedStringResource("lab.replayRecent", defaultValue: "Replay recent days", bundle: L10n.bundle)
    }
    /// Button that starts the replay.
    static var replayStart: LocalizedStringResource {
      LocalizedStringResource("lab.replayStart", defaultValue: "Run Replay", bundle: L10n.bundle)
    }
    /// What the replay is.
    static var replayNote: LocalizedStringResource {
      LocalizedStringResource("lab.replayNote",
        defaultValue: "Replays a strategy version over the data fetched on the Mac. Simulated: the bot never reads it.",
        bundle: L10n.bundle)
    }
    /// Replay states on the card's pill.
    static var replayStateIdle: LocalizedStringResource {
      LocalizedStringResource("lab.replayState.idle", defaultValue: "Not run", bundle: L10n.bundle)
    }
    static var replayStateRunning: LocalizedStringResource {
      LocalizedStringResource("lab.replayState.running", defaultValue: "Running", bundle: L10n.bundle)
    }
    static var replayStateDone: LocalizedStringResource {
      LocalizedStringResource("lab.replayState.done", defaultValue: "Done", bundle: L10n.bundle)
    }
    static var replayStateFailed: LocalizedStringResource {
      LocalizedStringResource("lab.replayState.failed", defaultValue: "Failed", bundle: L10n.bundle)
    }
    /// Before any replay.
    static var replayIdle: LocalizedStringResource {
      LocalizedStringResource("lab.replayIdle", defaultValue: "No replay yet.", bundle: L10n.bundle)
    }
    /// The replay could not be read; the reason follows.
    static func replayFailed(_ reason: String) -> LocalizedStringResource {
      LocalizedStringResource("lab.replayFailed", defaultValue: "Replay not read: \(reason)", bundle: L10n.bundle)
    }
    /// Replay running, with its New York start time.
    static func replayRunningSince(_ time: String) -> LocalizedStringResource {
      LocalizedStringResource("lab.replayRunningSince", defaultValue: "Running since \(time)", bundle: L10n.bundle)
    }
    /// Replay figure labels.
    static var replayTrades: LocalizedStringResource {
      LocalizedStringResource("lab.replayTrades", defaultValue: "Trades", bundle: L10n.bundle)
    }
    static var replayWinRate: LocalizedStringResource {
      LocalizedStringResource("lab.replayWinRate", defaultValue: "Win rate", bundle: L10n.bundle)
    }
    static var replayMeanR: LocalizedStringResource {
      LocalizedStringResource("lab.replayMeanR", defaultValue: "Mean R", bundle: L10n.bundle)
    }
    static var replayProfitFactor: LocalizedStringResource {
      LocalizedStringResource("lab.replayProfitFactor", defaultValue: "Profit factor", bundle: L10n.bundle)
    }
    static var replayMaxDrawdown: LocalizedStringResource {
      LocalizedStringResource("lab.replayMaxDrawdown", defaultValue: "Max drawdown", bundle: L10n.bundle)
    }
    /// The result under the bot's own risk limits, in USD.
    static var replayWithLimits: LocalizedStringResource {
      LocalizedStringResource("lab.replayWithLimits", defaultValue: "Bot limits", bundle: L10n.bundle)
    }
    /// A result in R, such as "+0.18 R".
    static func replayR(_ value: String) -> LocalizedStringResource {
      LocalizedStringResource("lab.replayR", defaultValue: "\(value) R", bundle: L10n.bundle)
    }
    /// The mean R's confidence interval: "Mean R at 95%: −0.21 R … +0.57 R".
    static func replayInterval(_ confidence: String, _ low: String, _ high: String) -> LocalizedStringResource {
      LocalizedStringResource("lab.replayInterval", defaultValue: "Mean R at \(confidence)%: \(low) … \(high)",
        bundle: L10n.bundle)
    }
    /// How many trades the bot's risk limits would have taken.
    static func replayBotTrades(_ trades: Int) -> LocalizedStringResource {
      LocalizedStringResource("lab.replayBotTrades", defaultValue: "With the bot's limits: \(trades) trades", bundle: L10n.bundle)
    }
    /// The data the replay covered and where it ends.
    static func replayData(_ first: String, _ last: String, _ sessions: Int) -> LocalizedStringResource {
      LocalizedStringResource("lab.replayData", defaultValue: "Data \(first) – \(last), \(sessions) sessions · ends \(last)",
        bundle: L10n.bundle)
    }
    static var later: LocalizedStringResource {
      LocalizedStringResource("lab.later",
        // swiftlint:disable:next line_length
        defaultValue: "Results are simulated from the captured bars; observers never trade. Approving a new version stays on the Mac.",
        bundle: L10n.bundle)
    }
    static func agreement(_ shared: Int, _ entered: Int, _ symbols: String) -> LocalizedStringResource {
      LocalizedStringResource("lab.agreement",
        defaultValue: "bot also traded \(shared) of \(entered): \(symbols)", bundle: L10n.bundle)
    }
    static func failed(_ cause: String) -> LocalizedStringResource {
      LocalizedStringResource("lab.failed", defaultValue: "Couldn't read the observers: \(cause)", bundle: L10n.bundle)
    }
    /// Button that starts a replay of two versions.
    static var replayStartCompare: LocalizedStringResource {
      LocalizedStringResource("lab.replayStartCompare", defaultValue: "Run and Compare", bundle: L10n.bundle)
    }
    /// Picker of the version to replay.
    static var replayVersion: LocalizedStringResource {
      LocalizedStringResource("lab.replayVersion", defaultValue: "Version", bundle: L10n.bundle)
    }
    /// Between the two versions of a comparison.
    static var replayVersus: LocalizedStringResource {
      LocalizedStringResource("lab.replayVersus", defaultValue: "vs", bundle: L10n.bundle)
    }
    /// Picker of the second version.
    static var replayCompare: LocalizedStringResource {
      LocalizedStringResource("lab.replayCompare", defaultValue: "Compare with", bundle: L10n.bundle)
    }
    /// No second version.
    static var replayCompareNone: LocalizedStringResource {
      LocalizedStringResource("lab.replayCompareNone", defaultValue: "No comparison", bundle: L10n.bundle)
    }
    /// Picker of the replayed days.
    static var replayDays: LocalizedStringResource {
      LocalizedStringResource("lab.replayDays", defaultValue: "Days", bundle: L10n.bundle)
    }
    /// Replay over the last sessions, with their number.
    static func replayLastSessions(_ sessions: Int) -> LocalizedStringResource {
      LocalizedStringResource("lab.replayLastSessions", defaultValue: "Last \(sessions) sessions", bundle: L10n.bundle)
    }
    /// Replay over one chosen day.
    static var replayOneDay: LocalizedStringResource {
      LocalizedStringResource("lab.replayOneDay", defaultValue: "One day", bundle: L10n.bundle)
    }
    /// Picker of the one day.
    static var replayDay: LocalizedStringResource {
      LocalizedStringResource("lab.replayDay", defaultValue: "Day", bundle: L10n.bundle)
    }
    /// A strategy version: name and version.
    static func versionName(_ name: String, _ version: String) -> LocalizedStringResource {
      LocalizedStringResource("lab.versionName", defaultValue: "\(name) v\(version)", bundle: L10n.bundle)
    }
    /// A version with its role.
    static func versionWithRole(_ name: String, _ role: String) -> LocalizedStringResource {
      LocalizedStringResource("lab.versionWithRole", defaultValue: "\(name) · \(role)", bundle: L10n.bundle)
    }
    /// Role of the version that trades.
    static var roleActive: LocalizedStringResource {
      LocalizedStringResource("lab.roleActive", defaultValue: "active", bundle: L10n.bundle)
    }
    /// Role of a shadow version.
    static var roleObserver: LocalizedStringResource {
      LocalizedStringResource("lab.roleObserver", defaultValue: "observer", bundle: L10n.bundle)
    }
    /// Role of a version that is neither.
    static var roleCandidate: LocalizedStringResource {
      LocalizedStringResource("lab.roleCandidate", defaultValue: "candidate", bundle: L10n.bundle)
    }
    /// Under a one-day replay.
    static func replayOneDayNote(_ day: String) -> LocalizedStringResource {
      LocalizedStringResource("lab.replayOneDayNote",
        defaultValue: "\(day) only: one day proves nothing, read it as an example.",
        bundle: L10n.bundle)
    }
    /// Under a running comparison: the second version, replayed once the first ends.
    static func replayThen(_ name: String) -> LocalizedStringResource {
      LocalizedStringResource("lab.replayThen", defaultValue: "Then \(name), over the same days", bundle: L10n.bundle)
    }
    /// Second version minus the first.
    static var replayDifference: LocalizedStringResource {
      LocalizedStringResource("lab.replayDifference", defaultValue: "Difference", bundle: L10n.bundle)
    }
    /// Under the difference.
    static var replayMeanRPerTrade: LocalizedStringResource {
      LocalizedStringResource("lab.replayMeanRPerTrade", defaultValue: "mean R per trade", bundle: L10n.bundle)
    }
    /// A version's trades and its result with the bot's limits.
    static func replayTradesAndUsd(_ trades: Int, _ usd: String) -> LocalizedStringResource {
      LocalizedStringResource("lab.replayTradesAndUsd", defaultValue: "\(trades) trades · \(usd)", bundle: L10n.bundle)
    }
    /// The second version could not be replayed.
    static func replayCompareFailed(_ name: String, _ cause: String) -> LocalizedStringResource {
      LocalizedStringResource("lab.replayCompareFailed", defaultValue: "\(name) was not replayed: \(cause)", bundle: L10n.bundle)
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
        // swiftlint:disable:next line_length
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
        defaultValue: "That link is not a Tickr pairing link.",
        bundle: L10n.bundle)
    }
    static func notRedeemed(_ cause: String) -> LocalizedStringResource {
      LocalizedStringResource("pair.notRedeemed", defaultValue: "Not paired: \(cause)", bundle: L10n.bundle)
    }
    static var notSaved: LocalizedStringResource {
      LocalizedStringResource("pair.notSaved",
        defaultValue: "Not paired: the phone could not keep the token in its Keychain. Run pair on the Mac again.",
        bundle: L10n.bundle)
    }
    static var invalid: LocalizedStringResource {
      LocalizedStringResource("pair.invalid",
        defaultValue: "This is not a pairing link.",
        bundle: L10n.bundle)
    }
    static var prompt: LocalizedStringResource {
      LocalizedStringResource("pair.prompt", defaultValue: "tickr://pair?…", bundle: L10n.bundle)
    }
    static var sheetFooter: LocalizedStringResource {
      LocalizedStringResource("pair.sheetFooter",
        // swiftlint:disable:next line_length
        defaultValue: "On the Mac run `python -m tickr.api --config config/bot.toml pair`, then AirDrop the pairing file it names to this phone and paste the link here.",
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
    static var demoDay: LocalizedStringResource {
      LocalizedStringResource("settings.demoDay", defaultValue: "Demo day", bundle: L10n.bundle)
    }
    static var demoDayFooter: LocalizedStringResource {
      LocalizedStringResource("settings.demoDayFooter",
        // swiftlint:disable:next line_length
        defaultValue: "Shows the made-up demo day from the Mac, and only that day, through the same connection; the address and pairing stay as they are.",
        bundle: L10n.bundle)
    }
    static var jobs: LocalizedStringResource {
      LocalizedStringResource("settings.jobs", defaultValue: "Jobs on the Mac", bundle: L10n.bundle)
    }
    static var jobsFooter: LocalizedStringResource {
      LocalizedStringResource("settings.jobsFooter",
        defaultValue: "Launch times are in the Mac's local time; other times are New York time.", bundle: L10n.bundle)
    }
    static var botService: LocalizedStringResource {
      LocalizedStringResource("settings.botService", defaultValue: "Bot service", bundle: L10n.bundle)
    }
    static var notRunning: LocalizedStringResource {
      LocalizedStringResource("settings.notRunning", defaultValue: "Not running", bundle: L10n.bundle)
    }
    /// The bot's status is stale: its last reported state may no longer hold.
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
    /// A launchd job this app does not know by name.
    static var jobOther: LocalizedStringResource {
      LocalizedStringResource("settings.job.other", defaultValue: "Other job", bundle: L10n.bundle)
    }
    static var reconcile: LocalizedStringResource {
      LocalizedStringResource("settings.reconcile", defaultValue: "Reconcile", bundle: L10n.bundle)
    }
    /// Before the countdown to the next reconcile.
    static var nextIn: LocalizedStringResource {
      LocalizedStringResource("settings.nextIn", defaultValue: "in", bundle: L10n.bundle)
    }
    static func lastAt(_ time: String) -> LocalizedStringResource {
      LocalizedStringResource("settings.lastAt", defaultValue: "last \(time)", bundle: L10n.bundle)
    }
    static var backup: LocalizedStringResource {
      LocalizedStringResource("settings.backup", defaultValue: "Backup", bundle: L10n.bundle)
    }
    static func backupFailed(_ time: String) -> LocalizedStringResource {
      LocalizedStringResource("settings.backupFailed", defaultValue: "Failed \(time)", bundle: L10n.bundle)
    }
    static var environmentFooter: LocalizedStringResource {
      LocalizedStringResource("settings.environmentFooter",
        // swiftlint:disable:next line_length
        defaultValue: "Sandbox or Production is set in config/bot.toml on the Mac; Production also needs your authorization file there. The phone only shows it.",
        bundle: L10n.bundle)
    }
    static var session: LocalizedStringResource {
      LocalizedStringResource("settings.session", defaultValue: "Session · New York", bundle: L10n.bundle)
    }
    static var sessionFooter: LocalizedStringResource {
      LocalizedStringResource("settings.sessionFooter",
        defaultValue: "US exchange hours: extended 04:00–20:00, regular 09:30–16:00. Half days are not drawn.",
        bundle: L10n.bundle)
    }
    static var regularHours: LocalizedStringResource {
      LocalizedStringResource("settings.regularHours", defaultValue: "regular hours", bundle: L10n.bundle)
    }
    static var preMarket: LocalizedStringResource {
      LocalizedStringResource("settings.preMarket", defaultValue: "pre-market", bundle: L10n.bundle)
    }
    static var afterHours: LocalizedStringResource {
      LocalizedStringResource("settings.afterHours", defaultValue: "after hours", bundle: L10n.bundle)
    }
    static var closed: LocalizedStringResource {
      LocalizedStringResource("settings.closed", defaultValue: "market closed", bundle: L10n.bundle)
    }
    static var preflight: LocalizedStringResource {
      LocalizedStringResource("settings.preflight", defaultValue: "Preflight", bundle: L10n.bundle)
    }
    static var allPassed: LocalizedStringResource {
      LocalizedStringResource("settings.allPassed", defaultValue: "all passed", bundle: L10n.bundle)
    }
    static var checking: LocalizedStringResource {
      LocalizedStringResource("settings.checking", defaultValue: "checking…", bundle: L10n.bundle)
    }
    static var checkBotRunning: LocalizedStringResource {
      LocalizedStringResource("settings.checkBotRunning", defaultValue: "Bot running", bundle: L10n.bundle)
    }
    static var checkStatusCurrent: LocalizedStringResource {
      LocalizedStringResource("settings.checkStatusCurrent", defaultValue: "Status current", bundle: L10n.bundle)
    }
    static var checkStreamFresh: LocalizedStringResource {
      LocalizedStringResource("settings.checkStreamFresh", defaultValue: "Quote stream fresh", bundle: L10n.bundle)
    }
    static var checkBrokerMatches: LocalizedStringResource {
      LocalizedStringResource("settings.checkBrokerMatches", defaultValue: "Broker matches records", bundle: L10n.bundle)
    }
    static var checkStopsVerified: LocalizedStringResource {
      LocalizedStringResource("settings.checkStopsVerified", defaultValue: "Every position has a stop", bundle: L10n.bundle)
    }
    static var checkGateOpen: LocalizedStringResource {
      LocalizedStringResource("settings.checkGateOpen", defaultValue: "Trading gate open", bundle: L10n.bundle)
    }
    static func accountFailed(_ cause: String) -> LocalizedStringResource {
      LocalizedStringResource("settings.accountFailed",
        defaultValue: "Couldn't read the broker check: \(cause)",
        bundle: L10n.bundle)
    }
    static func failing(_ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("settings.failing", defaultValue: "\(count) failing", bundle: L10n.bundle)
    }
    static func brokerCounts(_ positions: Int, _ orders: Int) -> LocalizedStringResource {
      LocalizedStringResource("settings.brokerCounts", defaultValue: "positions: \(positions) · orders: \(orders)",
        bundle: L10n.bundle)
    }
    static func stops(_ verified: Int, _ total: Int) -> LocalizedStringResource {
      LocalizedStringResource("settings.stops", defaultValue: "\(verified) of \(total) verified", bundle: L10n.bundle)
    }
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
        // swiftlint:disable:next line_length
        defaultValue: "In the Simulator the Mac's own address works. On the phone, pair with the link that `python -m tickr.api pair` leaves on the Mac; it reaches the Mac through Tailscale over HTTPS. The token stays in this phone's Keychain and goes only to the paired address.",
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
        // swiftlint:disable:next line_length
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

/// Every text of the Chart tab, in Localizable.xcstrings with the rest.
enum ChartText {
  static let title = LocalizedStringResource("chart.title", defaultValue: "Chart")
  static let loading = LocalizedStringResource("chart.loading",
    defaultValue: "Loading the chart…")
  static let noDaysTitle = LocalizedStringResource("chart.noDays.title",
    defaultValue: "No recorded days yet")
  static let noDaysBody = LocalizedStringResource("chart.noDays.body",
    defaultValue: "The bot records bars and trades while it runs. Days appear here once there is something to show.")
  static let noBarsTitle = LocalizedStringResource("chart.noBars.title",
    defaultValue: "No captured bars")
  static let noBarsBody = LocalizedStringResource("chart.noBars.body",
    defaultValue: "The bot captured no bars on this day.")
  static let failedTitle = LocalizedStringResource("chart.failed.title",
    defaultValue: "Could not load the chart")
  static let retry = LocalizedStringResource("chart.retry", defaultValue: "Try Again")
  static let previousDay = LocalizedStringResource("chart.previousDay",
    defaultValue: "Previous day")
  static let nextDay = LocalizedStringResource("chart.nextDay", defaultValue: "Next day")
  static let day = LocalizedStringResource("chart.day", defaultValue: "Day")
  static let live = LocalizedStringResource("chart.live", defaultValue: "Live")
  static let timeframe = LocalizedStringResource("chart.timeframe", defaultValue: "Interval")
  /// The range picker and its segments: the chosen day, five sessions, one and three months, a year.
  static let range = LocalizedStringResource("chart.range", defaultValue: "Range")
  static let rangeDay = LocalizedStringResource("chart.range.day", defaultValue: "Day")
  static let rangeFiveDays = LocalizedStringResource("chart.range.fiveDays", defaultValue: "5D")
  static let rangeOneMonth = LocalizedStringResource("chart.range.oneMonth", defaultValue: "1M")
  static let rangeThreeMonths = LocalizedStringResource("chart.range.threeMonths", defaultValue: "3M")
  static let rangeOneYear = LocalizedStringResource("chart.range.oneYear", defaultValue: "1Y")
  /// Market data (GET /chart) could not be read for a range beyond one day.
  static func candlesUnavailable(_ cause: String) -> LocalizedStringResource {
    LocalizedStringResource("chart.candlesUnavailable", defaultValue: "Market data is not available: \(cause)")
  }
  /// Market data answered with no candles for the range.
  static func noCandles(_ cause: String) -> LocalizedStringResource {
    LocalizedStringResource("chart.noCandles", defaultValue: "Market data has no candles for this symbol and range: \(cause)")
  }
  static let m1 = LocalizedStringResource("chart.timeframe.m1", defaultValue: "1m")
  static let m5 = LocalizedStringResource("chart.timeframe.m5", defaultValue: "5m")
  static let m30 = LocalizedStringResource("chart.timeframe.m30", defaultValue: "30m")
  static let h1 = LocalizedStringResource("chart.timeframe.h1", defaultValue: "1h")
  static let d1 = LocalizedStringResource("chart.timeframe.d1", defaultValue: "D")
  static let w1 = LocalizedStringResource("chart.timeframe.w1", defaultValue: "W")
  static let mo1 = LocalizedStringResource("chart.timeframe.mo1", defaultValue: "M")
  static let vwap = LocalizedStringResource("chart.indicator.vwap", defaultValue: "VWAP")
  static let volume = LocalizedStringResource("chart.indicator.volume",
    defaultValue: "Volume")
  static let zoomIn = LocalizedStringResource("chart.zoomIn", defaultValue: "Zoom in")
  static let zoomOut = LocalizedStringResource("chart.zoomOut", defaultValue: "Zoom out")
  static let liveHint = LocalizedStringResource("chart.live.hint",
    defaultValue: "Scrolls to the newest candle.")
  static let todayLive = LocalizedStringResource("chart.todayLive", defaultValue: "today · live")
  static let refusedEntry = LocalizedStringResource("chart.event.refused",
    defaultValue: "Entry refused")
  static let trades = LocalizedStringResource("chart.trades", defaultValue: "Trades")
  static let noTrades = LocalizedStringResource("chart.noTrades",
    defaultValue: "No closed trades on this symbol this day.")
  static let entry = LocalizedStringResource("chart.entry", defaultValue: "Entry")
  static let exit = LocalizedStringResource("chart.exit", defaultValue: "Exit")
  static let stop = LocalizedStringResource("chart.stop", defaultValue: "Stop")
  static let axisTime = LocalizedStringResource("chart.axis.time", defaultValue: "Time")
  static let axisPrice = LocalizedStringResource("chart.axis.price", defaultValue: "Price")
  static let axisLine = LocalizedStringResource("chart.axis.line", defaultValue: "Line")

  /// The fast or slow EMA toggle, with its period in bars.
  static func ema(_ period: Int) -> LocalizedStringResource {
    LocalizedStringResource("chart.indicator.ema", defaultValue: "EMA \(period)")
  }

  /// The ATR pane toggle and label, with its period in bars.
  static func atr(_ period: Int) -> LocalizedStringResource {
    LocalizedStringResource("chart.indicator.atr", defaultValue: "ATR \(period)")
  }
  /// Name of the values a study pane plots (VoiceOver).
  static let axisValue = LocalizedStringResource("chart.axisValue", defaultValue: "Value")
  /// A moving-average line in the legend.
  static func movingAverage(_ period: Int) -> LocalizedStringResource {
    LocalizedStringResource("chart.indicator.ma", defaultValue: "MA\(period)")
  }
  /// Toggles of the indicator menu.
  static let movingAverages = LocalizedStringResource("chart.indicator.maToggle", defaultValue: "Moving averages (MA)")
  static let bollinger = LocalizedStringResource("chart.indicator.boll", defaultValue: "Bollinger bands (BOLL)")
  static let macdToggle = LocalizedStringResource("chart.indicator.macdToggle", defaultValue: "MACD")
  static let stochasticToggle = LocalizedStringResource("chart.indicator.stochToggle", defaultValue: "Slow stochastic")
  static let rsiToggle = LocalizedStringResource("chart.indicator.rsiToggle", defaultValue: "RSI")
  static let indicators = LocalizedStringResource("chart.indicators", defaultValue: "Indicators")
  static let overlays = LocalizedStringResource("chart.indicators.overlays", defaultValue: "On the price")
  static let panes = LocalizedStringResource("chart.indicators.panes", defaultValue: "Panes below")
  /// The candles / line switch.
  static let candles = LocalizedStringResource("chart.style.candles", defaultValue: "Candles")
  static let lineStyle = LocalizedStringResource("chart.style.line", defaultValue: "Line")
  /// Legend names of the Bollinger lines.
  static let bollingerUpper = LocalizedStringResource("chart.indicator.bollUpper", defaultValue: "UB")
  static let bollingerMiddle = LocalizedStringResource("chart.indicator.bollMiddle", defaultValue: "MB")
  static let bollingerLower = LocalizedStringResource("chart.indicator.bollLower", defaultValue: "LB")
  /// MACD pane legend: the MACD line with its periods, then the signal line and the histogram.
  static func macd(_ fast: Int, _ slow: Int, _ signal: Int) -> LocalizedStringResource {
    LocalizedStringResource("chart.indicator.macd", defaultValue: "MACD(\(fast),\(slow),\(signal))")
  }
  static let macdSignal = LocalizedStringResource("chart.indicator.macdSignal", defaultValue: "Signal")
  static let macdHistogram = LocalizedStringResource("chart.indicator.macdHistogram", defaultValue: "Histogram")
  /// Stochastic pane legend: the %K line with the periods, then the %D line.
  static func stochasticK(_ period: Int, _ smoothing: Int) -> LocalizedStringResource {
    LocalizedStringResource("chart.indicator.stochK", defaultValue: "Stoch(\(period),\(smoothing)) K")
  }
  static let stochasticD = LocalizedStringResource("chart.indicator.stochD", defaultValue: "D")
  /// RSI pane legend.
  static func rsi(_ period: Int) -> LocalizedStringResource {
    LocalizedStringResource("chart.indicator.rsi", defaultValue: "RSI\(period)")
  }
  /// Header: the day's high and low, and its volume.
  static let highLow = LocalizedStringResource("chart.header.highLow", defaultValue: "H/L")
  static let dayVolume = LocalizedStringResource("chart.header.volume", defaultValue: "Volume")
  /// Header: the day's high and low, already formatted ("7.19–5.70").
  static func range(_ high: String, _ low: String) -> LocalizedStringResource {
    LocalizedStringResource("chart.header.range", defaultValue: "\(high)–\(low)")
  }

  /// The line above the chart while no candle is read: timeframe and candles on screen (both
  /// already formatted), and how to move and read the chart.
  static func caption(_ timeframe: String, _ bars: String) -> LocalizedStringResource {
    LocalizedStringResource("chart.caption",
      defaultValue: "\(timeframe) · \(bars) · drag to scroll · touch and hold to read")
  }

  /// Candles on screen, for `caption`.
  static func bars(_ count: Int) -> LocalizedStringResource {
    LocalizedStringResource("chart.bars", defaultValue: "\(count) bars")
  }

  /// The crosshair readout of one candle: open, high, low, close, volume (already formatted).
  static func readout(_ open: String, _ high: String, _ low: String, _ close: String, _ volume: String)
    -> LocalizedStringResource {
    LocalizedStringResource("chart.readout",
      defaultValue: "O \(open)  H \(high)  L \(low)  C \(close)  V \(volume)")
  }
  static let decisions = LocalizedStringResource("chart.decisions",
    defaultValue: "Why the bot acted")
  static let noDecisions = LocalizedStringResource("chart.decisions.none",
    defaultValue: "No decisions recorded for this symbol that day.")
  static let noEntries = LocalizedStringResource("chart.decisions.noEntries",
    defaultValue: "No entries or exits; the strategy only watched.")
  static let keyDecisions = LocalizedStringResource("chart.decisions.key",
    defaultValue: "Entries and exits only")
  static let observer = LocalizedStringResource("chart.decisions.observer",
    defaultValue: "observer")
  static let tradingStrategy = LocalizedStringResource("chart.decisions.strategyLabel",
    defaultValue: "Trading strategy")
  static let noStrategyDecisions = LocalizedStringResource("chart.decisions.noStrategy",
    defaultValue: "The trading strategy recorded nothing on this symbol that day.")
  static let observers = LocalizedStringResource("chart.decisions.observers",
    defaultValue: "Observers · never trade")
  static let openPosition = LocalizedStringResource("chart.symbol.open",
    defaultValue: "open position")
  static let traded = LocalizedStringResource("chart.symbol.traded",
    defaultValue: "traded that day")
  static let verdictIgnore = LocalizedStringResource("chart.verdict.ignore",
    defaultValue: "IGNORE")
  static let verdictWatch = LocalizedStringResource("chart.verdict.watch",
    defaultValue: "WATCH")
  static let verdictEnter = LocalizedStringResource("chart.verdict.enter",
    defaultValue: "ENTER")
  static let verdictHold = LocalizedStringResource("chart.verdict.hold",
    defaultValue: "HOLD")
  static let verdictExit = LocalizedStringResource("chart.verdict.exit",
    defaultValue: "EXIT")
  static func allDecisions(_ count: Int) -> LocalizedStringResource {
    LocalizedStringResource("chart.decisions.all", defaultValue: "All \(count) decisions")
  }
  static func decisionsFailed(_ cause: String) -> LocalizedStringResource {
    LocalizedStringResource("chart.decisions.failed",
      defaultValue: "Couldn't read the decisions: \(cause)")
  }
  static func entryStop(_ entry: String, _ stop: String) -> LocalizedStringResource {
    LocalizedStringResource("chart.decisions.entryStop", defaultValue: "entry \(entry) · stop \(stop)")
  }
  static func strategy(_ name: String, _ version: String) -> LocalizedStringResource {
    LocalizedStringResource("chart.decisions.strategy", defaultValue: "\(name) v\(version)")
  }
  static func repeats(_ count: Int, _ since: String) -> LocalizedStringResource {
    LocalizedStringResource("chart.decisions.repeats", defaultValue: "×\(count) in a row since \(since)")
  }
}
