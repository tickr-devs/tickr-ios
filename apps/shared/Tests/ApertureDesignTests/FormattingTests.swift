@testable import ApertureDesign
import Foundation
import Testing

func d(_ text: String) -> Decimal { Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))! }

@Suite struct FormattingTests {
  @Test(arguments: [
    ("11.8", "+11.80"), ("-1.60", "\u{2212}1.60"), ("0", "0.00"), ("-0.001", "0.00"), ("1234.5", "+1234.50"),
  ])
  func signedMoney(value: String, shown: String) {
    #expect(Money.signed(d(value)) == shown)
  }

  @Test(arguments: [("9.3", "+$9.30"), ("-4.1", "\u{2212}$4.10"), ("0", "$0.00")])
  func signedUSD(value: String, shown: String) {
    #expect(Money.signedUSD(d(value)) == shown)
  }

  @Test func plain() {
    #expect(Money.plain(d("12.3")) == "12.30")
    #expect(Money.plain(d("-12.3")) == "12.30")
    #expect(Money.plain(d("0.125"), fractionDigits: 2) == "0.13")
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
