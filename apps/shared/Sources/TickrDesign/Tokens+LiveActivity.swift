import SwiftUI

// Tokens of the iPhone Live Activity (mockup v138): the Dynamic Island and the Lock Screen card,
// drawn by the widget extension (apps/ios/Widgets). In their own file because Tokens.swift is at
// SwiftLint's file length limit.

extension Tokens {
  /// The Live Activity's type and its rows' stop-to-target bar.
  public enum LiveActivity {
    /// The compact island's count and day result, in points (14 pt, semibold, as the system's).
    public static let compactSize: CGFloat = 14
    /// The expanded island's and the Lock Screen's day result, in points.
    public static let headerFigureSize: CGFloat = 16
    /// A position row's symbol and result, and the state line, in points.
    public static let rowSize: CGFloat = 13
    /// The stops line under the rows, in points.
    public static let footnoteSize: CGFloat = 11

    /// The compact island's open-position count and "Flat".
    public static let compact = Font.system(size: compactSize, weight: .semibold)
    /// The compact island's day result: tabular digits, so a change never shifts it.
    public static let compactFigure = Font.system(size: compactSize, weight: .semibold, design: .monospaced)
    /// "Tickr" beside the mark in the expanded island.
    public static let brand = Font.system(size: headerFigureSize, weight: .semibold)
    /// The day result in the expanded island and on the Lock Screen.
    public static let headerFigure = Font.system(size: headerFigureSize, weight: .semibold, design: .monospaced)
    /// The state line ("Entries paused · …", "Tickr · 2 positions protected").
    public static let line = Font.system(size: rowSize, weight: .semibold)
    /// A row's symbol.
    public static let symbol = Font.system(size: rowSize, weight: .bold, design: .monospaced)
    /// A row's unrealized result and its "stop $X" in place of a bar.
    public static let figure = Font.system(size: rowSize, weight: .semibold, design: .monospaced)
    /// "Stops confirmed at broker 2 s ago".
    public static let footnote = Font.system(size: footnoteSize, design: .monospaced)

    /// The mark beside "Tickr" in the expanded island, in points.
    public static let mark: CGFloat = 18
    /// Width of a row's symbol column, so the bars of every row line up, in points.
    public static let symbolColumn: CGFloat = 48
    /// Least width of a row's result column, so the bars end together, in points.
    public static let figureColumn: CGFloat = 64
    /// The bar's track and fill height, in points.
    public static let barHeight: CGFloat = 6
    /// The knob at the last price on the bar, in points.
    public static let knob: CGFloat = 12
    /// The state dot's ring around it (open and alarm), in points.
    public static let dotRing: CGFloat = 14
  }
}
