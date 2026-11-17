import Foundation
import Synchronization
import Testing
import TickrKit
@testable import TickrMac

/// Picking a past day (calendar, day list, title-bar menu, ⌘[): its trades are read first, shown
/// as soon as they come, and never replaced by the earlier day's, zeros or silence (owner report
/// 2026-11-17: picking yesterday seemed to do nothing while the day's other reads took a minute).
extension AppModelTests {
  /// Days of the fixtures (status-response-v1.json serves 2026-11-16 as today).
  static let tradesDay = "2026-11-16"
  static let emptyDay = "2026-11-13"
  static let unreadDay = "2026-11-12"
  /// How long a pick may take to land against the canned routes, and how often it is looked at.
  static let pickWait: Duration = .seconds(5)
  static let pickPoll: Duration = .milliseconds(10)

  /// The model on today (the fixtures' status), with the days and two recorded day documents.
  static func modelWithDays() async throws -> AppModel {
    let file = { (name: String) in try Data(contentsOf: fixturesDir.appendingPathComponent(name)) }
    let traded = try file("day-v1.json")
    // The day with trades, as a past day: the trades fixture, dated the day before.
    var past = try #require(JSONSerialization.jsonObject(with: traded) as? [String: Any])
    past["day"] = "2026-11-15"
    let pastData = try JSONSerialization.data(withJSONObject: past)
    try RouteProtocol.routes.withLock {
      $0.bodies["/days"] = try file("days-v1.json")
      $0.bodies["/days/\(tradesDay)"] = traded
      $0.bodies["/days/2026-11-15"] = pastData
      $0.bodies["/days/\(emptyDay)"] = try file("day-v1.empty.json")
    }
    let model = AppModel(baseURL: APIClient.defaultBaseURL)
    await model.refreshStatus()
    await model.refreshHistory()
    #expect(model.shownDayState == .live)
    return model
  }

  /// Waits until the pick has an outcome (its trades or a cause).
  static func waitForPick(_ model: AppModel) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: pickWait)
    while model.shownDayState == .loading, clock.now < deadline { try await Task.sleep(for: pickPoll) }
  }

  @Test("A picked day's trades are the first read, ahead of the day's other reads")
  func pickedDayReadFirst() async throws {
    let model = try await Self.modelWithDays()
    RouteProtocol.routes.withLock { $0.paths = [] }
    model.selectedDay = try WireDate("2026-11-15")
    #expect(model.shownDayState == .loading)
    try await Self.waitForPick(model)
    let paths = RouteProtocol.routes.withLock { $0.paths }
    #expect(paths.first == "/days/2026-11-15")
    guard case .loaded(let day) = model.shownDayState else {
      Issue.record("not loaded: \(model.shownDayState)")
      return
    }
    #expect(day.day == (try WireDate("2026-11-15")))
    #expect(model.shownTrades.map(\.symbol) == ["WXYZ", "ABCD"])
  }

  @Test("Another pick drops the earlier day's trades at once, never showing them under the new day")
  func anotherPickDropsTheEarlierDay() async throws {
    let model = try await Self.modelWithDays()
    model.selectedDay = try WireDate("2026-11-15")
    try await Self.waitForPick(model)
    #expect(!model.shownTrades.isEmpty)
    model.selectedDay = try WireDate(Self.emptyDay)
    #expect(model.shownDayState == .loading)
    #expect(model.shownTrades.isEmpty)
    try await Self.waitForPick(model)
    guard case .loaded(let day) = model.shownDayState else {
      Issue.record("not loaded: \(model.shownDayState)")
      return
    }
    // A day without trades is read and empty, not loading and not failed.
    #expect(day.day == (try WireDate(Self.emptyDay)))
    #expect(day.trades.isEmpty)
  }

  @Test("A day that cannot be read is unavailable with its cause; Retry reads it again")
  func unreadableDayHasACause() async throws {
    let model = try await Self.modelWithDays()
    model.selectedDay = try WireDate(Self.unreadDay)
    try await Self.waitForPick(model)
    guard case .failed(let cause) = model.shownDayState else {
      Issue.record("not failed: \(model.shownDayState)")
      return
    }
    #expect(!cause.isEmpty)
    // The day list's own state is untouched: the list still reads as listed.
    #expect(model.historyError == nil)
    RouteProtocol.routes.withLock {
      $0.bodies["/days/\(Self.unreadDay)"] = $0.bodies["/days/\(Self.emptyDay)"].flatMap { data in
        String(data: data, encoding: .utf8)?.replacingOccurrences(of: Self.emptyDay, with: Self.unreadDay)
          .data(using: .utf8)
      }
    }
    model.retryShownDay()
    #expect(model.shownDayState == .loading)
    try await Self.waitForPick(model)
    #expect(model.dayDocument?.day == (try WireDate(Self.unreadDay)))
  }

  @Test("An answer for another day than the one asked is refused with its cause, never shown")
  func otherDaysAnswerRefused() async throws {
    let model = try await Self.modelWithDays()
    RouteProtocol.routes.withLock { $0.bodies["/days/\(Self.unreadDay)"] = $0.bodies["/days/\(Self.emptyDay)"] }
    model.selectedDay = try WireDate(Self.unreadDay)
    try await Self.waitForPick(model)
    guard case .failed(let cause) = model.shownDayState else {
      Issue.record("not failed: \(model.shownDayState)")
      return
    }
    #expect(cause.contains(Self.emptyDay))
    #expect(model.dayDocument == nil)
  }

  @Test("Back to today shows today's live trades, not the picked day's")
  func todayAgain() async throws {
    let model = try await Self.modelWithDays()
    model.selectedDay = try WireDate(Self.emptyDay)
    try await Self.waitForPick(model)
    model.showToday()
    #expect(model.shownDayState == .live)
    #expect(model.dayDocument == nil)
  }
}
