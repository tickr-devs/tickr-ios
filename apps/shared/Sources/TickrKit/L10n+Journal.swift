import Foundation

// The day's journal (Board.journal): its tags and lines.
extension L10n {
  /// Tag: the bot started.
  static var journalBotOn: LocalizedStringResource {
    LocalizedStringResource("kit.journal.botOn", defaultValue: "BOT ON", bundle: bundle)
  }
  /// Tag: the bot stopped.
  static var journalBotOff: LocalizedStringResource {
    LocalizedStringResource("kit.journal.botOff", defaultValue: "BOT OFF", bundle: bundle)
  }
  /// Tag: an entry order filled.
  static var journalBought: LocalizedStringResource {
    LocalizedStringResource("kit.journal.bought", defaultValue: "BOUGHT", bundle: bundle)
  }
  /// Tag: a closing order filled.
  static var journalSold: LocalizedStringResource {
    LocalizedStringResource("kit.journal.sold", defaultValue: "SOLD", bundle: bundle)
  }
  /// Tag: a stop order filled.
  static var journalStopFilled: LocalizedStringResource {
    LocalizedStringResource("kit.journal.stopFilled", defaultValue: "STOP FILLED", bundle: bundle)
  }
  /// Tag: the broker took a stop order.
  static var journalStopPlaced: LocalizedStringResource {
    LocalizedStringResource("kit.journal.stopPlaced", defaultValue: "STOP SET", bundle: bundle)
  }
  /// Tag: a stop was moved.
  static var journalStopMoved: LocalizedStringResource {
    LocalizedStringResource("kit.journal.stopMoved", defaultValue: "STOP MOVED", bundle: bundle)
  }
  /// Tag: the bot asked to close a trade.
  static var journalExit: LocalizedStringResource {
    LocalizedStringResource("kit.journal.exit", defaultValue: "EXIT", bundle: bundle)
  }
  /// Tag: a trade ended.
  static var journalClosed: LocalizedStringResource {
    LocalizedStringResource("kit.journal.closed", defaultValue: "CLOSED", bundle: bundle)
  }
  /// Tag: a block on new entries was lifted.
  static var journalFenceCleared: LocalizedStringResource {
    LocalizedStringResource("kit.journal.fenceCleared", defaultValue: "CLEARED", bundle: bundle)
  }
  /// A price in a line: "@ 4.12".
  static func journalAt(_ price: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.journal.at", defaultValue: "@ \(price)", bundle: bundle)
  }
  /// The stop sent with an entry: "stop 3.95".
  static func journalStopAt(_ price: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.journal.stopAt", defaultValue: "stop \(price)", bundle: bundle)
  }
  /// A moved stop's new price: "to 4.02".
  static func journalTo(_ price: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.journal.to", defaultValue: "to \(price)", bundle: bundle)
  }
  /// The bot started, strategy unknown.
  static var journalStarted: LocalizedStringResource {
    LocalizedStringResource("kit.journal.started", defaultValue: "Started", bundle: bundle)
  }
  /// The bot started with a strategy: "Started · price-action v3".
  static func journalStartedWith(_ name: String, _ version: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.journal.startedWith", defaultValue: "Started · \(name) v\(version)", bundle: bundle)
  }
  /// The bot stopped.
  static var journalStopped: LocalizedStringResource {
    LocalizedStringResource("kit.journal.stopped", defaultValue: "Stopped", bundle: bundle)
  }
  /// The bot was interrupted.
  static var journalInterrupted: LocalizedStringResource {
    LocalizedStringResource("kit.journal.interrupted", defaultValue: "Interrupted", bundle: bundle)
  }
  /// The bot refused to start trading.
  static var journalRefusedStart: LocalizedStringResource {
    LocalizedStringResource("kit.journal.refusedStart", defaultValue: "Stopped: start refused", bundle: bundle)
  }
  /// The bot did not finish stopping in time.
  static var journalDeadline: LocalizedStringResource {
    LocalizedStringResource("kit.journal.deadline", defaultValue: "Stopped before it finished cleanly", bundle: bundle)
  }
  /// An entry order was not accepted.
  static var journalEntryRefused: LocalizedStringResource {
    LocalizedStringResource("kit.journal.entryRefused", defaultValue: "entry order not accepted", bundle: bundle)
  }
  /// A stop order was not accepted.
  static var journalStopRefused: LocalizedStringResource {
    LocalizedStringResource("kit.journal.stopRefused", defaultValue: "stop order not accepted", bundle: bundle)
  }
  /// A closing order was not accepted.
  static var journalExitRefused: LocalizedStringResource {
    LocalizedStringResource("kit.journal.exitRefused", defaultValue: "closing order not accepted", bundle: bundle)
  }
  /// A command of a kind this app does not know.
  static var journalCommandOther: LocalizedStringResource {
    LocalizedStringResource("kit.journal.commandOther", defaultValue: "Command", bundle: bundle)
  }
}
