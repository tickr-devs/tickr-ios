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
    let allLocked = alerts.lockedKinds.allSatisfy { $0.locked }
    #expect(allLocked)
    let switchable = alerts.switchableGroups.reduce(0) { $0 + $1.kinds.count }
    #expect(alerts.lockedKinds.count + switchable == alerts.kinds.count)
    let groups = alerts.switchableGroups.map { $0.group }
    let ordered = AlertsV1.groupOrder.filter { groups.contains($0) }
    #expect(groups == ordered)
    for section in alerts.switchableGroups {
      let fits = section.kinds.allSatisfy { !$0.locked && $0.group == section.group }
      #expect(fits)
    }
  }

  @Test func aChannelNotBuiltIsNoChoiceOneNotSetUpIs() throws {
    let alerts = try alerts()
    #expect(alerts.channel(.push)?.cause == .notBuilt)
    #expect(!alerts.canChange(.push))
    // A channel the owner has not set up yet stays a choice: the routing is a preference.
    #expect(alerts.channel(.telegram)?.cause == .notConfigured)
    #expect(alerts.canChange(.telegram))
  }

  @Test func theColumnsAreTheChannelsTheBotAnswers() throws {
    let alerts = try alerts()
    #expect(alerts.columns == alerts.channels.map(\.channel))
    // A bot that retires a channel loses its column, never shows a stale one.
    var object = try #require(try JSONSerialization.jsonObject(with: fixture("alerts-v1.json")) as? [String: Any])
    let channels = try #require(object["channels"] as? [[String: Any]])
    object["channels"] = channels.filter { $0["channel"] as? String != "telegram" }
    let fewer = try Wire.decoder().decode(AlertsV1.self, from: try JSONSerialization.data(withJSONObject: object))
    #expect(!fewer.columns.contains(.telegram))
    #expect(fewer.columns.count == alerts.columns.count - 1)
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
      write: (200, try answer(kind: kind.kind, channel: .telegram, on: !kind.channels.telegram)))
    let routing = AlertRouting()
    await routing.refresh(try client(transport))
    await routing.set(AlertCell(kind: kind.kind, channel: .telegram), on: !kind.channels.telegram, client: try client(transport))
    let puts = transport.requests.filter { $0.httpMethod == APIClient.put }
    #expect(puts.count == 1)
    #expect(puts.first?.url?.path == APIClient.alertRoutingPath)
    let body = try #require(puts.first?.httpBody)
    let sent = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    #expect(sent["kind"] as? String == kind.kind)
    #expect(sent["channel"] as? String == "telegram")
    #expect(sent["on"] as? Bool == !kind.channels.telegram)
    let shown = try #require(routing.alerts?.kinds.first { $0.kind == kind.kind })
    #expect(routing.isOn(shown, .telegram) == !kind.channels.telegram)
    #expect(routing.pending.isEmpty && routing.changeError == nil)
  }

  @Test func aRefusalShowsWhyAndTheBotsStateAgain() async throws {
    let kind = try #require(try alerts().kinds.first { !$0.locked })
    let transport = AlertsAnswers(read: (200, try fixture("alerts-v1.json")), write: (409, try refusal()))
    let routing = AlertRouting()
    await routing.set(AlertCell(kind: kind.kind, channel: .telegram), on: !kind.channels.telegram, client: try client(transport))
    let error = try #require(routing.changeError)
    #expect(!error.contains("409") && !error.contains("conflict"))
    let shown = try #require(routing.alerts?.kinds.first { $0.kind == kind.kind })
    #expect(routing.isOn(shown, .telegram) == kind.channels.telegram)
    #expect(transport.requests.filter { $0.httpMethod == APIClient.put }.count == 1)
  }

  @Test func aLostAnswerIsNeverSentAgainOnlyReadAgain() async throws {
    let transport = AlertsAnswers(read: (200, try fixture("alerts-v1.json")), write: nil)
    let routing = AlertRouting()
    await routing.set(AlertCell(kind: "daily-ceiling-reached", channel: .telegram), on: false, client: try client(transport))
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
