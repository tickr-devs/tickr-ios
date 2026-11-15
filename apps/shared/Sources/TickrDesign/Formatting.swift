import Foundation

/// Decimals of the statistics on the Lab and performance cards (both apps).
public enum StatDigits {
  /// A mean R and its bounds.
  public static let r = 2
  /// A profit factor.
  public static let factor = 2
  /// A win rate or a confidence, in whole percents.
  public static let percent = 0
}

/// Number formatting for the operator apps. Pure and locale-independent, so both apps and the
/// tests agree on every string. Money keeps two decimals; a minus is the typographic U+2212.
public enum Money {
  static let minus = "\u{2212}"
  /// Decimals shown for money and prices (cents).
  public static let centsDigits = 2
  /// The fixed locale of every number ("." as the separator, whatever the user's locale).
  static let posixLocale = "en_US_POSIX"

  /// "12.34" for 12.34; never a sign.
  public static func plain(_ value: Decimal, fractionDigits: Int = centsDigits) -> String {
    fixed(abs(value), fractionDigits: fractionDigits)
  }

  /// "+11.80", "−1.60", "0.00".
  public static func signed(_ value: Decimal, fractionDigits: Int = centsDigits) -> String {
    let body = fixed(abs(value), fractionDigits: fractionDigits)
    if rounded(value, fractionDigits) == 0 { return body }
    return (value > 0 ? "+" : minus) + body
  }

  /// Prices from one dollar trade in whole cents; below it, in hundredths of a cent (Reg NMS
  /// Rule 612), shown with `subPennyDigits` decimals.
  public static let subPennyBelow: Decimal = 1
  public static let subPennyDigits = 4

  /// A price rounded to its tick: "12.35" for 12.3456…, "0.4567" for 0.45671…; never a sign.
  public static func price(_ value: Decimal) -> String {
    plain(value, fractionDigits: abs(value) < subPennyBelow ? subPennyDigits : centsDigits)
  }

  /// "+$11.80", "−$1.60", "$0.00".
  public static func signedUSD(_ value: Decimal) -> String {
    let body = "$" + fixed(abs(value), fractionDigits: centsDigits)
    if rounded(value, centsDigits) == 0 { return body }
    return (value > 0 ? "+" : minus) + body
  }

  static func rounded(_ value: Decimal, _ digits: Int) -> Decimal {
    var input = value
    var output = Decimal()
    NSDecimalRound(&output, &input, digits, .plain)
    return output
  }

  static func fixed(_ value: Decimal, fractionDigits: Int) -> String {
    let number = NSDecimalNumber(decimal: rounded(value, fractionDigits))
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: posixLocale)
    formatter.numberStyle = .decimal
    formatter.usesGroupingSeparator = false
    formatter.minimumFractionDigits = fractionDigits
    formatter.maximumFractionDigits = fractionDigits
    formatter.minimumIntegerDigits = 1
    return formatter.string(from: number) ?? number.stringValue
  }
}

/// Risk arithmetic shown next to a position. Long positions only (v1 trades long only).
public enum Risk {
  /// Planned loss if the stop fills exactly: (entry − stop) × quantity. Nil when the stop is
  /// unknown or not below the entry.
  public static func plannedLoss(entry: Decimal, stop: Decimal?, quantity: Decimal) -> Decimal? {
    guard let stop, stop < entry else { return nil }
    return (entry - stop) * quantity
  }

  /// Result in R: (price − entry) / (entry − stop). Nil when R is undefined.
  public static func multiple(entry: Decimal, stop: Decimal?, price: Decimal) -> Decimal? {
    guard let stop, stop < entry else { return nil }
    return (price - entry) / (entry - stop)
  }

  /// The unit of a result in R (risk multiples); the same in every language.
  static let unit = "R"

  /// "+1.6 R", "−1.0 R".
  public static func text(_ r: Decimal) -> String { "\(Money.signed(r, fractionDigits: 1)) \(unit)" }

  /// "+0.18 R": a mean or a bound, where one decimal would hide the difference.
  public static func text(_ r: Decimal, fractionDigits: Int) -> String {
    "\(Money.signed(r, fractionDigits: fractionDigits)) \(unit)"
  }
}
