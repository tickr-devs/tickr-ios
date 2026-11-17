import Foundation
import Synchronization
import Testing
@testable import TickrKit

/// Answers GET /chart and GET /bars with a status and body each, and records the paths asked.
final class DayRoutes: URLProtocol {
  struct State: Sendable {
    var answers: [String: (Int, Data)] = [:]
    var asked: [String] = []
  }

  static let state = Mutex(State())

  static func session() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [DayRoutes.self]
    return URLSession(configuration: configuration)
  }

  override static func canInit(with request: URLRequest) -> Bool { true }
  override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let url = request.url else { return }
    let path = url.path()
    let answer = Self.state.withLock { state in
      state.asked.append(path)
      return state.answers[path] ?? (404, Data())
    }
    if let response = HTTPURLResponse(url: url, statusCode: answer.0, httpVersion: "HTTP/1.1",
      headerFields: ["Content-Type": "application/json"]) {
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    }
    client?.urlProtocol(self, didLoad: answer.1)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}

@Suite(.serialized) struct DayBarsTests {
  let client: APIClient
  /// The day of the fixtures (chart-v1 and bars-v1).
  let day = try? WireDate("2026-11-16")

  init() throws {
    client = APIClient(baseURL: try #require(URL(string: "http://127.0.0.1:8766")), transport: DayRoutes.session())
    let chart = try fixture("chart-v1.json")
    let bars = try fixture("bars-v1.json")
    DayRoutes.state.withLock {
      $0 = DayRoutes.State(answers: ["/chart": (200, chart), "/bars": (200, bars)], asked: [])
    }
  }

  @Test("Today is read from market data, every screen alike")
  func todayFromMarketData() async throws {
    let day = try #require(day)
    let read = try await DayBars.read(client, symbol: "ABCD", day: day, today: day)
    guard case .marketData(let chart) = read else {
      Issue.record("today was not read from market data")
      return
    }
    #expect(read.bars.map(\.close) == chart.bars.map(\.close))
    #expect(DayRoutes.state.withLock { $0.asked } == ["/chart"])
  }

  @Test("A recorded day is the bot's capture; market data is not asked")
  func recordedDayFromCapture() async throws {
    let day = try #require(day)
    let read = try await DayBars.read(client, symbol: "ABCD", day: day, today: try WireDate("2026-11-17"))
    guard case .capture = read else {
      Issue.record("a recorded day did not read the capture")
      return
    }
    #expect(DayRoutes.state.withLock { $0.asked } == ["/bars"])
  }

  @Test("Today without market data (503), or before its session began, is the capture")
  func todayWithoutMarketData() async throws {
    let day = try #require(day)
    let off = Data(#"{"error": "unavailable", "cause": "chart market data is off", "api_version": 1}"#.utf8)
    DayRoutes.state.withLock { $0.answers["/chart"] = (503, off) }
    guard case .capture = try await DayBars.read(client, symbol: "ABCD", day: day, today: day) else {
      Issue.record("a 503 did not fall back to the capture")
      return
    }
    // The latest session is still the day before (before 04:00): its candles are not today's.
    let tomorrow = try WireDate("2026-11-17")
    DayRoutes.state.withLock { $0.answers["/chart"] = (200, (try? fixture("chart-v1.json")) ?? Data()) }
    guard case .capture = try await DayBars.read(client, symbol: "ABCD", day: tomorrow, today: tomorrow) else {
      Issue.record("yesterday's session was taken for today")
      return
    }
  }

  @Test("Any other refusal is an error, never a silent switch of source")
  func otherRefusalsFail() async throws {
    let day = try #require(day)
    let limited = Data(#"{"error": "rate_limited", "cause": "chart read budget", "api_version": 1}"#.utf8)
    DayRoutes.state.withLock { $0.answers["/chart"] = (429, limited) }
    await #expect(throws: APIError.self) {
      try await DayBars.read(client, symbol: "ABCD", day: day, today: day)
    }
  }
}
