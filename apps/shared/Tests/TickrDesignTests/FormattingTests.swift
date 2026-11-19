import Foundation
import Testing
@testable import TickrDesign
import TickrKit

func d(_ text: String) -> Decimal { Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))! }

@Suite struct FormattingTests {
  @Test(arguments: [
    ("11.8", "+11.80"), ("-1.60", "\u{2212}1.60"), ("0", "0.00"), ("-0.001", "0.00"), ("1234.5", "+1234.50"),
  ])
  func signedMoney(value: String, shown: String) {
    #expect(Money.signed(d(value)) == shown)
  }

  @Test(arguments: [
    ("9.3", "+$9.30"), ("-4.1", "\u{2212}$4.10"), ("0", "$0.00"), ("-1234.5", "\u{2212}$1,234.50"),
    ("1000011.8", "+$1,000,011.80"),
  ])
  func signedUSD(value: String, shown: String) {
    #expect(Money.signedUSD(d(value)) == shown)
  }

  @Test func plain() {
    #expect(Money.plain(d("12.3")) == "12.30")
    #expect(Money.plain(d("-12.3")) == "12.30")
    #expect(Money.plain(d("0.125"), fractionDigits: 2) == "0.13")
  }

  @Test("A computed price shows at its tick, cents from a dollar and four decimals below")
  func price() {
    #expect(Money.price(d("12.345678901234567890123456789")) == "12.35")
    #expect(Money.price(d("1")) == "1.00")
    #expect(Money.price(d("0.456789")) == "0.4568")
    // The watched rows' recorded values: a trigger from a dollar never shows four decimals.
    #expect(Money.price(d("57.1099")) == "57.11")
    #expect(Money.price(d("9.6300")) == "9.63")
    #expect(Money.price(d("57.10")) == "57.10")
  }

  @Test("A distance between prices takes the price's decimals and never rounds down to zero")
  func priceDistance() {
    #expect(Money.priceDistance(d("0.00985"), at: d("57.1099")) == "0.01")
    #expect(Money.priceDistance(d("0.02"), at: d("9.63")) == "0.02")
    #expect(Money.priceDistance(d("0.001"), at: d("12.35")) == "0.01")
    #expect(Money.priceDistance(d("0.00012"), at: d("0.4567")) == "0.0002")
    #expect(Money.priceDistance(d("-0.5"), at: d("12")) == "0.50")
    #expect(Money.priceDistance(d("0"), at: d("12")) == "0.00")
  }

  // Every number below is the same in English and Spanish: `Money`, `Percent` and `Volume` take
  // no locale (a "." separator and the U+2212 minus whatever the person's language), so a figure
  // reads alike on both apps and in both languages. Only `DayText` follows the language.

  @Test("Owner rule: a price below a dollar shows four decimals, from a dollar two; half rounds up")
  func priceTicksByOwnerRule() {
    #expect(Money.price(d("0.4567")) == "0.4567")
    #expect(Money.price(d("0.5")) == "0.5000")
    #expect(Money.price(d("1")) == "1.00")
    // NSDecimalRound .plain: a half rounds away from zero.
    #expect(Money.price(d("12.345")) == "12.35")
    #expect(Money.price(d("0")) == "0.0000")
    #expect(Money.price(d("-0.4567")) == "0.4567")
    // From a thousand a price is grouped with ",", in every language.
    #expect(Money.price(d("1234.5")) == "1,234.50")
    #expect(Money.price(d("999.999")) == "1,000.00")
  }

  @Test("A chart's Double rounds as it reads, not as its binary value (12.345 is 12.3449999…)")
  func chartPrices() {
    #expect(Money.price(12.345 as Double) == "12.35")
    #expect(Money.price(0.4567 as Double) == "0.4567")
    #expect(Money.price(0.5 as Double) == "0.5000")
    #expect(Money.price(1 as Double) == "1.00")
    // A value that is not a number shows the shared dash, never "0.0000".
    #expect(Money.price(Double.nan) == "\u{2014}")
    #expect(Money.price(Double.infinity) == "\u{2014}")
    #expect(Money.value(-Double.infinity) == "\u{2014}")
    #expect(Money.signed(Double.nan) == "\u{2014}")
    #expect(Money.number(Double.nan) == "\u{2014}")
    #expect(Percent.signed(fraction: Double.nan) == "\u{2014}")
    #expect(Volume.compact(Double.infinity) == "\u{2014}")
  }

