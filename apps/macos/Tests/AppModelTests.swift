@testable import ApertureMac
import ApertureKit
import FactoryTesting
import Foundation
import Synchronization
import Testing

/// Answers the API reads the app model makes from canned bodies by path, and records the
/// symbols whose bars were asked for. Shared state, so the suite runs one test at a time.
final class RouteProtocol: URLProtocol {
  struct Routes: Sendable {
    var bodies: [String: Data] = [:]
    var barSymbols: [String] = []
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
    if path == "/bars", let symbol = URLComponents(url: url, resolvingAgainstBaseURL: false)?
      .queryItems?.first(where: { $0.name == "symbol" })?.value {
      Self.routes.withLock { $0.barSymbols.append(symbol) }
    }
    let body = Self.routes.withLock { $0.bodies[path] }
    let response = HTTPURLResponse(url: url, statusCode: body == nil ? 404 : 200, httpVersion: "HTTP/1.1",
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
}
