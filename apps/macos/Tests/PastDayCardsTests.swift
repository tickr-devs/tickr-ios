import Foundation
import Synchronization
import Testing
import TickrKit
@testable import TickrScreens

/// The canned routes of `RouteProtocol`, answered through a transport that can hold some reads
/// back, and answers by path and query first (`/skipped?date=2026-11-13`), then by path.
struct HeldTransport: APITransport {
  /// Reads held back by `delay`, by path.
  let held: Set<String>
  let delay: Duration

  func response(to request: URLRequest) async throws -> (Data, URLResponse) {
    guard let url = request.url else { throw URLError(.badURL) }
    let path = url.path()
    RouteProtocol.routes.withLock { $0.paths.append(path) }
    if held.contains(path) { try await Task.sleep(for: delay) }
    let query = url.query().map { "\(path)?\($0)" } ?? path
    let body = RouteProtocol.routes.withLock { $0.bodies[query] ?? $0.bodies[path] }
    guard let response = HTTPURLResponse(url: url, statusCode: body == nil ? 404 : 200,
      httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"]) else {
      throw URLError(.badServerResponse)
    }
    return (body ?? Data(), response)
  }
}

/// A picked past day (owner 2026-11-22): its trades show as soon as they come, its cards are read
/// all at once and shown together once every read has answered (each card shows its loader until
/// then), and never another pick's answers.
extension AppModelTests {
  static let cardPaths: Set<String> = ["/flow", "/watching", "/symbols", "/movers", "/events", "/skipped",
    "/performance"]
  /// Long enough that a card shown alone would be seen by the poll below, many times over.
  static let heldRead: Duration = .milliseconds(300)

  /// Canned card answers, and the client reading them through `HeldTransport`.
  static func modelWithCards(held: Set<String>) async throws -> AppModel {
    let file = { (name: String) in try Data(contentsOf: fixturesDir.appendingPathComponent(name)) }
    try RouteProtocol.routes.withLock {
      $0.bodies["/flow"] = try file("flow-v1.json")
      $0.bodies["/watching"] = try file("watching-v1.json")
      $0.bodies["/symbols"] = try file("symbols-v1.json")
      $0.bodies["/movers"] = try file("movers-v1.json")
      $0.bodies["/skipped"] = try file("skipped-v1.json")
      $0.bodies["/performance"] = try file("performance-v1.json")
      $0.bodies["/events"] = try file("day-events-v1.empty.json")
    }
    Container.shared.apiClient.register { endpoint in
      APIClient(baseURL: endpoint.baseURL, transport: HeldTransport(held: held, delay: heldRead))
    }
    return try await modelWithDays()
  }

  /// Whether any card of the shown day has an answer (its document or its cause).
  static func anyCard(_ model: AppModel) -> Bool {
    model.flow != nil || model.watching != nil || model.symbols != nil || model.movers != nil
      || model.skipped != nil || model.performance != nil
      || model.skippedError != nil || model.performanceError != nil
  }

  static func everyCard(_ model: AppModel) -> Bool {
    model.flow != nil && model.watching != nil && model.symbols != nil && model.movers != nil
      && model.skipped != nil && model.performance != nil
  }

  @Test("A picked day's trades show as they come; its cards are read at once and shown together")
  func cardsShowTogether() async throws {
    let model = try await Self.modelWithCards(held: ["/skipped"])
    RouteProtocol.routes.withLock { $0.paths = [] }
    model.selectedDay = try WireDate(Self.emptyDay)
    // Every card shows its loader from the pick on, not the earlier day's answers.
    #expect(!Self.anyCard(model))
    try await Self.waitForPick(model)
    // The trades do not wait for the held card.
    #expect(model.dayDocument != nil)
    #expect(!Self.anyCard(model))
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: Self.pickWait)
    while !Self.anyCard(model), clock.now < deadline {
      // The skipped signals are held back: no other card may show before they come.
      try await Task.sleep(for: Self.pickPoll)
    }
    #expect(Self.everyCard(model))
    let paths = RouteProtocol.routes.withLock { $0.paths }
    // Every part was asked before any card answered: the held read held no other read back.
    #expect(Set(paths.prefix(Self.cardPaths.count + 1)) == Self.cardPaths.union(["/days/\(Self.emptyDay)"]))
  }

  @Test("A periodic read of the picked day leaves its cards alone while they are read together")
  func periodicReadWaits() async throws {
    let model = try await Self.modelWithCards(held: ["/performance"])
    model.selectedDay = try WireDate(Self.emptyDay)
    try await Self.waitForPick(model)
    await model.refreshSkipped()  // the history poll, while the cards are still being read
    #expect(model.skipped == nil)
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: Self.pickWait)
    while !Self.anyCard(model), clock.now < deadline { try await Task.sleep(for: Self.pickPoll) }
    #expect(Self.everyCard(model))
  }

  @Test("A newer pick cancels the earlier day's card reads; their answers are never shown")
  func newerPickWins() async throws {
    let model = try await Self.modelWithCards(held: ["/skipped"])
    let empty = try Data(contentsOf: fixturesDir.appendingPathComponent("skipped-v1.empty.json"))
    RouteProtocol.routes.withLock { $0.bodies["/skipped?date=2026-11-15"] = empty }
    model.selectedDay = try WireDate(Self.emptyDay)
    try await Self.waitForPick(model)
    model.selectedDay = try WireDate("2026-11-15")
    #expect(!Self.anyCard(model))
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: Self.pickWait + Self.heldRead)
    while !Self.anyCard(model), clock.now < deadline { try await Task.sleep(for: Self.pickPoll) }
    // Wait out the earlier pick's held read too: its answer must not replace the newer one.
    try await Task.sleep(for: Self.heldRead)
    #expect(model.skipped?.signals.isEmpty == true)
    #expect(Self.everyCard(model))
  }

  @Test("A failed card read shows its own cause, together with the others")
  func failedCardHasItsCause() async throws {
    let model = try await Self.modelWithCards(held: [])
    RouteProtocol.routes.withLock { $0.bodies["/performance"] = nil }
    model.selectedDay = try WireDate(Self.emptyDay)
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: Self.pickWait)
    while !Self.anyCard(model), clock.now < deadline { try await Task.sleep(for: Self.pickPoll) }
    #expect(model.performance == nil && model.performanceError != nil)
    #expect(model.skipped != nil && model.flow != nil)
  }
}
