import ApertureDesign
import ApertureKit
import Charts
import SwiftUI

/// Candles with the bot's indicator lines, the trades' entry, exit and stop, the strategy's watch and
/// entry marks, and volume underneath. Scrolls sideways through the day; touch and hold to read
/// one candle. Which stretch of the day is on screen lives in `viewport`, so the controls under the
/// chart can zoom it and bring back the newest candle.
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
  /// Space above and below the visible prices, as a share of their range.
  static let pricePadding = 0.08
  /// Value labels on the volume and ATR panes' scales.
  static let paneAxisMarks = 2
  /// Width every pane gives its scale labels, so the plot areas of all panes are equally wide
  /// and candles, volume and ATR line up.
  static let axisLabelWidth: CGFloat = 44
  /// Smallest scale the readout line may shrink to before it truncates.
  static let readoutMinimumScale = 0.7
  /// Size of a watch or entry mark on its candle, in points.
  static let eventSize: CGFloat = 60

  let series: ChartSeries
  /// The ATR line, one value per candle of `series`.
  let atr: [Double?]
  let trades: [DayTrade]
  /// The bot's open position on this symbol, when the chart is of its status's day.
  let position: Position?
  /// The trading strategy's watch and entry marks.
  let events: [ChartEvent]
  let lines: Lines
  @Binding var viewport: ChartViewport

  @State private var selected: Date?

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      readout
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(selected == nil ? Palette.textQuaternary : Palette.textSecondary)
        .lineLimit(1)
        .minimumScaleFactor(Self.readoutMinimumScale)
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
    .onAppear { viewport.followEnd(series) }
    .onChange(of: series.timeframe) { viewport.followEnd(series) }
    .onChange(of: series.candles.last) { old, _ in
      // Keep following the newest candle when it was already in view.
      if let old, old.end >= viewport.scroll.addingTimeInterval(window) { viewport.followEnd(series) }
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
      if let position {
        positionMarks(position)
      }
      ForEach(events) { event in
        eventMark(event)
      }
      if let candle = selectedCandle {
        RuleMark(x: .value(Plot.time, middle(candle)))
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
      // Coloured tags over the scale: the last price, entries and stops.
      let tags = priceTags
      AxisMarks(position: .trailing, values: tags.map(\.price)) { value in
        AxisValueLabel {
          if tags.indices.contains(value.index) {
            priceTag(tags[value.index])
          }
        }
      }
    }
    .modifier(Scrolling(window: window, domain: timeDomain, scroll: $viewport.scroll))
    .chartXSelection(value: $selected)
    .chartPlotStyle { $0.background(Palette.surfaceSunken) }
    .accessibilityLabel(Text(ChartText.title))
  }

  private var volumeChart: some View {
    Chart(series.candles) { candle in
      RectangleMark(
        xStart: .value(Plot.time, bodyStart(candle)),
        xEnd: .value(Plot.time, bodyEnd(candle)),
        yStart: .value(Plot.volume, 0),
        yEnd: .value(Plot.volume, candle.volume))
        .foregroundStyle((candle.isUp ? Palette.profit : Palette.loss).opacity(Tokens.Opacity.border))
    }
    .chartXAxis(.hidden)
    .chartYAxis {
      // No scale, as in the design; an empty label as wide as the price scale keeps the bars under
      // their candles.
      AxisMarks(position: .trailing, values: [Double.zero]) { _ in
        AxisValueLabel {
          Color.clear.frame(width: Self.axisLabelWidth)
        }
      }
    }
    .modifier(Scrolling(window: window, domain: timeDomain, scroll: $viewport.scroll))
    .accessibilityHidden(true)
  }

  /// Average true range under the volume, with its scale on the right.
  private var atrChart: some View {
    Chart {
      ForEach(Array(zip(series.candles, atr)), id: \.0.id) { candle, value in
        if let value {
          LineMark(
            x: .value(Plot.time, middle(candle)),
            y: .value(Plot.atr, value))
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
    .modifier(Scrolling(window: window, domain: timeDomain, scroll: $viewport.scroll))
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
      x: .value(Plot.time, middle(candle)),
      yStart: .value(Plot.price, candle.low),
      yEnd: .value(Plot.price, candle.high))
      .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.thin))
      .foregroundStyle(colour)
    if candle.open == candle.close {
      RuleMark(
        xStart: .value(Plot.time, bodyStart(candle)),
        xEnd: .value(Plot.time, bodyEnd(candle)),
        y: .value(Plot.price, candle.close))
        .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.regular))
        .foregroundStyle(colour)
    } else {
      RectangleMark(
        xStart: .value(Plot.time, bodyStart(candle)),
        xEnd: .value(Plot.time, bodyEnd(candle)),
        yStart: .value(Plot.price, candle.open),
        yEnd: .value(Plot.price, candle.close))
        .foregroundStyle(colour)
    }
  }

  @ChartContentBuilder
  private func lineMarks(_ id: Series, _ values: [Double?], _ colour: Color, shown: Bool) -> some ChartContent {
    if shown {
      ForEach(Array(zip(series.candles, values)), id: \.0.id) { candle, value in
        if let value {
          LineMark(
            x: .value(Plot.time, middle(candle)),
            y: .value(Plot.price, value),
            series: .value(Plot.line, id))
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
    levelLines(entry: entry, stop: trade.stopPrice.map(ChartFormat.double))
    PointMark(
      x: .value(Plot.time, trade.openedAt.date),
      y: .value(Plot.entry, entry))
      .symbol { marker(Image(systemName: "arrowtriangle.up.fill"), Palette.info) }
    PointMark(
      x: .value(Plot.time, trade.closedAt.date),
      y: .value(Plot.exit, exit))
      .symbol { marker(Image(systemName: "arrowtriangle.down.fill"), Palette.result(trade.resultGrossUsd.value)) }
  }

  /// The open position's entry and stop, with the entry marked at its time.
  @ChartContentBuilder
  private func positionMarks(_ position: Position) -> some ChartContent {
    let entry = ChartFormat.double(position.entryPrice)
    levelLines(entry: entry, stop: position.stop.price.map(ChartFormat.double),
      protected: position.stop.state.isProtected)
    PointMark(
      x: .value(Plot.time, position.openedAt.date),
      y: .value(Plot.entry, entry))
      .symbol { marker(Image(systemName: "arrowtriangle.up.fill"), Palette.info) }
  }

  /// Dashed lines across the chart at an entry and its stop; a stop the broker has not proven
  /// working is amber, not red.
  @ChartContentBuilder
  private func levelLines(entry: Double, stop: Double?, protected: Bool = true) -> some ChartContent {
    RuleMark(y: .value(Plot.entry, entry))
      .foregroundStyle(Palette.info.opacity(Tokens.Opacity.border))
      .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.thin, dash: Tokens.Stroke.dash))
    if let stop {
      RuleMark(y: .value(Plot.stop, stop))
        .foregroundStyle(Self.stopColour(protected: protected).opacity(Tokens.Opacity.border))
        .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.thin, dash: Tokens.Stroke.dash))
    }
  }

  /// A dot on the candle where the strategy began watching (amber), said enter (blue) or was
  /// refused an entry (grey).
  private func eventMark(_ event: ChartEvent) -> some ChartContent {
    PointMark(
      x: .value(Plot.time, event.candle.addingTimeInterval(series.timeframe.seconds / 2)),
      y: .value(Plot.price, event.price))
      .symbolSize(Self.eventSize)
      .foregroundStyle(Self.colour(event.kind))
      .accessibilityLabel(Text(Self.title(event.kind)))
  }

  static func stopColour(protected: Bool) -> Color {
    protected ? Palette.loss : Palette.warning
  }

  static func colour(_ kind: ChartEvent.Kind) -> Color {
    switch kind {
    case .watch: Palette.warning
    case .enter: Palette.info
    case .refused: Palette.textQuaternary
    }
  }

  static func title(_ kind: ChartEvent.Kind) -> LocalizedStringResource {
    switch kind {
    case .watch: ChartText.verdictWatch
    case .enter: ChartText.verdictEnter
    case .refused: ChartText.refusedEntry
    }
  }

  /// A level shown as a coloured tag over the price scale.
  struct PriceTag: Hashable {
    let price: Double
    let fill: Color
  }

  /// The last close, then each entry and stop on the chart (the trades' and the open position's).
  private var priceTags: [PriceTag] {
    var tags: [PriceTag] = []
    var levels = trades.map { (ChartFormat.double($0.entryPrice), $0.stopPrice.map(ChartFormat.double), true) }
    if let position {
      levels.append((ChartFormat.double(position.entryPrice), position.stop.price.map(ChartFormat.double),
        position.stop.state.isProtected))
    }
    for (entry, stop, protected) in levels {
      tags.append(PriceTag(price: entry, fill: Palette.info))
      if let stop { tags.append(PriceTag(price: stop, fill: Self.stopColour(protected: protected))) }
    }
    if let last = series.candles.last {
      tags.append(PriceTag(price: last.close, fill: last.isUp ? Palette.profit : Palette.loss))
    }
    return tags
  }

  private func priceTag(_ tag: PriceTag) -> some View {
    Text(tag.price, format: ChartFormat.price)
      .font(Tokens.Typography.annotationBold)
      .foregroundStyle(Palette.surface)
      .lineLimit(1)
      .minimumScaleFactor(Self.readoutMinimumScale)
      .padding(.horizontal, Tokens.Space.xxs)
      .frame(width: Self.axisLabelWidth, alignment: .leading)
      .background(tag.fill, in: RoundedRectangle(cornerRadius: Tokens.Radius.small))
  }

  private func marker(_ image: Image, _ colour: Color) -> some View {
    image
      .font(Tokens.Typography.badge)
      .foregroundStyle(colour)
  }

  private var timeAxis: some AxisContent {
    AxisMarks(values: .automatic) { value in
      AxisGridLine(stroke: StrokeStyle(lineWidth: Tokens.Stroke.hairline))
        .foregroundStyle(Palette.separator)
      AxisValueLabel {
        // Never truncated to "…" at the right edge.
        if let date = value.as(Date.self) {
          Text(date, format: ChartFormat.time)
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textQuaternary)
            .fixedSize()
        }
      }
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
      Text(ChartText.caption(String(localized: ChartFormat.title(series.timeframe)),
        String(localized: ChartText.bars(viewport.barsShown(series)))))
    }
  }

  // MARK: geometry

  /// The day's time from the first candle's start to the last one's end.
  private var timeDomain: ClosedRange<Date> {
    guard let first = series.candles.first, let last = series.candles.last else { return Date.now...Date.now }
    return first.start...last.end
  }

  /// Seconds of the day on screen.
  private var window: TimeInterval { viewport.window(series) }

  private var selectedCandle: Candle? {
    guard let selected else { return nil }
    return series.candles.first { $0.start <= selected && selected < $0.end }
  }

  /// Prices of the candles on screen and the open position's entry and stop, with a little room
  /// above and below.
  private var priceDomain: ClosedRange<Double> {
    let end = viewport.scroll.addingTimeInterval(window)
    let shown = series.candles.filter { $0.end > viewport.scroll && $0.start < end }
    let candles = shown.isEmpty ? series.candles : shown
    let levels = [position?.entryPrice, position?.stop.price].compactMap { $0.map(ChartFormat.double) }
    let low = (candles.map(\.low) + levels).min() ?? 0
    let high = (candles.map(\.high) + levels).max() ?? 1
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
}

