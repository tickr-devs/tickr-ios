import ActivityKit
import TickrKit
import UIKit

/// Hands the bot the phone's push tokens (APNs): TickrScreens' `NotificationPermission` asks to
/// show notifications and registers once allowed; the token it gets, and the Live Activity's
/// tokens (`LiveActivityTokens`), go to the bot through `PushRegistrar`. A failure is recorded in
/// the diagnostics log; the next launch or a new token tries again, never a loop.
@MainActor
final class PhoneAppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    LiveActivityTokens.watch(Container.shared.pushRegistrar())
    return true
  }

  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Container.shared.pushRegistrar().received(deviceToken, kind: .alert)
  }

  func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
    Container.shared.pushRegistrar().failed(error, kind: .alert)
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
