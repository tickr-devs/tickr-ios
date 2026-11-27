import Foundation

/// Where the apps reach the bot: its API behind TLS on the cloud server, the same for every build
/// (owner, 2026-11-27: no address to type, no pairing link). The owner signs in once with his
/// tickr.bot account (`AccountSignIn`) and the bot gives this device its own tokens (`BotSession`).
public enum BotAddress {
  /// The bot's API.
  public static let url = URL(string: "https://api.tickr.bot")!
}

/// The name the bot lists a device under (docs/api.md, POST /session).
public enum DeviceName {
  /// `raw` (the system's name for the device) with only what a bot device name may hold (letters,
  /// digits, space, dot, dash, underscore; a letter or digit at each end), or `fallback` when
  /// nothing is left.
  public static func of(_ raw: String) -> String {
    let kept = String(String.UnicodeScalarView(raw.unicodeScalars.filter { characters.contains($0) }))
    let trimmed = kept.trimmingCharacters(in: ends)
    return trimmed.isEmpty ? fallback : trimmed
  }

  /// The letters and digits a bot device name may hold (src/tickr/api/devices.py NAME): ASCII only.
  static let lettersAndDigits = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
  /// The marks a bot device name may hold between them.
  static let marks = " ._-"
  static let characters = CharacterSet(charactersIn: lettersAndDigits + marks)
  /// What a device name may not start or end with.
  static let ends = CharacterSet(charactersIn: marks)
  /// The device name when the system's name has no character a bot device name may hold.
  static let fallback = "device"
}
