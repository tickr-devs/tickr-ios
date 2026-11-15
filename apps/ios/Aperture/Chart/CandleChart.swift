import ApertureDesign
import ApertureKit
import Charts
import SwiftUI

/// The price pane (candles or a filled close line, volume along its bottom, the bot's lines and
/// the chosen studies, the trades' entry, exit and stop, the strategy's watch and entry marks)
/// and the study panes under it (MACD, slow stochastic, RSI, ATR), which scroll together through
/// the day. Touch and hold to read one candle: one line runs through every pane and the header
/// rows read that candle. Which stretch of the day is on screen lives in `viewport`, so the
/// controls under the chart can zoom it and bring back the newest candle.
struct CandleChart: View {
  /// Which lines and panes are drawn, and how prices are drawn.
  struct Lines: Equatable {
    var style = Style.candles
    var vwap = true
    var fastEMA = true
    var slowEMA = false
    var movingAverages = false
    var bollinger = false
    var volume = true
    var macd = false
    var stochastic = false
    var rsi = true
    var atr = false

    /// The study panes under the price pane, top to bottom.
    var panes: [Pane] {
      [macd ? .macd : nil, stochastic ? .stochastic : nil, rsi ? .rsi : nil, atr ? .atr : nil].compactMap { $0 }
    }
  }

  /// Candles, or a line of closes with a fill under it.
  enum Style: Hashable {
    case candles
    case line
  }

  /// A study pane under the price pane.
  enum Pane: Hashable {
    case macd
    case stochastic
    case rsi
    case atr
  }

  /// Line series, kept apart so Charts does not join them.
  enum Series: String, Plottable {
    case close
    case vwap
    case fastEMA
    case slowEMA
    case shortAverage
    case mediumAverage
    case longAverage
    case bollingerUpper
    case bollingerMiddle
    case bollingerLower
    case macd
    case signal
    case stochasticK
    case stochasticD
    case rsi
    case atr
  }

  /// Height of the price pane, in points.
  static let priceHeight: CGFloat = 300
  /// Height of each study pane, in points.
  static let paneHeight: CGFloat = 72
  /// Height a price tag covers on the scale, with a gap, in points: an axis price this close
  /// to a tag hides under it.
  static let tagClearance: CGFloat = 20
  /// Share of a candle's time slot its body fills; the rest is the gap between candles.
  static let bodyShare = 0.64
  /// Space above and below the visible prices, as a share of their range.
  static let pricePadding = 0.08
  /// Height of the volume bars along the bottom of the price pane, as a share of the price range.
  static let volumeShare = 0.22
  /// Value labels on a study pane's scale.
  static let paneAxisMarks = 2
  /// Width every pane gives its scale labels, so the plot areas of all panes are equally wide
  /// and candles, volume and studies line up.
  static let axisLabelWidth: CGFloat = 50
  /// Smallest scale the readout line may shrink to before it truncates.
  static let readoutMinimumScale = 0.7
  /// Size of a watch or entry mark on its candle, in points.
  static let eventSize: CGFloat = 60
  /// Length of the leader line of the high and low labels, in points.
  static let extremeLeader: CGFloat = 12
  /// Room above a study pane's line for its legend, as a share of the pane's value range.
  static let legendHeadroom = 0.35
  /// Annotations near an edge move inside the chart instead of being cut off.
  static let keepInside = AnnotationOverflowResolution(x: .fit(to: .chart), y: .fit(to: .chart))
  /// Colours of the moving-average lines, in the order of `Studies.movingAveragePeriods`.
  static let averageColours = [Palette.info, Palette.warning, Palette.highlight]
  /// Line series of the moving averages, in the same order.
  static let averageSeries: [Series] = [.shortAverage, .mediumAverage, .longAverage]

  let series: ChartSeries
  /// Real times of the candles, for the readout and the axis beyond one day.
  var times = ChartTimes.day
  /// Moving averages, Bollinger, MACD, RSI and stochastic of `series`' candles.
  let studies: CandleStudies
  /// The ATR line, one value per candle of `series`.
  let atr: [Double?]
  let trades: [DayTrade]
  /// The bot's open position on this symbol, when the chart is of its status's day.
  let position: Position?
  /// The trading strategy's watch and entry marks.
  let events: [ChartEvent]
  let lines: Lines
  @Binding var viewport: ChartViewport
  /// The value scales' width, grown with Dynamic Type so a price such as 128.40 is never cut.
  @ScaledMetric(relativeTo: .caption2) private var axisWidth = CandleChart.axisLabelWidth

