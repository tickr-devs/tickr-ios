import ApertureDesign
import ApertureKit
import Charts
import SwiftUI

/// Candles with the bot's indicator lines, the trades' entry, exit and stop, and volume underneath.
/// Scrolls sideways through the day; touch and hold to read one candle.
struct CandleChart: View {
  /// Which lines are drawn.
  struct Lines: Equatable {
    var vwap = true
    var fastEMA = true
    var slowEMA = false
    var volume = true
    var atr = false
  }

  /// Line series, kept apart so Charts does not join them.
  enum Series: String, Plottable {
    case vwap
    case fastEMA
    case slowEMA
  }

  /// Height of the price pane, in points.
  static let priceHeight: CGFloat = 300
  /// Height of the volume and ATR panes, in points.
  static let volumeHeight: CGFloat = 64
  /// Share of a candle's time slot its body fills; the rest is the gap between candles.
  static let bodyShare = 0.64
  /// Candles on screen when the chart opens, and the fewest and most zooming allows.
  static let defaultVisible = 40.0
  static let fewestVisible = 15.0
  static let mostVisible = 390.0
  /// How much one zoom step changes the number of candles on screen.
  static let zoomStep = 1.5
  /// Space above and below the visible prices, as a share of their range.
  static let pricePadding = 0.08
  /// Value labels on the volume and ATR panes' scales.
  static let paneAxisMarks = 2
  /// Width every pane gives its scale labels, so the plot areas of all panes are equally wide
  /// and candles, volume and ATR line up.
  static let axisLabelWidth: CGFloat = 44
  /// Smallest scale the readout line may shrink to before it truncates.
  static let readoutMinimumScale = 0.7

  let series: ChartSeries
  /// The ATR line, one value per candle of `series`.
  let atr: [Double?]
  let trades: [DayTrade]
  let lines: Lines

