import FactoryTesting
import Foundation
import Synchronization
import Testing
@testable import TickrKit

/// Answers requests from a canned (status, body) and records what was asked.
/// The canned answer is shared state, so the suite that uses it runs its tests one at a time.
final class StubProtocol: URLProtocol {
  /// The canned answer and what was asked, behind a lock: URLSession calls the protocol on its
  /// own threads.
  struct Exchange: Sendable {
    var answer: (Int, Data) = (200, Data())
    var seen: [URLRequest] = []
    var seenBodies: [Data] = []
  }

  static let exchange = Mutex(Exchange())

  static var answer: (Int, Data) {
    get { exchange.withLock { $0.answer } }
    set { exchange.withLock { $0.answer = newValue } }
  }

  static var seen: [URLRequest] {
    get { exchange.withLock { $0.seen } }
    set { exchange.withLock { $0.seen = newValue } }
  }

  static var seenBodies: [Data] {
    get { exchange.withLock { $0.seenBodies } }
    set { exchange.withLock { $0.seenBodies = newValue } }
  }

  /// A session whose every request is answered by this stub.
  static func session() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubProtocol.self]
    return URLSession(configuration: configuration)
  }

  override static func canInit(with request: URLRequest) -> Bool { true }
  override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    Self.seen.append(request)
    Self.seenBodies.append(request.httpBody ?? Self.readStream(request.httpBodyStream))
    let response = HTTPURLResponse(url: request.url!, statusCode: Self.answer.0,
      httpVersion: "HTTP/1.1",
      headerFields: ["Content-Type": "application/json"])!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Self.answer.1)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}

  static func readStream(_ stream: InputStream?) -> Data {
    guard let stream else { return Data() }
    stream.open()
    defer { stream.close() }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 1024)
    while stream.hasBytesAvailable {
      let count = stream.read(&buffer, maxLength: buffer.count)
      if count <= 0 { break }
      data.append(buffer, count: count)
    }
    return data
  }
}

@Suite(.container, .serialized) struct APIClientTests {
  let client: APIClient

  init() throws {
    client = APIClient(baseURL: try #require(URL(string: "http://127.0.0.1:8766")), transport: StubProtocol.session())
    StubProtocol.seen = []
    StubProtocol.seenBodies = []
  }

  @Test func containerBuildsTheClientWithItsSession() async throws {
    Container.shared.urlSession.register { StubProtocol.session() }
    StubProtocol.answer = try (200, fixture("status-response-v1.json"))
    let endpoint = APIClient.Endpoint(baseURL: try #require(URL(string: "http://127.0.0.1:8766")), token: "t")
    let response = try await Container.shared.apiClient(endpoint).status()
    #expect(response.status?.environment == "sandbox")
    let request = try #require(StubProtocol.seen.first)
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer t")
  }

  @Test func status() async throws {
    StubProtocol.answer = try (200, fixture("status-response-v1.json"))
    let response = try await client.status()
    #expect(response.status?.environment == "sandbox")
    let request = try #require(StubProtocol.seen.first)
    #expect(request.httpMethod == "GET")
    #expect(request.url?.absoluteString == "http://127.0.0.1:8766/status")
  }

  @Test func newReadsUseTheirPaths() async throws {
    let day = try WireDate("2026-11-16")
    StubProtocol.answer = try (200, fixture("account-response-v1.json"))
    _ = try await client.account()
    StubProtocol.answer = try (200, fixture("observers-v1.json"))
    _ = try await client.observers(day: day)
    StubProtocol.answer = try (200, fixture("decisions-v1.json"))
    _ = try await client.decisions(symbol: "ABCD", day: day)
    #expect(StubProtocol.seen.map { $0.url?.absoluteString } == [
      "http://127.0.0.1:8766/account",
      "http://127.0.0.1:8766/observers?date=2026-11-16",
      "http://127.0.0.1:8766/decisions?symbol=ABCD&date=2026-11-16",
    ])
  }

  @Test func commandsSendExactBodies() async throws {
    StubProtocol.answer = try (202, fixture("command-accepted-v1.json"))
    let cases: [(OperatorCommand, String, [String: String])] = [
      (.entryStop(on: true), "/commands/entry-stop", ["state": "on"]),
      (.entryStop(on: false), "/commands/entry-stop", ["state": "off"]),
      (.cancelOwnOrders, "/commands/cancel-own-orders", [:]),
      (.flatten, "/commands/flatten", [:]),
      (.flattenSymbol("ABCD"), "/commands/flatten", ["symbol": "ABCD"]),
      (.stopBot, "/commands/stop-bot", [:]),
      (.emergency, "/commands/emergency", [:]),
    ]
    for (index, (command, path, body)) in cases.enumerated() {
      _ = try await client.send(command)
      let request = StubProtocol.seen[index]
      #expect(request.httpMethod == "POST")
      #expect(request.url?.path == path)
      #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
      #expect(request.value(forHTTPHeaderField: "Origin") == nil)
      let sent = try JSONSerialization.jsonObject(with: StubProtocol.seenBodies[index]) as? [String: String]
      #expect(sent == body)
    }
  }

