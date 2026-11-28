import Foundation
import Testing
@testable import TickrKit

/// The fields the bot added after version 1 shipped: a day's market session, the bot run's
/// start and the operator stop's schedule cause (tickr-bot#21, #24).
struct ContractScheduleTests {
  @Test func daySessions() throws {
    let days = try Wire.decoder().decode(DaysV1.self, from: fixture("days-v1.sessions.json"))
    #expect(days.days.map(\.session) == [.half, .closed, .closed, .regular, nil])
  }

  @Test func runStartedAt() throws {
    let status = try Wire.decoder().decode(StatusResponseV1.self, from: fixture("status-response-v1.json"))
    #expect(status.schedule?.runStartedAt?.text == "2026-11-16T09:00:00.000Z")
  }

  @Test func operatorStopHasNoSchedule() throws {
    let data = try fixture("status-response-v1.operator-stopped.json")
    let status = try Wire.decoder().decode(StatusResponseV1.self, from: data)
    #expect(status.schedule == nil)
    #expect(status.scheduleCauseCodes.map(\.code) == ["operator_stopped"])
  }
}
