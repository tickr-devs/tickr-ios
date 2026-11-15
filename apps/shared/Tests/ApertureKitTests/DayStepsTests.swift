@testable import ApertureKit
import Foundation
import Testing

@Suite("Stepping through recorded days")
struct DayStepsTests {
  func summary(_ day: String) throws -> DaySummary {
    DaySummary(day: try WireDate(day), trades: 1, wins: 1, losses: 0,
      resultGrossUsd: try DecimalString("1"), hasBars: true,
      clean: try Wire.decoder().decode(CleanDay.self, from: Data(DayCalendarTests.clean.utf8)))
  }

  /// Newest first, as GET /days lists them, with today's session among them.
  func days() throws -> [DaySummary] {
    try ["2026-11-16", "2026-11-13", "2026-11-11", "2026-11-10"].map(summary)
  }

  @Test("Back goes to the newest older recorded day, skipping days without a record")
  func previous() throws {
    let days = try days()
    #expect(DaySteps.previous(try WireDate("2026-11-16"), in: days)?.day.text == "2026-11-13")
    #expect(DaySteps.previous(try WireDate("2026-11-13"), in: days)?.day.text == "2026-11-11")
    #expect(DaySteps.previous(try WireDate("2026-11-10"), in: days) == nil)
  }

  @Test("Forward goes to the oldest newer past day, then to today")
  func next() throws {
    let days = try days()
    let today = try WireDate("2026-11-16")
    #expect(DaySteps.next(try WireDate("2026-11-11"), in: days, today: today)?.day.text == "2026-11-13")
    #expect(DaySteps.next(try WireDate("2026-11-13"), in: days, today: today) == nil)
  }
}