  @State private var visible = CandleChart.defaultVisible
  @State private var scroll = Date.distantPast
  @State private var selected: Date?

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      HStack {
        readout
          .font(Tokens.Typography.captionMono)
          .foregroundStyle(selected == nil ? Palette.textQuaternary : Palette.textSecondary)
          .lineLimit(1)
          .minimumScaleFactor(Self.readoutMinimumScale)
        Spacer(minLength: Tokens.Space.s)
        zoomButtons
      }
      priceChart
        .frame(height: Self.priceHeight)
      if lines.volume {
        volumeChart
          .frame(height: Self.volumeHeight)
          .transition(.opacity)
      }
      if lines.atr {
        atrChart
          .frame(height: Self.volumeHeight)
          .transition(.opacity)
      }
    }
    .padding(Tokens.Space.l)
    .apertureCard()
    .animation(Tokens.Motion.standard, value: lines)
    .onAppear { followEnd() }
    .onChange(of: series.timeframe) { followEnd() }
    .onChange(of: series.candles.last) { old, _ in
      // Keep following the newest candle when it was already in view.
      if let old, old.end >= scroll.addingTimeInterval(window) { followEnd() }
    }
    .sensoryFeedback(.selection, trigger: selectedCandle)
  }

  // MARK: panes

  private var priceChart: some View {
    Chart {
      ForEach(series.candles) { candle in
        candleMarks(candle)
      }
      lineMarks(.vwap, series.vwap, Palette.seriesVWAP, shown: lines.vwap)
      lineMarks(.fastEMA, series.fastEMA, Palette.seriesFastEMA, shown: lines.fastEMA)
      lineMarks(.slowEMA, series.slowEMA, Palette.seriesSlowEMA, shown: lines.slowEMA)
      ForEach(trades) { trade in
        tradeMarks(trade)
      }
      if let candle = selectedCandle {
        RuleMark(x: .value(String(localized: ChartText.axisTime), middle(candle)))
          .foregroundStyle(Palette.textTertiary)
          .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.thin, dash: Tokens.Stroke.dashFine))
      }
    }
    .chartYScale(domain: priceDomain)
    .chartXAxis { timeAxis }
    .chartYAxis {
      AxisMarks(position: .trailing) { value in
        AxisGridLine(stroke: StrokeStyle(lineWidth: Tokens.Stroke.hairline))
          .foregroundStyle(Palette.separator)
        AxisValueLabel {
          axisLabel(value, ChartFormat.price, Palette.textQuaternary)
        }
      }
    }
    .modifier(Scrolling(window: window, domain: timeDomain, scroll: $scroll))
    .chartXSelection(value: $selected)
    .chartPlotStyle { $0.background(Palette.surfaceSunken) }
    .accessibilityLabel(Text(ChartText.title))
  }

  private var volumeChart: some View {
    Chart(series.candles) { candle in
      RectangleMark(
        xStart: .value(String(localized: ChartText.axisTime), bodyStart(candle)),
        xEnd: .value(String(localized: ChartText.axisTime), bodyEnd(candle)),
        yStart: .value(String(localized: ChartText.volume), 0),
        yEnd: .value(String(localized: ChartText.volume), candle.volume))
        .foregroundStyle((candle.isUp ? Palette.profit : Palette.loss).opacity(Tokens.Opacity.faint))
    }
    .chartXAxis(.hidden)
    .chartYAxis {
      AxisMarks(position: .trailing, values: .automatic(desiredCount: Self.paneAxisMarks)) { value in
        AxisValueLabel {
          axisLabel(value, ChartFormat.volume, Palette.textQuaternary)
        }
      }
    }
    .modifier(Scrolling(window: window, domain: timeDomain, scroll: $scroll))
    .accessibilityHidden(true)
  }

  /// Average true range under the volume, with its scale on the right.
  private var atrChart: some View {
    Chart {
      ForEach(Array(zip(series.candles, atr)), id: \.0.id) { candle, value in
        if let value {
          LineMark(
            x: .value(String(localized: ChartText.axisTime), middle(candle)),
            y: .value(String(localized: ChartText.atr(Indicators.atrPeriod)), value))
            .foregroundStyle(Palette.seriesATR)
            .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.regular))
        }
      }
    }
    .chartXAxis(.hidden)
    .chartYAxis {
      AxisMarks(position: .trailing, values: .automatic(desiredCount: Self.paneAxisMarks)) { value in
        AxisValueLabel {
          axisLabel(value, ChartFormat.price, Palette.seriesATRText)
        }
      }
    }
    .chartYScale(domain: .automatic(includesZero: false))
    .modifier(Scrolling(window: window, domain: timeDomain, scroll: $scroll))
    .overlay(alignment: .topLeading) {
      Text(ChartText.atr(Indicators.atrPeriod))
        .font(Tokens.Typography.badge)
        .foregroundStyle(Palette.seriesATRText)
    }
  }

  // MARK: marks

  @ChartContentBuilder
  private func candleMarks(_ candle: Candle) -> some ChartContent {
    let colour = candle.isUp ? Palette.profit : Palette.loss
    RuleMark(
      x: .value(String(localized: ChartText.axisTime), middle(candle)),
      yStart: .value(String(localized: ChartText.axisPrice), candle.low),
      yEnd: .value(String(localized: ChartText.axisPrice), candle.high))
      .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.thin))
      .foregroundStyle(colour)
    if candle.open == candle.close {
      RuleMark(
        xStart: .value(String(localized: ChartText.axisTime), bodyStart(candle)),
        xEnd: .value(String(localized: ChartText.axisTime), bodyEnd(candle)),
        y: .value(String(localized: ChartText.axisPrice), candle.close))
        .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.regular))
        .foregroundStyle(colour)
    } else {
      RectangleMark(
        xStart: .value(String(localized: ChartText.axisTime), bodyStart(candle)),
        xEnd: .value(String(localized: ChartText.axisTime), bodyEnd(candle)),
        yStart: .value(String(localized: ChartText.axisPrice), candle.open),
        yEnd: .value(String(localized: ChartText.axisPrice), candle.close))
        .foregroundStyle(colour)
    }
  }

  @ChartContentBuilder
  private func lineMarks(_ id: Series, _ values: [Double?], _ colour: Color, shown: Bool) -> some ChartContent {
    if shown {
      ForEach(Array(zip(series.candles, values)), id: \.0.id) { candle, value in
        if let value {
          LineMark(
            x: .value(String(localized: ChartText.axisTime), middle(candle)),
            y: .value(String(localized: ChartText.axisPrice), value),
            series: .value(String(localized: ChartText.axisLine), id))
            .foregroundStyle(colour)
            .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.regular))
            .interpolationMethod(.monotone)
        }
      }
    }
  }

  @ChartContentBuilder
  private func tradeMarks(_ trade: DayTrade) -> some ChartContent {
    let entry = ChartFormat.double(trade.entryPrice)
    let exit = ChartFormat.double(trade.exitPrice)
    RuleMark(y: .value(String(localized: ChartText.entry), entry))
      .foregroundStyle(Palette.info.opacity(Tokens.Opacity.border))
      .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.thin, dash: Tokens.Stroke.dash))
      .annotation(position: .top, alignment: .leading) {
        levelTag(ChartText.entry, entry, Palette.infoText)
      }
    if let stop = trade.stopPrice.map(ChartFormat.double) {
      RuleMark(y: .value(String(localized: ChartText.stop), stop))
        .foregroundStyle(Palette.loss.opacity(Tokens.Opacity.border))
        .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.thin, dash: Tokens.Stroke.dash))
        .annotation(position: .bottom, alignment: .leading) {
          levelTag(ChartText.stop, stop, Palette.lossText)
        }
    }
    PointMark(
      x: .value(String(localized: ChartText.axisTime), trade.openedAt.date),
      y: .value(String(localized: ChartText.entry), entry))
      .symbol { marker(Image(systemName: "arrowtriangle.up.fill"), Palette.info) }
    PointMark(
      x: .value(String(localized: ChartText.axisTime), trade.closedAt.date),
      y: .value(String(localized: ChartText.exit), exit))
      .symbol { marker(Image(systemName: "arrowtriangle.down.fill"), Palette.result(trade.resultGrossUsd.value)) }
  }

  private func levelTag(_ title: LocalizedStringResource, _ price: Double, _ colour: Color) -> some View {
    HStack(spacing: Tokens.Space.xxs) {
      Text(title)
      Text(price, format: ChartFormat.price)
    }
    .font(Tokens.Typography.badge)
    .foregroundStyle(colour)
  }

  private func marker(_ image: Image, _ colour: Color) -> some View {
    image
      .font(Tokens.Typography.badge)
      .foregroundStyle(colour)
  }

  private var timeAxis: some AxisContent {
    AxisMarks(values: .automatic) { _ in
      AxisGridLine(stroke: StrokeStyle(lineWidth: Tokens.Stroke.hairline))
        .foregroundStyle(Palette.separator)
      AxisValueLabel(format: ChartFormat.time)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
    }
  }

  /// A scale label of fixed width (see `axisLabelWidth`).
  private func axisLabel<Style: FormatStyle>(_ value: AxisValue, _ format: Style, _ colour: Color) -> some View
    where Style.FormatInput == Double, Style.FormatOutput == String {
    Text(value.as(Double.self).map { format.format($0) } ?? String())
      .font(Tokens.Typography.annotation)
      .foregroundStyle(colour)
      .lineLimit(1)
      .minimumScaleFactor(Self.readoutMinimumScale)
      .frame(width: Self.axisLabelWidth, alignment: .leading)
  }

  // MARK: readout and zoom

  @ViewBuilder
  private var readout: some View {
    if let candle = selectedCandle {
      Text(ChartText.readout(
        candle.open.formatted(ChartFormat.price), candle.high.formatted(ChartFormat.price),
        candle.low.formatted(ChartFormat.price), candle.close.formatted(ChartFormat.price),
        candle.volume.formatted(ChartFormat.volume)))
    } else {
      Text(ChartText.hint)
    }
  }

  private var zoomButtons: some View {
    HStack(spacing: Tokens.Space.xs) {
      Button { zoom(by: Self.zoomStep) } label: { Image(systemName: "minus.magnifyingglass") }
        .disabled(visible >= min(Self.mostVisible, Double(series.candles.count)))
        .accessibilityLabel(Text(ChartText.zoomOut))
      Button { zoom(by: 1 / Self.zoomStep) } label: { Image(systemName: "plus.magnifyingglass") }
        .disabled(visible <= Self.fewestVisible)
        .accessibilityLabel(Text(ChartText.zoomIn))
    }
    .buttonStyle(.borderless)
    .foregroundStyle(Palette.infoText)
  }

  private func zoom(by factor: Double) {
    let end = scroll.addingTimeInterval(window)
    withAnimation(Tokens.Motion.quick) {
      visible = min(max(visible * factor, Self.fewestVisible), Self.mostVisible)
      scroll = end.addingTimeInterval(-window)
    }
  }

  // MARK: geometry

  /// The day's time from the first candle's start to the last one's end.
  private var timeDomain: ClosedRange<Date> {
    guard let first = series.candles.first, let last = series.candles.last else { return Date.now...Date.now }
    return first.start...last.end
  }

  /// Seconds of the day on screen.
  private var window: TimeInterval { visible * series.timeframe.seconds }

  private var selectedCandle: Candle? {
    guard let selected else { return nil }
    return series.candles.first { $0.start <= selected && selected < $0.end }
  }

  /// Prices of the candles on screen, with a little room above and below.
  private var priceDomain: ClosedRange<Double> {
    let end = scroll.addingTimeInterval(window)
    let shown = series.candles.filter { $0.end > scroll && $0.start < end }
    let candles = shown.isEmpty ? series.candles : shown
    let low = candles.map(\.low).min() ?? 0
    let high = candles.map(\.high).max() ?? 1
    let pad = max(high - low, high * Self.pricePadding) * Self.pricePadding
    return (low - pad)...(high + pad)
  }

  private func middle(_ candle: Candle) -> Date {
    candle.start.addingTimeInterval(series.timeframe.seconds / 2)
  }

  private func bodyStart(_ candle: Candle) -> Date {
    candle.start.addingTimeInterval(series.timeframe.seconds * (1 - Self.bodyShare) / 2)
  }

  private func bodyEnd(_ candle: Candle) -> Date {
    candle.end.addingTimeInterval(-series.timeframe.seconds * (1 - Self.bodyShare) / 2)
  }

  /// Scroll so the newest candle sits at the right edge.
  private func followEnd() {
    guard let last = series.candles.last, let first = series.candles.first else { return }
    scroll = max(first.start, last.end.addingTimeInterval(-window))
  }
}

