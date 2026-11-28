import Foundation

// The names of the strategies the apps know (`StrategyName`).
extension L10n {
  /// The hand-written price-action strategy (`price-action-v1`).
  static var strategyPriceAction: LocalizedStringResource {
    LocalizedStringResource("kit.strategy.priceAction", defaultValue: "Price action", bundle: bundle)
  }
}
