import Foundation
import Testing
@testable import TickrKit

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
       "entry_price": "12.345678901234567890123456789", "stop_price": null, "checks": [],
       "prices_after": [], "prices_after_cause": "none",
       "what_if": {"result_gross_usd": null, "result_r": null, "exit_reason": null, "cause": "none"}}
      """
    return try Wire.decoder().decode(SkippedSignalV1.self, from: Data(json.utf8))
  }

  /// A refusal the bot recorded without its cause.
  func refusedWithoutCause(_ minute: Int, _ symbol: String) throws -> SkippedSignalV1 {
    let json = """
      {"at": "2026-11-13T16:\(String(format: "%02d", minute)):00.000Z", "symbol": "\(symbol)",
       "strategy": {"name": "price-action", "version": "2"}, "admission": "refused", "refusal_cause": null, "refusal": null,
       "entry_price": null, "stop_price": null, "checks": [],
       "prices_after": [], "prices_after_cause": "none",
       "what_if": {"result_gross_usd": null, "result_r": null, "exit_reason": null, "cause": "none"}}
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

  @Test("A code is told apart from prose the bot wrote without one")
  func hasCode() {
    #expect(RefusalCause(Self.cooldown).hasCode)
    #expect(RefusalCause("NEW_RULE_2: x").hasCode)
    #expect(RefusalCause("NEW_RULE").hasCode)
    #expect(!RefusalCause("setup no longer valid").hasCode)
    #expect(!RefusalCause("Setup: no longer valid").hasCode)
    #expect(!RefusalCause("").hasCode)
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

  /// A refused signal with only a structured refusal (no `refusal_cause` text).
  func refused(_ minute: Int, _ symbol: String, code: String) throws -> SkippedSignalV1 {
    let json = """
      {"at": "2026-11-13T16:\(String(format: "%02d", minute)):00.000Z", "symbol": "\(symbol)",
       "strategy": {"name": "price-action", "version": "2"}, "admission": "refused",
       "refusal_cause": null,
       "refusal": {"code": "\(code)", "message": "m\(minute)", "since": null, "until": null, "params": {}},
       "entry_price": null, "stop_price": null, "checks": [],
       "prices_after": [], "prices_after_cause": "none",
       "what_if": {"result_gross_usd": null, "result_r": null, "exit_reason": null, "cause": "none"}}
      """
    return try Wire.decoder().decode(SkippedSignalV1.self, from: Data(json.utf8))
  }

  @Test("The structured refusal code groups signals whose messages differ")
  func groupsByStructuredCode() throws {
    let groups = SkippedGroup.make([
      try refused(27, "MVLD", code: "SYMBOL_COOLDOWN"),
      try refused(28, "MVLD", code: "SYMBOL_COOLDOWN"),
      try refused(29, "MVLD", code: "QUOTE_STALE"),
    ])
    #expect(groups.map(\.count) == [1, 2])
    #expect(groups.last?.first.refusal?.message == "m27")
    // Without the cause text, the structured refusal is the row's cause.
    #expect(groups.last?.cause?.code == "SYMBOL_COOLDOWN")
    #expect(groups.last?.cause?.detail == "m28")
    let counts = RefusalCount.make([
      try refused(27, "MVLD", code: "SYMBOL_COOLDOWN"),
      try refused(28, "MVLD", code: "SYMBOL_COOLDOWN"),
    ])
    #expect(counts.map(\.cause?.code) == ["SYMBOL_COOLDOWN"])
    #expect(counts.map(\.count) == [2])
  }

  @Test("Refusals counted by cause, most first; one without a cause is kept; not refused are left out")
  func counts() throws {
    let counts = RefusalCount.make([
      try signal(27, "MVLD", cause: Self.cooldown),
      try signal(27, "BXVR", cause: "QUOTE_STALE: quote 9 s old > 5 s"),
      try signal(28, "MVLD", cause: Self.cooldown),
      try signal(29, "HLQN", cause: nil),
      try refusedWithoutCause(30, "HLQN"),
    ])
    #expect(counts.map(\.cause?.code) == ["SYMBOL_COOLDOWN", nil, "QUOTE_STALE"])
    #expect(counts.map(\.count) == [2, 1, 1])
  }

  @Test("A structured refusal lends its window: the cooldown and its end come from since and until")
  func window() throws {
    let json = """
      {"at": "2026-11-13T16:30:00.000Z", "symbol": "MVLD", "strategy": {"name": "price-action", "version": "2"},
       "admission": "refused", "refusal_cause": "SYMBOL_COOLDOWN: MVLD closed at a loss",
       "refusal": {"code": "SYMBOL_COOLDOWN", "message": "MVLD closed at a loss",
                   "since": "2026-11-13T16:26:30.000Z", "until": "2026-11-13T16:56:30.000Z",
                   "params": {"symbol": "MVLD", "until": "11:56"}},
       "entry_price": null, "stop_price": null, "checks": [],
       "prices_after": [], "prices_after_cause": "none",
       "what_if": {"result_gross_usd": null, "result_r": null, "exit_reason": null, "cause": "none"}}
      """
    let signal = try Wire.decoder().decode(SkippedSignalV1.self, from: Data(json.utf8))
    let cause = try #require(SkippedGroup.make([signal]).first?.cause)
    let pause = try #require(cause.cooldown)
    #expect(pause.until.timeIntervalSince(pause.loss) == 1_800)
    #expect(cause.until == pause.until)
    #expect(RefusalCount.make([signal]).first?.cause?.until == pause.until)
  }

  @Test("Each refusal family has its symbol")
  func refusalSymbols() {
    #expect(RefusalCode.gateClosed.symbol == RefusalCode.gateSymbol)
    #expect(RefusalCode.cooldown.symbol == RefusalCode.cooldownSymbol)
    #expect(RefusalCode.quoteStale.symbol == RefusalCode.quoteSymbol)
    #expect(RefusalCode.dailyCeiling.symbol == RefusalCode.sizeSymbol)
  }
}
