@testable import ApertureKit
import Foundation
import Testing

@Suite("Decision runs and chart symbol order")
struct DecisionRunsTests {
  /// A decision at minute `minute` past 15:00 UTC; `skipped` gives it what-if levels (a refused
  /// ENTER), `failed` the rule of a check that did not pass.
  func decision(
    _ minute: Int,
    _ action: String,
    _ name: String = "price-action",
    version: String = "1",
    observer: Bool = false,
    skipped: Bool = false,
    failed: String? = nil
  ) throws -> DecisionV1 {
    let levels = skipped ? #""entry_price": "12.40", "stop_price": "12.10""# : #""entry_price": null, "stop_price": null"#
    let checks = failed.map {
      #"[{"rule": "\#($0)", "measured": null, "operator": "is", "threshold": null, "passed": false, "note": ""}]"#
    } ?? "[]"
    let json = """
      {"at": "2026-11-16T15:\(String(format: "%02d", minute)):00.000Z", "action": "\(action)",
       "strategy": {"name": "\(name)", "version": "\(version)"}, "observer": \(observer),
       "checks": \(checks), \(levels)}
      """
    return try Wire.decoder().decode(DecisionV1.self, from: Data(json.utf8))
  }

  @Test("Repeats of one verdict by one strategy merge; another verdict or strategy starts a run")
  func merge() throws {
    let runs = DecisionRun.merge([
      try decision(3, "ENTER", observer: true), try decision(2, "ENTER", observer: true),
      try decision(1, "ENTER", observer: true), try decision(0, "EXIT", observer: true),
      try decision(0, "EXIT", "other", observer: true),
    ])
    #expect(runs.map(\.count) == [3, 1, 1])
    let newest = try decision(3, "ENTER")
    let oldest = try decision(1, "ENTER")
    #expect(runs[0].latest.at == newest.at)
    #expect(runs[0].earliest.at == oldest.at)
  }

  @Test("A taken entry never merges with a refused one, nor decisions whose checks differ")
  func outcomes() throws {
    let runs = DecisionRun.merge([
      try decision(40, "ENTER", skipped: true, failed: "symbol_not_paused"),
      try decision(39, "ENTER", skipped: true, failed: "symbol_not_paused"),
      try decision(5, "ENTER"),
      try decision(4, "WATCH", failed: "ask_above_trigger"),
      try decision(3, "WATCH", failed: "volume_surge"),
    ])
    #expect(runs.map(\.count) == [2, 1, 1, 1])
    #expect(runs[1].latest.entryPrice == nil)
  }

  @Test("Entries an hour apart with holding between them are two rows, not a run of two")
  func runsBeforeFilter() throws {
    let list = DecisionList([try decision(0, "ENTER"), try decision(1, "HOLD"), try decision(2, "HOLD"),
      try decision(59, "ENTER")], everything: false)
    #expect(list.strategy.map(\.count) == [1, 1])
  }

  @Test("The trading strategy leads; ten observer entries in a row are one run")
  func strategyLeads() throws {
    var decisions = try (0..<10).map { try decision($0, "ENTER", "price-action-v2", version: "2", observer: true) }
    decisions.append(try decision(10, "ENTER"))
    decisions.append(try decision(11, "WATCH"))
    let list = DecisionList(decisions, everything: false)
    #expect(list.strategy.map(\.count) == [1])
    #expect(list.strategy[0].latest.action == .enter)
    #expect(list.observers.map { $0.map(\.count) } == [[10]])
    #expect(list.total == 12)
    #expect(list.key == 11)
  }

  @Test("Everything keeps watching and holding, newest first")
  func everything() throws {
    let list = DecisionList([try decision(0, "WATCH"), try decision(1, "WATCH"), try decision(2, "ENTER"),
      try decision(3, "HOLD")], everything: true)
    #expect(list.strategy.map(\.latest.action) == [.hold, .enter, .watch])
    #expect(list.strategy.map(\.count) == [1, 1, 2])
    #expect(list.observers.isEmpty)
  }

  @Test("Observers each get their own runs, the one with the newest decision first")
  func observersApart() throws {
    let list = DecisionList([
      try decision(0, "ENTER", "a", observer: true), try decision(0, "ENTER", "b", observer: true),
      try decision(1, "ENTER", "a", observer: true), try decision(1, "ENTER", "b", observer: true),
    ], everything: false)
    #expect(list.observers.map { $0.map(\.count) } == [[2], [2]])
    #expect(list.observers.map { $0[0].latest.strategy.name } == ["b", "a"])
    #expect(list.strategy.isEmpty)
    #expect(!list.isEmpty)
  }

  @Test("Open positions first, then traded symbols newest first, then the rest, only with bars")
  func symbolOrder() {
    let ordered = ChartSymbols.ordered(["AAAA", "BBBB", "CCCC", "MVLD", "ZZZZ"], open: ["MVLD", "GONE"],
      traded: ["BBBB", "ZZZZ", "MVLD"])
    #expect(ordered == ["MVLD", "ZZZZ", "BBBB", "AAAA", "CCCC"])
  }
}
