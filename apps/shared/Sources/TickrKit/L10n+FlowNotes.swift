import Foundation

/// Flow notes (FlowBoard): recorded refusals.
extension L10n {
  /// A risk refusal recorded without its detail.
  static var refusedByRisk: LocalizedStringResource {
    LocalizedStringResource("kit.refusedByRisk", defaultValue: "Refused by risk", bundle: bundle)
  }
  /// A risk refusal recorded as text; argument: the bot's detail.
  static func refusedByRiskDetail(_ detail: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.refusedByRiskDetail", defaultValue: "Refused by risk: \(detail)", bundle: bundle)
  }
}
