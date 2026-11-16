import Foundation
import Testing
import TickrKit
@testable import TickrMac

/// The Settings session strip's pre-market label comes from the bot's calendar.
@MainActor
@Suite("Session strip")
struct SessionStripTests {
  @Test("The pre-market label carries the calendar's time; an older bot's session has none")
  func preLabel() throws {
    let session = try #require(try fixture(JobsV1.self, "jobs-v1.json").session)
    #expect(SessionStrip.preLabel(SessionSpan(session)).key == "settings.preBacklogFrom")
    var object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf:
      fixturesDir.appendingPathComponent("jobs-v1.json"))) as? [String: Any])
    var times = try #require(object["session"] as? [String: Any])
    times["premarket_open"] = nil
    times["extended_close"] = nil
    object["session"] = times
    let older = try #require(try Wire.decoder().decode(JobsV1.self,
      from: JSONSerialization.data(withJSONObject: object)).session)
    #expect(SessionStrip.preLabel(SessionSpan(older)).key == "settings.preBacklog")
  }
}