/// Which stretch of the day the chart shows: how many candles fit on screen and where the view
/// starts. Kept by the Chart tab so its controls can zoom and follow the newest candle.
struct ChartViewport: Equatable {
  /// Candles on screen when the chart opens, and the fewest and most zooming allows.
  static let defaultVisible = 40.0
  static let fewestVisible = 15.0
  static let mostVisible = 390.0
  /// How much one zoom step changes the number of candles on screen.
  static let zoomStep = 1.5

  var visible = ChartViewport.defaultVisible
  var scroll = Date.distantPast

  /// Seconds of the day on screen.
  func window(_ series: ChartSeries) -> TimeInterval { visible * series.timeframe.seconds }

  /// Candles on screen: the zoom, or all of them when the day has fewer.
  func barsShown(_ series: ChartSeries) -> Int {
    min(Int(visible.rounded()), series.candles.count)
  }

  func canZoomOut(_ series: ChartSeries) -> Bool {
    visible < min(Self.mostVisible, Double(series.candles.count))
  }

  var canZoomIn: Bool { visible > Self.fewestVisible }

  /// Whether the newest candle is on screen.
  func showsEnd(_ series: ChartSeries) -> Bool {
    guard let last = series.candles.last else { return true }
    return last.end <= scroll.addingTimeInterval(window(series))
  }