  @Test("A study's value keeps a price's tick and its minus")
  func chartValues() {
    #expect(Money.value(0.4567) == "0.4567")
    #expect(Money.value(-0.0123) == "\u{2212}0.0123")
    #expect(Money.value(12.345) == "12.35")
    #expect(Money.value(50) == "50.00")
    #expect(Money.value(1234.5) == "1,234.50")
    #expect(Money.number(d("-0.12")) == "\u{2212}0.12")
    #expect(Money.number(d("0.12")) == "0.12")
    #expect(Money.number(d("-0.001")) == "0.00")
    #expect(Money.number(1.5 as Double, fractionDigits: 1) == "1.5")
  }

  @Test("A price's change per share keeps the price's tick, never a dollar sign")
  func priceChange() {
    #expect(Money.priceChange(d("0.06"), at: d("12.30")) == "+0.06")
    #expect(Money.priceChange(d("-0.0012"), at: d("0.4567")) == "\u{2212}0.0012")
    #expect(Money.priceChange(d("0.06"), at: nil) == "+0.06")
    #expect(Money.priceChange(0.0012, at: 0.98) == "+0.0012")
    #expect(Money.priceChange(Double.nan, at: 12) == "\u{2014}")
  }

  @Test(arguments: [
    ("250", "$250.00"), ("-4.1", "\u{2212}$4.10"), ("0", "$0.00"), ("1234.5", "$1,234.50"),
    ("1000011.8", "$1,000,011.80"), ("-1234.5", "\u{2212}$1,234.50"),
  ])
  func usdAmount(value: String, shown: String) {
    #expect(Money.usd(d(value)) == shown)
  }

  @Test("Percentages: signed changes to two decimals, movers to one, shares whole")
  func percent() {
    #expect(Percent.signed(fraction: d("0.0621")) == "+6.21%")
    #expect(Percent.signed(fraction: d("-0.004")) == "\u{2212}0.40%")
    #expect(Percent.signed(fraction: d("0")) == "0.00%")
    #expect(Percent.signed(fraction: d("-0.00001")) == "0.00%")
    #expect(Percent.signed(fraction: 0.0621 as Double) == "+6.21%")
    #expect(Percent.signed(points: d("18.24"), fractionDigits: Percent.moverDigits) == "+18.2%")
    #expect(Percent.plain(points: d("52.4")) == "52%")
    #expect(Percent.plain(fraction: d("0.524")) == "52%")
    #expect(Percent.changeDigits == 2)
  }

  @Test("Volumes are compact in the same letters in every language")
  func volume() {
    #expect(Volume.compact(950) == "950")
    #expect(Volume.compact(23_400) == "23.4K")
    #expect(Volume.compact(1_200_000) == "1.2M")
  }

  @Test("A trading day: weekday then date, no comma, in the person's language")
  func dayText() throws {
    let day = try WireDate("2026-11-16")
    #expect(DayText.day(day, locale: Locale(identifier: "en_US")) == "Mon Nov 16")
    let spanish = DayText.day(day, locale: Locale(identifier: "es_US"))
    // The weekday's case and any abbreviation dot are the language's own (ICU may write "lun.").
    #expect(spanish.lowercased().hasPrefix("lun"), "\(spanish)")
    #expect(spanish.contains("16"))
    #expect(spanish.lowercased().contains("nov"))
    #expect(!spanish.contains(","))
  }

  @Test func risk() {
    #expect(Risk.plannedLoss(entry: d("12.34"), stop: d("11.90"), quantity: d("10")) == d("4.4"))
    #expect(Risk.plannedLoss(entry: d("12.34"), stop: nil, quantity: d("10")) == nil)
    #expect(Risk.plannedLoss(entry: d("12.34"), stop: d("12.50"), quantity: d("10")) == nil)
    #expect(Risk.multiple(entry: d("10"), stop: d("9"), price: d("11.5")) == d("1.5"))
    #expect(Risk.multiple(entry: d("10"), stop: d("10"), price: d("11")) == nil)
    #expect(Risk.text(d("-1")) == "\u{2212}1.0 R")
  }
}
