import ApertureDesign
import ApertureKit
import Charts
import SwiftUI

/// Candles with the bot's lines, trades and levels, plus optional volume and ATR panes that
/// scroll, zoom and point together. Times read in New York, like the bot.
struct CandleChart: View {
  let series: ChartSeries
  let atr: [Double?]
  let lines: ChartLines
  let marks: [ChartMark]
  let levels: [ChartLevel]
  let decisions: [DecisionMark]
  let live: Bool
  @Binding var viewport: Viewport

  @State private var selection: Date?
  @State private var appeared = false
  @State private var pinchStart: Int?

  /// Height of the volume and ATR panes, in points.
  static let paneHeight: CGFloat = 90
  /// Share of a candle's slot its body fills; the rest is the gap between candles.
  static let bodyShare = 0.66
  /// Space above and below the visible prices, as a share of their range.
  static let pricePadding = 0.08
  /// Smallest price range drawn, as a share of the price, so a flat stretch is not a line.
  static let minimumSpan = 0.0005
  /// Gridlines each pane asks for on its value axis.
  static let priceTicks = 6
  static let paneTicks = 3
  /// Symbols of entry and exit marks.
  static let entrySymbol = "arrowtriangle.up.fill"
  static let exitSymbol = "arrowtriangle.down.fill"
  /// Symbols of decision marks: one the strategy acted on, and one that did not trade.
  static let decisionSymbol = "diamond.fill"
  static let observerSymbol = "diamond"

  private var candles: [Candle] { series.candles }

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      ChartReadout(series: series, atr: atr, lines: lines, index: shownIndex)
      priceChart
        .frame(maxHeight: .infinity)
      if lines.volume {
        volumeChart
          .frame(height: Self.paneHeight)
          .transition(.move(edge: .bottom).combined(with: .opacity))
      }
      if lines.atr {
        atrChart
          .frame(height: Self.paneHeight)
          .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
    .environment(\.timeZone, Format.newYork)
    .opacity(appeared ? 1 : 0)
    .onAppear {
      withAnimation(Tokens.Motion.entrance) { appeared = true }
    }
    .animation(Tokens.Motion.standard, value: lines)
    .animation(Tokens.Motion.quick, value: viewport.visible)
    .gesture(pinch)
  }

  // MARK: Panes

