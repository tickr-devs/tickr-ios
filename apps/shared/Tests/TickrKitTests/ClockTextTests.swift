import Foundation
import Testing
@testable import TickrKit

@Suite("ClockText: one 24-hour New York clock for both apps")
struct ClockTextTests {
  /// 2025-11-16 21:58:34 UTC is 16:58:34 in New York (EST, UTC−5).
  let afternoon = Date(timeIntervalSince1970: 1_763_330_314)

  @Test("Afternoon reads on the 24-hour clock, never 4:58:34 PM")
  func twentyFourHour() {
    #expect(ClockText.seconds(afternoon) == "16:58:34")
    #expect(ClockText.minutes(afternoon) == "16:58")
  }

  @Test("Midnight hour is 00, with two digits")
  func midnight() {
    // 2025-11-16 05:03:09 UTC is 00:03:09 in New York.
    let date = Date(timeIntervalSince1970: 1_763_269_389)
    #expect(ClockText.seconds(date) == "00:03:09")
  }
}
