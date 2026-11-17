import Foundation

/// A recorded check's numbers and operator as a person reads them: grouped thousands, a whole
/// number without decimals ("5,000,000"), any other value of 1 or more to two decimals
/// ("12,627,555.29", "12.40"), a smaller one to up to four ("0.0031"); "≥" for ">=". The bot
/// records them raw ("12627555.2850", ">=").
public enum CheckValue {
  public static func text(_ value: Decimal) -> String {
    var whole = value
    var source = value
    NSDecimalRound(&whole, &source, 0, .plain)
    if whole == value { return value.formatted(.number.precision(.fractionLength(0))) }
    let digits = abs(value) >= 1 ? wholeDigits : smallDigits
    // Half rounds up (owner rule): the number style alone rounds half to even ("…555.285" to .28).
    var rounded = Decimal()
    NSDecimalRound(&rounded, &source, digits, .plain)
    return rounded.formatted(.number.precision(.fractionLength(abs(value) >= 1 ? digits...digits : 0...digits)))
  }

  /// The operator in mathematical signs; any other is shown as recorded.
  public static func symbol(_ op: String) -> String { signs[op] ?? op }

  /// Decimals of a value of 1 or more.
  static let wholeDigits = 2
  /// Most decimals of a value under 1.
  static let smallDigits = 4
  /// The bot's ASCII operators and their signs (protocol constants).
  static let signs = [">=": "≥", "<=": "≤", "!=": "≠"]
}
