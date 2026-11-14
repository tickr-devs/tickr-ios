import Foundation

/// Every text of the Chart tab. Translations live in chart.xcstrings beside this file.
enum ChartText {
  static let title = LocalizedStringResource("chart.title", defaultValue: "Chart", table: ChartText.table)
  static let loading = LocalizedStringResource("chart.loading",
    defaultValue: "Loading the chart…", table: ChartText.table)
  static let noDaysTitle = LocalizedStringResource("chart.noDays.title",
    defaultValue: "No recorded days yet", table: ChartText.table)
  static let noDaysBody = LocalizedStringResource("chart.noDays.body",
    defaultValue: "The bot records bars and trades while it runs. Days appear here once there is something to show.",
    table: ChartText.table)
  static let noBarsTitle = LocalizedStringResource("chart.noBars.title",
    defaultValue: "No captured bars", table: ChartText.table)
  static let noBarsBody = LocalizedStringResource("chart.noBars.body",
    defaultValue: "The bot captured no bars on this day.", table: ChartText.table)
  static let failedTitle = LocalizedStringResource("chart.failed.title",
    defaultValue: "Could not load the chart", table: ChartText.table)
  static let retry = LocalizedStringResource("chart.retry", defaultValue: "Try Again", table: ChartText.table)
  static let previousDay = LocalizedStringResource("chart.previousDay",
    defaultValue: "Previous day", table: ChartText.table)
  static let nextDay = LocalizedStringResource("chart.nextDay", defaultValue: "Next day", table: ChartText.table)
  static let day = LocalizedStringResource("chart.day", defaultValue: "Day", table: ChartText.table)
  static let live = LocalizedStringResource("chart.live", defaultValue: "Live", table: ChartText.table)
  static let timeframe = LocalizedStringResource("chart.timeframe", defaultValue: "Timeframe", table: ChartText.table)
  static let m1 = LocalizedStringResource("chart.timeframe.m1", defaultValue: "M1", table: ChartText.table)
  static let m5 = LocalizedStringResource("chart.timeframe.m5", defaultValue: "M5", table: ChartText.table)
  static let m15 = LocalizedStringResource("chart.timeframe.m15", defaultValue: "M15", table: ChartText.table)
  static let vwap = LocalizedStringResource("chart.indicator.vwap", defaultValue: "VWAP", table: ChartText.table)
  static let volume = LocalizedStringResource("chart.indicator.volume",
    defaultValue: "Volume", table: ChartText.table)
  static let zoomIn = LocalizedStringResource("chart.zoomIn", defaultValue: "Zoom in", table: ChartText.table)
  static let zoomOut = LocalizedStringResource("chart.zoomOut", defaultValue: "Zoom out", table: ChartText.table)
  static let hint = LocalizedStringResource("chart.hint",
    defaultValue: "Touch and hold the chart to read a candle.", table: ChartText.table)
  static let trades = LocalizedStringResource("chart.trades", defaultValue: "Trades", table: ChartText.table)
  static let noTrades = LocalizedStringResource("chart.noTrades",
    defaultValue: "No closed trades on this symbol this day.", table: ChartText.table)
  static let entry = LocalizedStringResource("chart.entry", defaultValue: "Entry", table: ChartText.table)
  static let exit = LocalizedStringResource("chart.exit", defaultValue: "Exit", table: ChartText.table)
  static let stop = LocalizedStringResource("chart.stop", defaultValue: "Stop", table: ChartText.table)
  static let axisTime = LocalizedStringResource("chart.axis.time", defaultValue: "Time", table: ChartText.table)
  static let axisPrice = LocalizedStringResource("chart.axis.price", defaultValue: "Price", table: ChartText.table)
  static let axisLine = LocalizedStringResource("chart.axis.line", defaultValue: "Line", table: ChartText.table)

  /// The fast or slow EMA toggle, with its period in bars.
  static func ema(_ period: Int) -> LocalizedStringResource {
    LocalizedStringResource("chart.indicator.ema", defaultValue: "EMA \(period)", table: ChartText.table)
  }

  /// The crosshair readout of one candle: open, high, low, close, volume (already formatted).
  static func readout(_ open: String, _ high: String, _ low: String, _ close: String, _ volume: String)
    -> LocalizedStringResource {
    LocalizedStringResource("chart.readout",
      defaultValue: "O \(open)  H \(high)  L \(low)  C \(close)  V \(volume)", table: ChartText.table)
  }
}
