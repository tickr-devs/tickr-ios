import SwiftUI
import TickrDesign
import TickrKit

/// How the Safety card colours the age of the bot's last broker read, by the bot's own limits
/// (GET /settings: broker_read_warn_seconds and broker_read_max_age_seconds, from
/// config/bot.toml), so the colours follow the config instead of a copy of it.
enum BrokerReadAge {
  /// The bot's two limits, in seconds: late past `warn`, entries blocked past `block`.
  struct Limits: Equatable {
    let warn: TimeInterval
    let block: TimeInterval

    init(warn: TimeInterval, block: TimeInterval) {
      self.warn = warn
      self.block = block
    }

    /// From the bot's settings; nil until they are read.
    init?(_ settings: SettingsV1?) {
      guard let settings else { return nil }
      warn = NSDecimalNumber(decimal: settings.brokerReadWarnSeconds.value).doubleValue
      block = NSDecimalNumber(decimal: settings.brokerReadMaxAgeSeconds.value).doubleValue
    }
  }

  /// Profit up to the warn age, warning up to the block age, loss past it or when the bot never
  /// read the broker. Without the bot's limits a read's age is not judged (neutral).
  static func tone(since date: Date?, now: Date, limits: Limits?) -> Tone {
    guard let date else { return .loss }
    guard let limits else { return .neutral }
    let age = now.timeIntervalSince(date)
    if age <= limits.warn { return .profit }
    if age <= limits.block { return .warning }
    return .loss
  }

  /// The text colour of `tone(since:now:limits:)`.
  static func color(since date: Date?, now: Date, limits: Limits?) -> Color {
    tone(since: date, now: now, limits: limits).text
  }
}
