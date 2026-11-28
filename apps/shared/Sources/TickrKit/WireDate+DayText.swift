import Foundation

extension WireDate {
  /// Between a day's weekday and its date in `dayText`.
  static let daySpace = " "

  /// The day as both apps write it: weekday, then the date, no comma ("Fri Nov 13", "vie 13 nov"),
  /// the New York day whatever the device's time zone (`DayText` in TickrDesign, and a date the bot
  /// names in a reason).
  public static func dayText(_ date: Date, locale: Locale = .autoupdatingCurrent) -> String {
    var weekday = Date.FormatStyle.dateTime.weekday(.abbreviated).locale(locale)
    var monthDay = Date.FormatStyle.dateTime.month(.abbreviated).day().locale(locale)
    weekday.timeZone = newYork.timeZone
    monthDay.timeZone = newYork.timeZone
    return date.formatted(weekday) + daySpace + date.formatted(monthDay)
  }

  /// This day as `dayText(_:locale:)` writes it.
  public func dayText(locale: Locale = .autoupdatingCurrent) -> String {
    Self.dayText(noonInNewYork, locale: locale)
  }
}
