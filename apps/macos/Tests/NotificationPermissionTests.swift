import Foundation
import Testing
@testable import TickrScreens
import UserNotifications

@MainActor
@Suite("Notification permission")
struct NotificationPermissionTests {
  /// A defaults domain of this suite's own, empty at the start of each test.
  static func freshDefaults() throws -> UserDefaults {
    let name = "NotificationPermissionTests-\(UUID().uuidString)"
    return try #require(UserDefaults(suiteName: name))
  }

  @Test("The system's answers read as the screen's states")
  func statesFollowTheSystem() {
    #expect(NotificationPermission.state(of: .notDetermined) == .notAsked)
    #expect(NotificationPermission.state(of: .denied) == .denied)
    #expect(NotificationPermission.state(of: .authorized) == .allowed)
    #expect(NotificationPermission.state(of: .provisional) == .allowed)
  }

  @Test("A run that may not ask never shows the screen")
  func aRunThatMayNotAskShowsNothing() async throws {
    let permission = NotificationPermission(enabled: false, defaults: try Self.freshDefaults())
    await permission.screensShown()
    #expect(!permission.asking)
    #expect(permission.state == .unknown)
  }

  @Test("Not now closes the screen and keeps it from showing again by itself")
  func notNowIsRemembered() throws {
    let defaults = try Self.freshDefaults()
    let permission = NotificationPermission(enabled: false, defaults: defaults)
    permission.asking = true
    permission.notNow()
    #expect(!permission.asking)
    #expect(defaults.bool(forKey: NotificationPermission.answeredKey))
  }
}
