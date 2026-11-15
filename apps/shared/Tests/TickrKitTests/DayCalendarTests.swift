import Foundation
import Testing
@testable import TickrKit

@Suite("Trading-day calendar")
struct DayCalendarTests {
  /// A clean-day verdict for the summaries the calendar tests build.
  static let clean = """
    {"verdict": "clean", "cause": null, "causes": [], "reconcile_rows": 1, "first_reconcile_at": null,
     "last_reconcile_at": null, "day_end_seq": 1}
    """

  func summary(_ day: String, result: String) throws -> DaySummary {
    DaySummary(day: try WireDate(day), trades: 1, wins: 1, losses: 0,
      resultGrossUsd: try DecimalString(result), hasBars: true,
      clean: try Wire.decoder().decode(CleanDay.self, from: Data(Self.clean.utf8)))
  }

  @Test("A month starting on a Sunday has full Monday-to-Friday weeks and a lone last Monday")
  func november() throws {
    let weeks = DayCalendar.weeks(of: DayCalendar.Month(year: 2026, month: 11), days: [])
    #expect(weeks.count == 5)
    #expect(weeks[0].map { $0?.day.text } == ["2026-11-02", "2026-11-03", "2026-11-04", "2026-11-05", "2026-11-06"])
    #expect(weeks[4].map { $0?.day.text } == ["2026-11-30", nil, nil, nil, nil])
    #expect(weeks.allSatisfy { $0.count == DayCalendar.columns })
  }

  @Test("A month starting on a Thursday leaves Monday to Wednesday of its first week empty")
  func october() throws {
    let weeks = DayCalendar.weeks(of: DayCalendar.Month(year: 2026, month: 10), days: [])
    #expect(weeks[0].map { $0?.day.text } == [nil, nil, nil, "2026-10-01", "2026-10-02"])
    #expect(weeks.last?.map { $0?.day.text } == ["2026-10-26", "2026-10-27", "2026-10-28", "2026-10-29", "2026-10-30"])
  }

  @Test("A recorded day carries its summary; the other days carry none")
  func summaries() throws {
    let recorded = try summary("2026-11-13", result: "-42.5")
    let weeks = DayCalendar.weeks(of: DayCalendar.Month(year: 2026, month: 11), days: [recorded])
    let cells = weeks.flatMap { $0 }.compactMap { $0 }
    #expect(cells.first { $0.day.text == "2026-11-13" }?.summary == recorded)
    #expect(cells.filter { $0.summary != nil }.count == 1)
  }

  @Test("Months are the recorded ones plus today's, newest first, each once")
  func months() throws {
    let days = [
      try summary("2026-11-13", result: "10"),
      try summary("2026-11-12", result: "5"),
      try summary("2026-09-30", result: "-1"),
    ]
    let months = DayCalendar.months(days, including: try WireDate("2026-12-01"))
    #expect(months == [
      DayCalendar.Month(year: 2026, month: 12),
      DayCalendar.Month(year: 2026, month: 11),
      DayCalendar.Month(year: 2026, month: 9),
    ])
  }
}