/// Both panes scroll together through the day and show the same stretch of time.
private struct Scrolling: ViewModifier {
  let window: TimeInterval
  /// The whole day's time, the same on every pane, so a pane whose line starts later (ATR)
  /// still lines up under the candles.
  let domain: ClosedRange<Date>
  @Binding var scroll: Date

  func body(content: Content) -> some View {
    content
      .chartXScale(domain: domain)
      .chartScrollableAxes(.horizontal)
      .chartXVisibleDomain(length: window)
      .chartScrollPosition(x: $scroll)
  }
}

/// Number and date formats of the Chart tab. Times are New York times, as the bot's sessions are.
enum ChartFormat {
  /// Shown where a value is missing.
  static let missing = "—"
  /// Between the parts of a check: measured, operator, threshold.
  static let space = " "
  static let price = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(Money.centsDigits))
  static let volume = FloatingPointFormatStyle<Double>.number.notation(.compactName)
  static let change = FloatingPointFormatStyle<Double>.Percent.percent
    .precision(.fractionLength(1)).sign(strategy: .always())
  static let time: Date.FormatStyle = {
    var style = Date.FormatStyle.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)
    style.timeZone = WireDate.newYork.timeZone
    return style
  }()
  static let day: Date.FormatStyle = {
    var style = Date.FormatStyle.dateTime.weekday(.abbreviated).month(.abbreviated).day()
    style.timeZone = WireDate.newYork.timeZone
    return style
  }()

  /// A wire decimal as a number to draw.
  static func double(_ value: DecimalString) -> Double {
    NSDecimalNumber(decimal: value.value).doubleValue
  }

  static func title(_ timeframe: Timeframe) -> LocalizedStringResource {
    switch timeframe {
    case .m1: ChartText.m1
    case .m5: ChartText.m5
    case .m15: ChartText.m15
    }
  }
}
