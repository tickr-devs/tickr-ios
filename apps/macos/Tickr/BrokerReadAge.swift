import SwiftUI
import TickrDesign

/// How the Safety card colours the age of the bot's last broker read.
enum BrokerReadAge {
  /// Oldest read, in seconds, still shown as fresh: one and a half of the bot's reconciliation
  /// spacing (config/bot.toml [orders] reconcile_interval_seconds = 10), so one late pass is fine.
  static let freshSeconds: TimeInterval = 15
  /// Age, in seconds, past which the bot blocks entries (config/bot.toml [orders]
  /// broker_read_max_age_seconds = 30); older reads show as a loss colour.
  static let blockingSeconds: TimeInterval = 30

  /// Profit while fresh, warning while late but below the entry block, loss past it or when the
  /// bot never read the broker.
  static func tone(since date: Date?, now: Date) -> Tone {
    guard let date else { return .loss }
    let age = now.timeIntervalSince(date)
    if age <= freshSeconds { return .profit }
    if age <= blockingSeconds { return .warning }
    return .loss
  }

  /// The text colour of `tone(since:now:)`.
  static func color(since date: Date?, now: Date) -> Color {
    tone(since: date, now: now).text
  }
}
