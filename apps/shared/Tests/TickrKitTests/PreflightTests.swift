import Foundation
import Testing
@testable import TickrKit

@Suite("Preflight checks")
struct PreflightTests {
  func response(_ name: String) throws -> StatusResponseV1 {
    try Wire.decoder().decode(StatusResponseV1.self, from: fixture(name))
  }

  func account(_ name: String) throws -> AccountResponseV1 {
    try Wire.decoder().decode(AccountResponseV1.self, from: fixture(name))
  }

  func outcomes(_ results: [Preflight.Result]) -> [Preflight.Check: Preflight.Outcome] {
    Dictionary(uniqueKeysWithValues: results.map { ($0.check, $0.outcome) })
  }

  @Test("A current status and a matching broker read pass every check")
  func allPass() throws {
    let results = Preflight.run(status: try response("status-response-v1.json"), readFailed: false,
      account: try account("account-response-v1.json"))
    #expect(results.map(\.check) == Preflight.Check.allCases)
    #expect(results.allSatisfy { $0.outcome == .passed })
  }

  @Test("Nothing read yet: every check is unknown, none passed")
  func nothingRead() {
    #expect(Preflight.run(status: nil, readFailed: false, account: nil).allSatisfy { $0.outcome == .unknown })
  }

  @Test("A stale status fails its own check and leaves the bot's state unknown")
  func staleStatus() throws {
    let results = outcomes(Preflight.run(status: try response("status-response-v1.stale.json"), readFailed: false,
      account: nil))
    #expect(results[.statusCurrent] == .failed)
    #expect(results[.botRunning] == .unknown)
    #expect(results[.stopsVerified] == .unknown)
    #expect(results[.brokerMatches] == .unknown)
  }

  @Test("A stale or mismatching broker read fails the broker check")
  func brokerMismatch() throws {
    let results = outcomes(Preflight.run(status: try response("status-response-v1.json"), readFailed: false,
      account: try account("account-response-v1.stale.json")))
    #expect(results[.brokerMatches] == .failed)
    #expect(results[.statusCurrent] == .passed)
  }

  @Test("No open position passes the stop check")
  func noPositions() throws {
    let results = outcomes(Preflight.run(status: try response("status-response-v1.minimal.json"), readFailed: false,
      account: nil))
    #expect(results[.stopsVerified] == .passed)
  }

  @Test("A failed latest read never passes, even after a good older response")
  func failedRead() throws {
    let results = outcomes(Preflight.run(status: try response("status-response-v1.json"), readFailed: true,
      account: nil))
    #expect(results[.statusCurrent] == .failed)
    #expect(results[.botRunning] == .unknown)
    #expect(results[.stopsVerified] == .unknown)
    #expect(results[.gateOpen] == .unknown)
    #expect(!results.values.contains(.passed))
  }
}
