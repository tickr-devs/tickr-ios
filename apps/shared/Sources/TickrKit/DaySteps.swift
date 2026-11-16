import Foundation

/// Stepping through the recorded days one at a time, as Home's day switcher does: back to the
/// newest older day, forward to the oldest newer one, and from the newest past day forward to today.
public enum DaySteps {
  /// The newest recorded day before `day`; nil when none is older.
  public static func previous(_ day: WireDate, in days: [DaySummary]) -> DaySummary? {
    days.filter { $0.day < day }.max { $0.day < $1.day }
  }

  /// The oldest recorded day after `day` and before `today`; nil when the next step is today.
  public static func next(_ day: WireDate, in days: [DaySummary], today: WireDate) -> DaySummary? {
    days.filter { $0.day > day && $0.day < today }.min { $0.day < $1.day }
  }
}

/// The ‹ › day arrows around a day: whether they show at all, and which of them steps somewhere.
/// An arrow that would do nothing is never drawn as if it did: with nowhere to step in either
/// direction (the demo day locked, or no recorded day but the shown one) both are hidden; with one
/// way open, the other is shown disabled (dimmed, "dimmed" to VoiceOver).
public struct DayArrows: Equatable, Sendable {
  /// The arrows show at all.
  public let visible: Bool
  /// The back arrow steps to an older recorded day.
  public let canGoBack: Bool
  /// The forward arrow steps to a newer day (a recorded one, or today).
  public let canGoForward: Bool

  public init(locked: Bool, canGoBack: Bool, canGoForward: Bool) {
    self.canGoBack = !locked && canGoBack
    self.canGoForward = !locked && canGoForward
    visible = self.canGoBack || self.canGoForward
  }
}
