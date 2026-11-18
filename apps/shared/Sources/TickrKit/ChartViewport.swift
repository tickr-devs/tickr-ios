import Foundation

/// Which stretch of the day the chart shows: how many candles fit on screen and where the view
/// starts. Kept by the Chart tab so its controls can zoom and follow the newest candle.
public struct ChartViewport: Equatable, Sendable {
  /// Candles on screen when the chart opens, and the fewest and most zooming allows.
  public static let defaultVisible = 40.0
  public static let fewestVisible = 15.0
  public static let mostVisible = 390.0

  public var visible = ChartViewport.defaultVisible
  public var scroll = Date.distantPast
  /// Most candles the zoom may show: `mostVisible` until the chart is fitted, then every slot.
  public var most = ChartViewport.mostVisible

  /// Seconds of the day on screen.
  public func window(_ series: ChartSeries) -> TimeInterval { visible * series.timeframe.seconds }

  /// Candles on screen: the zoom, or all of them when the day has fewer.
  public func barsShown(_ series: ChartSeries) -> Int {
    min(Int(visible.rounded()), series.candles.count)
  }

  /// Whether a zoom out shows more: up to the whole range (`most`, set when fitted).
  public func canZoomOut(_ series: ChartSeries) -> Bool {
    visible < most
  }

  public var canZoomIn: Bool { visible > Self.fewestVisible }

  /// Whether the newest candle is on screen.
  public func showsEnd(_ series: ChartSeries) -> Bool {
    guard let last = series.candles.last else { return true }
    return last.end <= scroll.addingTimeInterval(window(series))
  }

  /// Show `factor` times as many candles, keeping the right edge where it is.
  public mutating func zoom(by factor: Double, _ series: ChartSeries) {
    let end = scroll.addingTimeInterval(window(series))
    visible = min(max(visible * factor, min(Self.fewestVisible, most)), most)
    scroll = end.addingTimeInterval(-window(series))
  }

  /// Show `count` candles (within the zoom's limits), keeping the time at `anchor` (0: the left
  /// edge, 1: the right edge) where it is on screen: a pinch zooms around the fingers.
  public mutating func zoom(to count: Double, keeping anchor: Double, _ series: ChartSeries) {
    let share = min(max(anchor, 0), 1)
    let held = scroll.addingTimeInterval(window(series) * share)
    visible = min(max(count, min(Self.fewestVisible, most)), most)
    var start = held.addingTimeInterval(-window(series) * share)
    if let first = series.candles.first { start = max(start, first.start) }
    scroll = start
  }

  /// Every candle on screen, first to last, and the `slots` reserved after them on today's Day
  /// chart.
  public mutating func fit(_ series: ChartSeries, slots: Int) {
    guard let first = series.candles.first else { return }
    most = Double(max(slots, series.candles.count))
    visible = most
    scroll = first.start
  }

  /// Scroll so the newest candle sits at the right edge.
  public mutating func followEnd(_ series: ChartSeries) {
    guard let last = series.candles.last, let first = series.candles.first else { return }
    scroll = max(first.start, last.end.addingTimeInterval(-window(series)))
  }

  public init() {}

  /// Whether the whole range is on screen: as the chart opened, or zoomed all the way out again.
  public var isFitted: Bool { visible >= most }

  /// A new read of the same chart (a new candle, the last one grown, today's reserve shrinking)
  /// never moves the person's window: a fitted chart stays fitted over what it now holds, a
  /// window that showed the newest candle follows it to the right edge, any other stays where
  /// it was scrolled. `previous` is the series before the read.
  public mutating func take(_ series: ChartSeries, slots: Int, previous: ChartSeries?) {
    if isFitted {
      fit(series, slots: slots)
    } else if let previous, showsEnd(previous) {
      followEnd(series)
    }
  }
}
