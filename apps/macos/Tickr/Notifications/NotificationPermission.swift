import Foundation
import TickrKit
import UserNotifications
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Whether this device shows the bot's notifications, and when the app's own screen asks for them
/// (`NotificationsAsk`, mockup v189, board PushAsk): once, after the first sign-in, never while the
/// app loads. "Allow notifications" brings the system's question; "Not now" leaves it for Settings ›
/// Connection. Once allowed, every run registers for remote notifications and the token reaches the
/// bot through `PushRegistrar`. One per app run (`Container.notificationPermission`).
@MainActor
@Observable
public final class NotificationPermission {
  /// What the system says of this app's notifications.
  public enum State: Sendable, Equatable {
    /// Not read yet.
    case unknown
    /// The system never asked.
    case notAsked
    case allowed
    /// Turned off: only the system's settings turn them on again.
    case denied
  }

  /// UserDefaults key, set to NO as a launch argument by the UI tests (`-askForNotifications NO`),
  /// that keeps the screen and the system's question off a run nobody answers.
  public static let asksKey = "askForNotifications"
  /// UserDefaults key: the screen was answered once, either way.
  static let answeredKey = "notificationsAsked"
  #if os(macOS)
  /// The system settings page of the apps' notifications (the Mac has no address for one app's).
  static let settingsAddress = "x-apple.systempreferences:com.apple.Notifications-Settings.extension"
  #endif

  public private(set) var state = State.unknown
  /// The screen shows.
  public var asking = false
  @ObservationIgnored private let enabled: Bool
  @ObservationIgnored private let defaults: UserDefaults

  /// `enabled` false: nothing is ever asked (UI tests, a run without an app bundle).
  public init(enabled: Bool, defaults: UserDefaults = .standard) {
    self.enabled = enabled
    self.defaults = defaults
  }

  /// Whether this run may ask: not when the UI tests turned it off, nor on a Mac run nobody can
  /// answer (`MacAppDelegate.asksForNotifications`).
  public static var asksOnThisRun: Bool {
    let defaults = UserDefaults.standard
    let allowed = defaults.object(forKey: asksKey) == nil || defaults.bool(forKey: asksKey)
    #if os(macOS)
    return allowed && MacAppDelegate.asksForNotifications
    #else
    return allowed
    #endif
  }

  /// The app's screens show (signed in, the opening played): registers when allowed, else shows the
  /// screen if it was never answered.
  public func screensShown() async {
    guard enabled else { return }
    await refresh()
    if state == .notAsked && !defaults.bool(forKey: Self.answeredKey) { asking = true }
  }

  /// Reads the system's answer again (Settings shows it; the owner may have changed it there), and
  /// registers when notifications are allowed.
  public func refresh() async {
    guard enabled else { return }
    let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    state = Self.state(of: status)
    if state == .allowed { register() }
  }

  /// "Allow notifications": the system's question, then the registration once allowed.
  public func allow() async {
    answered()
    do {
      _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    } catch {
      Container.shared.pushRegistrar().failed(error, kind: .alert)
    }
    await refresh()
  }

  /// "Not now": the screen closes; Settings › Connection offers it again.
  public func notNow() {
    answered()
  }

  /// Settings › Connection's "Notifications · Off": the same screen while the system never asked,
  /// else the system's settings, the only place that turns them on again.
  public func turnOn() {
    if state == .notAsked {
      asking = true
      return
    }
    #if os(macOS)
    if let url = URL(string: Self.settingsAddress) { NSWorkspace.shared.open(url) }
    #else
    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
    #endif
  }

  static func state(of status: UNAuthorizationStatus) -> State {
    switch status {
    case .notDetermined: .notAsked
    case .denied: .denied
    case .authorized, .provisional: .allowed
    default: .unknown
    }
  }

  private func answered() {
    asking = false
    defaults.set(true, forKey: Self.answeredKey)
  }

  private func register() {
    #if os(macOS)
    NSApplication.shared.registerForRemoteNotifications()
    #else
    UIApplication.shared.registerForRemoteNotifications()
    #endif
  }
}
