import TickrKit

/// When the Mac's looping ornaments move: the empty-positions radar, the event strip's and the
/// screeners' scroll and the brand mark's halo. They are ornament,
/// but a moving one reads as "the bot is at work", so each moves only while that is true: the bot
/// runs and its status is live and fresh. Stopped, stale, unreachable or on a recorded day they
/// stand still, as with Reduce Motion. The same rule as iOS Home's `OrnamentGate`.
enum OrnamentGate {
  static func moves(reduceMotion: Bool, current: Bool, botState: BotState?) -> Bool {
    !reduceMotion && current && botState == .running
  }
}

extension AppModel {
  /// Whether the ornaments move (`OrnamentGate`) for this model, under the screen's Reduce Motion.
  func ornamentsMove(reduceMotion: Bool) -> Bool {
    OrnamentGate.moves(reduceMotion: reduceMotion, current: isCurrent, botState: status?.botState)
  }
}
