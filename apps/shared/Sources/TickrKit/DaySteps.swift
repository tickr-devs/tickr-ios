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
