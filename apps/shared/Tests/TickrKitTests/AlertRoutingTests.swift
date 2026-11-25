import Foundation
import Synchronization
import Testing
@testable import TickrKit

/// Answers GET with `read` and PUT with `write` (or drops the connection), keeping what was asked.
private final class AlertsAnswers: APITransport {
  private let asked = Mutex<[URLRequest]>([])
  private let read: (Int, Data)
  private let write: (Int, Data)?

  init(read: (Int, Data), write: (Int, Data)?) {
    self.read = read
    self.write = write
  }

  var requests: [URLRequest] { asked.withLock { $0 } }

  func response(to request: URLRequest) async throws -> (Data, URLResponse) {
    asked.withLock { $0.append(request) }
    let answer: (Int, Data)
    if request.httpMethod == APIClient.put {
      guard let write else { throw URLError(.networkConnectionLost) }
      answer = write
    } else {
      answer = read
    }
    let url = try #require(request.url)
    let response = try #require(HTTPURLResponse(url: url, statusCode: answer.0, httpVersion: nil, headerFields: nil))
    return (answer.1, response)
  }
}

/// The notification settings (backlog T14): which kinds the owner can switch, which columns are a
/// choice, and a change sent once whose answer, or the bot's state after a refusal, is shown.
@MainActor
@Suite struct AlertRoutingTests {
  private func alerts() throws -> AlertsV1 {
    try Wire.decoder().decode(AlertsV1.self, from: fixture("alerts-v1.json"))
  }

  private func client(_ transport: AlertsAnswers) throws -> APIClient {
    APIClient(baseURL: try #require(URL(string: "http://127.0.0.1:8766")), transport: transport)
  }

  /// The fixture with one cell changed, as the bot would answer it.
  private func answer(kind: String, channel: AlertChannel, on: Bool) throws -> Data {
    var object = try #require(try JSONSerialization.jsonObject(with: fixture("alerts-v1.json")) as? [String: Any])
    var kinds = try #require(object["kinds"] as? [[String: Any]])
    let index = try #require(kinds.firstIndex { $0["kind"] as? String == kind })
    var routes = try #require(kinds[index]["channels"] as? [String: Bool])
    routes[channel.rawValue] = on
    kinds[index]["channels"] = routes
    object["kinds"] = kinds
    return try JSONSerialization.data(withJSONObject: object)
  }

  private func refusal() throws -> Data {
    var object = try #require(try JSONSerialization.jsonObject(with: fixture("error-v1.json")) as? [String: Any])
    object["error"] = "conflict"
    object["cause"] = "locked-kind: unprotected-position"
    object["cause_codes"] = [Any]()
    return try JSONSerialization.data(withJSONObject: object)
  }

  @Test func lockedKindsAreApartAndTheRestGroupedInOrder() throws {
    let alerts = try alerts()
    #expect(alerts.lockedKinds.allSatisfy(\.locked))
    #expect(alerts.lockedKinds.count + alerts.switchableGroups.flatMap(\.kinds).count == alerts.kinds.count)
    let groups = alerts.switchableGroups.map(\.group)
    #expect(groups == AlertsV1.groupOrder.filter(groups.contains))
    #expect(alerts.switchableGroups.allSatisfy { group in group.kinds.allSatisfy { !$0.locked && $0.group == group.group } })
  }

  @Test func aChannelNotBuiltIsNoChoice() throws {
    let alerts = try alerts()
    #expect(alerts.channel(.push)?.cause == .notBuilt)
    #expect(!alerts.canChange(.push))
    #expect(alerts.canChange(.mac))
    // A channel that failed the morning check stays a choice: the routing is a preference.
    #expect(alerts.channel(.imessage)?.configured == false)
    #expect(alerts.canChange(.imessage))
  }

  @Test func everyKindHasWordsAndAnUnknownOneNoCode() throws {
    for kind in try alerts().kinds {
      #expect(AlertKindCode(rawValue: kind.kind) != nil, "\(kind.kind)")
    }
    #expect(String(localized: AlertText.kind("never-sent")) == String(localized: AlertText.otherAlert))
  }

  @Test func aChangeIsSentOnceAndItsAnswerShown() async throws {
    let kind = try #require(try alerts().kinds.first { !$0.locked })
    let transport = AlertsAnswers(
      read: (200, try fixture("alerts-v1.json")),
      write: (200, try answer(kind: kind.kind, channel: .mac, on: !kind.channels.mac)))
    let routing = AlertRouting()
    await routing.refresh(try client(transport))
    await routing.set(AlertCell(kind: kind.kind, channel: .mac), on: !kind.channels.mac, client: try client(transport))
    let puts = transport.requests.filter { $0.httpMethod == APIClient.put }
    #expect(puts.count == 1)
    #expect(puts.first?.url?.path == APIClient.alertRoutingPath)
    let body = try #require(puts.first?.httpBody)
    let sent = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    #expect(sent["kind"] as? String == kind.kind)
    #expect(sent["channel"] as? String == "mac")
    #expect(sent["on"] as? Bool == !kind.channels.mac)
    let shown = try #require(routing.alerts?.kinds.first { $0.kind == kind.kind })
    #expect(routing.isOn(shown, .mac) == !kind.channels.mac)
    #expect(routing.pending.isEmpty && routing.changeError == nil)
  }

  @Test func aRefusalShowsWhyAndTheBotsStateAgain() async throws {
    let kind = try #require(try alerts().kinds.first { !$0.locked })
    let transport = AlertsAnswers(read: (200, try fixture("alerts-v1.json")), write: (409, try refusal()))
    let routing = AlertRouting()
    await routing.set(AlertCell(kind: kind.kind, channel: .mac), on: !kind.channels.mac, client: try client(transport))
    let error = try #require(routing.changeError)
    #expect(!error.contains("409") && !error.contains("conflict"))
    let shown = try #require(routing.alerts?.kinds.first { $0.kind == kind.kind })
    #expect(routing.isOn(shown, .mac) == kind.channels.mac)
    #expect(transport.requests.filter { $0.httpMethod == APIClient.put }.count == 1)
  }

  @Test func aLostAnswerIsNeverSentAgainOnlyReadAgain() async throws {
    let transport = AlertsAnswers(read: (200, try fixture("alerts-v1.json")), write: nil)
    let routing = AlertRouting()
    await routing.set(AlertCell(kind: "daily-ceiling-reached", channel: .imessage), on: false, client: try client(transport))
    #expect(routing.changeError != nil)
    #expect(transport.requests.filter { $0.httpMethod == APIClient.put }.count == 1)
    #expect(routing.alerts != nil)
  }

  @Test func clearingDropsEverything() async throws {
    let transport = AlertsAnswers(read: (200, try fixture("alerts-v1.json")), write: nil)
    let routing = AlertRouting()
    await routing.refresh(try client(transport))
    #expect(routing.alerts != nil)
    routing.clear()
    #expect(routing.alerts == nil && routing.readError == nil && routing.pending.isEmpty)
  }
}
