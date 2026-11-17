import Foundation

/// A clock time as both apps write it: New York (market) time on the 24-hour clock in every
/// language and whatever the device's clock setting or time zone, as the boards draw every time
/// ("14:06", "16:58:34"). The one time formatter of the apps (with `DayText` for days): never a
/// locale's "4:58:34 PM" beside 24-hour times on the next line.
public enum ClockText {
  /// "14:06".
  public static func minutes(_ date: Date) -> String {
    date.formatted(Date.VerbatimFormatStyle(
      format: "\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)",
      timeZone: WireDate.newYork.timeZone, calendar: WireDate.newYork))
  }

  /// "14:06:09": the same with seconds.
  public static func seconds(_ date: Date) -> String {
    date.formatted(Date.VerbatimFormatStyle(
      format: "\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\(second: .twoDigits)",
      timeZone: WireDate.newYork.timeZone, calendar: WireDate.newYork))
  }
}