  private var priceChart: some View {
    Chart {
      ForEach(candles) { candle in
        RuleMark(
          x: .value(Plot.time, candle.middle),
          yStart: .value(Plot.price, candle.low),
          yEnd: .value(Plot.price, candle.high))
          .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.thin))
          .foregroundStyle(color(candle))
        RectangleMark(
          xStart: .value(Plot.time, bodyStart(candle)),
          xEnd: .value(Plot.time, bodyEnd(candle)),
          yStart: .value(Plot.price, min(candle.open, candle.close)),
          yEnd: .value(Plot.price, max(candle.open, candle.close)))
          .foregroundStyle(color(candle))
      }
      if lines.vwap { line(series.vwap, name: Plot.vwap, color: Palette.seriesVWAP) }
      if lines.fastEMA { line(series.fastEMA, name: Plot.fastEMA, color: Palette.seriesFastEMA) }
      if lines.slowEMA { line(series.slowEMA, name: Plot.slowEMA, color: Palette.seriesSlowEMA) }
      ForEach(levels) { level in
        RuleMark(
          xStart: .value(Plot.time, max(level.since, firstStart)),
          xEnd: .value(Plot.time, lastEnd),
          y: .value(Plot.price, level.price))
          .foregroundStyle(level.color)
          .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.thin, dash: Tokens.Stroke.dash))
          .annotation(position: .top, alignment: .leading) {
            Text(level.label)
              .font(Tokens.Typography.annotationBold)
              .foregroundStyle(level.textColor)
          }
      }
      ForEach(marks) { mark in
        PointMark(x: .value(Plot.time, mark.time), y: .value(Plot.price, mark.price))
          .symbol {
            Image(systemName: mark.kind == .entry ? Self.entrySymbol : Self.exitSymbol)
              .font(Tokens.Typography.annotation)
              .foregroundStyle(mark.color)
          }
          .annotation(position: mark.kind == .entry ? .bottom : .top) {
            Text(mark.label)
              .font(Tokens.Typography.annotation)
              .foregroundStyle(mark.textColor)
          }
      }
      ForEach(decisions) { mark in
        PointMark(x: .value(Plot.time, mark.time), y: .value(Plot.price, mark.price))
          .symbol {
            Image(systemName: mark.hollow ? Self.observerSymbol : Self.decisionSymbol)
              .font(Tokens.Typography.annotation)
              .foregroundStyle(mark.color)
          }
          .annotation(position: .top) {
            Text(mark.label)
              .font(Tokens.Typography.annotation)
              .foregroundStyle(mark.color)
          }
      }
      if live, let last = candles.last {
        RuleMark(y: .value(Plot.price, last.close))
          .foregroundStyle(color(last).opacity(Tokens.Opacity.border))
          .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.hairline, dash: Tokens.Stroke.dashFine))
          .annotation(position: .trailing, alignment: .center) {
            Text(verbatim: Self.price(last.close))
              .font(Tokens.Typography.annotationBold)
              .padding(.horizontal, Tokens.Space.xs)
              .background(color(last).opacity(Tokens.Opacity.glow), in: .rect(cornerRadius: Tokens.Radius.small))
              .foregroundStyle(color(last))
          }
      }
      crosshair
    }
    .chartYScale(domain: priceDomain)
    .chartYAxis { AxisMarks(position: .trailing, values: .automatic(desiredCount: Self.priceTicks)) }
    .chartXAxis(hasPaneBelow ? .hidden : .automatic)
    .modifier(SharedAxis(chart: self, selection: $selection))
  }

  private var volumeChart: some View {
    Chart {
      ForEach(candles) { candle in
        BarMark(
          xStart: .value(Plot.time, bodyStart(candle)),
          xEnd: .value(Plot.time, bodyEnd(candle)),
          y: .value(Plot.volume, candle.volume))
          .foregroundStyle(color(candle).opacity(Tokens.Opacity.medium))
      }
      crosshair
    }
    .chartYAxis { AxisMarks(position: .trailing, values: .automatic(desiredCount: Self.paneTicks)) }
    .chartXAxis(lines.atr ? .hidden : .automatic)
    .modifier(SharedAxis(chart: self, selection: $selection))
  }

  private var atrChart: some View {
    Chart {
      line(atr, name: Plot.atr, color: Palette.seriesATR)
      crosshair
    }
    .chartYAxis { AxisMarks(position: .trailing, values: .automatic(desiredCount: Self.paneTicks)) }
    .modifier(SharedAxis(chart: self, selection: $selection))
    .overlay {
      if !atr.contains(where: { $0 != nil }) {
        Text(L10n.Chart.atrWaiting(Indicators.atrPeriod))
          .font(Tokens.Typography.caption)
          .foregroundStyle(Palette.textQuaternary)
      }
    }
  }

  @ChartContentBuilder private func line(_ values: [Double?], name: String, color: Color) -> some ChartContent {
    ForEach(points(values)) { point in
      LineMark(
        x: .value(Plot.time, point.time),
        y: .value(Plot.price, point.value),
        series: .value(Plot.series, name))
        .foregroundStyle(color)
        .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.regular))
        .interpolationMethod(.monotone)
    }
  }

  /// The defined values of a line, at the middle of their candles.
  private func points(_ values: [Double?]) -> [LinePoint] {
    zip(candles, values).compactMap { candle, value in
      value.map { LinePoint(time: candle.middle, value: $0) }
    }
  }

  @ChartContentBuilder private var crosshair: some ChartContent {
    if let index = selectedIndex {
      RuleMark(x: .value(Plot.time, candles[index].middle))
        .foregroundStyle(Palette.textQuaternary.opacity(Tokens.Opacity.border))
        .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.thin))
    }
  }

  // MARK: Geometry

  private var firstStart: Date { candles.first?.start ?? .now }
  private var lastEnd: Date { candles.last?.end ?? .now }
  private var hasPaneBelow: Bool { lines.volume || lines.atr }

  /// Seconds of time on screen.
  var visibleLength: TimeInterval {
    guard let visible = viewport.visible else { return lastEnd.timeIntervalSince(firstStart) }
    return TimeInterval(visible) * series.timeframe.seconds
  }

  /// Opening time of the window on screen; while not scrolled it follows the newest candle.
  var windowStart: Date {
    viewport.position ?? max(firstStart, lastEnd.addingTimeInterval(-visibleLength))
  }

  var xDomain: ClosedRange<Date> { firstStart...lastEnd }
  var zoomed: Bool { viewport.visible != nil }

  var scrollPosition: Binding<Date> {
    Binding(get: { windowStart }, set: { viewport.position = $0 })
  }

  private var gap: TimeInterval { series.timeframe.seconds * (1 - Self.bodyShare) / 2 }
  private func bodyStart(_ candle: Candle) -> Date { candle.start.addingTimeInterval(gap) }
  private func bodyEnd(_ candle: Candle) -> Date { candle.end.addingTimeInterval(-gap) }

  private func color(_ candle: Candle) -> Color { candle.isUp ? Palette.profit : Palette.loss }

  /// Prices of the candles and levels on screen, padded so nothing touches the edge.
  private var priceDomain: ClosedRange<Double> {
    let end = windowStart.addingTimeInterval(visibleLength)
    let shown = candles.filter { $0.end > windowStart && $0.start < end }
    let prices = shown.flatMap { [$0.low, $0.high] } + levels.map(\.price)
    guard let low = prices.min(), let high = prices.max() else { return 0...1 }
    let span = max(high - low, high * Self.minimumSpan)
    let pad = span * Self.pricePadding
    return (low - pad)...(high + pad)
  }

  private var selectedIndex: Int? {
    guard let selection else { return nil }
    return candles.firstIndex { $0.start <= selection && selection < $0.end }
  }

  /// The candle the readout describes: the pointed one, else the newest.
  private var shownIndex: Int? { selectedIndex ?? candles.indices.last }

  private var pinch: some Gesture {
    MagnifyGesture()
      .onChanged { value in
        let start = pinchStart ?? viewport.visible ?? candles.count
        pinchStart = start
        viewport.show(Int((Double(start) / value.magnification).rounded()), total: candles.count)
      }
      .onEnded { _ in pinchStart = nil }
  }

  static func price(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(Money.centsDigits)))
  }
}

