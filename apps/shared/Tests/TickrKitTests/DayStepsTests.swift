import Foundation
import Testing
@testable import TickrKit

@Suite("Stepping through recorded days")
struct DayStepsTests {
  func summary(_ day: String) throws -> DaySummary {
    DaySummary(day: try WireDate(day), trades: 1, wins: 1, losses: 0,
      resultGrossUsd: try DecimalString("1"), hasBars: true,
      clean: try Wire.decoder().decode(CleanDay.self, from: Data(DayCalendarTests.clean.utf8)), resultNetUsd: nil)
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

@Suite("The day arrows")
struct DayArrowsTests {
  @Test("Both ways open: both arrows show and both step")
  func bothWays() {
    let arrows = DayArrows(locked: false, canGoBack: true, canGoForward: true)
    #expect(arrows.visible && arrows.canGoBack && arrows.canGoForward)
  }

  @Test("On today with older days: the arrows show, forward is disabled")
  func todayWithHistory() {
    let arrows = DayArrows(locked: false, canGoBack: true, canGoForward: false)
    #expect(arrows.visible)
    #expect(arrows.canGoBack)
    #expect(!arrows.canGoForward)
  }

  @Test("On the oldest recorded day: the arrows show, back is disabled")
  func oldestDay() {
    let arrows = DayArrows(locked: false, canGoBack: false, canGoForward: true)
    #expect(arrows.visible)
    #expect(!arrows.canGoBack)
    #expect(arrows.canGoForward)
  }

  @Test("No recorded day but the shown one: no arrows at all")
  func noOtherDay() {
    let arrows = DayArrows(locked: false, canGoBack: false, canGoForward: false)
    #expect(!arrows.visible)
    #expect(!arrows.canGoBack && !arrows.canGoForward)
  }

  @Test("The demo day locks the day: no arrows, even with recorded days around it")
  func locked() {
    let arrows = DayArrows(locked: true, canGoBack: true, canGoForward: true)
    #expect(!arrows.visible)
    #expect(!arrows.canGoBack && !arrows.canGoForward)
  }

  @Test("Fed from the recorded days: today with only today recorded shows no arrows")
  func fromDays() throws {
    let steps = DayStepsTests()
    let today = try WireDate("2026-11-16")
    let onlyToday = [try steps.summary("2026-11-16")]
    let alone = DayArrows(locked: false, canGoBack: DaySteps.previous(today, in: onlyToday) != nil,
      canGoForward: false)
    #expect(!alone.visible)
    let days = try steps.days()
    let withHistory = DayArrows(locked: false, canGoBack: DaySteps.previous(today, in: days) != nil,
      canGoForward: false)
    #expect(withHistory.visible && withHistory.canGoBack && !withHistory.canGoForward)
  }
}
