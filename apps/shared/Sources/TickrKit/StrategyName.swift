import Foundation

/// A strategy's name for a person: "Price action" for the bot's `price-action-v1`, never the raw
/// id on a screen (owner, 2026-11-28; the board's "Model l2 12-01a"). An id this app does not
/// know reads as the bot sent it.
public enum StrategyName {
  /// The suffix the bot's ids carry for their generation ("-v1"); the version shown is the
  /// status's own `version`.
  static let generationMarker = "-v"

  /// The readable name of `id`.
  public static func title(_ id: String) -> String {
    let base = id.range(of: generationMarker, options: .backwards)
      .flatMap { Int(id[$0.upperBound...]) != nil ? String(id[..<$0.lowerBound]) : nil } ?? id
    return Known(rawValue: base).map { String(localized: $0.title) } ?? id
  }

  /// The strategies the apps can name.
  enum Known: String {
    case priceAction = "price-action"

    var title: LocalizedStringResource {
      switch self {
      case .priceAction: L10n.strategyPriceAction
      }
    }
  }
}
