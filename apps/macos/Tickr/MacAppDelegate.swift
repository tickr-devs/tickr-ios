#if os(macOS)
import AppKit
import TickrKit

/// Hands the push token the system gives this Mac to the bot (`PushRegistrar`): the app registers
/// for remote notifications once notifications are allowed (TickrMacApp). A failure, such as a
/// build signed without a team (no push entitlement), is recorded in the diagnostics log only.
@MainActor
final class MacAppDelegate: NSObject, NSApplicationDelegate {
  func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Container.shared.pushRegistrar().received(deviceToken, kind: .alert)
  }

  func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
    Container.shared.pushRegistrar().failed(error, kind: .alert)
  }
}
#endif
