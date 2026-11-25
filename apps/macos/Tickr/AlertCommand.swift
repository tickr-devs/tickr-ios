import Foundation
import SwiftUI
import UserNotifications

/// The app's entry point. Started as `<executable> --notify-alert TITLE TEXT` (by the bot and the
/// watchdog, src/tickr/runtime/alerts.py `AppNotifier`), it shows one notification with the
/// app's icon and exits without opening a window; otherwise it starts the app.
@main
enum Launcher {
  @MainActor
  static func main() {
    if let request = AlertRequest(arguments: CommandLine.arguments) {
      Task {
        let code = await AlertPoster().post(request)
        exit(code.rawValue)
      }
      // Runs the main actor's work (the task above) until it exits the process.
      RunLoop.main.run()
    }
    TickrMacApp.main()
  }
}

/// One alert to show, from the command line: exactly the flag, a title and a text.
struct AlertRequest: Equatable {
  /// The command-line flag of the notify mode (APP_ALERT_FLAG in runtime/alerts.py).
  static let flag = "--notify-alert"
  /// Arguments in notify mode: the executable, the flag, the title and the text.
  static let argumentCount = 4

  let title: String
  let text: String

  init?(arguments: [String]) {
    guard arguments.count == Self.argumentCount, arguments[1] == Self.flag else { return nil }
    title = arguments[2]
    text = arguments[3]
  }
}

/// Exit status of the notify mode, which the bot reads: anything but `shown` makes it show the
/// alert through osascript instead, so an alert is never lost.
enum AlertExit: Int32 {
  /// Handed to Notification Center.
  case shown = 0
  /// Notifications for the app are off or show nothing (System Settings > Notifications), or were
  /// never allowed.
  case notAllowed = 2
  /// Notification Center refused the request.
  case failed = 3
}

/// Shows the bot's alerts as the app's own notifications.
struct AlertPoster {
  /// Extension of an app bundle.
  static let appExtension = "app"

  /// Notifications need an app bundle: a `swift run` binary has none (Notification Center would
  /// stop the process), so there the notify mode reports `notAllowed` and the bot uses osascript.
  static var available: Bool { Bundle.main.bundleURL.pathExtension == appExtension }

  /// Asks once to show notifications; the app does this at launch, so the notify mode (which
  /// cannot show the question) finds the answer already given. True when they are allowed.
  @discardableResult
  func requestPermission() async -> Bool {
    (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
  }

  func post(_ request: AlertRequest) async -> AlertExit {
    guard Self.available else { return .notAllowed }
    let center = UNUserNotificationCenter.current()
    // Allowed but set to show nothing ("None") would exit 0 and show nothing: osascript instead.
    let settings = await center.notificationSettings()
    guard settings.authorizationStatus == .authorized, settings.alertSetting == .enabled else { return .notAllowed }
    let content = UNMutableNotificationContent()
    content.title = request.title
    content.body = request.text
    content.sound = .default
    do {
      try await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
      return .shown
    } catch {
      return .failed
    }
  }
}
