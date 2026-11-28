import Foundation
import TickrKit

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

  /// A price rounded to its tick: "12.35" for 12.3456…, "0.4567" for 0.45671…, "1,234.50" from a
  /// thousand (grouped with ","); never a sign.
  public static func price(_ value: Decimal) -> String {
    fixed(abs(value), fractionDigits: abs(value) < subPennyBelow ? subPennyDigits : centsDigits, grouped: true)
  }

  /// "+0.06", "−0.0012": a price's change per share at that price's tick (four decimals below
  /// one dollar, else two; two when the price is unknown), with its sign: the prices after an exit
  /// or a skipped signal on both apps. A move of the price, not an amount of money: no "$".
  public static func priceChange(_ change: Decimal, at price: Decimal?) -> String {
    let digits = price.map { abs($0) < subPennyBelow ? subPennyDigits : centsDigits } ?? centsDigits
    return signed(change, fractionDigits: digits)
  }

  /// "$11.90", "$0.4567": a price per share with its dollar sign, at its tick (`price`).
  public static func usdPrice(_ value: Decimal) -> String {
    dollar + price(value)
  }

  /// A distance between two prices in the decimals of the price it is measured at (`price`'s
  /// rule: cents from one dollar, hundredths of a cent below), rounded up so a distance that is
  /// not zero never reads as "0.00": 0.00985 at 57.11 is "0.01"; never a sign.
  public static func priceDistance(_ distance: Decimal, at price: Decimal) -> String {
    let digits = abs(price) < subPennyBelow ? subPennyDigits : centsDigits
    var input = abs(distance)
    var output = Decimal()
    NSDecimalRound(&output, &input, digits, .up)
    return fixed(output, fractionDigits: digits)
  }

  /// "+$11.80", "−$1,234.50", "$0.00": a money result (a day, a trade, an open position),
  /// thousands grouped with "," in every language.
  public static func signedUSD(_ value: Decimal) -> String {
    let body = dollar + fixed(abs(value), fractionDigits: centsDigits, grouped: true)
    if rounded(value, centsDigits) == 0 { return body }
    return (value > 0 ? "+" : minus) + body
  }

  /// "$250.00", "$1,000,011.80", "−$4.10": an amount that is not a result (room, a limit, a
  /// balance, a fee), so never a plus; a minus only when the amount itself is below zero;
  /// thousands grouped with "," in every language.
  public static func usd(_ value: Decimal) -> String {
    let body = dollar + fixed(abs(value), fractionDigits: centsDigits, grouped: true)
    return rounded(value, centsDigits) < 0 ? minus + body : body
  }

  /// "0.12", "−0.12": a value with its sign only below zero (a study's value: MACD, RSI, ATR).
  public static func number(_ value: Decimal, fractionDigits: Int = centsDigits) -> String {
    let body = fixed(abs(value), fractionDigits: fractionDigits)
    return rounded(value, fractionDigits) < 0 ? minus + body : body
  }

  /// The currency sign of every amount (the account is in US dollars).
  static let dollar = "$"
  /// What a value that is not a number shows: the shared dash.
  public static let missing = ApiText.missing
  /// Thousands separator of grouped figures, the same in every language.
  static let groupingSeparator = ","
  /// Digits per group.
  static let groupingSize = 3

  // MARK: chart values (Double)

  /// The decimal a chart's `Double` stands for, read through its shortest decimal text, so
  /// 12.345 (stored as 12.3449999…) rounds as it reads, to 12.35; zero for a value that is not
  /// finite (the text functions below show `missing` for one instead).
  public static func decimal(_ value: Double) -> Decimal {
    guard value.isFinite else { return 0 }
    return Decimal(string: String(value), locale: Locale(identifier: posixLocale)) ?? Decimal(value)
  }

  /// `price(_:)` of a chart value: the same tick on both apps' charts.
  public static func price(_ value: Double) -> String {
    value.isFinite ? price(decimal(value)) : missing
  }

  /// `signed(_:fractionDigits:)` of a chart value (a price change).
  public static func signed(_ value: Double, fractionDigits: Int = centsDigits) -> String {
    value.isFinite ? signed(decimal(value), fractionDigits: fractionDigits) : missing
  }

  /// `priceChange(_:at:)` of chart values (a candle's change from the one before).
  public static func priceChange(_ change: Double, at price: Double) -> String {
    change.isFinite ? priceChange(decimal(change), at: price.isFinite ? decimal(price) : nil) : missing
  }

  /// `number(_:fractionDigits:)` of a chart value (a study's value).
  public static func number(_ value: Double, fractionDigits: Int = centsDigits) -> String {
    value.isFinite ? number(decimal(value), fractionDigits: fractionDigits) : missing
  }

  /// A value on a chart's scale or legend (a price line, VWAP, an EMA, MACD, RSI, ATR): at a
  /// price's tick, four decimals below one in size, else two, with a minus below zero, so a study
  /// line and the price it is drawn against read alike ("0.4567", "−0.0123", "12.35").
  public static func value(_ value: Double) -> String {
    guard value.isFinite else { return missing }
    let exact = decimal(value)
    let body = price(exact)
    return rounded(exact, abs(exact) < subPennyBelow ? subPennyDigits : centsDigits) < 0 ? minus + body : body
  }

  static func rounded(_ value: Decimal, _ digits: Int) -> Decimal {
    var input = value
    var output = Decimal()
    NSDecimalRound(&output, &input, digits, .plain)
    return output
  }

  static func fixed(_ value: Decimal, fractionDigits: Int, grouped: Bool = false) -> String {
    let number = NSDecimalNumber(decimal: rounded(value, fractionDigits))
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: posixLocale)
    formatter.numberStyle = .decimal
    formatter.usesGroupingSeparator = grouped
    formatter.groupingSeparator = groupingSeparator
    formatter.groupingSize = groupingSize
    formatter.minimumFractionDigits = fractionDigits
    formatter.maximumFractionDigits = fractionDigits
    formatter.minimumIntegerDigits = 1
    return formatter.string(from: number) ?? number.stringValue
  }
}

