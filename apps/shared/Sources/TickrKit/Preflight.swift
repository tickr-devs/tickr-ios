import Foundation

/// The checks the owner looks at before trusting the bot with a session, each from what the bot
/// reported: its status and its last broker read (GET /account). A check whose input is missing
/// or out of date is unknown, never passed.
public enum Preflight {
  public enum Check: CaseIterable, Sendable {
    /// The bot's process is running.
    case botRunning
    /// The bot's status is current (not stale, not unavailable).
    case statusCurrent
    /// The quote stream is fresh for the open positions (not needed without one: the bot then
    /// reports the stream `off` by design).
    case streamFresh
    /// The broker's positions and orders matched the bot's records at its last read.
    case brokerMatches
    /// Every open position has a verified broker-side stop.
    case stopsVerified
    /// The trading gate is open.
    case gateOpen
  }

  /// `notNeeded`: the check has nothing to prove now (no open position needs a fresh quote); shown
  /// neutral and never counted as failing.
  public enum Outcome: Equatable, Sendable { case passed, failed, unknown, notNeeded }

  public struct Result: Identifiable, Equatable, Sendable {
    public let check: Check
    public let outcome: Outcome
    public var id: Check { check }
  }

  /// Every check, in `Check.allCases` order. `readFailed` is true when the latest read of the
  /// status failed: an older response then proves nothing about now.
  public static func run(status response: StatusResponseV1?, readFailed: Bool, account: AccountResponseV1?)
    -> [Result] {
    // Checks about the bot's state are only as good as a current status from the latest read.
    let current = readFailed ? nil : response.flatMap { $0.stale ? nil : $0.status }
    return Check.allCases.map { check in
      let outcome: Outcome
      switch check {
      case .statusCurrent:
        outcome = response == nil && !readFailed ? .unknown : (current == nil ? .failed : .passed)
      case .botRunning:
        outcome = verdict(current.map { $0.botState == .running })
      case .streamFresh:
        outcome = current.map { $0.freshness.stream == .off ? .notNeeded : verdict($0.freshness.stream == .fresh) }
          ?? .unknown
      case .stopsVerified:
        outcome = verdict(current.map { $0.positions.allSatisfy { $0.stop.state == .verified } })
      case .gateOpen:
        outcome = verdict(current.map(\.tradingGate.open))
      case .brokerMatches:
        // A stale broker read proves nothing about now.
        outcome = verdict(account.map { !$0.stale && $0.account.matchesRecords })
      }
      return Result(check: check, outcome: outcome)
    }
  }

  static func verdict(_ passed: Bool?) -> Outcome {
    guard let passed else { return .unknown }
    return passed ? .passed : .failed
  }
}