  @State private var selected: Date?

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      readout
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(selected == nil ? Palette.textQuaternary : Palette.textSecondary)
        .lineLimit(1)
        .minimumScaleFactor(Self.readoutMinimumScale)
      legend(priceLegend)
      VStack(spacing: 0) {
        priceChart
          .frame(height: Self.priceHeight)
        ForEach(lines.panes, id: \.self) { pane in
          paneChart(pane)
            .frame(height: Self.paneHeight)
            .overlay(alignment: .topLeading) { legend(paneLegend(pane)) }
            .overlay(alignment: .top) {
              Rectangle().fill(Palette.separator).frame(height: Tokens.Stroke.hairline)
            }
            .transition(.opacity)
        }
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

  // MARK: price pane

  private var priceChart: some View {
    let scale = priceScale
    return Chart {
      if lines.volume {
        ForEach(series.candles) { candle in
          RectangleMark(
            xStart: .value(Plot.time, bodyStart(candle)),
            xEnd: .value(Plot.time, bodyEnd(candle)),
            yStart: .value(Plot.price, scale.volumeBase),
            yEnd: .value(Plot.price, scale.volumeTop(candle.volume)))
            .foregroundStyle((candle.isUp ? Palette.profit : Palette.loss).opacity(Tokens.Opacity.faint))
        }
      }
      if lines.style == .line {
        lineArea(scale)
      } else {
        ForEach(series.candles) { candle in
          candleMarks(candle)
        }
      }
      if lines.bollinger {
        lineMarks(.bollingerUpper, studies.bollinger.map { $0?.upper }, Palette.accent.opacity(Tokens.Opacity.medium))
        lineMarks(.bollingerMiddle, studies.bollinger.map { $0?.middle }, Palette.accent)
        lineMarks(.bollingerLower, studies.bollinger.map { $0?.lower }, Palette.accent.opacity(Tokens.Opacity.medium))
      }
      if lines.movingAverages {
        ForEach(Array(studies.movingAverages.enumerated()), id: \.offset) { item in
          lineMarks(Self.averageSeries[item.offset], item.element, Self.averageColours[item.offset])
        }
      }
      if lines.vwap { lineMarks(.vwap, series.vwap, Palette.seriesVWAP) }
      if lines.fastEMA { lineMarks(.fastEMA, series.fastEMA, Palette.seriesFastEMA) }
      if lines.slowEMA { lineMarks(.slowEMA, series.slowEMA, Palette.seriesSlowEMA) }
      extremes
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
        crosshair(candle)
          .annotation(position: .bottom, spacing: 0, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
            Text(verbatim: times.text(candle.start))
              .fixedSize()
              .font(Tokens.Typography.annotationBold)
              .foregroundStyle(Palette.surface)
              .padding(.horizontal, Tokens.Space.xs)
              .background(Palette.textSecondary, in: RoundedRectangle(cornerRadius: Tokens.Radius.small))
          }
      }
    }
    .chartYScale(domain: scale.domain)
    .chartXAxis { timeAxis }
    .chartYAxis {
      // Coloured tags over the scale: the last price, entries and stops; a plain axis price
      // they would cover stays hidden.
      let tags = priceTags
      let clearance = (scale.domain.upperBound - scale.domain.lowerBound) * Self.tagClearance / Self.priceHeight
      AxisMarks(position: .trailing) { value in
        AxisGridLine(stroke: StrokeStyle(lineWidth: Tokens.Stroke.hairline))
          .foregroundStyle(Palette.separator)
        AxisValueLabel {
          if let price = value.as(Double.self), !tags.contains(where: { abs($0.price - price) < clearance }) {
            axisLabel(value, ChartFormat.price, Palette.textQuaternary)
          }
        }
      }
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

  /// The close as a line with a fill fading down to the volume bars, coloured by whether
  /// the stretch on screen ended above where it began.
  @ChartContentBuilder
  private func lineArea(_ scale: PriceScale) -> some ChartContent {
    let tint = visibleTrendUp ? Palette.profit : Palette.loss
    ForEach(series.candles) { candle in
      AreaMark(
        x: .value(Plot.time, middle(candle)),
        yStart: .value(Plot.price, scale.volumeBase + scale.volumeHeight),
        yEnd: .value(Plot.price, candle.close))
        .foregroundStyle(
          LinearGradient(
            colors: [tint.opacity(Tokens.Opacity.faint), tint.opacity(Tokens.Opacity.wash)],
            startPoint: .top, endPoint: .bottom))
      LineMark(
        x: .value(Plot.time, middle(candle)),
        y: .value(Plot.price, candle.close),
        series: .value(Plot.line, Series.close))
        .foregroundStyle(tint)
        .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.regular))
    }
  }

