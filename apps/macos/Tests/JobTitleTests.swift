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
}
