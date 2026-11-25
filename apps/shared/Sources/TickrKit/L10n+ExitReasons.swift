import Foundation

/// Why a trade closed (`Board.exitReasonTitle`), in the person's language.
extension L10n {
  static var exitStoppedOut: LocalizedStringResource {
    LocalizedStringResource("kit.exit.stoppedOut", defaultValue: "stopped out", bundle: bundle)
  }
  static var exitStrategy: LocalizedStringResource {
    LocalizedStringResource("kit.exit.strategy", defaultValue: "strategy exit", bundle: bundle)
  }
  static var exitOperator: LocalizedStringResource {
    LocalizedStringResource("kit.exit.operator", defaultValue: "operator exit", bundle: bundle)
  }
  static var exitOperatorFlatten: LocalizedStringResource {
    LocalizedStringResource("kit.exit.operatorFlatten", defaultValue: "closed", bundle: bundle)
  }
  static var exitInterrupted: LocalizedStringResource {
    LocalizedStringResource("kit.exit.interrupted", defaultValue: "interrupted", bundle: bundle)
  }
  static var exitSessionEnd: LocalizedStringResource {
    LocalizedStringResource("kit.exit.sessionEnd", defaultValue: "end-of-day close", bundle: bundle)
  }
  static var exitStreamLost: LocalizedStringResource {
    LocalizedStringResource("kit.exit.streamLost", defaultValue: "quotes lost", bundle: bundle)
  }
  static var exitStopRejected: LocalizedStringResource {
    LocalizedStringResource("kit.exit.stopRejected", defaultValue: "stop rejected", bundle: bundle)
  }
  static var exitUnprotected: LocalizedStringResource {
    LocalizedStringResource("kit.exit.unprotected", defaultValue: "unprotected too long", bundle: bundle)
  }
  static var exitEntryNotFilled: LocalizedStringResource {
    LocalizedStringResource("kit.exit.entryNotFilled", defaultValue: "entry not filled", bundle: bundle)
  }
  static var exitHoldElapsed: LocalizedStringResource {
    LocalizedStringResource("kit.exit.holdElapsed", defaultValue: "hold time over", bundle: bundle)
  }
  static var exitClosed: LocalizedStringResource {
    LocalizedStringResource("kit.exit.closed", defaultValue: "closed", bundle: bundle)
  }
  /// The operator ended an order no broker read could settle (`tickr resolve-order`).
  static var exitOrderResolved: LocalizedStringResource {
    LocalizedStringResource("kit.exit.orderResolved", defaultValue: "resolved by the operator", bundle: bundle)
  }
  /// A replay's trade still open when the captured bars ran out.
  static var exitEndOfData: LocalizedStringResource {
    LocalizedStringResource("kit.exit.endOfData", defaultValue: "bars ran out", bundle: bundle)
  }
}
