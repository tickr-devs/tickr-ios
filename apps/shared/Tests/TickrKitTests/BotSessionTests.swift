import FactoryTesting
import Foundation
import Security
import Synchronization
import Testing
@testable import TickrKit

/// Answers each request with the next scripted result and records what was sent.
final class ScriptedTransport: APITransport {
  enum Answer: Sendable {
    case http(Int, String)
    /// An answer with these headers too.
    case headed(Int, String, [String: String])
    case failure(URLError.Code)
  }

  private struct State {
    var answers: [Answer]
    var sent: [URLRequest] = []
  }

  private let state: Mutex<State>

  init(_ answers: [Answer]) {
    state = Mutex(State(answers: answers))
  }

  var sent: [URLRequest] { state.withLock { $0.sent } }

  func body(_ index: Int) -> [String: Any]? {
    let data = sent[index].httpBody ?? Data()
    return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
  }

  func response(to request: URLRequest) async throws -> (Data, URLResponse) {
    let answer = state.withLock { state in
      state.sent.append(request)
      return state.answers.isEmpty ? Answer.failure(.badServerResponse) : state.answers.removeFirst()
    }
    switch answer {
    case .failure(let code):
      throw URLError(code)
    case .http(let status, let body):
      return Self.answer(status, body, nil, to: request)
    case .headed(let status, let body, let headers):
      return Self.answer(status, body, headers, to: request)
    }
  }

  private static func answer(
    _ status: Int, _ body: String, _ headers: [String: String]?, to request: URLRequest
  ) -> (Data, URLResponse) {
    let url = request.url ?? BotAddress.url
    let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: headers)
    return (Data(body.utf8), response ?? URLResponse())
    }
  }
}

/// One generic-password item in memory.
final class MemoryKeychain: KeychainItems {
  private let stored = Mutex<Data?>(nil)

  var text: String? { stored.withLock { $0.flatMap { String(bytes: $0, encoding: .utf8) } } }

  func copy(_ query: [String: Any]) -> Data? { stored.withLock { $0 } }

  func update(_ query: [String: Any], _ attributes: [String: Any]) -> OSStatus {
    stored.withLock { item in
      guard item != nil else { return errSecItemNotFound }
      item = attributes[kSecValueData as String] as? Data
      return errSecSuccess
    }
  }

  func add(_ item: [String: Any]) -> OSStatus {
    stored.withLock { $0 = item[kSecValueData as String] as? Data }
    return errSecSuccess
  }

  func delete(_ query: [String: Any]) -> OSStatus {
    stored.withLock { $0 = nil }
    return errSecSuccess
  }
}

final class TestClock: Sendable {
  private let moment = Mutex(Date(timeIntervalSince1970: 1_795_000_000))
  var now: Date { moment.withLock { $0 } }
  func advance(_ seconds: TimeInterval) { moment.withLock { $0 = $0.addingTimeInterval(seconds) } }
}

func sessionJSON(_ access: String, _ refresh: String, accessIn: Int = 900, refreshIn: Int = 2_592_000) -> String {
  #"{"access_token":"\#(access)","access_expires_in":\#(accessIn),"refresh_token":"\#(refresh)","#
    + #""refresh_expires_in":\#(refreshIn),"api_version":1}"#
}

func signedInAnswer(_ access: String, _ refresh: String) throws -> SessionV1 {
  try Wire.decoder().decode(SessionV1.self, from: Data(sessionJSON(access, refresh).utf8))
}

/// What a session reported as ended.
final class Ends: Sendable {
  private let list = Mutex<[SignInEnd]>([])
  var all: [SignInEnd] { list.withLock { $0 } }
  func add(_ end: SignInEnd) { list.withLock { $0.append(end) } }
}

/// The bot tokens on this device (BotSession.swift): kept in the Keychain, the access token
/// handed out until it runs out, one renewal at a time, never resent.
@Suite struct BotSessionTests {
  let clock = TestClock()
  let items = MemoryKeychain()

  func session(_ transport: ScriptedTransport) -> BotSession {
    let clock = clock
    return BotSession(keychain: Keychain(items: items), transport: transport, now: { clock.now })
  }

  @Test func noSignInMeansSignInAgain() async {
    await #expect(throws: BotSessionError.signInAgain) { try await session(ScriptedTransport([])).accessToken() }
  }

  @Test func theAccessTokenIsUsedUntilItRunsOut() async throws {
    let transport = ScriptedTransport([])
    let bot = session(transport)
    #expect(await bot.signedIn(try signedInAnswer("a1", "r1")))
    clock.advance(899)
    #expect(try await bot.accessToken() == "a1")
    #expect(transport.sent.isEmpty)
    #expect(items.text?.contains("r1") == true)
  }

