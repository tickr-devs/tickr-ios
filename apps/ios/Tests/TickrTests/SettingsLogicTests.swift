import Foundation
import Testing
@testable import Tickr
import TickrDesign
import TickrKit

/// The backup row of Settings → Jobs is green only when a good backup exists and no failure is
/// newer.
@MainActor
@Suite struct SettingsLogicTests {
  private static let earlier = "2026-11-16T13:00:00.000Z"
  private static let later = "2026-11-16T14:00:00.000Z"

  private func job(last: String?, failed: String?) throws -> BackupJobV1 {
    try decode(BackupJobV1.self, [
      "last_at": last ?? NSNull(),
      "last_failed_at": failed ?? NSNull(),
      "last_failed_error": failed == nil ? NSNull() : "disk full",
      "cause": NSNull(),
    ] as [String: Any])
  }

  @Test func noBackupYetIsNeutral() throws {
    #expect(JobsSection.backupTone(try job(last: nil, failed: nil)) == .neutral)
  }

  @Test func goodBackupIsGreen() throws {
    #expect(JobsSection.backupTone(try job(last: Self.later, failed: Self.earlier)) == .profit)
    #expect(JobsSection.backupTone(try job(last: Self.later, failed: nil)) == .profit)
  }

  @Test func newerFailureIsRed() throws {
    #expect(JobsSection.backupTone(try job(last: Self.earlier, failed: Self.later)) == .loss)
    #expect(JobsSection.backupTone(try job(last: nil, failed: Self.later)) == .loss)
  }

  @Test func fixtureBackupIsGreen() throws {
    let jobs = try fixture(JobsV1.self, "jobs-v1.json")
    #expect(JobsSection.backupTone(jobs.backup) == .profit)
  }
}

/// What the Lab and Settings motion plays on: the active strategy pill pulses once per new entry
/// of the active version, the closed gate's dot once per gate change.
@MainActor
@Suite struct MotionTriggerTests {
  private static let entry = "2026-11-16T15:30:00.000Z"
  private static let close = "2026-11-16T15:40:00.000Z"

  /// The example status (one closed trade WXYZ, one open position ABCD) with `extra` closed trades
  /// and `positions` replaced when given.
  private func status(
    extra: [[String: Any]] = [], positions: [[String: Any]]? = nil
  ) throws -> StatusV1 {
    var object = try fixtureObject("status-v1.example.json")
    let trades = try #require(object["trades_today"] as? [[String: Any]])
    object["trades_today"] = trades + extra
    if let positions { object["positions"] = positions }
    return try decode(StatusV1.self, object)
  }

  /// A closed trade of `symbol` opened at `entry`, by `version` of the example strategy (nil: none
  /// recorded).
  private func trade(_ symbol: String, version: String?) throws -> [String: Any] {
    var trade = try #require((try fixtureObject("status-v1.example.json")["trades_today"] as? [[String: Any]])?.first)
    trade["symbol"] = symbol
    trade["opened_at"] = Self.entry
    trade["closed_at"] = Self.close
    trade["strategy"] = version.map { ["name": "price-action-v1", "version": $0] } ?? NSNull()
    return trade
  }

  @Test func activePillCountsEachEntryOnce() throws {
    let base = try status()
    #expect(LabView.entries(base) == 2)
    // A new trade of the active version, or one without a recorded strategy: one more entry each.
    #expect(LabView.entries(try status(extra: [trade("NEWT", version: "1")])) == 3)
    #expect(LabView.entries(try status(extra: [trade("NEWT", version: nil)])) == 3)
    // Another version's trade is not the active strategy's.
    #expect(LabView.entries(try status(extra: [trade("NEWT", version: "2")])) == 2)
  }

  @Test func closingAPositionIsNotANewEntry() throws {
    let open = try status()
    let position = try #require(try fixtureObject("status-v1.example.json")["positions"] as? [[String: Any]])
    let held = try #require(position.first)
    // The position ABCD closes: it leaves positions and comes back as a closed trade, same entry.
    var closed = try trade("ABCD", version: "1")
    closed["opened_at"] = held["opened_at"]
    let after = try status(extra: [closed], positions: [])
    #expect(LabView.entries(after) == LabView.entries(open))
  }
}