/// One defined value of an indicator line.
private struct LinePoint: Identifiable {
  let time: Date
  let value: Double

  var id: Date { time }
}

/// The time axis every pane shares: same domain, same window, same pointer.
private struct SharedAxis: ViewModifier {
  let chart: CandleChart
  @Binding var selection: Date?

  func body(content: Content) -> some View {
    content
      .chartXScale(domain: chart.xDomain)
      .chartScrollableAxes(chart.zoomed ? .horizontal : [])
      .chartXVisibleDomain(length: chart.visibleLength)
      .chartScrollPosition(x: chart.scrollPosition)
      .chartXSelection(value: $selection)
  }
}

/// Values of the candle under the pointer (or the newest), above the price pane.
private struct ChartReadout: View {
  let series: ChartSeries
  let atr: [Double?]
  let lines: ChartLines
  let index: Int?

  var body: some View {
    if let index {
      let candle = series.candles[index]
      HStack(spacing: Tokens.Space.m) {
        Text(verbatim: Format.marketMinute(candle.start))
          .font(Tokens.Typography.annotationBold)
          .foregroundStyle(Palette.textSecondary)
        value(L10n.Chart.open, CandleChart.price(candle.open))
        value(L10n.Chart.high, CandleChart.price(candle.high))
        value(L10n.Chart.low, CandleChart.price(candle.low))
        value(L10n.Chart.close, CandleChart.price(candle.close), color: candle.isUp ? Palette.profitText : Palette.lossText)
        value(L10n.Chart.volumeShort, candle.volume.formatted(.number.notation(.compactName)))
        if lines.vwap, let vwap = series.vwap[index] {
          value(L10n.Chart.vwap, CandleChart.price(vwap), color: Palette.seriesVWAP)
        }
        if lines.fastEMA, let fast = series.fastEMA[index] {
          value(L10n.Chart.ema(Indicators.fastEMAPeriod), CandleChart.price(fast), color: Palette.seriesFastEMA)
        }
        if lines.slowEMA, let slow = series.slowEMA[index] {
          value(L10n.Chart.ema(Indicators.slowEMAPeriod), CandleChart.price(slow), color: Palette.seriesSlowEMA)
        }
        if lines.atr, let value = atr[index] {
          self.value(L10n.Chart.atr(Indicators.atrPeriod), CandleChart.price(value), color: Palette.seriesATRText)
        }
      }
      .font(Tokens.Typography.annotation)
      .monospacedDigit()
      .contentTransition(.numericText())
    }
  }

  private func value(_ name: LocalizedStringResource, _ text: String, color: Color = Palette.textPrimary) -> some View {
    HStack(spacing: Tokens.Space.xs) {
      Text(name).foregroundStyle(Palette.textQuaternary)
      Text(verbatim: text).foregroundStyle(color)
    }
  }
}

/// Localized names of the plotted values (VoiceOver and Audio Graphs read them).
private enum Plot {
  static var time: String { String(localized: L10n.Chart.axisTime) }
  static var price: String { String(localized: L10n.Chart.axisPrice) }
  static var volume: String { String(localized: L10n.Chart.volume) }
  static var series: String { String(localized: L10n.Chart.axisSeries) }
  static var vwap: String { String(localized: L10n.Chart.vwap) }
  static var fastEMA: String { String(localized: L10n.Chart.ema(Indicators.fastEMAPeriod)) }
  static var slowEMA: String { String(localized: L10n.Chart.ema(Indicators.slowEMAPeriod)) }
  static var atr: String { String(localized: L10n.Chart.atr(Indicators.atrPeriod)) }
}

extension Candle {
  /// The middle of the candle's time slot, where its wick is drawn.
  var middle: Date { start.addingTimeInterval(end.timeIntervalSince(start) / 2) }
}
