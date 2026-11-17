import Foundation
import Testing
@testable import TickrKit

@Suite("Connection state: what the screens say about the link to the bot")
struct ConnectionStateTests {
  let now = Date(timeIntervalSince1970: 1_800_000_000)
  let retry = 3
  let unreachable = ReadFailure(detail: "Local API not reachable: Could not connect to the server.")

  func response(_ name: String) throws -> StatusResponseV1 {
    try Wire.decoder().decode(StatusResponseV1.self, from: fixture(name))
  }

  @Test("A link with no address is not configured, whatever was read")
  func notConfigured() throws {
    let state = ConnectionState.make(configured: false, response: try response("status-response-v1.json"),
      failure: unreachable, lastSuccess: now)
    #expect(state == .notConfigured)
    #expect(state.hasNoData)
  }

  @Test("Before the first answer the link is connecting and says nothing")
  func connecting() {
    let state = ConnectionState.make(configured: true, response: nil, failure: nil, lastSuccess: nil)
    #expect(state == .connecting)
    #expect(state.message(retrySeconds: retry) == nil)
  }

  @Test("An answered read is connected: no banner, data current")
  func connected() throws {
    let state = ConnectionState.make(configured: true, response: try response("status-response-v1.json"),
      failure: nil, lastSuccess: now)
    #expect(state == .connected)
    #expect(state.message(retrySeconds: retry) == nil)
    #expect(!state.isLastKnown)
  }

  @Test("A failed read after a good one keeps the last known data, marked as such")
  func staleAfterFailure() throws {
    let last = now.addingTimeInterval(-60)
    let state = ConnectionState.make(configured: true, response: try response("status-response-v1.json"),
      failure: unreachable, lastSuccess: last)
    #expect(state == .stale(lastSuccess: last, failure: unreachable))
    #expect(state.isLastKnown)
    #expect(!state.hasNoData)
    let message = try #require(state.message(retrySeconds: retry))
    #expect(message.title == L10n.connectionUnreachableTitle)
    #expect(message.subtitle == L10n.connectionLastKnown(ConnectionState.time(last), retry))
    #expect(message.details == unreachable.detail)
  }

  @Test("A failed read with nothing ever read is never connected: an empty state")
  func neverConnected() {
    let state = ConnectionState.make(configured: true, response: nil, failure: unreachable, lastSuccess: nil)
    #expect(state == .neverConnected(failure: unreachable))
    #expect(state.hasNoData)
    #expect(!state.isLastKnown)
    #expect(state.message(retrySeconds: retry)?.title == L10n.connectionUnreachableTitle)
    #expect(state.message(retrySeconds: retry)?.subtitle == L10n.connectionNothingYet(retry))
  }

  @Test("An API that answers with an error reads the same calm title; its cause is behind Details")
  func answeredWithError() {
    let failure = ReadFailure(detail: "API refused (503 unavailable): the demo day is not answering on port 8767")
    let state = ConnectionState.make(configured: true, response: nil, failure: failure, lastSuccess: nil)
    #expect(state.message(retrySeconds: retry)?.title == L10n.connectionUnreachableTitle)
    #expect(state.message(retrySeconds: retry)?.details == failure.detail)
  }

  @Test("The banner's words in English are the mockup's")
  func mockupWording() {
    #expect(String(localized: L10n.connectionUnreachableTitle) == "Can't reach the bot")
    #expect(String(localized: L10n.connectionLastKnown("10:46:12", 3))
      == "showing data from 10:46:12 · retrying every 3 s · commands off")
  }

  @Test("The API answering without a bot status is its own state, its cause behind Details")
  func noBotStatus() throws {
    let state = ConnectionState.make(configured: true, response: try response("status-response-v1.unavailable.json"),
      failure: nil, lastSuccess: now)
    guard case .noBotStatus(let cause) = state else {
      Issue.record("expected noBotStatus, got \(state)")
      return
    }
    #expect(state.hasNoData)
    #expect(state.message(retrySeconds: retry)?.details == cause)
  }

  @Test("A failure keeps the API client's description; a cancelled read is no failure")
  func failureFromError() {
    #expect(ReadFailure(APIError.unreachable("offline"))?.detail == APIError.unreachable("offline").errorDescription)
    #expect(ReadFailure(CancellationError()) == nil)
  }

  @Test("The last good read shows its clock time to the second, on the shared 24-hour clock")
  func lastSuccessTime() {
    #expect(ConnectionState.time(now) == ClockText.seconds(now))
  }
}
