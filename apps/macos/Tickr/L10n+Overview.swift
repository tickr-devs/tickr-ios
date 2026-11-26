import Foundation

/// Texts of the simpler Overview cards (mockup Main): the bot's one status line and its checks,
/// the position's close command and lines, the live flow's dropped counts and the fast movers'
/// rule.
extension L10n.Bot {
  /// The Bot card's status line when every check passes.
  static var checksPass: LocalizedStringResource {
    LocalizedStringResource("bot.checksPass", defaultValue: "All checks pass", bundle: L10n.bundle)
  }
  /// Under the status line: how many checks pass ("Checks 6 of 6").
  static func checksCount(_ passed: Int, _ total: Int) -> LocalizedStringResource {
    LocalizedStringResource("bot.checksCount", defaultValue: "Checks \(passed) of \(total)", bundle: L10n.bundle)
  }
  /// The same with the age of the last broker read ("Checks 6 of 6 · broker read 3 s ago").
  static func checksCountRead(_ passed: Int, _ total: Int, _ age: String) -> LocalizedStringResource {
    LocalizedStringResource("bot.checksCountRead", defaultValue: "Checks \(passed) of \(total) · broker read \(age)",
      bundle: L10n.bundle)
  }
  /// The status line while the bot's status is stale.
  static var notAnswering: LocalizedStringResource {
    LocalizedStringResource("bot.notAnswering", defaultValue: "Bot not answering", bundle: L10n.bundle)
  }
  /// The bot's pill while its status is stale, with how long it has been silent ("no answer · 47 s").
  static func noAnswer(_ age: String) -> LocalizedStringResource {
    LocalizedStringResource("bot.noAnswer", defaultValue: "no answer · \(age)", bundle: L10n.bundle)
  }
  /// Title of the popover with every check.
  static var checksTitle: LocalizedStringResource {
    LocalizedStringResource("bot.checksTitle", defaultValue: "Safety checks", bundle: L10n.bundle)
  }
  /// Hint of the status line: it opens the checks.
  static var checksHint: LocalizedStringResource {
    LocalizedStringResource("bot.checksHint", defaultValue: "Shows every check in plain words", bundle: L10n.bundle)
  }
  /// The selected position's close command ("Close ABCD"): the same command as Close ABCD position.
  static func closeSymbol(_ symbol: String) -> LocalizedStringResource {
    LocalizedStringResource("bot.closeSymbol", defaultValue: "Close \(symbol)", bundle: L10n.bundle)
  }
}

extension L10n.Position {
  /// The badge beside a position's stop once the broker confirmed it.
  static var protected: LocalizedStringResource {
    LocalizedStringResource("position.protected", defaultValue: "Protected", bundle: L10n.bundle)
  }
  /// "10 shares at $12.34".
  static func sharesAt(_ quantity: String, _ price: String) -> LocalizedStringResource {
    LocalizedStringResource("position.sharesAt", defaultValue: "\(quantity) shares at \(price)", bundle: L10n.bundle)
  }
  /// Before the position's current price and R.
  static var now: LocalizedStringResource {
    LocalizedStringResource("position.now", defaultValue: "Now", bundle: L10n.bundle)
  }
}

extension L10n.Flow {
  /// Under a stage's count: how many symbols it dropped ("−144").
  static func dropped(_ count: Int) -> LocalizedStringResource {
    LocalizedStringResource("flow.dropped", defaultValue: "−\(count)", bundle: L10n.bundle)
  }
  /// Under the risk stage's count: how many entries the risk limits refused ("2 refused").
  static func refusedCount(_ count: Int) -> LocalizedStringResource {
    LocalizedStringResource("flow.refusedCount", defaultValue: "\(count) refused", bundle: L10n.bundle)
  }
}

extension L10n.FastMovers {
  /// The info button beside the card's title, which shows the rule.
  static var ruleHint: LocalizedStringResource {
    LocalizedStringResource("fastMovers.ruleHint", defaultValue: "How a fast mover is picked", bundle: L10n.bundle)
  }
}

extension L10n.Toolbar {
  /// The Overview's title bar line: the environment alone ("tickr — paper trading").
  static func windowLineEnvironment(_ environment: String) -> LocalizedStringResource {
    LocalizedStringResource("toolbar.windowLineEnvironment", defaultValue: "tickr — \(environment)", bundle: L10n.bundle)
  }
  /// The connection status: the age of the bot's status ("updated 3 s ago").
  static func updated(_ age: String) -> LocalizedStringResource {
    LocalizedStringResource("toolbar.updated", defaultValue: "updated \(age)", bundle: L10n.bundle)
  }
}
