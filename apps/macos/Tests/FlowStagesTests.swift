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
}
