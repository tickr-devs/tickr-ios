import ActivityKit
import TickrKit
import UIKit
import UserNotifications

/// Registers the phone for the bot's push (APNs): once the screens show it asks to show
/// notifications and, once allowed, registers for remote notifications; the token it gets, and the Live Activity's
/// tokens (`LiveActivityTokens`), go to the bot through `PushRegistrar`. A failure is recorded in
/// the diagnostics log; the next launch or a new token tries again, never a loop.
@MainActor
final class PhoneAppDelegate: NSObject, UIApplicationDelegate {
  /// UserDefaults key, set to NO as a launch argument by the UI tests (`-askForNotifications NO`),
  /// that keeps the notification question off a run nobody answers.
  static let asksKey = "askForNotifications"

  func application(
    _ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    LiveActivityTokens.watch(Container.shared.pushRegistrar())
    return true
  }

  /// Asks to show notifications once the app's screens show (`PhoneSignInGate`: after the opening
  /// and the sign-in), never while it loads; not when the UI tests turned it off.
  static func askWhenReady() {
    let defaults = UserDefaults.standard
    guard defaults.object(forKey: asksKey) == nil || defaults.bool(forKey: asksKey) else { return }
    Task { await registerWhenAllowed(UIApplication.shared) }
  }

  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Container.shared.pushRegistrar().received(deviceToken, kind: .alert)
  }

  func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
    Container.shared.pushRegistrar().failed(error, kind: .alert)
  }

  /// Asks once to show alerts with sound (the bot's critical alerts arrive time-sensitive, by the
  /// entitlement); registers only when they are allowed, since a token is worth nothing otherwise.
  private static func registerWhenAllowed(_ application: UIApplication) async {
    let center = UNUserNotificationCenter.current()
    do {
      guard try await center.requestAuthorization(options: [.alert, .sound]) else { return }
    } catch {
      Container.shared.pushRegistrar().failed(error, kind: .alert)
      return
    }
    application.registerForRemoteNotifications()
  }
}

/// The Live Activity's push tokens for the bot: the push-to-start token (the bot starts the
/// activity at the day's first fill) and the update token of each activity it started. The app
/// never starts an activity itself.
@MainActor
enum LiveActivityTokens {
  /// Reports every such token to `registrar` while the app runs.
  static func watch(_ registrar: PushRegistrar) {
    Task {
      for await token in Activity<TickrActivityAttributes>.pushToStartTokenUpdates {
        registrar.received(token, kind: .activityStart)
      }
    }
    Task {
      for activity in Activity<TickrActivityAttributes>.activities { follow(activity, registrar) }
      for await activity in Activity<TickrActivityAttributes>.activityUpdates { follow(activity, registrar) }
    }
  }

  /// Reports `activity`'s update token, and each new one, until it ends.
  private static func follow(_ activity: Activity<TickrActivityAttributes>, _ registrar: PushRegistrar) {
    Task {
      for await token in activity.pushTokenUpdates {
        registrar.received(token, kind: .activityUpdate)
      }
    }
  }
}