  /// Show `factor` times as many candles, keeping the right edge where it is.
  mutating func zoom(by factor: Double, _ series: ChartSeries) {
    let end = scroll.addingTimeInterval(window(series))
    visible = min(max(visible * factor, Self.fewestVisible), Self.mostVisible)
    scroll = end.addingTimeInterval(-window(series))
  }

  /// Scroll so the newest candle sits at the right edge.
  mutating func followEnd(_ series: ChartSeries) {
    guard let last = series.candles.last, let first = series.candles.first else { return }
    scroll = max(first.start, last.end.addingTimeInterval(-window(series)))
  }
}

/// Names of the plotted values, read by VoiceOver; built once, not for every mark.
private enum Plot {
  static let time = String(localized: ChartText.axisTime)
  static let price = String(localized: ChartText.axisPrice)
  static let line = String(localized: ChartText.axisLine)
  static let volume = String(localized: ChartText.volume)
  static let entry = String(localized: ChartText.entry)
  static let stop = String(localized: ChartText.stop)
  static let exit = String(localized: ChartText.exit)
  static let atr = String(localized: ChartText.atr(Indicators.atrPeriod))
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
  /// 24-hour New York time of a bar ("14:05"): `.twoDigits(amPM: .omitted)` would drop the AM/PM
  /// of a 12-hour locale and show 02:05.
  static let time = Date.VerbatimFormatStyle(
    format: "\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)",
    timeZone: WireDate.newYork.timeZone, calendar: WireDate.newYork)
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
