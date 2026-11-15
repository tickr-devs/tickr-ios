import FactoryTesting
import Foundation
import Synchronization
import Testing
import TickrKit
@testable import TickrMac

/// Answers the API reads the app model makes from canned bodies by path, and records the
/// symbols whose bars were asked for. Shared state, so the suite runs one test at a time.
final class RouteProtocol: URLProtocol {
  struct Routes: Sendable {
    var bodies: [String: Data] = [:]
    var barSymbols: [String] = []
    var idempotencyKeys: [String?] = []
  }

  static let routes = Mutex(Routes())

  static func session() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [RouteProtocol.self]
    return URLSession(configuration: configuration)
  }

  override static func canInit(with request: URLRequest) -> Bool { true }
  override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let url = request.url else {
      client?.urlProtocol(self, didFailWithError: URLError(.badURL))
      return
    }
    let path = url.path()
    if request.httpMethod == "POST" {
      let key = request.value(forHTTPHeaderField: "Idempotency-Key")
      Self.routes.withLock { $0.idempotencyKeys.append(key) }
    }
    if path == "/bars", let symbol = URLComponents(url: url, resolvingAgainstBaseURL: false)?
      .queryItems?.first(where: { $0.name == "symbol" })?.value {
      Self.routes.withLock { $0.barSymbols.append(symbol) }
    }
    let body = Self.routes.withLock { $0.bodies[path] }
    // A queued command answers 202 Accepted, a read 200 OK (docs/api.md).
    let success = request.httpMethod == "POST" ? 202 : 200
    let response = HTTPURLResponse(url: url, statusCode: body == nil ? 404 : success, httpVersion: "HTTP/1.1",
      headerFields: ["Content-Type": "application/json"])
    if let response {
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    }
    client?.urlProtocol(self, didLoad: body ?? Data())
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}

@MainActor
@Suite("App model", .container, .serialized)
struct AppModelTests {
  /// The status fixture with a second open position (EFGH) next to ABCD.
  static func twoPositionStatus() throws -> Data {
    let data = try Data(contentsOf: fixturesDir.appendingPathComponent("status-response-v1.json"))
    var response = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    var status = try #require(response["status"] as? [String: Any])
    var positions = try #require(status["positions"] as? [[String: Any]])
    var second = try #require(positions.first)
    second["symbol"] = "EFGH"
    positions.append(second)
    status["positions"] = positions
    response["status"] = status
    return try JSONSerialization.data(withJSONObject: response)
  }

  /// The status fixture with the bot in `state`.
  static func status(botState state: String, stale: Bool = false) throws -> Data {
    let data = try Data(contentsOf: fixturesDir.appendingPathComponent("status-response-v1.json"))
    var response = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    var status = try #require(response["status"] as? [String: Any])
    status["bot_state"] = state
    response["status"] = status
    response["stale"] = stale
    return try JSONSerialization.data(withJSONObject: response)
  }

  init() throws {
    let file = { (name: String) in try Data(contentsOf: fixturesDir.appendingPathComponent(name)) }
    let bodies = [
      "/status": try Self.twoPositionStatus(),
      "/settings": try file("settings-v1.json"),
      "/bars": try file("bars-v1.json"),
    ]
    RouteProtocol.routes.withLock { $0 = RouteProtocol.Routes(bodies: bodies) }
    Container.shared.urlSession.register { RouteProtocol.session() }
  }

  @Test("Every open position gets a row and its own bars")
  func everyPositionCounts() async throws {
    let model = AppModel(baseURL: APIClient.defaultBaseURL)
    await model.refreshStatus()
    await model.refreshPositionBars()
    #expect(model.positions.map(\.id) == ["ABCD", "EFGH"])
    #expect(Set(RouteProtocol.routes.withLock { $0.barSymbols }) == ["ABCD", "EFGH"])
  }

