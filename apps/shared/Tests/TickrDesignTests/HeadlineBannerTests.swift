import Testing
import TickrDesign
import TickrKit

/// What the shared headline shows (mockup v108).
@Suite struct HeadlineBannerTests {
  @Test("An alarm hides the gate badge; otherwise the gate shows as the bot gives it")
  func alarmHidesGate() {
    #expect(HeadlineBanner.shownGate(.open, alarm: true) == nil)
    #expect(HeadlineBanner.shownGate(.paused, alarm: true) == nil)
    #expect(HeadlineBanner.shownGate(.open, alarm: false) == .open)
    #expect(HeadlineBanner.shownGate(.paused, alarm: false) == .paused)
  }

  @Test("Before the inline '·' a title's full stop is dropped; an alarm keeps its sentence")
  func titleBeforeTheSeparator() {
    #expect(HeadlineBanner.shownTitle("Outside the regular session.", alarm: false, hasDetail: true)
      == "Outside the regular session")
    #expect(HeadlineBanner.shownTitle("Outside the regular session.", alarm: false, hasDetail: false)
      == "Outside the regular session.")
    #expect(HeadlineBanner.shownTitle("Stop missing on ABCD.", alarm: true, hasDetail: true) == "Stop missing on ABCD.")
  }
}
