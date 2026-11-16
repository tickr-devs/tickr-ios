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

  @Test("Only the first rows of the Trades table rise, in order; later rows and rows that rose show at once")
  func tableEntrance() {
    let ids = (0..<30).map { "t\($0)" }
    let steps = RowEntrance.steps(ids, first: 10, risen: [])
    #expect(steps.count == 10)
    #expect(steps["t0"] == 0)
    #expect(steps["t9"] == 9)
    #expect(steps["t10"] == nil, "a row past the first screenful never waits")
    #expect(steps["t29"] == nil)
    // A recycled row that has risen does not rise again; the others keep their turn.
    let again = RowEntrance.steps(ids, first: 10, risen: ["t0", "t3"])
    #expect(again["t0"] == nil)
    #expect(again["t3"] == nil)
    #expect(again["t4"] == 4)
    #expect(RowEntrance.steps([String](), first: 10, risen: []).isEmpty)
    #expect(RowEntrance.steps(ids, first: 10, risen: Set(ids)).isEmpty)
  }

  @Test("The Trades table's last rising row waits well under a second")
  func tableEntranceIsShort() {
    #expect(Double(RowEntrance.tradesRows) * Tokens.Motion.stagger < 1)
  }
}
