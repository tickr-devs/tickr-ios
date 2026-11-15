import Foundation
import Testing
@testable import TickrKit

@Suite("Advisor proposal path, change directions and hold-out scale")
struct AdvisorPathTests {
  func runs() throws -> AdvisorRunsV1 {
    try Wire.decoder().decode(AdvisorRunsV1.self, from: fixture("advisor-runs-v1.json"))
  }

  /// settings-v1 with other observers.
  func settings(observers: [String]) throws -> SettingsV1 {
    var raw = try #require(try JSONSerialization.jsonObject(with: fixture("settings-v1.json")) as? [String: Any])
    raw["observers"] = observers
    return try Wire.decoder().decode(SettingsV1.self, from: JSONSerialization.data(withJSONObject: raw))
  }

  @Test("A judged proposal: proposed and judged, decided once noted, observer from the settings")
  func path() throws {
    let all = try runs()
    let proposal = all.runs[0]
    #expect(proposal.proposedFolder == "price-action-v1-v2")
    #expect(proposal.reached(.proposed, settings: nil))
    #expect(proposal.reached(.judged, settings: nil))
    #expect(!proposal.reached(.decided, settings: nil))
    #expect(!proposal.reached(.observer, settings: nil))
    #expect(proposal.reached(.observer, settings: try settings(observers: ["price-action-v1-v2"])))
    #expect(!proposal.reached(.active, settings: try settings(observers: [])))
    #expect(proposal.judge?.candidate == "price-action-v1 v2")
    let idea = all.runs[1]
    #expect(idea.proposedFolder == nil && idea.reached(.decided, settings: nil))
    #expect(!idea.reached(.observer, settings: try settings(observers: ["price-action-v1-v2"])))
    let refused = all.runs[2]
    #expect(!refused.reached(.proposed, settings: nil) && !refused.awaitingReview)
    #expect(all.lead?.id == proposal.id)
  }

  @Test("A proposal judged only under another name has no judge result and is not judged")
  func otherJudge() throws {
    var raw = try #require(try JSONSerialization.jsonObject(with: fixture("advisor-runs-v1.json")) as? [String: Any])
    var runs = try #require(raw["runs"] as? [[String: Any]])
    var judges = try #require(runs[0]["judges"] as? [[String: Any]])
    judges[0]["candidate"] = "price-action-v1 v9"
    runs[0]["judges"] = judges
    raw["runs"] = runs
    let decoded = try Wire.decoder().decode(AdvisorRunsV1.self, from: JSONSerialization.data(withJSONObject: raw))
    let proposal = decoded.runs[0]
    #expect(proposal.judge == nil)
    #expect(!proposal.reached(.judged, settings: nil))
  }

  @Test("Numbers move up or down; a switch only changes")
  func directions() throws {
    let changes = try runs().runs[0].changes
    #expect(changes.map(\.direction) == [.up, .changed])
    #expect(changes[0].path == "exit.stop_buffer_atr")
  }

  @Test("Base and candidate share a symmetric axis around 0 R")
  func scale() throws {
    let judge = try #require(try runs().runs[0].judge)
    let scale = HoldoutScale(judge)
    #expect(scale.bound == Decimal(string: "0.39"))
    #expect(scale.fraction(0) == 0.5)
    #expect(scale.fraction(Decimal(string: "-0.39")!) == 0)
    #expect(scale.fraction(Decimal(string: "5")!) == 1)
  }
}