  @Test func aRunOutAccessTokenIsRenewedOnceAndKept() async throws {
    let transport = ScriptedTransport([.http(200, sessionJSON("a2", "r2"))])
    let bot = session(transport)
    await bot.signedIn(try signedInAnswer("a1", "r1"))
    clock.advance(900)
    async let first = bot.accessToken()
    async let second = bot.accessToken()
    #expect(try await [first, second] == ["a2", "a2"])
    #expect(transport.sent.count == 1)
    let sent = transport.sent[0]
    #expect(sent.url?.absoluteString == "https://api.tickr.bot/session/refresh")
    #expect(sent.httpMethod == "POST")
    #expect(sent.value(forHTTPHeaderField: "Authorization") == nil)
    #expect(transport.body(0)?["refresh_token"] as? String == "r1")
    #expect(items.text?.contains("r2") == true)
    // Kept across a restart: a new session reads the Keychain.
    #expect(try await session(ScriptedTransport([])).accessToken() == "a2")
  }

  @Test func aRefusedRenewalSignsTheDeviceOut() async throws {
    let refusal = #"{"error":"unauthorized","cause":"used already","api_version":1}"#
    let bot = session(ScriptedTransport([.http(401, refusal)]))
    await bot.signedIn(try signedInAnswer("a1", "r1"))
    clock.advance(900)
    await #expect(throws: BotSessionError.signInAgain) { try await bot.accessToken() }
    #expect(items.text == nil)
    #expect(await !bot.isSignedIn)
  }

  @Test func aLostAnswerIsNeverResent() async throws {
    let transport = ScriptedTransport([.failure(.networkConnectionLost)])
    let bot = session(transport)
    await bot.signedIn(try signedInAnswer("a1", "r1"))
    clock.advance(900)
    await #expect(throws: BotSessionError.signInAgain) { try await bot.accessToken() }
    await #expect(throws: BotSessionError.signInAgain) { try await bot.accessToken() }
    #expect(transport.sent.count == 1)
  }

  @Test func noNetworkKeepsTheTokensForLater() async throws {
    let transport = ScriptedTransport([.failure(.notConnectedToInternet), .http(200, sessionJSON("a2", "r2"))])
    let bot = session(transport)
    await bot.signedIn(try signedInAnswer("a1", "r1"))
    clock.advance(900)
    await #expect(throws: BotSessionError.self) { try await bot.accessToken() }
    #expect(try await bot.accessToken() == "a2")
    #expect(transport.body(1)?["refresh_token"] as? String == "r1")
  }

  @Test func aRunOutRefreshTokenIsNotSent() async throws {
    let transport = ScriptedTransport([])
    let bot = session(transport)
    await bot.signedIn(try signedInAnswer("a1", "r1"))
    clock.advance(2_592_000)
    await #expect(throws: BotSessionError.signInAgain) { try await bot.accessToken() }
    #expect(transport.sent.isEmpty && items.text == nil)
  }

  @Test func aRevokedDeviceEndsItsSignInOnTheNextRequest() async throws {
    let unauthorized = #"{"error":"unauthorized","cause":"the bearer token is not the paired one","api_version":1}"#
    let refusal = #"{"error":"unauthorized","cause":"no signed-in device","api_version":1}"#
    let transport = ScriptedTransport([.http(401, unauthorized), .http(401, refusal)])
    let ends = Ends()
    let clock = clock
    let bot = BotSession(keychain: Keychain(items: items), transport: transport, now: { clock.now }, ended: { ends.add($0) })
    await bot.signedIn(try signedInAnswer("a1", "r1"))
    await #expect(throws: APIError.self) {
      try await APIClient(baseURL: BotAddress.url, session: bot, transport: transport).status()
    }
    #expect(transport.body(1)?["refresh_token"] as? String == "r1")
    #expect(ends.all == [.revoked] && items.text == nil)
  }

  @Test func aTokenThePairingLeftIsNoSignIn() async {
    #expect(Keychain(items: items).saveToken("a-pairing-token"))
    #expect(BotTokens.kept(in: Keychain(items: items)) == nil)
    await #expect(throws: BotSessionError.signInAgain) { try await session(ScriptedTransport([])).accessToken() }
  }

  @Test func theClientCarriesTheCurrentAccessToken() async throws {
    let transport = ScriptedTransport([.http(204, "")])
    let bot = session(transport)
    await bot.signedIn(try signedInAnswer("a1", "r1"))
    try await APIClient(baseURL: BotAddress.url, session: bot, transport: transport).signOut()
    #expect(transport.sent.first?.value(forHTTPHeaderField: "Authorization") == "Bearer a1")
  }
}
