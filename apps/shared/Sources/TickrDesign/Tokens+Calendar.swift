import SwiftUI

// Tokens of the Mac Trades & days calendar's day tiles (MacTrades v106); in their own file because
// Tokens.swift is at SwiftLint's file length limit.

extension Tokens.Typography {
  /// Sizes a day tile's result is tried in, in points, largest first: the board's 12, smaller only
  /// for a result that would not fit whole ("−$1,234.56" in a 378-point days column takes 10).
  /// Read by `calendarResultFonts`.
  public static let calendarResultSizes: [CGFloat] = [12, 11, 10, 9]
  /// A day tile's result in each of `calendarResultSizes`, bold mono, largest first. Read by the
  /// Mac calendar's day tile (`CalendarDay`), which shows the largest that holds the whole result.
  public static let calendarResultFonts: [Font] = calendarResultSizes.map {
    Font.system(size: $0, weight: .bold, design: .monospaced)
  }
}
