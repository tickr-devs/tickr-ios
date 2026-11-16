import Foundation
import Testing
@testable import TickrDesign

@Suite struct ControlsTests {
  // Money losses are the series pink (mockup v100); the tone follows the value as shown in cents.
  @Test(arguments: [
    ("12.5", Tone.profit), ("-0.01", Tone.series), ("0", Tone.neutral), ("-0.004", Tone.neutral),
    ("0.004", Tone.neutral), ("-0.005", Tone.series), ("0.005", Tone.profit),
  ])
  func resultTone(value: String, tone: Tone) {
    #expect(Tone.result(d(value)) == tone)
  }

  @Test(arguments: [(-0.5, 0.0), (0.4, 0.4), (1.7, 1.0)])
  func gaugesClampTheirFraction(given: Double, drawn: Double) {
    #expect(MeterBar(fraction: given, tone: .warning).fraction == drawn)
    #expect(MiniRing(fraction: given, tone: .warning, text: "").fraction == drawn)
  }
}
