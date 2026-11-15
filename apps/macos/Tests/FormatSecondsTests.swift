@testable import ApertureMac
import Foundation
import Testing

@Suite("Seconds as the app shows them")
struct FormatSecondsTests {
  @Test("Ages in whole seconds, settings without trailing zeros")
  func seconds() throws {
    #expect(Format.wholeSeconds(try #require(Decimal(string: "4.00"))) == "4")
    #expect(Format.wholeSeconds(try #require(Decimal(string: "42.6"))) == "43")
    #expect(Format.secondsNumber(try #require(Decimal(string: "5.00"))) == "5")
    #expect(Format.secondsNumber(try #require(Decimal(string: "0.50"))) == "0.5")
  }
}
