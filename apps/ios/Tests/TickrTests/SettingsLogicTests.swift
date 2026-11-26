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

/// The "Notify this iPhone" card shows the board's choice: the three alarms locked on, fills and the
/// loss ceiling on, the trailing stop off.
@Suite struct NotificationsSectionTests {
  @Test func alarmsAreLockedOn() {
    let locked = NotificationsSection.Event.allCases.filter(\.locked)
    #expect(locked == [.unprotected, .refused, .mismatch])
    for event in locked { #expect(event.on) }
  }

  @Test func ownerChoicesStartAsOnTheBoard() {
    let on = NotificationsSection.Event.allCases.filter { !$0.locked && $0.on }
    #expect(on == [.filled, .ceiling])
    #expect(!NotificationsSection.Event.trailing.on)
  }
}
