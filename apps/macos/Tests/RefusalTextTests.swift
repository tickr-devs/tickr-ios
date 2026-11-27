import Foundation
import Testing
@testable import TickrKit
@testable import TickrScreens

@Suite("Why a signal was refused, as the app shows it")
struct RefusalTextTests {
  @Test("The translated detail reads alone, the cooldown's names its end, and an old record reads in words, never as its code")
  func text() throws {
    let signals = try fixture(SkippedV1.self, "skipped-v1.json").signals
    let limit = try #require(signals.first { $0.symbol == "ABCD" })
    let limitRefusal = try #require(limit.refusal)
    #expect(RefusalText.text(limitRefusal, cause: limit.refusalCause) == ApiText.refusal(limitRefusal))
    #expect(RefusalText.text(limitRefusal, cause: limit.refusalCause) != limitRefusal.message)
    let cooldown = try #require(signals.first { $0.symbol == "ZNTH" })
    let refusal = try #require(cooldown.refusal)
    let sentence = try #require(RefusalReason.symbolCooldown.text(refusal.params))
    #expect(RefusalText.text(refusal, cause: cooldown.refusalCause) == sentence)
    #expect(RefusalText.text(nil, cause: "OLD_CAUSE") == String(localized: L10n.Cause.other))
    #expect(RefusalText.text(nil, cause: "OLD_CAUSE: x") == String(localized: L10n.Cause.other) + ": x")
    #expect(RefusalText.text(nil, cause: "BROKER_READ_STALE: read 9 s old")
      == String(localized: L10n.Cause.title(.brokerReadStale)) + ": read 9 s old")
    #expect(RefusalText.text(nil, cause: "setup no longer valid") == "setup no longer valid")
    #expect(RefusalText.text(nil, cause: nil) == nil)
  }
}
