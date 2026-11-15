@testable import ApertureDesign
import Foundation
import Testing

@Suite struct ControlsTests {
  @Test(arguments: [("12.5", Tone.profit), ("-0.01", Tone.loss), ("0", Tone.neutral)])
  func resultTone(value: String, tone: Tone) {
    #expect(Tone.result(d(value)) == tone)
  }

  @Test(arguments: [(-0.5, 0.0), (0.4, 0.4), (1.7, 1.0)])
  func gaugesClampTheirFraction(given: Double, drawn: Double) {
    #expect(MeterBar(fraction: given, tone: .warning).fraction == drawn)
    #expect(MiniRing(fraction: given, tone: .warning, text: "").fraction == drawn)
  }
}
