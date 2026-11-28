import Foundation

/// How long ago something happened, short and readable at any length: "47 s", "12 min", "5 h",
/// "2 d", never "179,318 s" (owner, 2026-11-28: raw seconds on a stale status). The apps put it
/// in their own sentence ("updated 47 s ago", "no answer for 12 min").
public enum Elapsed {
  /// Up to this many seconds the text counts seconds (2 min), then minutes.
  public static let secondsShownUpTo = 120
  /// Up to this many minutes the text counts minutes (2 h), then hours.
  public static let minutesShownUpTo = 120
  /// Up to this many hours the text counts hours (2 days), then days.
  public static let hoursShownUpTo = 48
  static let secondsPerMinute = 60
  static let minutesPerHour = 60
  static let hoursPerDay = 24

  /// `seconds` (clamped at 0) in the largest unit that keeps it a small whole number.
  public static func text(seconds: Int) -> String {
    let seconds = max(0, seconds)
    if seconds < secondsShownUpTo { return String(localized: L10n.elapsedSeconds(seconds)) }
    let minutes = seconds / secondsPerMinute
    if minutes < minutesShownUpTo { return String(localized: L10n.elapsedMinutes(minutes)) }
    let hours = minutes / minutesPerHour
    if hours < hoursShownUpTo { return String(localized: L10n.elapsedHours(hours)) }
    return String(localized: L10n.elapsedDays(hours / hoursPerDay))
  }

  /// The time from `date` to `now`.
  public static func text(since date: Date, now: Date) -> String {
    text(seconds: Int(now.timeIntervalSince(date)))
  }
}