  @Test func idempotencyKeyIsSentOnlyWhenGiven() async throws {
    StubProtocol.answer = try (202, fixture("command-accepted-v1.flatten-symbol.json"))
    let accepted = try await client.send(.flattenSymbol("ABCD"), idempotencyKey: "action-1")
    #expect(accepted.command.symbol == "ABCD")
    #expect(StubProtocol.seen[0].value(forHTTPHeaderField: "Idempotency-Key") == "action-1")
    _ = try await client.send(.flattenSymbol("ABCD"))
    #expect(StubProtocol.seen[1].value(forHTTPHeaderField: "Idempotency-Key") == nil)
  }

  @Test func conflictIsATypedRefusal() async throws {
    let body = Data(#"{"error":"conflict","cause":"key reused","api_version":1}"#.utf8)
    StubProtocol.answer = (409, body)
    await #expect(throws: APIError.refused(status: 409, error: "conflict", cause: "key reused")) {
      try await client.send(.stopBot, idempotencyKey: "action-1")
    }
  }

  @Test func journalRead() async throws {
    StubProtocol.answer = try (200, fixture("journal-v1.json"))
    let journal = try await client.journal()
    #expect(journal.lastSeq == journal.rows.last?.seq)
    #expect(StubProtocol.seen.first?.url?.absoluteString == "http://127.0.0.1:8766/journal")
  }

  @Test func advisorRead() async throws {
    StubProtocol.answer = try (200, fixture("advisor-runs-v1.json"))
    let advisor = try await client.advisor()
    #expect(advisor.runs.map(\.status) == [.proposed, .idea, .refused])
    #expect(advisor.runs.filter(\.awaitingReview).count == advisor.awaitingReview)
    #expect(advisor.runs.first?.judges.first?.verdict == .noEvidence)
    #expect(StubProtocol.seen.first?.url?.absoluteString == "http://127.0.0.1:8766/advisor")
  }

  @Test func advisorDecisionPosts() async throws {
    StubProtocol.answer = try (200, fixture("advisor-runs-v1.json"))
    let runs = try await client.decideAdvisor(run: "20261115T150000Z-price-action-v1", verdict: .rejected)
    #expect(runs.awaitingReview == 1)
    let sent = try #require(StubProtocol.seen.first)
    #expect(sent.httpMethod == "POST")
    #expect(sent.url?.absoluteString == "http://127.0.0.1:8766/advisor/decision")
    let body = try JSONSerialization.jsonObject(with: try #require(StubProtocol.seenBodies.first))
    #expect(body as? [String: String] == ["run": "20261115T150000Z-price-action-v1", "verdict": "rejected"])
  }

  @Test func labReplayReadsAndStarts() async throws {
    StubProtocol.answer = try (200, fixture("lab-replay-v1.json"))
    let done = try await client.labReplay()
    #expect(done.state == .done)
    #expect(done.summary?.trades == 37)
    StubProtocol.answer = try (202, fixture("lab-replay-v1.running.json"))
    let started = try await client.startLabReplay()
    #expect(started.state == .running)
    #expect(StubProtocol.seen.map(\.httpMethod) == ["GET", "POST"])
    #expect(StubProtocol.seen.map { $0.url?.path } == ["/lab/replay", "/lab/replay"])
    let sent = try JSONSerialization.jsonObject(with: StubProtocol.seenBodies[1]) as? [String: String]
    #expect(sent == [:])
  }

  @Test func labReplayComparesOneDay() async throws {
    StubProtocol.answer = try (202, fixture("lab-replay-v1.running.json"))
    let started = try await client.startLabReplay(
      version: "price-action-v1", compare: "volume-shock-v1", day: try WireDate("2026-11-13"))
    #expect(started.compare?.state == .running)
    #expect(started.day?.text == "2026-11-13")
    #expect(started.versions.first?.role == .active)
    let body = try #require(StubProtocol.seenBodies.last)
    let sent = try JSONSerialization.jsonObject(with: body) as? [String: String]
    #expect(sent == ["version": "price-action-v1", "compare": "volume-shock-v1", "day": "2026-11-13"])
  }

  @Test func tradeWhatIfAsksForOneVersionOnOneDay() async throws {
    StubProtocol.answer = try (200, fixture("trade-whatif-v1.json"))
    let found = try await client.tradeWhatIf(
      symbol: "ABCD", day: try WireDate("2026-11-13"), version: "price-action-v2")
    #expect(found.trades.count == 2)
    #expect(found.trades.first?.exitReason == .strategyExit)
    #expect(found.resultGrossUsd == nil)
    let url = try #require(StubProtocol.seen.last?.url)
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    #expect(url.path == "/trades/whatif")
    #expect(Set(items.map { "\($0.name)=\($0.value ?? "")" })
      == ["date=2026-11-13", "symbol=ABCD", "version=price-action-v2"])
  }

