import Foundation
import Testing
@testable import Tickr
import TickrKit

/// A picked past day on Activity shows only its own trades (owner report 2026-11-17).
@MainActor
@Suite struct ActivityDayTests {
  @Test func theAskedDaysDocumentLoads() throws {
    let day = try fixture(DayV1.self, "day-v1.json")
    #expect(ActivityModel.phase(of: day, asked: day.day) == .loaded)
  }

  @Test func anotherDaysDocumentIsRefusedWithBothDays() throws {
    let day = try fixture(DayV1.self, "day-v1.empty.json")
    let asked = try WireDate("2026-11-16")
    guard case .failed(let cause) = ActivityModel.phase(of: day, asked: asked) else {
      Issue.record("another day's document loaded")
      return
    }
    #expect(cause.contains(asked.text))
    #expect(cause.contains(day.day.text))
  }
}

/// One shown day for every tab (owner report 2026-11-17: Home stepped to yesterday while every
/// other tab stayed on today).
@MainActor
@Suite struct SharedDayTests {
  @Test func todayIsShownUntilADayIsPicked() {
    let app = AppModel()
    #expect(app.isLive)
    #expect(app.shownDay == app.today)
  }

  @Test func aPickedDayIsTheShownDayAndItsPartsStartEmpty() throws {
    let app = AppModel()
    let past = try WireDate("2026-11-13")
    app.selectedDay = past
    #expect(!app.isLive)
    #expect(app.shownDay == past)
    // Nothing of the day shown before stays under the new one.
    #expect(app.flow == nil && app.symbols == nil && app.movers == nil && app.skipped == nil)
    #expect(app.flowPending)
    app.selectedDay = nil
    #expect(app.isLive)
  }
}
