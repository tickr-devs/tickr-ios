import Foundation
import Testing
@testable import TickrKit

@Suite("Elapsed time in words")
struct ElapsedTests {
  @Test("Seconds, minutes, hours and days, each a small whole number")
  func units() {
    #expect(Elapsed.text(seconds: 47) == String(localized: L10n.elapsedSeconds(47)))
    #expect(Elapsed.text(seconds: Elapsed.secondsShownUpTo - 1)
      == String(localized: L10n.elapsedSeconds(Elapsed.secondsShownUpTo - 1)))
    #expect(Elapsed.text(seconds: Elapsed.secondsShownUpTo) == String(localized: L10n.elapsedMinutes(2)))
    #expect(Elapsed.text(seconds: 3 * 3_600) == String(localized: L10n.elapsedHours(3)))
    // The owner's screenshot (2026-11-28): a status 179,318 s old reads "2 d", never seconds.
    #expect(Elapsed.text(seconds: 179_318) == String(localized: L10n.elapsedDays(2)))
  }

  @Test("A clock behind the status reads 0 s, never a negative age")
  func negative() {
    #expect(Elapsed.text(seconds: -5) == String(localized: L10n.elapsedSeconds(0)))
  }
}
