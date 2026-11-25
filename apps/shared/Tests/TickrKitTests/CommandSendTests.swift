import Foundation
import Synchronization
import Testing
@testable import TickrKit

/// Answers every request with one canned answer (or a transport failure) and keeps what was asked.
private final class OneAnswer: APITransport {
  private let asked = Mutex<[URLRequest]>([])
  private let status: Int
  private let body: Data
  private let fails: Bool

  init(_ status: Int, _ body: Data) {
    self.status = status
    self.body = body
    fails = false
  }

  /// No answer at all: the connection dropped.
  init(failing: Void) {
    status = 0
    body = Data()
    fails = true
  }

  var requests: [URLRequest] { asked.withLock { $0 } }

  func response(to request: URLRequest) async throws -> (Data, URLResponse) {
    asked.withLock { $0.append(request) }
    if fails { throw URLError(.networkConnectionLost) }
    let url = try #require(request.url)
    let response = try #require(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil))
    return (body, response)
  }
}

/// A send's outcome is queued, refused or unknown, and an unknown one is settled by the key's
/// receipt, never by a new key (backlog A3).
@Suite struct CommandSendTests {
  private static let key = "phone:decision-1"

  private func client(_ transport: OneAnswer) throws -> APIClient {
    APIClient(baseURL: try #require(URL(string: "http://127.0.0.1:8766")), transport: transport)
  }

  /// An error-v1 body with `error`.
  private func refusal(_ error: String) throws -> Data {
    var object = try #require(try JSONSerialization.jsonObject(with: fixture("error-v1.json")) as? [String: Any])
    object["error"] = error
    object["cause"] = "the same key was used for another command"
    object["cause_codes"] = [Any]()
    return try JSONSerialization.data(withJSONObject: object)
  }

  @Test func anAcceptedSendIsQueuedUnderItsKey() async throws {
    let transport = OneAnswer(202, try fixture("command-accepted-v1.json"))
    let outcome = await CommandSend.send(.emergency, key: Self.key, client: try client(transport))
    guard case .queued = outcome else { Issue.record("\(outcome)"); return }
    #expect(transport.requests.first?.value(forHTTPHeaderField: APIClient.idempotencyKeyHeader) == Self.key)
  }

  @Test func aRefusalQueuedNothingAndShowsNoCode() async throws {
    let transport = OneAnswer(409, try refusal("conflict"))
    let outcome = await CommandSend.send(.flatten, key: Self.key, client: try client(transport))
    guard case .refused(let cause) = outcome else { Issue.record("\(outcome)"); return }
    #expect(!cause.contains("409") && !cause.contains("conflict"))
  }

  @Test func aLostAnswerOrAServerErrorIsUnknown() async throws {
    let dropped = await CommandSend.send(.stopBot, key: Self.key, client: try client(OneAnswer(failing: ())))
    guard case .unknown = dropped else { Issue.record("\(dropped)"); return }
    // A 5xx can come after the command file was written: it proves nothing.
    let internalError = await CommandSend.send(.stopBot, key: Self.key,
      client: try client(OneAnswer(500, try refusal("internal"))))
    guard case .unknown = internalError else { Issue.record("\(internalError)"); return }
  }

  @Test func theReceiptSaysQueuedOrNotAndSendsTheKey() async throws {
    let queued = OneAnswer(200, try fixture("command-receipt-v1.json"))
    guard case .queued(let accepted) = await CommandSend.receipt(key: Self.key, client: try client(queued)) else {
      Issue.record("not queued"); return
    }
    #expect(!accepted.command.commandId.isEmpty)
    let request = try #require(queued.requests.first)
    #expect(request.httpMethod == "GET" && request.url?.path == APIClient.receiptPath)
    #expect(request.value(forHTTPHeaderField: APIClient.idempotencyKeyHeader) == Self.key)
    let notQueued = OneAnswer(200, try fixture("command-receipt-v1.not-queued.json"))
    #expect(await CommandSend.receipt(key: Self.key, client: try client(notQueued)) == .notQueued)
  }

  @Test func anOlderApiIsUnservedAndNoAnswerKeepsTheReceiptUnknown() async throws {
    // An API older than receipts can never say: the app drops the key instead of waiting on it.
    let older = OneAnswer(404, try refusal("not_found"))
    #expect(await CommandSend.receipt(key: Self.key, client: try client(older)) == .unserved)
    guard case .unknown = await CommandSend.receipt(key: Self.key, client: try client(OneAnswer(failing: ()))) else {
      Issue.record("no answer read as an answer"); return
    }
  }

  /// How long the bot accepts a command, in seconds, as settings-v1.json serves it.
  private static let keep = Decimal(60)

  @Test func aKeyStaysUntilTheOutcomeIsKnown() {
    var keys = CommandKeys()
    var made = 0
    let fresh = { () -> String in made += 1; return "key-\(made)" }
    let start = Date.now
    let first = keys.key(for: .emergency, now: start, keepSeconds: Self.keep, fresh: fresh)
    keys.lost(.emergency, key: first, at: start)
    // Pressed again while unknown: the same key, so the API answers the first send.
    #expect(keys.key(for: .emergency, now: start, keepSeconds: Self.keep, fresh: fresh) == first)
    // Another command is another decision.
    #expect(keys.key(for: .flattenSymbol("ABCD"), now: start, keepSeconds: Self.keep, fresh: fresh) != first)
    keys.settled(.emergency)
    #expect(keys.key(for: .emergency, now: start, keepSeconds: Self.keep, fresh: fresh) != first)
    keys.lost(.stopBot, key: "kept", at: start)
    keys.clear()
    #expect(keys.unknown.isEmpty)
  }

  @Test func aKeyIsNeverKeptPastTheBotsCommandAge() {
    var keys = CommandKeys()
    let start = Date.now
    keys.lost(.emergency, key: "first", at: start)
    let past = start.addingTimeInterval(NSDecimalNumber(decimal: Self.keep).doubleValue)
    // At the age the bot refuses the first send anyway: a press is a new decision with a new key.
    #expect(keys.key(for: .emergency, now: past, keepSeconds: Self.keep) != "first")
    // An API that does not say how long keeps no key at all.
    #expect(keys.key(for: .emergency, now: start, keepSeconds: nil) != "first")
    keys.lost(.stopBot, key: "young", at: past)
    #expect(keys.expire(now: past, keepSeconds: Self.keep) == [.emergency])
    #expect(keys.unknown.keys.map { $0 } == [.stopBot])
    #expect(keys.expire(now: past, keepSeconds: nil) == [.stopBot])
    #expect(keys.unknown.isEmpty)
  }
}
