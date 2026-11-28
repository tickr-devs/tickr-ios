import Foundation

// The units of `Elapsed`.
extension L10n {
  /// `Elapsed` in seconds; argument: whole seconds.
  static func elapsedSeconds(_ value: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.elapsed.seconds", defaultValue: "\(value) s", bundle: bundle)
  }
  /// `Elapsed` in minutes; argument: whole minutes.
  static func elapsedMinutes(_ value: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.elapsed.minutes", defaultValue: "\(value) min", bundle: bundle)
  }
  /// `Elapsed` in hours; argument: whole hours.
  static func elapsedHours(_ value: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.elapsed.hours", defaultValue: "\(value) h", bundle: bundle)
  }
  /// `Elapsed` in days; argument: whole days.
  static func elapsedDays(_ value: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.elapsed.days", defaultValue: "\(value) d", bundle: bundle)
  }
}
