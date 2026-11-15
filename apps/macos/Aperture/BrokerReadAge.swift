import ApertureDesign
import SwiftUI

/// How the Safety card colours the age of the bot's last broker read.
enum BrokerReadAge {
  /// Oldest read, in seconds, still shown as fresh: one and a half of the bot's reconciliation
  /// spacing (config/bot.toml [orders] reconcile_interval_seconds = 10), so one late pass is fine.
  static let freshSeconds: TimeInterval = 15
  /// Age, in seconds, past which the bot blocks entries (config/bot.toml [orders]
  /// broker_read_max_age_seconds = 30); older reads show as a loss colour.
  static let blockingSeconds: TimeInterval = 30

  /// Green while fresh, warning while late but below the entry block, red past it or when the
  /// bot never read the broker.
  static func color(since date: Date?, now: Date) -> Color {
    guard let date else { return Palette.lossText }
    let age = now.timeIntervalSince(date)
    if age <= freshSeconds { return Palette.profitText }
    if age <= blockingSeconds { return Palette.warningText }
    return Palette.lossText
  }
}
