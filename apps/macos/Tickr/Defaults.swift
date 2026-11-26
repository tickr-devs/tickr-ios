import Foundation
import TickrKit

/// User-default keys of the app (Settings window).
enum Defaults {
  /// Base URL of the bot's local API.
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
  /// The bot's API address saved in Settings › General, else this Mac's own API.
  static func baseURL() -> URL {
    if let text = UserDefaults.standard.string(forKey: apiBaseURL), let url = URL(string: text) {
      return url
    }
    return APIClient.defaultBaseURL
  }
}
