import Foundation
import Testing
@testable import TickrDesign
import TickrKit

/// The entry model's pieces: the confidence meter's reading and the reason list's rows.
@Suite struct ModelPiecesTests {
  @Test("A confidence and a cutoff outside 0...1 are drawn at the nearest end")
  func clamps() {
    let high = ConfidenceReading(confidence: 1.3, cutoff: -0.2)
    #expect(high.confidence == 1)
    #expect(high.cutoff == 0)
    #expect(ConfidenceReading(confidence: -0.5, cutoff: 1.5).confidence == 0)
    #expect(ConfidenceReading(confidence: -0.5, cutoff: 1.5).cutoff == 1)
  }

  @Test("A number that is not finite is missing: the dash, no side of the cutoff, neutral")
  func notFinite() {
    let reading = ConfidenceReading(confidence: .nan, cutoff: 0.7)
    #expect(reading.confidence == nil)
    #expect(reading.reached == nil)
    #expect(reading.tone == .neutral)
    #expect(reading.confidenceText == Money.missing)
    #expect(ConfidenceReading(confidence: 0.7, cutoff: .infinity).cutoff == nil)
  }

  @Test("At or above the cutoff is reached (accent), below it is not (info), no cutoff is neutral")
  func side() {
    #expect(ConfidenceReading(confidence: 0.74, cutoff: 0.7).reached == true)
    #expect(ConfidenceReading(confidence: 0.7, cutoff: 0.7).reached == true)
    #expect(ConfidenceReading(confidence: 0.74, cutoff: 0.7).tone == .accent)
    #expect(ConfidenceReading(confidence: 0.64, cutoff: 0.7).reached == false)
    #expect(ConfidenceReading(confidence: 0.64, cutoff: 0.7).tone == .info)
    #expect(ConfidenceReading(confidence: 0.64, cutoff: nil).reached == nil)
    #expect(ConfidenceReading(confidence: 0.64, cutoff: nil).tone == .neutral)
  }

  @Test("Percents are whole and rounded down, so a value just below the cutoff never shows the cutoff")
  func percents() {
    let reading = ConfidenceReading(confidence: 0.74, cutoff: 0.7)
    #expect(reading.confidenceText == "74%")
    #expect(reading.cutoffText == "70%")
    #expect(ConfidenceReading(confidence: 0.6999, cutoff: 0.7).confidenceText == "69%")
    #expect(ConfidenceReading(confidence: 0.29, cutoff: nil).confidenceText == "29%")
    #expect(ConfidenceReading(confidence: 1, cutoff: nil).confidenceText == "100%")
    #expect(ConfidenceReading(confidence: 0, cutoff: nil).cutoffText == nil)
  }

  @Test("VoiceOver reads the confidence with its cutoff, or alone without one")
  func spoken() {
    let reading = ConfidenceReading(confidence: 0.74, cutoff: 0.7)
    #expect(reading.spokenValue == String(localized: ModelText.confidence("74%", cutoff: "70%")))
    #expect(ConfidenceReading(confidence: 0.74, cutoff: nil).spokenValue == "74%")
  }

  @Test("A reason's sign has its own symbol and tone and a name for VoiceOver, never the colour alone")
  func signs() {
    #expect(SignedReason.Sign.helps.symbol != SignedReason.Sign.hurts.symbol)
    #expect(SignedReason.Sign.helps.tone == .profit)
    #expect(SignedReason.Sign.hurts.tone == .series)
    #expect(String(localized: SignedReason.Sign.helps.label) != String(localized: SignedReason.Sign.hurts.label))
  }

  @Test("The list draws at most its limit of reasons, in the given order, and none for a limit below one")
  func limit() {
    let reasons = [
      SignedReason(.helps, verbatim: "a"),
      SignedReason(.hurts, verbatim: "b"),
      SignedReason(.helps, verbatim: "c"),
    ]
    #expect(SignedReasonList.shown(reasons, limit: 2).map(\.sign) == [.helps, .hurts])
    #expect(SignedReasonList.shown(reasons, limit: Tokens.Model.reasonRows).count == reasons.count)
    #expect(SignedReasonList.shown(reasons, limit: -1).isEmpty)
  }
}
