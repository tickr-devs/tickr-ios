import Foundation

/// Flow notes (FlowBoard): why the universe filter left a symbol out, and recorded refusals.
extension L10n {
  /// Left out by the universe filter: the screeners disagree about this instrument.
  static var universeConflictingRows: LocalizedStringResource {
    LocalizedStringResource("kit.universe.conflictingRows",
      defaultValue: "Listed by the screeners under conflicting details", bundle: bundle)
  }
  /// Left out by the universe filter; argument: the exchange.
  static func universeExchange(_ value: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.universe.exchange", defaultValue: "Exchange not allowed: \(value)", bundle: bundle)
  }
  /// Left out by the universe filter; argument: the currency.
  static func universeCurrency(_ value: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.universe.currency", defaultValue: "Currency not allowed: \(value)", bundle: bundle)
  }
  /// Left out by the universe filter: the security type is unknown.
  static var universeTypeUnknown: LocalizedStringResource {
    LocalizedStringResource("kit.universe.typeUnknown", defaultValue: "Security type unknown", bundle: bundle)
  }
  /// Left out by the universe filter; argument: the security type.
  static func universeType(_ value: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.universe.type", defaultValue: "Security type not allowed: \(value)", bundle: bundle)
  }
  /// Left out by the universe filter for a reason this app does not know.
  static var universeOther: LocalizedStringResource {
    LocalizedStringResource("kit.universe.other", defaultValue: "Left out by the universe filter", bundle: bundle)
  }
  /// A risk refusal recorded without its detail.
  static var refusedByRisk: LocalizedStringResource {
    LocalizedStringResource("kit.refusedByRisk", defaultValue: "Refused by risk", bundle: bundle)
  }
  /// A risk refusal recorded as text; argument: the bot's detail.
  static func refusedByRiskDetail(_ detail: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.refusedByRiskDetail", defaultValue: "Refused by risk: \(detail)", bundle: bundle)
  }
}