  /// The highest high and lowest low on screen, each labelled with its price.
  @ChartContentBuilder
  private var extremes: some ChartContent {
    if let found = series.candles.extremes(in: visibleIndices) {
      let high = series.candles[found.high]
      let low = series.candles[found.low]
      PointMark(x: .value(Plot.time, middle(high)), y: .value(Plot.price, high.high))
        .symbolSize(0)
        .annotation(position: .top, spacing: Tokens.Space.xxs, overflowResolution: Self.keepInside) {
          extremeLabel(high.high)
        }
      PointMark(x: .value(Plot.time, middle(low)), y: .value(Plot.price, low.low))
        .symbolSize(0)
        .annotation(position: .bottom, spacing: Tokens.Space.xxs, overflowResolution: Self.keepInside) {
          extremeLabel(low.low)
        }
    }
  }

  private func extremeLabel(_ price: Double) -> some View {
    HStack(spacing: Tokens.Space.xxs) {
      Text(price, format: ChartFormat.price)
      Rectangle()
        .fill(Palette.textTertiary)
        .frame(width: Self.extremeLeader, height: Tokens.Stroke.hairline)
    }
    .font(Tokens.Typography.annotation)
    .foregroundStyle(Palette.textTertiary)
    .fixedSize()
  }

  /// The touched candle's line, drawn in every pane so it reads as one line through them.
  private func crosshair(_ candle: Candle) -> some ChartContent {
    RuleMark(x: .value(Plot.time, middle(candle)))
      .foregroundStyle(Palette.textTertiary)
      .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.thin, dash: Tokens.Stroke.dashFine))
  }

  // MARK: study panes

  @ViewBuilder
  private func paneChart(_ pane: Pane) -> some View {
    switch pane {
    case .macd:
      Chart {
        ForEach(Array(zip(series.candles, studies.macd)), id: \.0.id) { candle, point in
          if let point {
            BarMark(
              xStart: .value(Plot.time, bodyStart(candle)),
              xEnd: .value(Plot.time, bodyEnd(candle)),
              y: .value(Plot.value, point.histogram))
              .foregroundStyle((point.histogram >= 0 ? Palette.profit : Palette.loss).opacity(Tokens.Opacity.medium))
          }
        }
        lineMarks(.macd, studies.macd.map { $0?.macd }, Palette.info)
        lineMarks(.signal, studies.macd.map { $0?.signal }, Palette.warning)
        if let candle = selectedCandle { crosshair(candle) }
      }
      .chartYScale(domain: macdDomain)
      .modifier(PaneAxes(marks: .automatic(desiredCount: Self.paneAxisMarks)))
      .modifier(Scrolling(window: window, domain: timeDomain, scroll: $viewport.scroll))
    case .stochastic:
      Chart {
        bands(high: Studies.stochasticHigh, low: Studies.stochasticLow)
        lineMarks(.stochasticK, studies.stochastic.map { $0?.k }, Palette.info)
        lineMarks(.stochasticD, studies.stochastic.map { $0?.d }, Palette.warning)
        if let candle = selectedCandle { crosshair(candle) }
      }
      .chartYScale(domain: 0...(Studies.oscillatorScale * (1 + Self.legendHeadroom)))
      .modifier(PaneAxes(marks: .values([Studies.stochasticLow, Studies.stochasticHigh])))
      .modifier(Scrolling(window: window, domain: timeDomain, scroll: $viewport.scroll))
    case .rsi:
      Chart {
        bands(high: Studies.rsiHigh, low: Studies.rsiLow)
        lineMarks(.rsi, studies.rsi, Palette.info)
        if let candle = selectedCandle { crosshair(candle) }
      }
      .chartYScale(domain: 0...(Studies.oscillatorScale * (1 + Self.legendHeadroom)))
      .modifier(PaneAxes(marks: .values([Studies.rsiLow, Studies.rsiHigh])))
      .modifier(Scrolling(window: window, domain: timeDomain, scroll: $viewport.scroll))
    case .atr:
      Chart {
        lineMarks(.atr, atr, Palette.seriesATR)
        if let candle = selectedCandle { crosshair(candle) }
      }
      .chartYScale(domain: .automatic(includesZero: false))
      .modifier(PaneAxes(marks: .automatic(desiredCount: Self.paneAxisMarks)))
      .modifier(Scrolling(window: window, domain: timeDomain, scroll: $viewport.scroll))
    }
  }

  /// Dashed lines at an oscillator's overbought and oversold levels.
  @ChartContentBuilder
  private func bands(high: Double, low: Double) -> some ChartContent {
    ForEach([high, low], id: \.self) { level in
      RuleMark(y: .value(Plot.value, level))
        .foregroundStyle(Palette.warning.opacity(Tokens.Opacity.border))
        .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.thin, dash: Tokens.Stroke.dashFine))
    }
  }

  /// MACD's value range on the whole day, with room above for the legend.
  private var macdDomain: ClosedRange<Double> {
    let values = studies.macd.compactMap { $0 }.flatMap { [$0.macd, $0.signal, $0.histogram] }
    guard let low = values.min(), let high = values.max(), high > low else { return -1...1 }
    return low...(high + (high - low) * Self.legendHeadroom)
  }

  // MARK: legends

  /// One coloured name and value in a legend row.
  struct LegendItem {
    let name: LocalizedStringResource
    let value: Double?
    let colour: Color
  }

  /// The touched candle, or the newest while nothing is touched: the candle legends read.
  private var legendIndex: Int? {
    if let selected, let index = series.candles.firstIndex(where: { $0.start <= selected && selected < $0.end }) {
      return index
    }
    return series.candles.indices.last
  }

  private var priceLegend: [LegendItem] {
    guard let index = legendIndex else { return [] }
    var items: [LegendItem] = []
    if lines.vwap { items.append(LegendItem(name: ChartText.vwap, value: series.vwap[index], colour: Palette.seriesVWAP)) }
    if lines.fastEMA {
      items.append(LegendItem(name: ChartText.ema(Indicators.fastEMAPeriod), value: series.fastEMA[index],
        colour: Palette.seriesFastEMA))
    }
    if lines.slowEMA {
      items.append(LegendItem(name: ChartText.ema(Indicators.slowEMAPeriod), value: series.slowEMA[index],
        colour: Palette.seriesSlowEMA))
    }
    if lines.movingAverages {
      for (offset, period) in Studies.movingAveragePeriods.enumerated() {
        items.append(LegendItem(name: ChartText.movingAverage(period), value: studies.movingAverages[offset][index],
          colour: Self.averageColours[offset]))
      }
    }
    if lines.bollinger {
      let band = studies.bollinger[index]
      items.append(LegendItem(name: ChartText.bollingerUpper, value: band?.upper, colour: Palette.accentText))
      items.append(LegendItem(name: ChartText.bollingerMiddle, value: band?.middle, colour: Palette.accentText))
      items.append(LegendItem(name: ChartText.bollingerLower, value: band?.lower, colour: Palette.accentText))
    }
    return items
  }

  private func paneLegend(_ pane: Pane) -> [LegendItem] {
    guard let index = legendIndex else { return [] }
    switch pane {
    case .macd:
      let point = studies.macd[index]
      return [
        LegendItem(name: ChartText.macd(Studies.macdFast, Studies.macdSlow, Studies.macdSignal), value: point?.macd,
          colour: Palette.infoText),
        LegendItem(name: ChartText.macdSignal, value: point?.signal, colour: Palette.warningText),
        LegendItem(name: ChartText.macdHistogram, value: point?.histogram, colour: Palette.highlightText),
      ]
    case .stochastic:
      let point = studies.stochastic[index]
      return [
        LegendItem(name: ChartText.stochasticK(Studies.stochasticPeriod, Studies.stochasticSmoothing), value: point?.k,
          colour: Palette.infoText),
        LegendItem(name: ChartText.stochasticD, value: point?.d, colour: Palette.warningText),
      ]
    case .rsi:
      return [LegendItem(name: ChartText.rsi(Studies.rsiPeriod), value: studies.rsi[index], colour: Palette.infoText)]
    case .atr:
      return [LegendItem(name: ChartText.atr(Indicators.atrPeriod), value: atr[index], colour: Palette.seriesATRText)]
    }
  }

  /// A row of names and values, each in its line's colour; empty when nothing is drawn.
  @ViewBuilder
  private func legend(_ items: [LegendItem]) -> some View {
    if !items.isEmpty {
      HStack(spacing: Tokens.Space.s) {
        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
          // A clear gap between a name ending in a number and its value ("EMA9  28.84").
          HStack(spacing: Tokens.Space.xs) {
            Text(item.name)
            Text(item.value.map { ChartFormat.price.format($0) } ?? ChartFormat.missing)
          }
          .foregroundStyle(item.colour)
        }
      }
      .font(Tokens.Typography.annotation)
      .monospacedDigit()
      .lineLimit(1)
      .minimumScaleFactor(Self.readoutMinimumScale)
      .padding(.top, Tokens.Space.xxs)
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
  private func lineMarks(_ id: Series, _ values: [Double?], _ colour: Color) -> some ChartContent {
    ForEach(Array(zip(series.candles, values)), id: \.0.id) { candle, value in
      if let value {
        LineMark(
          x: .value(Plot.time, middle(candle)),
          y: .value(Plot.value, value),
          series: .value(Plot.line, id))
          .foregroundStyle(colour)
          .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.regular))
          .interpolationMethod(.monotone)
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
      .frame(width: axisWidth, alignment: .leading)
      .background(tag.fill, in: RoundedRectangle(cornerRadius: Tokens.Radius.small))
  }

  private func marker(_ image: Image, _ colour: Color) -> some View {
    image
      .font(Tokens.Typography.badge)
      .foregroundStyle(colour)
  }

  /// Clock times on one day; beyond one day, where each session, week, month or quarter begins.
  @AxisContentBuilder private var timeAxis: some AxisContent {
    if times.marks.isEmpty {
      // Aligned: the first and last labels stay inside the chart instead of being cut at its edges.
      AxisMarks(preset: .aligned, values: .automatic) { value in
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
    } else {
      let labels = Dictionary(times.marks.map { ($0.time, $0.text) }, uniquingKeysWith: { first, _ in first })
      AxisMarks(preset: .aligned, values: times.marks.map(\.time)) { value in
        AxisGridLine(stroke: StrokeStyle(lineWidth: Tokens.Stroke.hairline))
          .foregroundStyle(Palette.separator)
        AxisValueLabel {
          Text(verbatim: value.as(Date.self).flatMap { labels[$0] } ?? ChartFormat.missing)
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
      .frame(width: axisWidth, alignment: .leading)
  }

  // MARK: readout and zoom

  @ViewBuilder
  private var readout: some View {
    if let candle = selectedCandle {
      HStack(spacing: Tokens.Space.s) {
        Text(ChartText.readout(
          candle.open.formatted(ChartFormat.price), candle.high.formatted(ChartFormat.price),
          candle.low.formatted(ChartFormat.price), candle.close.formatted(ChartFormat.price),
          candle.volume.formatted(ChartFormat.volume)))
        if let index = legendIndex, let change = series.candles.change(at: index) {
          Text(change.fraction, format: ChartFormat.change)
            .foregroundStyle(change.amount >= 0 ? Palette.profitText : Palette.lossText)
        }
      }
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

  /// Indices of the candles on screen; all of them when none is.
  private var visibleIndices: Range<Int> {
    let end = viewport.scroll.addingTimeInterval(window)
    guard let first = series.candles.firstIndex(where: { $0.end > viewport.scroll }),
      let last = series.candles.lastIndex(where: { $0.start < end }), first <= last else {
      return series.candles.indices
    }
    return first..<(last + 1)
  }

  /// Whether the stretch on screen closed at or above where it opened.
  private var visibleTrendUp: Bool {
    let shown = visibleIndices
    guard let first = shown.first, let last = shown.last else { return true }
    return series.candles[last].close >= series.candles[first].open
  }

  /// Prices of the candles on screen, the open position's entry and stop and the drawn Bollinger
  /// bands, with a little room above and below and room under them for the volume bars.
  private var priceScale: PriceScale {
    let shown = visibleIndices
    let candles = series.candles[shown]
    var prices = candles.flatMap { [$0.low, $0.high] }
    prices += [position?.entryPrice, position?.stop.price].compactMap { $0.map(ChartFormat.double) }
    if lines.bollinger {
      prices += shown.compactMap { studies.bollinger[$0] }.flatMap { [$0.lower, $0.upper] }
    }
    let low = prices.min() ?? 0
    let high = prices.max() ?? 1
    let pad = max(high - low, high * Self.pricePadding) * Self.pricePadding
    let volumeHeight = lines.volume ? (high - low + pad + pad) * Self.volumeShare : 0
    let bottom = low - pad - volumeHeight
    return PriceScale(
      domain: bottom...(high + pad), volumeBase: bottom, volumeHeight: volumeHeight,
      volumeCeiling: candles.map(\.volume).max() ?? 0)
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

/// The price pane's value range and where its volume bars sit.
struct PriceScale {
  let domain: ClosedRange<Double>
  /// Price at the bottom of the volume bars.
  let volumeBase: Double
  /// Price range the tallest volume bar on screen spans.
  let volumeHeight: Double
  /// Largest volume on screen.
  let volumeCeiling: Double

  /// Price at the top of a bar of `volume`.
  func volumeTop(_ volume: Double) -> Double {
    guard volumeCeiling > 0 else { return volumeBase }
    return volumeBase + volume / volumeCeiling * volumeHeight
  }
}

/// A study pane's axes: no time axis (the price pane has it), a value scale on the right as wide
/// as the price scale so every pane's candles line up.
private struct PaneAxes: ViewModifier {
  /// Which values the scale labels.
  enum Marks {
    case automatic(desiredCount: Int)
    case values([Double])
  }

  let marks: Marks
  @ScaledMetric(relativeTo: .caption2) private var axisWidth = CandleChart.axisLabelWidth

  func body(content: Content) -> some View {
    content
      .chartXAxis(.hidden)
      .chartYAxis {
        switch marks {
        case .automatic(let count):
          AxisMarks(position: .trailing, values: .automatic(desiredCount: count)) { value in label(value) }
        case .values(let values):
          AxisMarks(position: .trailing, values: values) { value in label(value) }
        }
      }
  }

  @AxisMarkBuilder
  private func label(_ value: AxisValue) -> some AxisMark {
    AxisGridLine(stroke: StrokeStyle(lineWidth: Tokens.Stroke.hairline))
      .foregroundStyle(Palette.separator)
    AxisValueLabel {
      Text(value.as(Double.self).map { ChartFormat.price.format($0) } ?? String())
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
        .lineLimit(1)
        .minimumScaleFactor(CandleChart.readoutMinimumScale)
        .frame(width: axisWidth, alignment: .leading)
    }
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
  static let value = String(localized: ChartText.axisValue)
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
  /// A signed price change ("+0.82", "−0.15").
  static let signedPrice = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(Money.centsDigits))
    .sign(strategy: .always())
  static let change = FloatingPointFormatStyle<Double>.Percent.percent
    .precision(.fractionLength(1)).sign(strategy: .always())
  /// 24-hour New York time of a bar ("14:05"): `.twoDigits(amPM: .omitted)` would drop the AM/PM
  /// of a 12-hour locale and show 02:05.
  static let time = Date.VerbatimFormatStyle(
    format: "\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)",
    timeZone: WireDate.newYork.timeZone, calendar: WireDate.newYork)
  static let day = newYork(Date.FormatStyle.dateTime.weekday(.abbreviated).month(.abbreviated).day())
  /// Dates of a chart beyond one day, in New York and the person's language: "Fri 13" (a
  /// session), "Nov 9" (a week), "Nov 2026" (a monthly candle), "Nov" and "2026" on a long axis.
  static let sessionDay = newYork(Date.FormatStyle.dateTime.weekday(.abbreviated).day())
  static let monthDay = newYork(Date.FormatStyle.dateTime.month(.abbreviated).day())
  static let monthYear = newYork(Date.FormatStyle.dateTime.month(.abbreviated).year())
  static let month = newYork(Date.FormatStyle.dateTime.month(.abbreviated))
  static let year = newYork(Date.FormatStyle.dateTime.year())

  private static func newYork(_ style: Date.FormatStyle) -> Date.FormatStyle {
    var style = style
    style.timeZone = WireDate.newYork.timeZone
    return style
  }

  /// A wire decimal as a number to draw.
  static func double(_ value: DecimalString) -> Double {
    NSDecimalNumber(decimal: value.value).doubleValue
  }

  static func title(_ timeframe: Timeframe) -> LocalizedStringResource {
    switch timeframe {
    case .m1: ChartText.m1
    case .m5: ChartText.m5
    case .m30: ChartText.m30
    case .h1: ChartText.h1
    case .d1: ChartText.d1
    case .w1: ChartText.w1
    case .mo1: ChartText.mo1
    }
  }
}
