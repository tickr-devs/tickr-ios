import Foundation
import Testing
import TickrDesign
@testable import TickrKit
@testable import TickrMac

@Suite("Motion triggers")
struct MotionTriggerTests {
  @Test("A Settings job's dot pulses when its state changes, not when the same state is read again")
  func jobDot() {
    #expect(JobDot(tone: .accent, live: true) == JobDot(tone: .accent, live: true))
    #expect(JobDot(tone: .accent, live: true) != JobDot(tone: .neutral, live: false))
    #expect(JobDot(tone: .info, live: true) != JobDot(tone: .info, live: false))
  }

  @Test("An observer's role dot pulses for a new decision or version, nothing else")
  func observerEvent() throws {
    let observers = try fixture(ObserversV1.self, "observers-v1.json")
    let observer = try #require(observers.observers.first)
    #expect(VersionEvent.observer(observer) == VersionEvent.observer(observer))
  }

  @Test("The active version's role dot pulses for a new trade of it; none without a status")
  func activeEvent() throws {
    #expect(VersionEvent.active(nil) == nil)
    let response = try fixture(StatusResponseV1.self, "status-response-v1.json")
    let event = VersionEvent.active(response.status)
    #expect(event != nil)
    #expect(event == VersionEvent.active(response.status))
    // One trade fewer: another event.
    let data = try Data(contentsOf: fixturesDir.appendingPathComponent("status-response-v1.json"))
    var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    var status = try #require(json["status"] as? [String: Any])
    let trades = try #require(status["trades_today"] as? [Any])
    try #require(!trades.isEmpty)
    status["trades_today"] = Array(trades.dropLast())
    json["status"] = status
    let fewer = try Wire.decoder().decode(StatusResponseV1.self, from: JSONSerialization.data(withJSONObject: json))
    #expect(VersionEvent.active(fewer.status) != event)
  }
}
