import Foundation
import Testing
@testable import TickrKit

@Suite("When the bot is meant to run")
struct StatusScheduleTests {
  @Test("Off schedule: not expected to run, with the next run and the last trading day")
  func offSchedule() throws {
    let response = try Wire.decoder().decode(StatusResponseV1.self, from: fixture("status-response-v1.off-schedule.json"))
    let schedule = try #require(response.schedule)
    #expect(!schedule.expectedRunning)
    #expect(schedule.runEndsAt == nil)
    #expect(schedule.timezone == "America/New_York")
    #expect(schedule.lastTradingDay == (try WireDate("2026-11-20")))
    #expect(schedule.nextStartAt.date < schedule.nextEndAt.date)
    #expect(response.scheduleCause == nil)
  }

  @Test("No schedule: the cause in the person's language, never a guessed run")
  func noSchedule() throws {
    let response = try Wire.decoder().decode(StatusResponseV1.self, from: fixture("status-response-v1.no-schedule.json"))
    #expect(response.schedule == nil)
    #expect(response.scheduleCauseCodes.map(\.code) == ["calendar_not_covered"])
    let text = try #require(response.scheduleCauseText)
    #expect(!text.contains("OUT_OF_COVERAGE"))
  }
}
