import FactoryTesting
import Foundation
import Synchronization
import Testing
import TickrDesign
import TickrKit
@testable import TickrMac

/// Answers the API reads the app model makes from canned bodies by path, and records the
/// symbols whose bars were asked for. Shared state, so the suite runs one test at a time.
final class RouteProtocol: URLProtocol {
  struct Routes: Sendable {
    var bodies: [String: Data] = [:]
    /// Symbols whose today was asked of market data (GET /chart).
    var chartSymbols: [String] = []
    var idempotencyKeys: [String?] = []
    /// Every path asked for, in the order asked.
    var paths: [String] = []
    /// Paths whose request gets no answer: the connection drops.
    var failing: Set<String> = []
    /// Bodies of one host only, by host then path; checked before `bodies`.
    var byHost: [String: [String: Data]] = [:]
    /// Paths answered with this HTTP status instead of the usual one (an error body in `bodies`).
    var statuses: [String: Int] = [:]
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
    Self.routes.withLock { $0.paths.append(path) }
    if request.httpMethod == "POST" {
      let key = request.value(forHTTPHeaderField: "Idempotency-Key")
      Self.routes.withLock { $0.idempotencyKeys.append(key) }
    }
    if let symbol = URLComponents(url: url, resolvingAgainstBaseURL: false)?
      .queryItems?.first(where: { $0.name == "symbol" })?.value {
      if path == "/chart" { Self.routes.withLock { $0.chartSymbols.append(symbol) } }
    }
    let host = url.host()
    let (failing, hostBody) = Self.routes.withLock { routes in
      (routes.failing.contains(path), host.flatMap { routes.byHost[$0]?[path] })
    }
    if failing {
      client?.urlProtocol(self, didFailWithError: URLError(.networkConnectionLost))
      return
    }
    let (body, status) = Self.routes.withLock { (hostBody ?? $0.bodies[path], $0.statuses[path]) }
    // A queued command answers 202 Accepted, a read 200 OK (docs/api.md).
    let success = request.httpMethod == "POST" ? 202 : 200
    let response = HTTPURLResponse(url: url, statusCode: status ?? (body == nil ? 404 : success), httpVersion: "HTTP/1.1",
      headerFields: ["Content-Type": "application/json"])
    if let response {
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    }
    client?.urlProtocol(self, didLoad: body ?? Data())
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}

/// Answers through `session`, every answer of `host` after `seconds`: a slow server.
struct SlowHost: APITransport {
  let host: String
  let seconds: Double
  let session: URLSession

  func response(to request: URLRequest) async throws -> (Data, URLResponse) {
    if request.url?.host() == host { try await Task.sleep(for: .seconds(seconds)) }
    return try await session.data(for: request)
  }
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

  /// Today's one-minute market data of the status's day (the chart fixture, as 1m candles).
  static func todayChart() throws -> Data {
    let data = try Data(contentsOf: fixturesDir.appendingPathComponent("chart-v1.json"))
    var chart = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    chart["interval"] = "1m"
    return try JSONSerialization.data(withJSONObject: chart)
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
      "/chart": try Self.todayChart(),
    ]
    RouteProtocol.routes.withLock { $0 = RouteProtocol.Routes(bodies: bodies) }
    Container.shared.urlSession.register { RouteProtocol.session() }
  }

  @Test("Every open position gets a row and its own bars, today's from market data as on the Chart")
  func everyPositionCounts() async throws {
    let model = AppModel(baseURL: APIClient.defaultBaseURL)
    await model.refreshStatus()
    await model.refreshPositionBars()
    #expect(model.positions.map(\.id) == ["ABCD", "EFGH"])
    #expect(Set(RouteProtocol.routes.withLock { $0.chartSymbols }) == ["ABCD", "EFGH"])
    // One source of truth: the Overview's card reads today where the Chart does (`DayBars`).
    guard case .marketData(let chart) = model.positionBars("ABCD") else {
      Issue.record("the position card did not read market data")
      return
    }
    #expect(chart.range == .oneDay)
    #expect(model.positions.first?.latestClose == chart.bars.last?.close.value)
  }