  @Test("The daily room is the bot's own number, never computed by the app")
  func dailyRoomComesFromStatus() async throws {
    let model = AppModel(baseURL: APIClient.defaultBaseURL)
    #expect(model.dailyRoom == nil)
    await model.refreshStatus()
    #expect(model.dailyRoom == Decimal(string: "248.40"))
  }

  @Test("A failed account read clears the earlier answer")
  func accountFailureClears() async throws {
    let model = AppModel(baseURL: APIClient.defaultBaseURL)
    RouteProtocol.routes.withLock { $0.bodies["/account"] = try? Data(contentsOf:
      fixturesDir.appendingPathComponent("account-response-v1.json")) }
    await model.refreshAccount()
    #expect(model.account?.account.matchesRecords == true)
    RouteProtocol.routes.withLock { $0.bodies["/account"] = nil }
    await model.refreshAccount()
    #expect(model.account == nil)
    #expect(model.accountError != nil)
  }

  @Test("Today and ages follow the bot's clock (served_at), not this Mac's")
  func botClock() async throws {
    // The Mac says Sunday Nov 15; the bot (the fixture) serves Monday Nov 16, 10:00:02 New York.
    let mac = try WireTime("2026-11-15T17:00:00.000Z").date
    Container.shared.now.register { { mac } }
    let model = AppModel(baseURL: APIClient.defaultBaseURL)
    #expect(model.today == (try WireDate("2026-11-15")))
    await model.refreshStatus()
    #expect(model.today == (try WireDate("2026-11-16")))
    let served = try WireTime("2026-11-16T15:00:02.123Z").date
    #expect(abs(model.botNow.timeIntervalSince(served)) < 1)
    #expect(model.isLive)
  }

  @Test("The shown day's flow and watched symbols are read; a failed read clears each")
  func flowAndWatching() async throws {
    let model = AppModel(baseURL: APIClient.defaultBaseURL)
    RouteProtocol.routes.withLock {
      $0.bodies["/flow"] = try? Data(contentsOf: fixturesDir.appendingPathComponent("flow-v1.json"))
      $0.bodies["/watching"] = try? Data(contentsOf: fixturesDir.appendingPathComponent("watching-v1.json"))
    }
    await model.refreshFlow()
    #expect(model.flow?.stages.count == FlowStage.allCases.count)
    #expect(model.watching?.rows.first?.symbol == "ABCD")
    RouteProtocol.routes.withLock { $0.bodies["/flow"] = nil }
    await model.refreshFlow()
    #expect(model.flow == nil)
    #expect(model.flowError != nil)
    #expect(model.watching != nil)
  }

  @Test("Performance over the days ending on the shown day is read; a failed read clears it")
  func performance() async throws {
    let model = AppModel(baseURL: APIClient.defaultBaseURL)
    RouteProtocol.routes.withLock { $0.bodies["/performance"] = try? Data(contentsOf:
      fixturesDir.appendingPathComponent("performance-v1.json")) }
    await model.refreshPerformance()
    #expect(model.performance?.trades == 5)
    #expect(model.performance?.exclusions.count == 1)
    RouteProtocol.routes.withLock { $0.bodies["/performance"] = nil }
    await model.refreshPerformance()
    #expect(model.performance == nil)
    #expect(model.performanceError != nil)
  }

  @Test("The shown day's skipped signals are read; a failed read clears them")
  func skippedSignals() async throws {
    let model = AppModel(baseURL: APIClient.defaultBaseURL)
    RouteProtocol.routes.withLock { $0.bodies["/skipped"] = try? Data(contentsOf:
      fixturesDir.appendingPathComponent("skipped-v1.json")) }
    await model.refreshSkipped()
    #expect(model.skipped?.signals.map(\.admission) == [.refused, .refused, .notEvaluated])
    RouteProtocol.routes.withLock { $0.bodies["/skipped"] = nil }
    await model.refreshSkipped()
    #expect(model.skipped == nil)
    #expect(model.skippedError != nil)
  }

