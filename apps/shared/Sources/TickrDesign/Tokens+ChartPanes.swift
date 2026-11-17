import SwiftUI

// The Mac chart's panes (mockup v103) and the price axis's labels beside the level tags, in their
// own file because Tokens.swift is at SwiftLint's file length limit.

extension Tokens.Chart {
  /// Height of each study pane under the Mac's price pane (volume, ATR, RSI, MACD, stochastic),
  /// in points: fixed, so many panes never squeeze each other (mockup v103).
  public static let studyPaneHeight: CGFloat = 44
  /// The Mac's price pane fills what the study panes leave of the chart card, never less than
  /// `priceMinHeight` nor more than `priceMaxHeight` points (mockup v103: 420 with the default
  /// panes, 240 at the least).
  public static let priceMinHeight: CGFloat = 240
  public static let priceMaxHeight: CGFloat = 420
  /// Height the time axis's labels take under the bottom pane of the Mac's chart, in points (the
  /// board's 22).
  public static let timeAxisHeight: CGFloat = 22
  /// A price axis label's height and a level tag's (the last price, entry, stop, H / L), in
  /// points: a label whose centre is closer to a tag's than half of both together lies under the
  /// tag and is hidden (`AxisLabels.shows`).
  public static let axisLabelHeight: CGFloat = 13
  public static let levelTagHeight: CGFloat = 17
}
