@testable import ApertureDesign
import XCTest

final class FormattingTests: XCTestCase {
  func d(_ text: String) -> Decimal { Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))! }

  func testSignedMoney() {
    XCTAssertEqual(Money.signed(d("11.8")), "+11.80")
    XCTAssertEqual(Money.signed(d("-1.60")), "\u{2212}1.60")
    XCTAssertEqual(Money.signed(d("0")), "0.00")
    XCTAssertEqual(Money.signed(d("-0.001")), "0.00")
    XCTAssertEqual(Money.signed(d("1234.5")), "+1234.50")
  }

  func testSignedUSD() {
    XCTAssertEqual(Money.signedUSD(d("9.3")), "+$9.30")
    XCTAssertEqual(Money.signedUSD(d("-4.1")), "\u{2212}$4.10")
    XCTAssertEqual(Money.signedUSD(d("0")), "$0.00")
  }

  func testPlain() {
    XCTAssertEqual(Money.plain(d("12.3")), "12.30")
    XCTAssertEqual(Money.plain(d("-12.3")), "12.30")
    XCTAssertEqual(Money.plain(d("0.125"), fractionDigits: 2), "0.13")
  }

  func testRisk() {
    XCTAssertEqual(Risk.plannedLoss(entry: d("12.34"), stop: d("11.90"), quantity: d("10")), d("4.4"))
    XCTAssertNil(Risk.plannedLoss(entry: d("12.34"), stop: nil, quantity: d("10")))
    XCTAssertNil(Risk.plannedLoss(entry: d("12.34"), stop: d("12.50"), quantity: d("10")))
    XCTAssertEqual(Risk.multiple(entry: d("10"), stop: d("9"), price: d("11.5")), d("1.5"))
    XCTAssertNil(Risk.multiple(entry: d("10"), stop: d("10"), price: d("11")))
    XCTAssertEqual(Risk.text(d("-1")), "\u{2212}1.0 R")
  }
}
