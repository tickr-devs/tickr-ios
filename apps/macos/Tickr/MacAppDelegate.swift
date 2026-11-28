#if os(macOS)
import AppKit
import TickrKit
import UserNotifications

/// Hands the push token the system gives this Mac to the bot (`PushRegistrar`): the app registers
/// for remote notifications once notifications are allowed (TickrMacApp). A failure, such as a
/// build signed without a team (no push entitlement), is recorded in the diagnostics log only.
@MainActor
final class MacAppDelegate: NSObject, NSApplicationDelegate {
  /// Path extension of an app bundle; without one (`swift run`) the system has no app to notify.
  static let appExtension = "app"

  /// True when the app runs from a bundle, so notifications and push can be asked for.
  static var isBundled: Bool { Bundle.main.bundleURL.pathExtension == appExtension }

  /// Whether this run asks to show notifications: not in the UI tests' fixture mode, where nobody
  /// could answer, nor without an app bundle (`swift run`).
  static var asksForNotifications: Bool {
    #if DEBUG
    isBundled && !PreviewAPI.servesFixtures
    #else
    isBundled
    #endif
  }

  /// Asks once to show notifications; when allowed, registers for remote notifications, and the
  /// token reaches the bot through `PushRegistrar`.
  static func registerForPushIfAllowed() async {
    let center = UNUserNotificationCenter.current()
    guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
    NSApplication.shared.registerForRemoteNotifications()
  }

  func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Container.shared.pushRegistrar().received(deviceToken, kind: .alert)
  }

  func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
    Container.shared.pushRegistrar().failed(error, kind: .alert)
  }
}
#endif
