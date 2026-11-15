import ApertureDesign
import ApertureKit
import Charts
import SwiftUI

/// Candles with the bot's lines, trades and levels, plus optional volume and ATR panes that
/// scroll, zoom and point together. Times read in New York, like the bot.
struct CandleChart: View {
  let plot: ChartPlot
  let lines: ChartLines
  let marks: [ChartMark]
  let levels: [ChartLevel]
  let decisions: [DecisionMark]
  let live: Bool
  @Binding var viewport: Viewport

  @State private var pointer = ChartPointer()
  /// The pointer state, for the shared axis and crosshair of every pane.
  var pointerModel: ChartPointer { pointer }
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
  /// Width of every pane's value labels, in points: one width keeps the panes' plot areas, and so
  /// their candles and crosshairs, lined up.
  static let axisLabelWidth: CGFloat = 56
  /// Gridlines each pane asks for on its value axis.
  static let priceTicks = 6
  static let paneTicks = 3
  /// Symbols of entry and exit marks.
  static let entrySymbol = "arrowtriangle.up.fill"
  static let exitSymbol = "arrowtriangle.down.fill"
  /// Symbols of decision marks: one the strategy acted on, and one that did not trade.
  static let decisionSymbol = "diamond.fill"
  static let observerSymbol = "diamond"
  /// Candles drawn beyond each side of the window while zoomed, as a share of the window, so a
  /// fast scroll never shows a bare edge before the next redraw. Farther candles are not drawn.
  static let drawnMargin = 1.0

