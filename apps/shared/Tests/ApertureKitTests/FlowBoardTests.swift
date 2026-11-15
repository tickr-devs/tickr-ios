import Foundation
import Testing

@testable import ApertureKit

@Suite("Flow board")
struct FlowBoardTests {
  @Test("Each symbol sits once at its furthest stage; exclusions and stops shape it")
  func marksFromTheFixtures() throws {
    let flow = try Wire.decoder().decode(FlowV1.self, from: fixture("flow-v1.json"))
    let skipped = try Wire.decoder().decode(SkippedV1.self, from: fixture("skipped-v1.json"))
    let marks = FlowBoard.marks(flow: flow, skipped: skipped)
    #expect(marks.map(\.id) == ["ABCD", "EFGH", "SPY", "WXYZ"])
    #expect(marks.map(\.stage) == [.order, .order, .universe, .stop])
    #expect(marks.map(\.tone) == [.pending, .alarm, .normal, .normal])
    // SPY was left out by the universe; ABCD's later refusal does not undo its fill.
    #expect(marks.map(\.refused) == [false, false, true, false])
    #expect(marks[2].note == "SECURITY_TYPE_NOT_ALLOWED: ETF")
  }

  @Test("A symbol risk refused that never passed risk sits in the risk tray")
  func refusedByRisk() throws {
    let flow = try Wire.decoder().decode(FlowV1.self, from: fixture("flow-v1.json"))
    let skipped = try Wire.decoder().decode(SkippedV1.self, from: fixture("skipped-v1.json"))
    var json = try #require(JSONSerialization.jsonObject(with: fixture("flow-v1.json")) as? [String: Any])
    var stages = try #require(json["stages"] as? [[String: Any]])
    for index in stages.indices where ["risk", "order"].contains(stages[index]["stage"] as? String) {
      stages[index]["symbols"] = ["EFGH", "WXYZ"]
      stages[index]["count"] = 2
    }
    json["stages"] = stages
    let trimmed = try Wire.decoder().decode(FlowV1.self, from: JSONSerialization.data(withJSONObject: json))
    let abcd = try #require(FlowBoard.marks(flow: trimmed, skipped: skipped).first { $0.id == "ABCD" })
    #expect(abcd.stage == .risk)
    #expect(abcd.refused)
    #expect(abcd.note == "1 open position(s), limit 1")
    #expect(FlowBoard.marks(flow: flow, skipped: nil).count == 4)
    #expect(FlowBoard.marks(flow: nil, skipped: skipped).isEmpty)
  }
}
