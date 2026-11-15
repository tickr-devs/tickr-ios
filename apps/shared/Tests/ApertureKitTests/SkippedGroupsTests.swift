@testable import ApertureKit
import Foundation
import Testing

@Suite("Not-taken signals: causes and grouping")
struct SkippedGroupsTests {
  static let cooldown = "SYMBOL_COOLDOWN: MVLD closed at a loss at 2026-11-13T16:26:30+00:00; "
    + "no entry before 2026-11-13T16:56:30.250000+00:00"

  func signal(_ minute: Int, _ symbol: String, cause: String?) throws -> SkippedSignalV1 {
    let admission = cause == nil ? "not_evaluated" : "refused"
    let json = """
      {"at": "2026-11-13T16:\(String(format: "%02d", minute)):00.000Z", "symbol": "\(symbol)",
       "strategy": {"name": "price-action", "version": "2"}, "admission": "\(admission)",
       "refusal_cause": \(cause.map { "\"\($0)\"" } ?? "null"),
       "refusal": null,
       "entry_price": "12.345678901234567890123456789", "stop_price": null, "checks": []}
      """
    return try Wire.decoder().decode(SkippedSignalV1.self, from: Data(json.utf8))
  }

  @Test("A cause splits into its code and detail, and its times can be rewritten")
  func cause() throws {
    let cause = RefusalCause(Self.cooldown)
    #expect(cause.code == "SYMBOL_COOLDOWN")
    #expect(cause.times.count == 2)
    #expect(cause.known == .cooldown)
    #expect(cause.readable { _ in "T" } == "MVLD closed at a loss at T; no entry before T")
    let pause = try #require(cause.cooldown)
    #expect(pause.until.timeIntervalSince(pause.loss) == 1_800.25)
    #expect(RefusalCause("QUOTE_STALE: quote 9 s old > 5 s").cooldown == nil)
    #expect(RefusalCause("NEW_RULE: x").known == nil)
    #expect(RefusalCause("setup no longer valid").code == "setup no longer valid")
    #expect(RefusalCause("setup no longer valid").detail.isEmpty)
  }

  @Test("Times parse with and without fractions of a second")
  func times() {
    let times = RefusalCause(Self.cooldown).times
    #expect(times[0] == Date(timeIntervalSince1970: 1_794_587_190))
    #expect(times[1].timeIntervalSince(times[0]) == 1_800.25)
  }

  @Test("Repeats on one symbol merge across other symbols; another cause starts a new group")
  func groups() throws {
    let groups = SkippedGroup.make([
      try signal(27, "MVLD", cause: Self.cooldown),
      try signal(27, "BXVR", cause: "QUOTE_STALE: quote 9 s old > 5 s"),
      try signal(28, "MVLD", cause: Self.cooldown),
      try signal(29, "MVLD", cause: Self.cooldown),
      try signal(30, "MVLD", cause: "POSITION_LIMIT_REACHED: 1 open position(s), limit 1"),
      try signal(31, "MVLD", cause: nil),
    ])
    #expect(groups.map(\.count) == [1, 1, 3, 1])
    #expect(groups.map(\.latest.symbol) == ["MVLD", "MVLD", "MVLD", "BXVR"])
    #expect(groups[2].cause?.code == "SYMBOL_COOLDOWN")
    #expect(groups[0].cause == nil)
  }

  @Test("Refusals counted by cause, most first; signals not refused are left out")
  func counts() throws {
    let counts = RefusalCount.make([
      try signal(27, "MVLD", cause: Self.cooldown),
      try signal(27, "BXVR", cause: "QUOTE_STALE: quote 9 s old > 5 s"),
      try signal(28, "MVLD", cause: Self.cooldown),
      try signal(29, "HLQN", cause: nil),
    ])
    #expect(counts.map(\.cause.code) == ["SYMBOL_COOLDOWN", "QUOTE_STALE"])
    #expect(counts.map(\.count) == [2, 1])
  }
}
