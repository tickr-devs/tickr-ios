import Foundation
import Testing
@testable import TickrMac

@MainActor
@Suite("Launchd job names in Settings")
struct JobTitleTests {
  @Test("A known job reads in words; an unknown one never as its launchd name")
  func title() {
    #expect(JobsSection.title("watchdog") == String(localized: L10n.Settings.jobWatchdog))
    #expect(JobsSection.title("com.example.new-job") == String(localized: L10n.Settings.jobOther))
  }

  @Test("The bot's start reads with its day when it was not today in New York")
  func startedDay() throws {
    let wire = ISO8601DateFormatter()
    let evening = try #require(wire.date(from: "2026-11-18T02:29:00Z"))  // Nov 17, 21:29 ET
    let morning = try #require(wire.date(from: "2026-11-18T14:00:00Z"))  // Nov 18, 09:00 ET
    #expect(JobsSection.started(evening, now: morning) == BackupSection.when(evening))
    #expect(JobsSection.started(morning, now: morning) == Format.marketMinute(morning))
  }
}
