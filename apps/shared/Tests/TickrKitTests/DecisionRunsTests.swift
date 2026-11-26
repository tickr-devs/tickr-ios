import Foundation
import Testing
@testable import TickrKit

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
    // The admission as the bot records it: a skipped ENTER here is a refused one, an observer's
    // ENTER is never evaluated, any other verdict has none.
    let refused = #""admission": "refused", "refusal_cause": "POSITION_LIMIT_REACHED: limit 1", "refusal": "#
      + #"{"code": "POSITION_LIMIT_REACHED", "message": "limit 1", "since": null, "until": null, "params": {}}"#
    let admission = switch (action, observer, skipped) {
    case ("ENTER", true, _): #""admission": "not_evaluated", "refusal_cause": null, "refusal": null"#
    case ("ENTER", false, true): refused
    case ("ENTER", false, false): #""admission": "taken", "refusal_cause": null, "refusal": null"#
    default: #""admission": "not_applicable", "refusal_cause": null, "refusal": null"#
    }
    let checks = failed.map {
      #"[{"rule": "\#($0)", "measured": null, "operator": "is", "threshold": null, "passed": false, "note": ""}]"#
    } ?? "[]"
    let json = """
      {"at": "2026-11-16T15:\(String(format: "%02d", minute)):00.000Z", "action": "\(action)",
       "strategy": {"name": "\(name)", "version": "\(version)"}, "observer": \(observer),
       "checks": \(checks), \(levels), \(admission)}
      """
    return try Wire.decoder().decode(DecisionV1.self, from: Data(json.utf8))
  }

  @Test("Repeats of one verdict by one strategy merge; another verdict or strategy starts a run")
  func merge() throws {
    let runs = DecisionRun.merge([
      try decision(3, "ENTER"), try decision(2, "ENTER"), try decision(1, "ENTER"), try decision(0, "EXIT"),
      try decision(0, "EXIT", "other"),
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

  @Test("A shadow strategy's decisions are left out of the list and its counts")
  func shadowLeftOut() throws {
    var decisions = try (0..<10).map { try decision($0, "ENTER", "price-action-v2", version: "2", observer: true) }
    decisions.append(try decision(10, "ENTER"))
    decisions.append(try decision(11, "WATCH"))
    let list = DecisionList(decisions, everything: false)
    #expect(list.strategy.map(\.count) == [1])
    #expect(list.strategy[0].latest.action == .enter)
    #expect(list.total == 2)
    #expect(list.key == 1)
    #expect(DecisionList(Array(decisions.prefix(10)), everything: true).isEmpty)
  }

  @Test("Everything keeps watching and holding, newest first")
  func everything() throws {
    let list = DecisionList([try decision(0, "WATCH"), try decision(1, "WATCH"), try decision(2, "ENTER"),
      try decision(3, "HOLD")], everything: true)
    #expect(list.strategy.map(\.latest.action) == [.hold, .enter, .watch])
    #expect(list.strategy.map(\.count) == [1, 1, 2])
  }

  @Test("Open positions first, then traded symbols newest first, then the rest, only with bars")
  func symbolOrder() {
    let ordered = ChartSymbols.ordered(["AAAA", "BBBB", "CCCC", "MVLD", "ZZZZ"], open: ["MVLD", "GONE"],
      traded: ["BBBB", "ZZZZ", "MVLD"])
    #expect(ordered == ["MVLD", "ZZZZ", "BBBB", "AAAA", "CCCC"])
  }

  @Test("An explanation lists the failed checks first, then the admission, then the passed checks")
  func explainLinesWhyFirst() throws {
    let json = """
      {"at": "2026-11-16T15:00:00.000Z", "action": "IGNORE",
       "strategy": {"name": "price-action", "version": "1"}, "observer": false,
       "checks": [
         {"rule": "bars_consistent", "measured": null, "operator": "is", "threshold": null, "passed": true, "note": ""},
         {"rule": "close_above_vwap", "measured": null, "operator": "is", "threshold": null, "passed": false, "note": ""},
         {"rule": "range_in_atr", "measured": null, "operator": "is", "threshold": null, "passed": true, "note": ""}],
       "entry_price": null, "stop_price": null,
       "admission": "not_applicable", "refusal_cause": null, "refusal": null}
      """
    let decision = try Wire.decoder().decode(DecisionV1.self, from: Data(json.utf8))
    #expect(decision.explainLines == [1, 3, 0, 2])
  }
}