extension PriceText {
  /// The apps' one price rule (`Money.price`, `Money.priceDistance`) for TickrKit's sentences.
  public static let money = PriceText(price: Money.price, distance: Money.priceDistance)
}

/// A number of shares, as the Risk room card counts them.
public enum Shares {
  /// From this many shares a count is shown in millions ("5.6M"), so a limit that allows a huge
  /// size never pushes its row's label onto more lines than the design's (mockup v115).
  public static let millionsFrom: Decimal = 1_000_000
  /// Decimals of a count in millions.
  static let millionsDigits = 1
  /// After a count in millions.
  static let millionsSign = "M"

  /// "3,521", "24,333", "5.6M": grouped with "," in every language, millions with one decimal
  /// rounded down (never more than the limit allows).
  public static func text(_ value: Decimal) -> String {
    guard abs(value) >= millionsFrom else { return Money.fixed(value, fractionDigits: 0, grouped: true) }
    var input = value / millionsFrom
    var output = Decimal()
    NSDecimalRound(&output, &input, millionsDigits, .down)
    return Money.fixed(output, fractionDigits: millionsDigits) + millionsSign
  }
}

extension SizeText {
  /// The apps' one money, price and share-count rules for the "Last entry size" block: a price per
  /// share is an amount here, so it carries the dollar sign ("$0.7100").
  public static let money = SizeText(usd: Money.usd, price: Money.usdPrice, shares: Shares.text)
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

/// Percentages, locale-independent like `Money`: "+6.21%", "52%", a minus U+2212.
public enum Percent {
  /// Decimals of a price's change in percent: the Chart's day change and its readout, both apps
  /// (the MacChart board's "+0.98%").
  public static let changeDigits = 2
  /// Decimals of a screener's change (the boards' mover chips: "+18.2%").
  public static let moverDigits = 1
  /// Percent points in a whole.
  static let pointsPerWhole: Decimal = 100
  /// The sign after the number, in every language.
  static let sign = "%"

  /// "+6.21%", "−0.40%", "0.00%" from a fraction (0.0621).
  public static func signed(fraction: Decimal, fractionDigits: Int = changeDigits) -> String {
    signed(points: fraction * pointsPerWhole, fractionDigits: fractionDigits)
  }

  /// The same from a chart value.
  public static func signed(fraction: Double, fractionDigits: Int = changeDigits) -> String {
    fraction.isFinite ? signed(fraction: Money.decimal(fraction), fractionDigits: fractionDigits) : Money.missing
  }

  /// "+18.2%" from points (18.24).
  public static func signed(points: Decimal, fractionDigits: Int = changeDigits) -> String {
    Money.signed(points, fractionDigits: fractionDigits) + sign
  }

  /// "52%" from points (52.4): a share, a win rate; never a sign.
  public static func plain(points: Decimal, fractionDigits: Int = StatDigits.percent) -> String {
    Money.plain(points, fractionDigits: fractionDigits) + sign
  }

  /// "52%" from a fraction (0.524).
  public static func plain(fraction: Decimal, fractionDigits: Int = StatDigits.percent) -> String {
    plain(points: fraction * pointsPerWhole, fractionDigits: fractionDigits)
  }
}

/// Share volumes: "950", "23.4K", "1.2M", in the same letters in every language.
public enum Volume {
  /// The locale whose short compact names the apps show (K, M, B).
  static let compactLocale = "en_US"
  /// Most decimals of a compact volume.
  static let digits = 1

  public static func compact(_ value: Double) -> String {
    guard value.isFinite else { return Money.missing }
    return value.formatted(.number.notation(.compactName).precision(.fractionLength(0...digits))
      .locale(Locale(identifier: compactLocale)))
  }
}

/// A trading day as both apps write it: weekday, then the date, no comma ("Fri Nov 13",
/// "vie 13 nov"), the New York day whatever the device's time zone (noon in New York is already
/// the next day from UTC+7 eastward).
public enum DayText {
  public static func day(_ date: Date, locale: Locale = .autoupdatingCurrent) -> String {
    WireDate.dayText(date, locale: locale)
  }

  public static func day(_ day: WireDate, locale: Locale = .autoupdatingCurrent) -> String {
    day.dayText(locale: locale)
  }
}
