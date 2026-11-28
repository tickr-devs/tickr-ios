import Foundation

extension WireDate {
  /// Saturday or Sunday in New York: no US exchange session (the day picker lists trading days
  /// only, mockup v202, page p-days).
  public var isWeekend: Bool {
    WireDate.newYork.isDateInWeekend(noonInNewYork)
  }
}