  @Test("A status listing positions whose bars were not read reads them at once, not at the next bars poll")
  func positionBarsWithTheirStatus() async throws {
    let model = AppModel(baseURL: APIClient.defaultBaseURL)
    // At launch the bars poll runs before any status: it knows no position and reads nothing.
    await model.refreshPositionBars()
    #expect(RouteProtocol.routes.withLock { $0.chartSymbols }.isEmpty)
    await model.refreshStatus()
    #expect(Set(RouteProtocol.routes.withLock { $0.chartSymbols }) == ["ABCD", "EFGH"])
    #expect(model.positionBars("ABCD") != nil, "the position card has its price rows with the first status")
    // The same positions again: the bars poll keeps them current, the status read does not repeat it.
    let reads = RouteProtocol.routes.withLock { $0.chartSymbols.count }
    await model.refreshStatus()
    #expect(RouteProtocol.routes.withLock { $0.chartSymbols.count } == reads)
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

  @Test("The session strip's stripes drift only while the bot runs with live, fresh status")
  func sessionStripesGate() async throws {
    let model = AppModel(baseURL: APIClient.defaultBaseURL)
    // No status yet: still.
    #expect(!JobsSection.stripesMove(reduceMotion: false, model: model))
    RouteProtocol.routes.withLock { $0.bodies["/status"] = try? Self.status(botState: "running") }
    await model.refreshStatus()
    #expect(JobsSection.stripesMove(reduceMotion: false, model: model))
    #expect(!JobsSection.stripesMove(reduceMotion: true, model: model))
    RouteProtocol.routes.withLock { $0.bodies["/status"] = try? Self.status(botState: "running", stale: true) }
    await model.refreshStatus()
    #expect(!JobsSection.stripesMove(reduceMotion: false, model: model))
    RouteProtocol.routes.withLock { $0.bodies["/status"] = try? Self.status(botState: "stopped") }
    await model.refreshStatus()
    #expect(!JobsSection.stripesMove(reduceMotion: false, model: model))
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
    await model.send(.flattenSymbol("ABCD"), title: "Close ABCD position")
    await model.send(.flattenSymbol("ABCD"), title: "Close ABCD position")
    let keys = RouteProtocol.routes.withLock { $0.idempotencyKeys }.compactMap { $0 }
    #expect(keys.count == 2 && Set(keys).count == 2)
  }

  @Test("A send whose answer was lost keeps its key until the receipt settles it, never a second command")
  func lostAnswerKeepsItsKey() async throws {
    let file = { (name: String) in try Data(contentsOf: fixturesDir.appendingPathComponent(name)) }
    RouteProtocol.routes.withLock { $0.failing = ["/commands/flatten"] }
    let model = AppModel(baseURL: APIClient.defaultBaseURL)
    await model.refreshStatus()
    await model.send(.flattenSymbol("ABCD"), title: "Close ABCD position")
    #expect(model.toast?.unknown == true, "a lost answer is unknown, not refused")
    // Pressed again while unknown: the same key, so the API answers the first send.
    await model.send(.flattenSymbol("ABCD"), title: "Close ABCD position")
    var keys = RouteProtocol.routes.withLock { $0.idempotencyKeys }.compactMap { $0 }
    #expect(keys.count == 2 && Set(keys).count == 1)
    // The receipt says it was queued: it is awaited as any queued command.
    let receipt = try file("command-receipt-v1.json")
    RouteProtocol.routes.withLock { $0.bodies["/commands/receipt"] = receipt }
    await model.refreshStatus()
    let queued = try Wire.decoder().decode(CommandReceiptV1.self, from: receipt).accepted
    #expect(model.sent.first?.id == queued?.command.commandId)
    #expect(model.toast?.unknown == false)
    // Settled: the next press is a new decision with a new key.
    let accepted = try file("command-accepted-v1.json")
    RouteProtocol.routes.withLock {
      $0.failing = []
      $0.bodies["/commands/flatten"] = accepted
    }
    await model.send(.flattenSymbol("ABCD"), title: "Close ABCD position")
    keys = RouteProtocol.routes.withLock { $0.idempotencyKeys }.compactMap { $0 }
    #expect(keys.count == 3 && Set(keys).count == 2)
  }

  @Test("A receipt that says not queued drops the key and says so")
  func lostAnswerNotQueued() async throws {
    let notQueued = try Data(contentsOf: fixturesDir.appendingPathComponent("command-receipt-v1.not-queued.json"))
    RouteProtocol.routes.withLock {
      $0.failing = ["/commands/stop-bot"]
      $0.bodies["/commands/receipt"] = notQueued
    }
    let model = AppModel(baseURL: APIClient.defaultBaseURL)
    await model.refreshStatus()
    await model.send(.stopBot, title: "Stop bot")
    await model.refreshStatus()
    #expect(model.toast?.outcome == .refused && model.toast?.unknown == false)
    #expect(model.toast?.cause == String(localized: L10n.Bot.notQueued))
  }

  @Test("An API that serves no receipts drops a lost send's key and says the outcome is not known")
  func lostAnswerUnservedReceipt() async throws {
    var notFound = try #require(try JSONSerialization.jsonObject(with:
      Data(contentsOf: fixturesDir.appendingPathComponent("error-v1.json"))) as? [String: Any])
    notFound["error"] = "not_found"
    notFound["cause_codes"] = [Any]()
    let body = try JSONSerialization.data(withJSONObject: notFound)
    RouteProtocol.routes.withLock {
      $0.failing = ["/commands/stop-bot"]
      $0.bodies["/commands/receipt"] = body
      $0.statuses["/commands/receipt"] = 404
    }
    let model = AppModel(baseURL: APIClient.defaultBaseURL)
    await model.refreshStatus()
    await model.send(.stopBot, title: "Stop bot")
    await model.refreshStatus()
    #expect(model.toast?.cause == String(localized: L10n.Bot.outcomeNotKnown))
    // The key went with it: the next press is a new decision with a new key.
    await model.send(.stopBot, title: "Stop bot")
    let keys = RouteProtocol.routes.withLock { $0.idempotencyKeys }.compactMap { $0 }
    #expect(keys.count == 2 && Set(keys).count == 2)
  }

  /// This Mac's clock in the age test, moved by hand.
  nonisolated static let clock = Mutex(Date.now)

  @Test("A lost send's key is never kept past the bot's command age (settings), so a later press is sent anew")
  func lostAnswerKeyAgesOut() async throws {
    Self.clock.withLock { $0 = .now }
    Container.shared.now.register { { Self.clock.withLock { $0 } } }
    RouteProtocol.routes.withLock { $0.failing = ["/commands/emergency"] }
    let model = AppModel(baseURL: APIClient.defaultBaseURL)
    await model.refreshStatus()
    let keep = try #require(model.settings?.commandMaxAgeSeconds?.value)
    await model.send(.emergency, title: "Emergency")
    #expect(model.toast?.unknown == true)
    // Past the age the bot refuses the first send anyway: its old answer must not stand for a new press.
    Self.clock.withLock { $0 += NSDecimalNumber(decimal: keep).doubleValue + 1 }
    await model.send(.emergency, title: "Emergency")
    let keys = RouteProtocol.routes.withLock { $0.idempotencyKeys }.compactMap { $0 }
    #expect(keys.count == 2 && Set(keys).count == 2)
    // And a key that ages out between presses is shown as not known.
    Self.clock.withLock { $0 += NSDecimalNumber(decimal: keep).doubleValue + 1 }
    await model.refreshStatus()
    #expect(model.toast?.cause == String(localized: L10n.Bot.outcomeNotKnown))
  }

  @Test("Nothing is sent when the status read right before the send fails, even once")
  func sendNeedsAFreshRead() async throws {
    let model = AppModel(baseURL: APIClient.defaultBaseURL)
    await model.refreshStatus()
    #expect(model.commandsEnabled)
    // One failed read is still hidden as a passing blip; the command must not ride on it.
    RouteProtocol.routes.withLock { $0.failing = ["/status"] }
    await model.send(.entryStop(on: true), title: "Pause entries")
    #expect(Self.sentCount() == 0)
    #expect(model.toast?.outcome == .refused)
  }

  @Test("A late answer from the server before a switch never shows as the new server's")
  func lateAnswerFromTheOldServerIsDropped() async throws {
    let stale = try Self.status(botState: "running", stale: true)
    RouteProtocol.routes.withLock { $0.byHost[Self.slowHost] = ["/status": stale] }
    Container.shared.apiClient.register { endpoint in
      APIClient(baseURL: endpoint.baseURL, token: endpoint.token,
        transport: SlowHost(host: Self.slowHost, seconds: Self.slowAnswerSeconds, session: RouteProtocol.session()))
    }
    let model = AppModel(baseURL: APIClient.defaultBaseURL)
    let late = Task { await model.refreshStatus() }
    try await Task.sleep(for: .seconds(Self.slowAnswerSeconds / 2))
    model.connect(to: try #require(URL(string: "http://localhost:8766")))
    #expect(await late.value == false)
    #expect(model.response?.stale != true, "the old server's stale status replaced the new one's")
  }

  /// The old server of the switch test, and how long its answers take, in seconds.
  static let slowHost = "127.0.0.1"
  static let slowAnswerSeconds = 0.4

  /// Commands sent so far (each POST carries one idempotency key).
  static func sentCount() -> Int { RouteProtocol.routes.withLock { $0.idempotencyKeys.count } }

  @Test("A flatten press only asks; the model holds the question, and only the yes sends it, once")
  func flattenAsksBeforeSending() async throws {
    RouteProtocol.routes.withLock { $0.bodies["/commands/flatten"] = try? Data(contentsOf:
      fixturesDir.appendingPathComponent("command-accepted-v1.json")) }
    let model = AppModel(baseURL: APIClient.defaultBaseURL)
    await model.refreshStatus()
    model.press(.flatten(symbol: "ABCD"), in: .window)
    let question = try #require(model.confirming, "a press opens its question")
    #expect(question.action == .flatten(symbol: "ABCD") && question.place == .window)
    // The question lives in the model, not in the view that asked: status reads (which redraw
    // and can rebuild Overview's cards) leave it open, and nothing is sent meanwhile.
    await model.refreshStatus()
    await model.refreshStatus()
    #expect(model.confirming == question)
    #expect(Self.sentCount() == 0, "nothing is sent before the yes")
    let send = try #require(model.accept(question), "the yes to the open question sends")
    #expect(model.confirming == nil, "accepting closes the question in the same step")
    #expect(model.accept(question) == nil, "a second yes to the same question sends nothing")
    await send.value
    #expect(Self.sentCount() == 1)
  }

  @Test("Only the open question is accepted: a cancelled or replaced one sends nothing")
  func onlyTheOpenQuestionSends() async throws {
    let model = AppModel(baseURL: APIClient.defaultBaseURL)
    await model.refreshStatus()
    model.press(.flatten(symbol: "ABCD"), in: .window)
    let cancelled = try #require(model.confirming)
    model.withdraw(cancelled)
    #expect(model.accept(cancelled) == nil)
    model.press(.stopBot, in: .window)
    let older = try #require(model.confirming)
    model.press(.closeAll, in: .window)
    let newer = try #require(model.confirming)
    #expect(model.accept(older) == nil, "a replaced question sends nothing")
    #expect(model.confirming == newer, "and leaves the newer one open")
    model.withdraw(newer)
    #expect(Self.sentCount() == 0)
  }

  @Test("Stop bot with positions open asks to choose; only an answer with a mode sends, once")
  func stopBotWithPositionsAsksToChoose() async throws {
    RouteProtocol.routes.withLock { $0.bodies["/commands/stop-bot"] = try? Data(contentsOf:
      fixturesDir.appendingPathComponent("command-accepted-v1.stop-close-and-stop.json")) }
    let model = AppModel(baseURL: APIClient.defaultBaseURL)
    await model.refreshStatus()
    model.press(.stopBot, in: .window)
    let question = try #require(model.confirming)
    #expect(question.stop == .choose(symbols: ["ABCD", "EFGH"]))
    #expect(StopChoice.title(question.stop) == String(localized: StopText.chooseTitle(2)))
    #expect(model.accept(question) == nil, "a choice without an answer sends nothing")
    #expect(model.confirming == question, "and stays open")
    model.withdraw(question)
    #expect(model.accept(question, mode: .closeAndStop) == nil, "a withdrawn choice sends nothing")
    #expect(Self.sentCount() == 0)
    model.press(.stopBot, in: .window)
    let asked = try #require(model.confirming)
    let send = try #require(model.accept(asked, mode: .closeAndStop))
    await send.value
    #expect(Self.sentCount() == 1)
    #expect(RouteProtocol.routes.withLock { $0.paths }.filter { $0 == "/commands/stop-bot" }.count == 1)
  }

  /// A model with a current status and a flatten question open in `place`.
  static func modelAsking(in place: CommandPlace = .window) async throws -> AppModel {
    let model = AppModel(baseURL: APIClient.defaultBaseURL)
    await model.refreshStatus()
    model.press(.flatten(symbol: "ABCD"), in: place)
    _ = try #require(model.confirming)
    return model
  }

  @Test("A question closes when its window or panel closes, and only there")
  func questionClosesWithItsPlace() async throws {
    let model = try await Self.modelAsking(in: .menuBar)
    model.withdrawQuestion(in: .window)
    #expect(model.confirming != nil, "the main window closing leaves the panel's question")
    model.withdrawQuestion(in: .menuBar)
    #expect(model.confirming == nil, "the panel closing withdraws its question: it never reappears")
  }

  @Test("A question closes on a stale status")
  func questionClosesOnStaleStatus() async throws {
    let model = try await Self.modelAsking()
    RouteProtocol.routes.withLock { $0.bodies["/status"] = try? Self.status(botState: "running", stale: true) }
    await model.refreshStatus()
    #expect(model.confirming == nil)
  }

  @Test("A question closes once status reads keep failing")
  func questionClosesOnFailedRead() async throws {
    let model = try await Self.modelAsking()
    RouteProtocol.routes.withLock { $0.bodies["/status"] = nil }
    for _ in 0..<ReadFailures.shownAfter { await model.refreshStatus() }
    #expect(model.fetchError != nil)
    #expect(model.confirming == nil)
  }

  @Test("Failed reads in a row keep the last known status under a banner, with commands off")
  func failedReadKeepsLastKnownData() async throws {
    let model = AppModel(baseURL: APIClient.defaultBaseURL)
    await model.refreshStatus()
    #expect(model.connectionState == .connected)
    #expect(model.commandsEnabled)
    RouteProtocol.routes.withLock { $0.bodies["/status"] = nil }
    await model.refreshStatus()
    #expect(model.connectionState == .connected, "one failed poll between answers is no outage")
    #expect(model.headline.severity != .alarm)
    for _ in 1..<ReadFailures.shownAfter { await model.refreshStatus() }
    #expect(model.connectionState.isLastKnown, "the last good read is kept and named as last known")
    #expect(model.status != nil, "the screens keep the last known data")
    #expect(!model.commandsEnabled, "commands that need a live bot stay off")
    #expect(model.headline.severity == .alarm)
    #expect(model.connectionMessage?.details != nil, "the technical cause is kept for Details")
  }

  @Test("A question closes when commands turn off for a recorded day")
  func questionClosesOnRecordedDay() async throws {
    let model = try await Self.modelAsking()
    model.selectedDay = WireDate(newYorkDateOf: model.botNow.addingTimeInterval(-Self.daySeconds))
    #expect(!model.commandsEnabled)
    #expect(model.confirming == nil)
  }

  /// Seconds in a day, to name yesterday.
  static let daySeconds: TimeInterval = 86_400

  @Test("A question closes when the API address changes")
  func questionClosesOnAddressSwitch() async throws {
    let model = try await Self.modelAsking()
    model.connect(to: try #require(URL(string: "http://127.0.0.1:9")))
    #expect(model.confirming == nil)
  }

  @Test("A question closes when the demo day is switched")
  func questionClosesOnDemoSwitch() async throws {
    let model = try await Self.modelAsking()
    model.setDemoDay(true)
    #expect(model.confirming == nil)
  }

  @Test("Cancel sends nothing; each press is its own question; nothing is asked while commands are off")
  func withdrawnQuestionsSendNothing() async throws {
    let model = AppModel(baseURL: APIClient.defaultBaseURL)
    model.press(.flatten(symbol: "ABCD"), in: .window)
    #expect(model.confirming == nil, "no status yet: commands are off, so nothing is asked")
    await model.refreshStatus()
    model.press(.closeAll, in: .window)
    let first = try #require(model.confirming)
    model.withdraw(first)
    #expect(model.confirming == nil)
    model.press(.closeAll, in: .window)
    let second = try #require(model.confirming)
    #expect(second != first, "a second press is a new question")
    model.withdraw(first)
    #expect(model.confirming == second, "closing an old question leaves the newer one open")
    model.withdraw(second)
    #expect(Self.sentCount() == 0)
  }

  @Test("Start is offered only when no current status says the bot is alive; it is sent once")
  func startBot() async throws {
    RouteProtocol.routes.withLock { $0.bodies["/commands/start-bot"] = try? Data(contentsOf:
      fixturesDir.appendingPathComponent("bot-start-v1.json")) }
    let model = AppModel(baseURL: APIClient.defaultBaseURL)
    #expect(!model.canStartBot, "no answer from the API yet")
    RouteProtocol.routes.withLock { $0.bodies["/status"] = try? Self.status(botState: "running") }
    await model.refreshStatus()
    #expect(!model.canStartBot && model.canStopBot)
    RouteProtocol.routes.withLock { $0.bodies["/status"] = try? Self.status(botState: "running", stale: true) }
    await model.refreshStatus()
    #expect(model.canStartBot, "a stale status proves nothing about the bot now")
    RouteProtocol.routes.withLock { $0.bodies["/status"] = try? Self.status(botState: "stopped") }
    await model.refreshStatus()
    #expect(model.canStartBot && !model.canStopBot)
    await model.startBot()
    #expect(model.botStart == .accepted(stopCleared: true))
    #expect(RouteProtocol.routes.withLock { $0.idempotencyKeys }.count == 1)
  }

  @Test("The configuration file is read; a failed read clears it")
  func configFile() async throws {
    let model = AppModel(baseURL: APIClient.defaultBaseURL)
    RouteProtocol.routes.withLock { $0.bodies["/config"] = try? Data(contentsOf:
      fixturesDir.appendingPathComponent("config-v1.json")) }
    await model.refreshConfig()
    #expect(model.config?.valid == true && model.config?.sections.isEmpty == false)
    RouteProtocol.routes.withLock { $0.bodies["/config"] = nil }
    await model.refreshConfig()
    #expect(model.config == nil && model.configError != nil)
  }

  @Test("Flatten of one symbol closes only that symbol; Close all is the API's emergency command")
  func actionsMapToCommands() {
    #expect(BotAction.flatten(symbol: "ABCD").command == .flattenSymbol("ABCD"))
    #expect(BotAction.closeAll.command == .emergency)
    #expect(BotAction.stopBot.command == .stopBot)
    #expect(BotAction.pauseEntries.command == .entryStop(on: true))
    #expect(BotAction.resumeEntries.command == .entryStop(on: false))
  }

  @Test("Every command that closes or stops asks first; pausing and resuming act at once")
  func closingAndStoppingAsk() {
    for action in [BotAction.flatten(symbol: "ABCD"), .closeAll, .stopBot] {
      #expect(action.needsConfirmation && action.isDestructive)
    }
    #expect(!BotAction.pauseEntries.needsConfirmation && !BotAction.resumeEntries.needsConfirmation)
  }

  @Test("Close all says it is closing the positions while it is on its way")
  func closeAllInFlightTitle() {
    #expect(BotAction.closeAll.inFlightTitle.key == OperatorCommand.flatten.inFlightTitle.key)
    #expect(BotAction.stopBot.inFlightTitle.key == OperatorCommand.stopBot.inFlightTitle.key)
  }

  @Test("Commands are sorted into the design's tiers")
  func actionsHaveTheirTiers() {
    #expect(BotAction.pauseEntries.tier == .secondary(.warning))
    #expect(BotAction.resumeEntries.tier == .secondary(.accent))
    for action in [BotAction.flatten(symbol: "ABCD"), .closeAll, .stopBot] {
      #expect(action.tier == .destructive)
    }
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
  @Test("Ornaments move only while the bot runs with fresh live status, and never with Reduce Motion")
  func ornamentsFollowTheBot() async throws {
    let model = AppModel(baseURL: APIClient.defaultBaseURL)
    #expect(!model.ornamentsMove(reduceMotion: false), "no status yet")
    let cases: [(String, Bool, Bool)] = [("running", false, true), ("running", true, false), ("stopped", false, false)]
    for (state, stale, moves) in cases {
      let body = try Self.status(botState: state, stale: stale)
      RouteProtocol.routes.withLock { $0.bodies["/status"] = body }
      await model.refreshStatus()
      #expect(model.ornamentsMove(reduceMotion: false) == moves, "\(state), stale \(stale)")
      #expect(!model.ornamentsMove(reduceMotion: true))
    }
    // A recorded day: the ornaments stand still even while the bot runs.
    model.selectedDay = try WireDate("2020-01-02")
    #expect(!model.ornamentsMove(reduceMotion: false))
  }

  @Test("Today's tile pulses for a trade or a position, not for another read of the same day")
  func todayEvent() async throws {
    let model = AppModel(baseURL: APIClient.defaultBaseURL)
    #expect(model.todayEvent == nil)
    await model.refreshStatus()
    let first = try #require(model.todayEvent)
    await model.refreshStatus()
    #expect(model.todayEvent == first, "the same trading read again is no event")
    let body = try Self.status(botState: "running")
    RouteProtocol.routes.withLock { $0.bodies["/status"] = body }
    await model.refreshStatus()
    #expect(model.todayEvent != first, "a position closed is an event")
  }

  @Test("An open position's dot pulses for a fill or a stop, never for a newer price")
  func positionEvent() async throws {
    let model = AppModel(baseURL: APIClient.defaultBaseURL)
    await model.refreshStatus()
    let row = try #require(model.positions.first)
    let moved = PositionRow(position: row.position, lastBarClose: (row.lastBarClose ?? 0) + 1,
      lastBarAt: row.lastBarAt, closes: row.closes, latestClose: row.latestClose)
    #expect(moved.event == row.event)
    var status = try #require(JSONSerialization.jsonObject(with: Self.twoPositionStatus()) as? [String: Any])
    var inner = try #require(status["status"] as? [String: Any])
    var positions = try #require(inner["positions"] as? [[String: Any]])
    var stop = try #require(positions[0]["stop"] as? [String: Any])
    stop["state"] = stop["state"] as? String == "verified" ? "pending" : "verified"
    positions[0]["stop"] = stop
    inner["positions"] = positions
    status["status"] = inner
    let body = try JSONSerialization.data(withJSONObject: status)
    RouteProtocol.routes.withLock { $0.bodies["/status"] = body }
    await model.refreshStatus()
    #expect(try #require(model.positions.first).event != row.event)
  }

  @Test("The chart's LIVE dot pulses for a new bar, not for the same bars read again")
  func newestBar() async throws {
    let chart = ChartModel()
    let day = try WireDate("2026-11-16")
    #expect(chart.newestBar == nil)
    await chart.load(baseURL: APIClient.defaultBaseURL, symbol: "ABCD", day: day)
    let first = try #require(chart.newestBar)
    await chart.load(baseURL: APIClient.defaultBaseURL, symbol: "ABCD", day: day)
    #expect(chart.newestBar == first)
  }
}
