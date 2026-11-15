@testable import ApertureKit
@testable import ApertureMac
import Foundation
import Testing

@Suite("Why a signal was refused, as the app shows it")
struct RefusalTextTests {
  @Test("The message reads alone, a cooldown adds its end, and an old record keeps its cause")
  func text() throws {
    let signals = try fixture(SkippedV1.self, "skipped-v1.json").signals
    let limit = try #require(signals.first { $0.symbol == "ABCD" })
    #expect(RefusalText.text(limit.refusal, cause: limit.refusalCause) == limit.refusal?.message)
    let cooldown = try #require(signals.first { $0.symbol == "ZNTH" })
    let refusal = try #require(cooldown.refusal)
    let until = try #require(refusal.until)
    #expect(RefusalText.text(refusal, cause: cooldown.refusalCause)
      == String(localized: L10n.Trades.refusedUntil(refusal.message, Format.marketMinute(until.date))))
    #expect(RefusalText.text(nil, cause: "OLD_CAUSE") == "OLD_CAUSE")
    #expect(RefusalText.text(nil, cause: nil) == nil)
  }
}
