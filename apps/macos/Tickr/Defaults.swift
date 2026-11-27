import Foundation
import TickrKit

/// User-default keys of the app (Settings window).
enum Defaults {
  /// An address that replaces the bot's (`BotAddress`): never set by the app, only for development
  /// (`defaults write … apiBaseURL http://127.0.0.1:8766` for a bot on this Mac, or a UI test's
  /// launch argument). It gets no token.
  static let apiBaseURL = "apiBaseURL"
  /// Whether the demo day is shown instead of the bot (Settings › General, `AppModel.demoDay`).
  static let demoDay = "demoDay"
  /// Whether the menu-bar extra is shown.
  static let showMenuBarExtra = "showMenuBarExtra"
  /// Appearance forced for every window, `light` or `dark`; unset or empty follows the system.
  /// Chosen in Settings › General (Appearance · theme); the screen tour sets it as a launch
  /// argument (`-appearance light`), which wins over the stored choice.
  static let appearance = "appearance"
  static let light = "light"
  static let dark = "dark"
}

extension Defaults {
  /// The bot's API (`BotAddress`), unless a development address replaces it.
  static func baseURL() -> URL {
    if let text = UserDefaults.standard.string(forKey: apiBaseURL), let url = URL(string: text), url.host() != nil {
      return url
    }
    return BotAddress.url
  }
}
