import SwiftUI
import Testing
@testable import TickrDesign

@Suite("The extended-hours band per theme (mockup v114)")
struct ChartSessionTokensTests {
  @Test("5% of the text colour in light, 9% in dark")
  func bandPerTheme() {
    #expect(Tokens.Chart.extendedBandOpacity(.light) == 0.05)
    #expect(Tokens.Chart.extendedBandOpacity(.dark) == 0.09)
  }
}