  private var series: ChartSeries { plot.series }
  private var atr: [Double?] { plot.atr }
  private var candles: [Candle] { plot.candles }

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      ChartReadout(plot: plot, lines: lines, pointer: pointer)
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
      ForEach(candles[drawn]) { candle in
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
    }
    .chartYScale(domain: priceDomain)
    .chartYAxis { valueAxis(ticks: Self.priceTicks, format: Self.priceFormat) }
    .chartXAxis(hasPaneBelow ? .hidden : .automatic)
    .modifier(SharedAxis(chart: self))
  }

  private var volumeChart: some View {
    Chart {
      ForEach(candles[drawn]) { candle in
        BarMark(
          xStart: .value(Plot.time, bodyStart(candle)),
          xEnd: .value(Plot.time, bodyEnd(candle)),
          y: .value(Plot.volume, candle.volume))
          .foregroundStyle(color(candle).opacity(Tokens.Opacity.medium))
      }
    }
    .chartYAxis { valueAxis(ticks: Self.paneTicks, format: .number.notation(.compactName)) }
    .chartXAxis(lines.atr ? .hidden : .automatic)
    .modifier(SharedAxis(chart: self))
  }

  private var atrChart: some View {
    Chart {
      line(atr, name: Plot.atr, color: Palette.seriesATR)
    }
    .chartYAxis { valueAxis(ticks: Self.paneTicks, format: Self.priceFormat) }
    .modifier(SharedAxis(chart: self))
    .overlay {
      if !atr.contains(where: { $0 != nil }) {
        Text(L10n.Chart.atrWaiting(Indicators.atrPeriod))
          .font(Tokens.Typography.caption)
          .foregroundStyle(Palette.textQuaternary)
      }
    }
  }

  /// A pane's value scale on the right, its labels all `axisLabelWidth` wide: scales of different
  /// widths (prices, volumes in thousands, ATR) gave each pane a plot area of its own width, so the
  /// same minute, and the crosshair on it, sat at a different x in each pane.
  private func valueAxis(ticks: Int, format: FloatingPointFormatStyle<Double>) -> some AxisContent {
    AxisMarks(position: .trailing, values: .automatic(desiredCount: ticks)) { value in
      AxisGridLine()
      AxisTick()
      AxisValueLabel {
        Text(verbatim: value.as(Double.self)?.formatted(format) ?? Format.missing)
          .frame(width: Self.axisLabelWidth, alignment: .leading)
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

  /// The defined values of a line among the drawn candles, at the middle of their candles.
  private func points(_ values: [Double?]) -> [LinePoint] {
    drawn.compactMap { index in
      values[index].map { LinePoint(time: candles[index].middle, value: $0) }
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

  /// What the pointer is over. The chart reports a time; only a move to another candle changes
  /// what the crosshair and the readout show, and only they redraw for it.
  var selection: Binding<Date?> {
    Binding(
      get: { pointer.time },
      set: { time in
        pointer.time = time
        let index = time.flatMap(plot.index(at:))
        if pointer.index != index { pointer.index = index }
      })
  }

  /// Candles drawn: the whole day, or while zoomed the window with `drawnMargin` on each side.
  private var drawn: Range<Int> {
    guard zoomed else { return candles.indices }
    let margin = visibleLength * Self.drawnMargin
    return plot.indices(
      from: windowStart.addingTimeInterval(-margin), to: windowStart.addingTimeInterval(visibleLength + margin))
  }

  private var gap: TimeInterval { series.timeframe.seconds * (1 - Self.bodyShare) / 2 }
  private func bodyStart(_ candle: Candle) -> Date { candle.start.addingTimeInterval(gap) }
  private func bodyEnd(_ candle: Candle) -> Date { candle.end.addingTimeInterval(-gap) }

  private func color(_ candle: Candle) -> Color { candle.isUp ? Palette.profit : Palette.loss }

  /// Prices of the candles and levels on screen, padded so nothing touches the edge.
  private var priceDomain: ClosedRange<Double> {
    let shown = candles[plot.indices(from: windowStart, to: windowStart.addingTimeInterval(visibleLength))]
    let prices = shown.flatMap { [$0.low, $0.high] } + levels.map(\.price)
    guard let low = prices.min(), let high = prices.max() else { return 0...1 }
    let span = max(high - low, high * Self.minimumSpan)
    let pad = span * Self.pricePadding
    return (low - pad)...(high + pad)
  }

  private var pinch: some Gesture {
    MagnifyGesture()
      .onChanged { value in
        let start = pinchStart ?? viewport.visible ?? candles.count
        pinchStart = start
        viewport.show(Int((Double(start) / value.magnification).rounded()), total: candles.count)
      }
      .onEnded { _ in pinchStart = nil }
  }

  /// Prices and ATR values: dollars and cents.
  static let priceFormat = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(Money.centsDigits))

  static func price(_ value: Double) -> String {
    value.formatted(priceFormat)
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

  func body(content: Content) -> some View {
    content
      .chartXScale(domain: chart.xDomain)
      .chartScrollableAxes(chart.zoomed ? .horizontal : [])
      .chartXVisibleDomain(length: chart.visibleLength)
      .chartScrollPosition(x: chart.scrollPosition)
      .chartXSelection(value: chart.selection)
      .chartOverlay { proxy in Crosshair(pointer: chart.pointerModel, candles: chart.plot.candles, proxy: proxy) }
  }
}

/// The vertical line through the pointed candle, drawn over a pane rather than as a mark in it,
/// so moving the pointer redraws one line instead of the whole chart.
private struct Crosshair: View {
  let pointer: ChartPointer
  let candles: [Candle]
  let proxy: ChartProxy

  var body: some View {
    GeometryReader { geometry in
      if let index = pointer.index, candles.indices.contains(index), let plotFrame = proxy.plotFrame,
        let x = proxy.position(forX: candles[index].middle) {
        let frame = geometry[plotFrame]
        if x >= 0, x <= frame.width {
          Rectangle()
            .fill(Palette.textQuaternary.opacity(Tokens.Opacity.border))
            .frame(width: Tokens.Stroke.thin, height: frame.height)
            .position(x: frame.minX + x, y: frame.midY)
        }
      }
    }
    .allowsHitTesting(false)
  }
}

/// Values of the candle under the pointer (or the newest), above the price pane. It alone reads
/// the pointer, so a pointer move redraws this row and not the panes.
private struct ChartReadout: View {
  let plot: ChartPlot
  let lines: ChartLines
  let pointer: ChartPointer

  private var series: ChartSeries { plot.series }
  private var atr: [Double?] { plot.atr }

  var body: some View {
    let pointed = pointer.index.flatMap { series.candles.indices.contains($0) ? $0 : nil }
    if let index = pointed ?? series.candles.indices.last {
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

/// Localized names of the plotted values (VoiceOver and Audio Graphs read them). Looked up once:
/// every mark names its values, and a lookup per mark per redraw cost thousands of lookups.
private enum Plot {
  static let time = String(localized: L10n.Chart.axisTime)
  static let price = String(localized: L10n.Chart.axisPrice)
  static let volume = String(localized: L10n.Chart.volume)
  static let series = String(localized: L10n.Chart.axisSeries)
  static let vwap = String(localized: L10n.Chart.vwap)
  static let fastEMA = String(localized: L10n.Chart.ema(Indicators.fastEMAPeriod))
  static let slowEMA = String(localized: L10n.Chart.ema(Indicators.slowEMAPeriod))
  static let atr = String(localized: L10n.Chart.atr(Indicators.atrPeriod))
}

extension Candle {
  /// The middle of the candle's time slot, where its wick is drawn.
  var middle: Date { start.addingTimeInterval(end.timeIntervalSince(start) / 2) }
}
