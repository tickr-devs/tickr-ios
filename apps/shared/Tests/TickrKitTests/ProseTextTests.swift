import Foundation
import Testing
@testable import TickrKit

@Suite("Causes the API writes itself, in the person's language")
struct ProseTextTests {
  func days() throws -> [DaySummary] {
    try Wire.decoder().decode(DaysV1.self, from: fixture("days-v1.json")).days
  }

  @Test("Each part reads as its sentence; a quoted fence reads as its title and its own cause")
  func cleanDayCauses() throws {
    let days = try days()
    let open = try #require(days.first { $0.clean.cause == "the day is not over" })
    #expect(ApiText.prose(open.clean.causeCodes, text: open.clean.cause)
      == ProseReason.dayNotOver.text([:]))

    let dirty = try #require(days.first { $0.clean.verdict == .notClean })
    let foreign = try #require(dirty.clean.causes.first { $0.textCodes.count == 2 })
    let mismatch = try #require(foreign.textCodes.last)
    let fence = try #require(FenceReason.foreignOrder.text([:]))
    let reconcile = try #require(ProseReason.reconcileMismatch.text(mismatch.params))
    #expect(ApiText.prose(foreign.textCodes, text: foreign.text)
      == ApiText.fenceTitle("foreign-order:manual-1") + ApiText.detailSeparator + fence
      + ApiText.proseSeparator + reconcile)
    #expect(ApiText.prose(foreign.textCodes, text: foreign.text) != foreign.text)
  }

  @Test("No codes, an unknown code or a missing value: the bot's own words, never half translated")
  func fallback() {
    let known = ReasonV1(code: ProseReason.dayNotOver.rawValue, params: [:])
    let unknown = ReasonV1(code: "unrecognized", params: [:])
    let missing = ReasonV1(code: ProseReason.safetyExit.rawValue, params: [:])
    #expect(ApiText.prose([], text: "bot words") == "bot words")
    #expect(ApiText.prose([known, unknown], text: "bot words") == "bot words")
    #expect(ApiText.prose([missing], text: "bot words") == "bot words")
    #expect(ApiText.prose([known], text: nil) == nil)
  }
}
