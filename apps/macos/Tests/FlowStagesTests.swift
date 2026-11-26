import Foundation
import Testing
@testable import TickrKit
@testable import TickrMac

@Suite("The reconcile stage of the Overview pipeline")
struct FlowStagesTests {
  /// The latest reconciliation of the full flow fixture (match) and of the empty one (unknown).
  private func latest(_ name: String) throws -> FlowReconcileV1 {
    try fixture(FlowV1.self, name).reconcile
  }

  @Test("Live fences outrank a matching reconciliation")
  func fencesBeforeMatch() throws {
    let fences = try #require(try latest("flow-v1.json").fences)
    let stage = FlowStages.reconcile(liveFences: fences, latest: try latest("flow-v1.json"))
    #expect(stage.value == String(localized: L10n.Common.fences(fences.count)))
    #expect(stage.value != String(localized: L10n.Flow.match))
    #expect(stage.agrees == false)
  }

  @Test("Without live fences a match reads as a match")
  func match() throws {
    let stage = FlowStages.reconcile(liveFences: [], latest: try latest("flow-v1.json"))
    #expect(stage == .init(value: String(localized: L10n.Flow.match), note: nil, agrees: true))
  }

  @Test("An unknown agreement is not shown as fine; its cause becomes the tooltip")
  func unknown() throws {
    let empty = try latest("flow-v1.empty.json")
    let stage = FlowStages.reconcile(liveFences: [], latest: empty)
    #expect(stage.value == nil)
    #expect(stage.note == empty.agreementCauseText)
    #expect(stage.note != empty.agreementCause)
    #expect(stage.agrees == nil)
    #expect(FlowStages.reconcile(liveFences: nil, latest: nil) == .init(value: nil, note: nil))
  }

  /// A recorded day's clean-day verdict, with `causes` as JSON.
  private func clean(_ verdict: String, rows: Int, causes: String = "[]") throws -> CleanDay {
    let json = """
      {"verdict": "\(verdict)", "cause": null, "causes": \(causes), "reconcile_rows": \(rows),
       "first_reconcile_at": null, "last_reconcile_at": null, "day_end_seq": 1}
      """
    return try Wire.decoder().decode(CleanDay.self, from: Data(json.utf8))
  }

  @Test("A recorded clean day with reconciliation passes reads as a match, not a bare dash")
  func recordedMatch() throws {
    let stage = FlowStages.reconcile(recorded: try clean("clean", rows: 3))
    #expect(stage == .init(value: String(localized: L10n.Flow.match), note: nil, agrees: true))
  }

  @Test("A recorded mismatch reads as a mismatch; a day with no pass or no verdict stays unknown")
  func recordedOther() throws {
    let mismatch = """
      [{"kind": "reconcile_mismatch", "text": "positions differ", "journal_seqs": [7]}]
      """
    #expect(FlowStages.reconcile(recorded: try clean("not_clean", rows: 3, causes: mismatch)).agrees == false)
    #expect(FlowStages.reconcile(recorded: try clean("clean", rows: 0)).value == nil)
    #expect(FlowStages.reconcile(recorded: try clean("unknown", rows: 3)).agrees == nil)
  }
}

@Suite("What each early stage of the Overview pipeline dropped")
struct FlowDropsTests {
  @Test("Each stage drops the difference to the one before; the first drops nothing")
  func funnel() {
    #expect(FlowStages.dropped([412, 268, 141, 96]) == [nil, 144, 127, 45])
  }

  @Test("An unknown count, or one not below the stage before, drops nothing (never a guess or a minus zero)")
  func unknownOrNoDrop() {
    #expect(FlowStages.dropped([412, nil, 141, 141]) == [nil, nil, nil, nil])
    #expect(FlowStages.dropped([100, 120]) == [nil, nil])
    #expect(FlowStages.dropped([]) == [])
  }
}