  @Test func redeemPairingPostsTheCodeWithoutAToken() async throws {
    let remote = APIClient(baseURL: try #require(URL(string: "https://mac.ts.net")), transport: StubProtocol.session())
    StubProtocol.answer = try (200, fixture("paired-v1.json"))
    let paired = try await remote.redeemPairing(code: "c0de")
    #expect(paired.token == "example-token-not-a-secret_0123456789-abcdef")
    let sent = try #require(StubProtocol.seen.first)
    #expect(sent.httpMethod == "POST")
    #expect(sent.url?.absoluteString == "https://mac.ts.net/pair")
    #expect(sent.value(forHTTPHeaderField: "Authorization") == nil)
    let body = try JSONSerialization.jsonObject(with: StubProtocol.seenBodies[0]) as? [String: String]
    #expect(body == ["code": "c0de"])
  }

  @Test func refusedPairingCodeIsATypedRefusal() async throws {
    let remote = APIClient(baseURL: try #require(URL(string: "https://mac.ts.net")), transport: StubProtocol.session())
    let body = Data(#"{"error":"unauthorized","cause":"the pairing code has expired","api_version":1}"#.utf8)
    StubProtocol.answer = (401, body)
    await #expect(throws: APIError.refused(status: 401, error: "unauthorized", cause: "the pairing code has expired")) {
      try await remote.redeemPairing(code: "old")
    }
  }

  @Test func labReplayRunningIsAConflict() async throws {
    let body = Data(#"{"error":"conflict","cause":"replay running","api_version":1}"#.utf8)
    StubProtocol.answer = (409, body)
    await #expect(throws: APIError.refused(status: 409, error: "conflict", cause: "replay running")) {
      try await client.startLabReplay()
    }
  }

  @Test func acceptedWarningIsDecoded() async throws {
    StubProtocol.answer = try (202, fixture("command-accepted-v1.warning.json"))
    let accepted = try await client.send(.flatten)
    #expect(accepted.command.kind == .flatten)
    #expect(accepted.warning != nil)
  }

  @Test func typedRefusal() async throws {
    StubProtocol.answer = try (403, fixture("error-v1.json"))
    let error = await #expect(throws: APIError.self) { try await client.status() }
    guard case .refused(let status, let code, _) = error else {
      Issue.record("expected a refusal, got \(String(describing: error))")
      return
    }
    #expect(status == 403)
    #expect(code == "forbidden_host")
  }

  @Test(arguments: [(200, "{\"api_version\": 2}"), (500, "oops")])
  func nonContractAnswerIsAContractError(status: Int, body: String) async throws {
    StubProtocol.answer = (status, Data(body.utf8))
    let error = await #expect(throws: APIError.self) { try await client.status() }
    guard case .contract = error else {
      Issue.record("expected a contract error, got \(String(describing: error))")
      return
    }
  }

  @Test func pendingCommands() async throws {
    StubProtocol.answer = try (200, fixture("pending-commands-v1.json"))
    let pending = try await client.pendingCommands()
    #expect(pending.commands.map(\.kind) == [.flatten])
  }

  @Test func historyRequests() async throws {
    let day = try WireDate("2026-11-16")
    StubProtocol.answer = try (200, fixture("days-v1.json"))
    let days = try await client.days()
    #expect(days.days.first?.day == day)
    StubProtocol.answer = try (200, fixture("day-v1.json"))
    let one = try await client.day(day)
    #expect(one.trades.map(\.symbol) == ["WXYZ", "ABCD"])
    StubProtocol.answer = try (200, fixture("bars-v1.json"))
    let bars = try await client.bars(symbol: "ABCD", day: day)
    #expect(bars.bars.count == 3)
    #expect(StubProtocol.seen.map { $0.url?.absoluteString } == [
      "http://127.0.0.1:8766/days",
      "http://127.0.0.1:8766/days/2026-11-16",
      "http://127.0.0.1:8766/bars?symbol=ABCD&date=2026-11-16",
    ])
  }
}