  @Test("The chart reads a symbol's decisions; a failed read clears them")
  func chartDecisions() async throws {
    let chart = ChartModel()
    let day = try WireDate("2026-11-16")
    RouteProtocol.routes.withLock { $0.bodies["/decisions"] = try? Data(contentsOf:
      fixturesDir.appendingPathComponent("decisions-v1.json")) }
    await chart.loadDecisions(baseURL: APIClient.defaultBaseURL, symbol: "ABCD", day: day)
    #expect(chart.decisions?.decisions.map(\.action) == [.watch, .enter, .enter])
    #expect(chart.decisions?.decisions[1].observer == true)
    #expect(chart.decisions?.decisions.last?.admission == .refused)
    RouteProtocol.routes.withLock { $0.bodies["/decisions"] = nil }
    await chart.loadDecisions(baseURL: APIClient.defaultBaseURL, symbol: "ABCD", day: day)
    #expect(chart.decisions == nil)
    #expect(chart.decisionsError != nil)
  }

  @Test("Positions with a stopped or silent bot are flagged; a fresh running bot is not")
  func unattendedPositions() async throws {
    let cases: [(String, Bool, Unattended?)] = [
      ("stopped", false, Unattended(reason: .stopped, count: 1)),
      ("running", true, Unattended(reason: .silent, count: 1)),
      ("running", false, nil),
    ]
    let model = AppModel(baseURL: APIClient.defaultBaseURL)
    for (state, stale, expected) in cases {
      let body = try Self.status(botState: state, stale: stale)
      RouteProtocol.routes.withLock { $0.bodies["/status"] = body }
      await model.refreshStatus()
      #expect(model.unattendedPositions == expected, "\(state), stale \(stale)")
    }
  }

  @Test("Each command send carries its own idempotency key")
  func sendCarriesAKey() async throws {
    let accepted = try Data(contentsOf: fixturesDir.appendingPathComponent("command-accepted-v1.json"))
    RouteProtocol.routes.withLock { $0.bodies["/commands/flatten"] = accepted }
    let model = AppModel(baseURL: APIClient.defaultBaseURL)
    await model.refreshStatus()
    await model.send(.flattenSymbol("ABCD"), title: "Flatten ABCD")
    await model.send(.flattenSymbol("ABCD"), title: "Flatten ABCD")
    let keys = RouteProtocol.routes.withLock { $0.idempotencyKeys }.compactMap { $0 }
    #expect(keys.count == 2 && Set(keys).count == 2)
  }

  @Test("Flatten of one symbol closes only that symbol; every action has a command")
  func actionsMapToCommands() {
    #expect(BotAction.flatten(symbol: "ABCD").command == .flattenSymbol("ABCD"))
    #expect(BotAction.flattenAll.command == .flatten)
    #expect(BotAction.stopBot.command == .stopBot)
    #expect(BotAction.emergency.command == .emergency)
  }

  @Test("The chart builds its plot once per new bars or timeframe; an unchanged read reuses it")
  func chartPlotIsCached() async throws {
    let chart = ChartModel()
    let day = try WireDate("2026-11-16")
    #expect(chart.plot(timeframe: .m1) == nil)
    await chart.load(baseURL: APIClient.defaultBaseURL, symbol: "ABCD", day: day)
    let first = try #require(chart.plot(timeframe: .m1))
    #expect(chart.plot(timeframe: .m1)?.revision == first.revision)
    await chart.load(baseURL: APIClient.defaultBaseURL, symbol: "ABCD", day: day)
    #expect(chart.revision == first.revision, "the same bars read again must not redraw the chart")
    #expect(chart.plot(timeframe: .m5)?.timeframe == .m5)
    chart.clear()
    #expect(chart.plot(timeframe: .m1) == nil)
    await chart.load(baseURL: APIClient.defaultBaseURL, symbol: "ABCD", day: day)
    #expect(try #require(chart.plot(timeframe: .m1)).revision > first.revision)
  }
}
