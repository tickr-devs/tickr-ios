import Foundation
import Testing

@testable import TickrKit

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
    #expect(marks[2].note == String(localized: L10n.universeType("ETF")))
  }

  @Test("A universe exclusion reads in words, never as its code")
  func exclusions() {
    #expect(FlowBoard.exclusion("EXCHANGE_NOT_ALLOWED: OTC") == String(localized: L10n.universeExchange("OTC")))
    #expect(FlowBoard.exclusion("CONFLICTING_ROWS: AAA/X/USD/CS; BBB/X/USD/CS")
      == String(localized: L10n.universeConflictingRows))
    #expect(FlowBoard.exclusion("NEW_FILTER: 3") == String(localized: L10n.universeOther))
    #expect(FlowBoard.exclusion("left out by hand") == "left out by hand")
  }

  @Test("A refusal recorded as text reads without its code, its times in New York")
  func recordedRefusals() throws {
    let cooldown = "SYMBOL_COOLDOWN: MVLD closed at a loss at 2026-11-13T16:26:30+00:00"
    let time = try #require(try? Date("2026-11-13T16:26:30Z", strategy: .iso8601))
    #expect(FlowBoard.newYorkMinute(time) == "11:26")
    #expect(FlowBoard.recordedRefusal(cooldown)
      == String(localized: L10n.refusedByRiskDetail("MVLD closed at a loss at 11:26")))
    #expect(FlowBoard.recordedRefusal("NEW_RULE") == String(localized: L10n.refusedByRisk))
    #expect(FlowBoard.recordedRefusal("setup no longer valid") == "setup no longer valid")
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
    // The refusal's detail in the reader's language, from its code and values.
    #expect(abcd.note == RefusalReason.positionLimitReached.text(["open": "1", "limit": "1"]))
    #expect(FlowBoard.marks(flow: flow, skipped: nil).count == 4)
    #expect(FlowBoard.marks(flow: nil, skipped: skipped).isEmpty)
  }

  @Test("An open position's own stop state colours its mark, not the stage's")
  func openPositionTone() throws {
    let flow = try Wire.decoder().decode(FlowV1.self, from: fixture("flow-v1.json"))
    let status = try #require(Wire.decoder().decode(StatusResponseV1.self, from: fixture("status-response-v1.json")).status)
    // The flow still says ABCD's stop is pending; the status, newer, says it is verified.
    let marks = FlowBoard.marks(flow: flow, skipped: nil, positions: status.positions)
    #expect(marks.first { $0.id == "ABCD" }?.tone == .normal)
    #expect(marks.first { $0.id == "EFGH" }?.tone == .alarm)
  }
}
