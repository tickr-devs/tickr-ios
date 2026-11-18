import Charts
import SwiftUI
import TickrDesign
import TickrKit

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
    var rsi = false
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

  /// Colours of the two EMA lines as the iOS design draws them: the fast one violet, the slow
  /// one teal (the swap keeps the fast line apart from the rising candles' green).
  static var fastEMAColour: Color { Palette.highlight }
  static var slowEMAColour: Color { Palette.accent }
  /// Side of an entry or exit marker, a filled circle with its direction inside, and of a
  /// watch, entry or refused mark, a plain filled circle, in points.
  static let markerSide: CGFloat = 16
  /// How far a marker that would cover another one is moved at a time, in points: one side
  /// and a small gap, so stacked markers on the same or neighbouring candles never touch.
  static let markerStep: CGFloat = 18

  /// Height of the price pane, in points.
  static let priceHeight: CGFloat = 300
  /// Height of each study pane, in points.
  static let paneHeight: CGFloat = 72
  /// Height a price tag covers on the scale, with a gap, in points: an axis price this close
  /// to a tag hides under it.
  static let tagClearance: CGFloat = 20
  /// Largest text size of the chart's labels, tags and legends: the panes have a fixed height,
  /// so larger text would cover the candles and other labels.
  static let largestText = DynamicTypeSize.xxxLarge
  /// Share of a candle's time slot its body fills; the rest is the gap between candles.
  static let bodyShare = 0.64
  /// Value labels on a study pane's scale.
  static let paneAxisMarks = 2
  /// Width every pane gives its scale labels, so the plot areas of all panes are equally wide
  /// and candles, volume and studies line up.
  static let axisLabelWidth: CGFloat = 50
  /// Length of the leader line of the high and low labels, in points.
  static let extremeLeader: CGFloat = 12
  /// Room above a study pane's line for its legend, as a share of the pane's value range.
  static let legendHeadroom = 0.35
  /// Clock labels on screen at most, on one day.
  static let clockLabels = 4
  /// Width a time label needs with a gap to the next, in points at the default text size:
  /// labels closer than this are left out.
  static let timeLabelSlot: CGFloat = 52
  /// Area of the dot on the touched candle's close, in square points (a Charts symbol size).
  static let scrubDotArea: CGFloat = 36
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
  /// The range's name for the caption ("Day · 1m · 40 bars …").
  var rangeTitle: LocalizedStringResource = ChartText.rangeDay
  /// What the chart still waits for while the chart's request budget fills it (a cold 5D):
  /// a progress line over the chart (mockup v102); nil when it is complete.
  var pending: ChartPendingV1?
  /// The live bid of the symbol (GET /quotes) while today is shown: the price tag sits at it instead
  /// of the last closed candle's close, as the price above the chart does.
  var livePrice: Double?
  @Binding var viewport: ChartViewport
  /// The value scales' width, grown with Dynamic Type so a price such as 128.40 is never cut.
  @ScaledMetric(relativeTo: .caption2) private var axisWidth = CandleChart.axisLabelWidth
  /// A price tag's height on the scale, grown with Dynamic Type like the tag's text.
  @ScaledMetric(relativeTo: .caption2) private var tagRoom = CandleChart.tagClearance
  /// An axis label's height on the scale, grown with Dynamic Type like its text.
  @ScaledMetric(relativeTo: .caption2) private var labelRoom = Tokens.Chart.axisLabelHeight
  /// The time labels' slot, grown with Dynamic Type.
  @ScaledMetric(relativeTo: .caption2) private var labelSlot = CandleChart.timeLabelSlot
  /// The price pane's plot width, for spacing the time labels.
  @State private var chartWidth: CGFloat = 0

  /// Where the finger is on the chart while it touches.
  @State private var touched: Date?
  /// The candle the finger last rested on, held after it lifts so its values can be read
  /// (owner, 2026-11-18); a tap lets it go.
  @State private var held: Date?
  /// The candle the readout, legends and crosshair show: the touched one, else the held one.
  private var selected: Date? { touched ?? held }
  /// The chart's selection: a touch moves it, and lifting the finger holds its last candle.
  private var touch: Binding<Date?> {
    Binding(get: { touched }, set: { time in
      if time == nil, let last = touched { held = last }
      touched = time
    })
  }
  /// The window when the pinch began: the pinch scales it, not the window it last set.
  @State private var pinchStart: ChartViewport?
  /// Start of the newest candle the chart has taken in. A candle after it, a new minute bar that
  /// just arrived, is left out until it has grown in over the chart (the board's `grow`).
  @State private var grownThrough: Date?
  /// The new candle growing in now, drawn over the chart (`GrowingCandle`) instead of as a mark:
  /// Core Animation scales the small view, where an animated mark redrew the whole chart on every
  /// frame and the growth showed as a jump.
  @State private var growing: Date?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  /// The theme on screen: the extended-hours band is stronger in dark (mockup v114).
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      if let pending {
        // Days still to come while the chart's budget fills a cold 5D (mockup v102's progress).
        ProgressLine(fraction: pending.fraction, label: PendingText.caption(pending))
        Text(PendingText.caption(pending))
          .font(Tokens.Typography.captionMono)
          .foregroundStyle(Palette.textQuaternary)
      }
      readout
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(selected == nil ? Palette.textQuaternary : Palette.textSecondary)
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
      // Two fingers zoom every pane together, around the point between them; one finger still
      // scrolls and touch-and-hold still reads a candle.
      .simultaneousGesture(pinch)
    }
    .padding(Tokens.Space.l)
    .tickrCard()
    .animation(Tokens.Motion.standard, value: lines)
    .onAppear {
      place()
      grownThrough = series.candles.last?.start
    }
    .onChange(of: GrowthKey(timeframe: series.timeframe, first: series.candles.first?.start,
      last: series.candles.last?.start)) { old, new in
      // Only a new bar on the same chart grows; another range, interval or day just shows.
      let newBar = old.timeframe == new.timeframe && old.first == new.first
        && (new.last ?? .distantPast) > (old.last ?? .distantFuture)
      if newBar && !reduceMotion { growing = new.last }
      grownThrough = new.last
    }
    // Another chart (interval, range, day) opens on the whole range; a new read of the same
    // chart keeps the person's window (`ChartViewport.take`).
    .onChange(of: series.timeframe) { place() }
    .onChange(of: series.candles.first?.start) { place() }
    .onChange(of: series) { old, new in viewport.take(new, slots: slotCount, previous: old) }
    .sensoryFeedback(.selection, trigger: selectedCandle)
  }

  /// The whole range on screen, today's reserved slots included (mockup v113: Day opens on the
  /// whole session, 5D on its five days); zoom in to read closer.
  private func place() {
    // Another chart: a candle held on the last one means nothing here.
    held = nil
    viewport.fit(series, slots: slotCount)
  }

  /// Slots on the time axis: the candles, and on today's Day chart the rest of the day.
  private var slotCount: Int { times.sessions?.slots ?? series.candles.count }

  // MARK: price pane

  private var priceChart: some View {
    let scale = priceScale
    return Chart {
      // The lines and marks are clipped to the plot: a value off the scale (a closed trade's
      // stop, a line just past the stretch on screen) ends at the plot's edge instead of running
      // over the chips above the chart. The labels below are kept inside by their own fit.
      sessionMarks(scale)
      seriesMarks(scale)
        .clipShape(Rectangle())
      markerMarks(scale)
        .clipShape(Rectangle())
      extremes(scale)
      if let candle = selectedCandle {
        band(candle)
        // The time on a pill at the top of the line, clear of the time axis's labels.
        crosshair(candle)
          .annotation(position: .top, spacing: 0, overflowResolution: .init(x: .fit(to: .plot), y: .fit(to: .plot))) {
            Text(verbatim: times.text(candle.start))
              .fixedSize()
              .font(Tokens.Typography.annotationBold)
              .foregroundStyle(Palette.surface)
              .padding(.horizontal, Tokens.Space.xs)
              .background(Palette.textSecondary, in: RoundedRectangle(cornerRadius: Tokens.Radius.small))
          }
        // The touched candle's close: a line across, its price on the scale and a dot on it.
        RuleMark(y: .value(Plot.price, candle.close))
          .foregroundStyle(Palette.textTertiary)
          .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.thin, dash: Tokens.Stroke.dashFine))
          .annotation(position: .trailing, alignment: .center, spacing: 0,
            overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .plot))) {
            priceTag(PriceTag(price: candle.close, fill: Palette.textSecondary, shownAt: candle.close))
          }
        PointMark(x: .value(Plot.time, middle(candle)), y: .value(Plot.price, candle.close))
          .symbolSize(Self.scrubDotArea)
          .foregroundStyle(candle.isUp ? Palette.candleUp : Palette.candleDown)
      }
    }
    .chartYScale(domain: scale.domain)
    .chartOverlay(alignment: .topLeading) { proxy in
      if let start = growing, lines.style != .line, let candle = series.candles.last(where: { $0.start == start }) {
        GeometryReader { geometry in
          if let plot = proxy.plotFrame.map({ geometry[$0] }), let frame = growthFrame(candle, proxy) {
            GrowingCandle(candle: candle, frame: frame) {
              if growing == start { growing = nil }
            }
            .frame(width: plot.width, height: plot.height)
            .clipped()
            .offset(x: plot.minX, y: plot.minY)
          }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .id(start)
      }
    }
    .chartXAxis { timeAxis }
    .chartYAxis {
      // Coloured tags over the scale: the last price, entries and stops; a plain axis price
      // they would cover stays hidden.
      let tags = priceTags(scale)
      let shownAt = tags.map(\.shownAt)
      let clearance = labelClearance(scale)
      AxisMarks(position: .trailing) { value in
        AxisGridLine(stroke: StrokeStyle(lineWidth: Tokens.Stroke.hairline))
          .foregroundStyle(Palette.separator)
        AxisValueLabel {
          if let price = value.as(Double.self), AxisLabels.shows(price, tags: shownAt, clearance: clearance) {
            axisLabel(value, Palette.textQuaternary)
          }
        }
      }
      // Each tag is found by its own place on the scale, which no other tag shares.
      AxisMarks(position: .trailing, values: tags.map(\.shownAt)) { value in
        AxisValueLabel {
          if let place = value.as(Double.self), let tag = tags.first(where: { $0.shownAt == place }) {
            priceTag(tag)
          }
        }
      }
    }
    .modifier(Scrolling(window: window, domain: timeDomain, scroll: $viewport.scroll))
    .onGeometryChange(for: CGFloat.self, of: { $0.size.width }, action: { chartWidth = $0 })
    .chartXSelection(value: touch)
    // A tap lets a held candle go.
    .simultaneousGesture(TapGesture().onEnded { held = nil })
    .chartPlotStyle { $0.background(Palette.surfaceSunken) }
    .accessibilityLabel(Text(ChartText.title))
  }

  /// The volume bars, the candles or the close line, and the lines drawn over them.
  @ChartContentBuilder
  private func seriesMarks(_ scale: PriceScale) -> some ChartContent {
    if lines.volume {
      ForEach(series.candles) { candle in
        RectangleMark(
          xStart: .value(Plot.time, bodyStart(candle)),
          xEnd: .value(Plot.time, bodyEnd(candle)),
          yStart: .value(Plot.price, scale.volumeBase),
          yEnd: .value(Plot.price, scale.volumeTop(candle.volume)))
          // Extended hours' volume lighter than the regular session's (mockup v113).
          .foregroundStyle((candle.isUp ? Palette.candleUp : Palette.candleDown).opacity(
            Tokens.Opacity.faint * (candle.extended ? Tokens.Chart.extendedVolumeShare : 1)))
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
    if showsVWAP { lineMarks(.vwap, series.vwap, Palette.seriesVWAP) }
    if lines.fastEMA { lineMarks(.fastEMA, series.fastEMA, CandleChart.fastEMAColour) }
    if lines.slowEMA { lineMarks(.slowEMA, series.slowEMA, CandleChart.slowEMAColour) }
  }

  /// Closed trades' and the open position's levels and markers, and the strategy's event dots.
  @ChartContentBuilder
  private func markerMarks(_ scale: PriceScale) -> some ChartContent {
    let lifts = markerLifts(scale)
    ForEach(trades) { trade in
      tradeMarks(trade, lifts)
    }
    if let position {
      positionMarks(position, lifts)
    }
    ForEach(events) { event in
      if let lift = lifts[.event(event)] {
        eventMark(event, lift: lift)
      }
    }
  }

  /// The close as a line with a fill fading down to the volume bars, coloured by whether
  /// the stretch on screen ended above where it began.
  @ChartContentBuilder
  private func lineArea(_ scale: PriceScale) -> some ChartContent {
    let tint = visibleTrendUp ? Palette.candleUp : Palette.candleDown
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
  private func extremes(_ scale: PriceScale) -> some ChartContent {
    if let found = series.candles.extremes(in: visibleIndices) {
      let high = series.candles[found.high]
      let low = series.candles[found.low]
      // Beside its candle, on the side with more room, so a high or low near either edge of
      // the screen is never cut (the chart's own fit does not know the scrolled stretch).
      let highLeft = labelGoesLeft(high)
      let lowLeft = labelGoesLeft(low)
      // A high or low at a tagged price (the last close, an entry, a stop) is already named by
      // its tag: a second label there would lie over it.
      let tagged = priceTags(scale).map(\.shownAt)
      let clearance = tagClearance(scale)
      if !tagged.contains(where: { abs($0 - high.high) < clearance }) {
        PointMark(x: .value(Plot.time, middle(high)), y: .value(Plot.price, high.high))
          .symbolSize(0)
          .annotation(position: highLeft ? .leading : .trailing, spacing: Tokens.Space.xxs,
            overflowResolution: Self.keepInside) {
            extremeLabel(high.high, left: highLeft)
          }
      }
      if !tagged.contains(where: { abs($0 - low.low) < clearance }) {
        PointMark(x: .value(Plot.time, middle(low)), y: .value(Plot.price, low.low))
          .symbolSize(0)
          .annotation(position: lowLeft ? .leading : .trailing, spacing: Tokens.Space.xxs,
            overflowResolution: Self.keepInside) {
            extremeLabel(low.low, left: lowLeft)
          }
      }
    }
  }

  /// How close, in prices, an axis label may come to a tag before they overlap (`AxisLabels`):
  /// half a label's height and half a tag's, both grown with Dynamic Type.
  private func labelClearance(_ scale: PriceScale) -> Double {
    AxisLabels.clearance(labelHeight: Double(labelRoom), tagHeight: Double(tagRoom),
      span: scale.domain.upperBound - scale.domain.lowerBound, height: Double(Self.priceHeight))
  }

  /// The price span a tag covers on the scale: a high or low label this close to a tag hides
  /// under it.
  private func tagClearance(_ scale: PriceScale) -> Double {
    (scale.domain.upperBound - scale.domain.lowerBound) * Double(tagRoom) / Self.priceHeight
  }

  /// Whether a high or low label goes left of its candle: when the candle is in the right half
  /// of the screen.
  private func labelGoesLeft(_ candle: Candle) -> Bool {
    let shown = shownStretch
    let half = shown.lowerBound.addingTimeInterval(shown.upperBound.timeIntervalSince(shown.lowerBound) / 2)
    return middle(candle) > half
  }

  /// The price with a short leader pointing at its candle.
  private func extremeLabel(_ price: Double, left: Bool) -> some View {
    let leader = Rectangle()
      .fill(Palette.textTertiary)
      .frame(width: Self.extremeLeader, height: Tokens.Stroke.hairline)
    return HStack(spacing: Tokens.Space.xxs) {
      if left {
        Text(verbatim: Money.price(price))
        leader
      } else {
        leader
        Text(verbatim: Money.price(price))
      }
    }
    .font(Tokens.Typography.annotation)
    .foregroundStyle(Palette.textTertiary)
    .fixedSize()
  }

  /// The touched candle's slot, lightly lit behind it, in every pane.
  private func band(_ candle: Candle) -> some ChartContent {
    RectangleMark(xStart: .value(Plot.time, candle.start), xEnd: .value(Plot.time, candle.end))
      .foregroundStyle(Palette.textPrimary.opacity(Tokens.Opacity.wash))
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
              .foregroundStyle(Tone.result(Money.decimal(point.histogram)).fill.opacity(Tokens.Opacity.medium))
          }
        }
        lineMarks(.macd, studies.macd.map { $0?.macd }, Palette.info)
        lineMarks(.signal, studies.macd.map { $0?.signal }, Palette.warning)
        if let candle = selectedCandle {
          band(candle)
          crosshair(candle)
        }
      }
      .chartYScale(domain: macdDomain)
      .modifier(PaneAxes(marks: .automatic(desiredCount: Self.paneAxisMarks)))
      .modifier(Scrolling(window: window, domain: timeDomain, scroll: $viewport.scroll))
    case .stochastic:
      Chart {
        bands(high: Studies.stochasticHigh, low: Studies.stochasticLow)
        lineMarks(.stochasticK, studies.stochastic.map { $0?.k }, Palette.info)
        lineMarks(.stochasticD, studies.stochastic.map { $0?.d }, Palette.warning)
        if let candle = selectedCandle {
          band(candle)
          crosshair(candle)
        }
      }
      .chartYScale(domain: 0...(Studies.oscillatorScale * (1 + Self.legendHeadroom)))
      .modifier(PaneAxes(marks: .values([Studies.stochasticLow, Studies.stochasticHigh])))
      .modifier(Scrolling(window: window, domain: timeDomain, scroll: $viewport.scroll))
    case .rsi:
      Chart {
        bands(high: Studies.rsiHigh, low: Studies.rsiLow)
        lineMarks(.rsi, studies.rsi, Palette.info)
        if let candle = selectedCandle {
          band(candle)
          crosshair(candle)
        }
      }
      .chartYScale(domain: 0...(Studies.oscillatorScale * (1 + Self.legendHeadroom)))
      .modifier(PaneAxes(marks: .values([Studies.rsiLow, Studies.rsiHigh])))
      .modifier(Scrolling(window: window, domain: timeDomain, scroll: $viewport.scroll))
    case .atr:
      Chart {
        lineMarks(.atr, atr, Palette.seriesATR)
        if let candle = selectedCandle {
          band(candle)
          crosshair(candle)
        }
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
    if showsVWAP { items.append(LegendItem(name: ChartText.vwap, value: series.vwap[index], colour: Palette.seriesVWAP)) }
    if lines.fastEMA {
      items.append(LegendItem(name: ChartText.ema(Indicators.fastEMAPeriod), value: series.fastEMA[index],
        colour: CandleChart.fastEMAColour))
    }
    if lines.slowEMA {
      items.append(LegendItem(name: ChartText.ema(Indicators.slowEMAPeriod), value: series.slowEMA[index],
        colour: CandleChart.slowEMAColour))
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
            Text(verbatim: item.value.map(Money.value) ?? ChartFormat.missing)
          }
          .foregroundStyle(item.colour)
        }
      }
      .font(Tokens.Typography.annotation)
      .monospacedDigit()
      .padding(.top, Tokens.Space.xxs)
    }
  }

  // MARK: marks

  @ChartContentBuilder
  private func candleMarks(_ candle: Candle) -> some ChartContent {
    // A bar that has not grown in yet stands flat on its low, faded out.
    // A new bar not taken in yet, or growing in over the chart, is not drawn here.
    let shown = candle.start <= (grownThrough ?? .distantFuture) && candle.start != growing
    let height = { (price: Double) in shown ? price : candle.low }
    let colour = (candle.isUp ? Palette.candleUp : Palette.candleDown).opacity(shown ? 1 : 0)
    RuleMark(
      x: .value(Plot.time, middle(candle)),
      yStart: .value(Plot.price, candle.low),
      yEnd: .value(Plot.price, height(candle.high)))
      .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.thin))
      .foregroundStyle(colour)
    if candle.open == candle.close {
      RuleMark(
        xStart: .value(Plot.time, bodyStart(candle)),
        xEnd: .value(Plot.time, bodyEnd(candle)),
        y: .value(Plot.price, height(candle.close)))
        .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.regular))
        .foregroundStyle(colour)
    } else {
      RectangleMark(
        xStart: .value(Plot.time, bodyStart(candle)),
        xEnd: .value(Plot.time, bodyEnd(candle)),
        yStart: .value(Plot.price, height(candle.open)),
        yEnd: .value(Plot.price, height(candle.close)))
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
  /// A trade's entry and stop lines, and its entry and exit markers where they are on screen.
  @ChartContentBuilder
  private func tradeMarks(_ trade: DayTrade, _ lifts: [MarkerID: Int]) -> some ChartContent {
    let entry = ChartFormat.double(trade.entryPrice)
    let exit = ChartFormat.double(trade.exitPrice)
    levelLines(entry: entry, stop: trade.stopPrice.map(ChartFormat.double))
    if let lift = lifts[.entry(trade.tradeId)] {
      PointMark(
        x: .value(Plot.time, times.drawn(trade.openedAt.date) ?? trade.openedAt.date),
        y: .value(Plot.entry, entry))
        .symbol { marker(Image(systemName: "arrowtriangle.up.fill"), Palette.info, lift: lift) }
    }
    if let lift = lifts[.exit(trade.tradeId)] {
      PointMark(
        x: .value(Plot.time, times.drawn(trade.closedAt.date) ?? trade.closedAt.date),
        y: .value(Plot.exit, exit))
        .symbol {
          marker(Image(systemName: "arrowtriangle.down.fill"), Palette.result(trade.resultUsd.value), lift: lift)
        }
    }
  }

  /// The open position's entry and stop, with the entry marked at its time when it is on screen.
  @ChartContentBuilder
  private func positionMarks(_ position: Position, _ lifts: [MarkerID: Int]) -> some ChartContent {
    let entry = ChartFormat.double(position.entryPrice)
    levelLines(entry: entry, stop: position.stop.price.map(ChartFormat.double),
      protected: position.stop.state.isProtected)
    if let lift = lifts[.position] {
      PointMark(
        x: .value(Plot.time, times.drawn(position.openedAt.date) ?? position.openedAt.date),
        y: .value(Plot.entry, entry))
        .symbol { marker(Image(systemName: "arrowtriangle.up.fill"), Palette.info, lift: lift) }
    }
  }

  /// A round marker on the price pane.
  enum MarkerID: Hashable, Sendable {
    /// A closed trade's entry and exit, by its trade id.
    case entry(String)
    case exit(String)
    /// The open position's entry.
    case position
    case event(ChartEvent)
  }

  /// How many steps each marker on screen is moved (up when positive) so none covers another
  /// (`ChartMarkerLayout`); a marker missing here is off screen and not drawn.
  private func markerLifts(_ scale: PriceScale) -> [MarkerID: Int] {
    var markers: [ChartMarkerLayout.Marker<MarkerID>] = []
    // At their drawn times (the candles sit back to back); one before the first candle is off it.
    // Entries and exits state a price, so they are pinned there: the strategy's marks move instead.
    for trade in trades {
      if let at = times.drawn(trade.openedAt.date) {
        markers.append(.init(id: .entry(trade.tradeId), time: at, price: ChartFormat.double(trade.entryPrice),
          pinned: true))
      }
      if let at = times.drawn(trade.closedAt.date) {
        markers.append(.init(id: .exit(trade.tradeId), time: at, price: ChartFormat.double(trade.exitPrice),
          pinned: true))
      }
    }
    if let position, let at = times.drawn(position.openedAt.date) {
      markers.append(.init(id: .position, time: at, price: ChartFormat.double(position.entryPrice), pinned: true))
    }
    for event in events {
      markers.append(.init(id: .event(event), time: eventTime(event), price: event.price))
    }
    let span = scale.domain.upperBound - scale.domain.lowerBound
    let plot = max(chartWidth - axisWidth, 0)
    let layout = ChartMarkerLayout.Scale(
      shown: shownStretch,
      prices: scale.domain,
      pointsPerSecond: window > 0 ? Double(plot) / window : 0,
      pointsPerPrice: span > 0 ? Double(Self.priceHeight) / span : 0,
      side: Double(Self.markerSide), step: Double(Self.markerStep))
    return ChartMarkerLayout.place(markers, scale: layout)
  }

  /// Where a watch, entry or refused mark sits: the middle of its candle.
  private func eventTime(_ event: ChartEvent) -> Date {
    event.candle.addingTimeInterval(series.timeframe.seconds / 2)
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
  /// refused an entry (grey), moved `lift` steps (up when positive) clear of the markers before it.
  private func eventMark(_ event: ChartEvent, lift: Int) -> some ChartContent {
    PointMark(
      x: .value(Plot.time, eventTime(event)),
      y: .value(Plot.price, event.price))
      .symbol {
        Circle()
          .fill(Self.colour(event.kind))
          .frame(width: Self.markerSide, height: Self.markerSide)
          .offset(y: -CGFloat(lift) * Self.markerStep)
      }
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
    /// Where on the scale the tag is drawn: at `price`, or pinned to the top or bottom edge of
    /// the price area when `price` is off it, and pushed clear of the other tags
    /// (`PriceTagPlacement`). No two tags share it.
    let shownAt: Double
  }

  /// The last close, then the open position's stop and entry, then each trade's stop and entry,
  /// latest opened first: the order in which tags are kept when the price area is too short for
  /// all of them. Placed inside the price area of `scale` and apart from each other; a tag that
  /// does not fit is left out.
  private func priceTags(_ scale: PriceScale) -> [PriceTag] {
    var tags: [(price: Double, fill: Color)] = []
    if let last = series.candles.last {
      tags.append((livePrice ?? last.close, last.isUp ? Palette.candleUp : Palette.candleDown))
    }
    var levels = trades.sorted { $0.openedAt.date > $1.openedAt.date }.map {
      (ChartFormat.double($0.entryPrice), $0.stopPrice.map(ChartFormat.double), true)
    }
    if let position {
      levels.insert((ChartFormat.double(position.entryPrice), position.stop.price.map(ChartFormat.double),
        position.stop.state.isProtected), at: 0)
    }
    for (entry, stop, protected) in levels {
      if let stop { tags.append((stop, Self.stopColour(protected: protected))) }
      tags.append((entry, Palette.info))
    }
    // The price area is above the volume bars; half a tag's room keeps the whole tag inside it
    // and a whole one keeps two tags apart.
    let area = (scale.volumeBase + scale.volumeHeight)...scale.domain.upperBound
    let shown = PriceTagPlacement.positions(of: tags.map(\.price), in: area, halfHeight: tagClearance(scale) / 2)
    return zip(tags, shown).compactMap { tag, place in
      place.map { PriceTag(price: tag.price, fill: tag.fill, shownAt: $0) }
    }
  }

  private func priceTag(_ tag: PriceTag) -> some View {
    Text(verbatim: Money.price(tag.price))
      .font(Tokens.Typography.annotationBold)
      .foregroundStyle(Palette.surface)
      .padding(.horizontal, Tokens.Space.xxs)
      .frame(width: axisWidth, alignment: .leading)
      .background(tag.fill, in: RoundedRectangle(cornerRadius: Tokens.Radius.small))
  }

  /// An entry or exit marker, moved `lift` steps (up when positive) clear of the markers before it.
  private func marker(_ image: Image, _ colour: Color, lift: Int) -> some View {
    image
      .font(Tokens.Typography.chevron)
      .foregroundStyle(Palette.onAccent)
      .frame(width: Self.markerSide, height: Self.markerSide)
      .background(colour, in: Circle())
      .offset(y: -CGFloat(lift) * Self.markerStep)
  }

  /// Day and 5D: the session labels ("Pre 04:00", "09:30", "16:00", "After 20:00"; a day's name
  /// over five days) and round clock times between them (mockup v113); a month or longer: where
  /// each week, month or quarter begins. A label near either end hangs inward, never cut.
  @AxisContentBuilder private var timeAxis: some AxisContent {
    let marks = axisMarks
    let shown = shownStretch
    let byTime = Dictionary(marks.map { ($0.time, $0) }, uniquingKeysWith: { first, _ in first })
    AxisMarks(values: marks.map(\.time)) { value in
      // Looked up by time, never by position: a mark Charts leaves out must not shift the
      // labels after it onto the wrong candles.
      let mark = value.as(Date.self).flatMap { byTime[$0] }
      // A session's start has its dashed boundary instead of a gridline.
      if mark?.strong != true || times.sessions == nil {
        AxisGridLine(stroke: StrokeStyle(lineWidth: Tokens.Stroke.hairline))
          .foregroundStyle(Palette.separator)
      }
      if let placed = mark?.anchor {
        // A session axis's label, moved by its offset to where `AxisLabelPlacer` put it: Charts
        // hangs a trailing label's right edge from its tick and every other label's left edge.
        AxisValueLabel(
          centered: false, anchor: placed == .trailing ? .topTrailing : .topLeading,
          collisionResolution: .disabled, horizontalSpacing: 0
        ) {
          Text(verbatim: mark?.text ?? ChartFormat.missing)
            .font(Tokens.Chart.sessionAxisLabel)
            .foregroundStyle(mark?.strong == true ? Palette.textTertiary : Palette.textQuaternary)
            .fixedSize()
            .offset(x: mark?.offset ?? 0)
        }
      } else {
        AxisValueLabel(anchor: Self.unitPoint(mark.map { ChartAxis.anchor(of: $0.time, shown: shown) } ?? .centre)) {
          Text(verbatim: mark?.text ?? ChartFormat.missing)
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textQuaternary)
            .fixedSize()
        }
      }
    }
  }

  /// The labelled times on screen: on Day and 5D the session axis's labels, placed in order so
  /// none overlaps another; beyond them the range's own boundaries, none closer than a label's
  /// width and none outside the stretch on screen (a label just past the left edge hung back
  /// into it, cut: "L3:50").
  private var axisMarks: [ChartAxisLabel] {
    let shown = shownStretch
    let plot = chartWidth - axisWidth
    if let sessions = times.sessions {
      guard plot > 0, window > 0 else { return [] }
      return sessionLabels(sessions, shown: shown, plot: Double(plot))
    }
    let inside = times.marks.filter { shown.contains($0.time) }
    guard plot > 0 else { return inside }
    let gap = window * Double(labelSlot / plot)
    return ChartAxis.spaced(inside.map(\.time), gap: gap, shown: shown, preferred: { inside[$0].major })
      .map { inside[$0] }
  }

  /// The session axis's labels across a plot `plot` points wide: sessions first, then the end,
  /// then round times at least `Tokens.Chart.hourLabelSpacing` apart, each `axisLabelGap` from
  /// the next and `axisLabelInset` in from the edges; a session label too wide takes its short
  /// form (mockup v113, "Collisions").
  private func sessionLabels(_ sessions: SessionAxis, shown: ClosedRange<Date>, plot: Double) -> [ChartAxisLabel] {
    let perSecond = plot / window
    let step = SessionAxis.hourStep(
      timeframe: series.timeframe, pointsPerSlot: series.timeframe.seconds * perSecond,
      least: Double(Tokens.Chart.hourLabelSpacing))
    let labels = sessions.labels(range: times.range, candles: times.realCandles, extendedClose: times.extendedClose,
      hourStep: step)
    let font = UIFont.monospacedSystemFont(ofSize: Tokens.Chart.sessionAxisLabelSize, weight: .regular)
    let texts = labels.map { SessionAxisText.texts($0.kind, dayName: { $0.formatted(ChartFormat.sessionDay) }) }
    var items: [AxisLabelPlacer.Item] = []
    for (label, forms) in zip(labels, texts) {
      let time = times.slotTime(label.slot) ?? shown.lowerBound
      items.append(AxisLabelPlacer.Item(
        x: time.timeIntervalSince(shown.lowerBound) * perSecond,
        widths: forms.map { Double(($0 as NSString).size(withAttributes: [.font: font]).width) }, anchor: label.anchor,
        required: SessionAxisText.isSession(label.kind)))
    }
    return AxisLabelPlacer.place(
      items, width: plot, gap: Double(Tokens.Chart.axisLabelGap), inset: Double(Tokens.Chart.axisLabelInset)
    ).compactMap { placed in
      let label = labels[placed.item]
      guard let time = times.slotTime(label.slot) else { return nil }
      let item = items[placed.item]
      let edge = label.anchor == .trailing ? placed.left + item.widths[placed.text] : placed.left
      return ChartAxisLabel(
        time: time, text: texts[placed.item][placed.text], strong: SessionAxisText.isSession(label.kind),
        anchor: label.anchor, offset: CGFloat(edge - item.x))
    }
  }

  /// The extended-hours bands behind the candles (pre-market and after-hours, a `textPrimary`
  /// tint) with their "PRE" / "AFTER" captions where the band is wide enough, and the dashed
  /// boundaries between the parts of the day (mockup v113).
  @ChartContentBuilder
  private func sessionMarks(_ scale: PriceScale) -> some ChartContent {
    ForEach(sessionBands) { band in
      RectangleMark(
        xStart: .value(Plot.time, band.start), xEnd: .value(Plot.time, band.end),
        yStart: .value(Plot.price, scale.domain.lowerBound), yEnd: .value(Plot.price, scale.domain.upperBound))
        .foregroundStyle(Palette.textPrimary.opacity(Tokens.Chart.extendedBandOpacity(colorScheme)))
        .annotation(position: .overlay, alignment: .topLeading) {
          if let caption = band.caption, fits(caption, from: band.start, to: band.end) {
            Text(caption)
              .font(Tokens.Chart.bandCaption)
              .tracking(Tokens.Chart.bandCaptionSize * Tokens.Chart.bandCaptionTracking)
              .foregroundStyle(Palette.textQuaternary)
              .padding(Tokens.Chart.bandCaptionInset)
              .fixedSize()
          }
        }
    }
    ForEach(sessionBoundaries, id: \.self) { time in
      RuleMark(x: .value(Plot.time, time))
        .foregroundStyle(Palette.textQuaternary.opacity(Tokens.Chart.sessionBoundaryOpacity))
        .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.thin, dash: Tokens.Stroke.dashFine))
    }
  }

  /// The bands of the extended hours, at drawn times.
  private var sessionBands: [SessionBand] {
    (times.sessions?.bands ?? []).compactMap { band in
      guard let start = times.slotTime(band.segment.first), let end = times.slotTime(band.end) else { return nil }
      return SessionBand(
        start: start, end: end, caption: SessionAxisText.caption(band.segment.session).map { String(localized: $0) })
    }
  }

  /// Where the parts of the day meet, at drawn times; none at the chart's left edge.
  private var sessionBoundaries: [Date] { (times.sessions?.boundaries ?? []).compactMap(times.slotTime) }

  /// Whether a band's caption fits inside it on screen, with its inset on both sides.
  private func fits(_ caption: String, from start: Date, to end: Date) -> Bool {
    let plot = Double(chartWidth - axisWidth)
    guard plot > 0, window > 0 else { return false }
    let font = UIFont.monospacedSystemFont(ofSize: Tokens.Chart.bandCaptionSize, weight: .semibold)
    let width = (caption as NSString).size(withAttributes: [
      .font: font, .kern: Tokens.Chart.bandCaptionSize * Tokens.Chart.bandCaptionTracking,
    ]).width
    let room = width + Tokens.Chart.bandCaptionInset + Tokens.Chart.bandCaptionInset
    return plot * end.timeIntervalSince(start) / window >= Double(room)
  }

  /// Where a time label's top hangs from its tick.
  private static func unitPoint(_ anchor: ChartAxis.Anchor) -> UnitPoint {
    switch anchor {
    case .leading: .topLeading
    case .centre: .top
    case .trailing: .topTrailing
    }
  }

  /// A scale label of fixed width (see `axisLabelWidth`).
  private func axisLabel(_ value: AxisValue, _ colour: Color) -> some View {
    Text(value.as(Double.self).map { Money.price($0) } ?? String())
      .font(Tokens.Typography.annotation)
      .foregroundStyle(colour)
      .frame(width: axisWidth, alignment: .leading)
  }

  // MARK: readout and zoom

  /// Pinch: spread to zoom in, pinch to zoom out down to the whole range, as the − and + do.
  private var pinch: some Gesture {
    MagnifyGesture()
      .onChanged { value in
        let start = pinchStart ?? viewport
        pinchStart = start
        var zoomed = start
        zoomed.zoom(to: start.visible / value.magnification, keeping: value.startAnchor.x, series)
        viewport = zoomed
      }
      .onEnded { _ in pinchStart = nil }
  }

  @ViewBuilder
  private var readout: some View {
    if let candle = selectedCandle {
      HStack(spacing: Tokens.Space.s) {
        Text(ChartText.readout(
          Money.price(candle.open), Money.price(candle.high), Money.price(candle.low), Money.price(candle.close),
          Volume.compact(candle.volume)))
        if let index = legendIndex, let change = series.candles.change(at: index) {
          Text(verbatim: Percent.signed(fraction: change.fraction))
            .foregroundStyle(Palette.result(Money.decimal(change.amount)))
        }
      }
    } else {
      Text(ChartText.caption(String(localized: rangeTitle), String(localized: ChartFormat.title(series.timeframe)),
        String(localized: ChartText.bars(viewport.barsShown(series)))))
    }
  }

  // MARK: geometry

  /// The drawn time from the first candle's start to the last one's end, or on today's Day chart
  /// to the extended close, the rest of the day kept empty (mockup v113).
  private var timeDomain: ClosedRange<Date> {
    guard let first = series.candles.first, let last = series.candles.last else { return Date.now...Date.now }
    return first.start...(times.reservedEnd ?? last.end)
  }

  /// Seconds of the day on screen.
  private var window: TimeInterval { viewport.window(series) }

  /// The stretch of time on screen.
  private var shownStretch: ClosedRange<Date> {
    let start = max(viewport.scroll, timeDomain.lowerBound)
    return start...start.addingTimeInterval(window)
  }

  /// VWAP is a session's line: drawn on intraday candles only.
  private var showsVWAP: Bool { lines.vwap && series.timeframe.isIntraday }

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

  /// Prices of the candles on screen, the open position's entry and stop and every line drawn
  /// over them (Bollinger bands, moving averages, VWAP, EMAs), so no line runs off the plot, with
  /// a little room above and below and room under them for the volume bars.
  private var priceScale: PriceScale {
    let shown = visibleIndices
    let candles = series.candles[shown]
    var drawn: [[Double?]] = []
    if lines.bollinger {
      drawn += [studies.bollinger.map { $0?.lower }, studies.bollinger.map { $0?.upper }]
    }
    if lines.movingAverages { drawn += studies.movingAverages }
    if showsVWAP { drawn.append(series.vwap) }
    if lines.fastEMA { drawn.append(series.fastEMA) }
    if lines.slowEMA { drawn.append(series.slowEMA) }
    let levels = [position?.entryPrice, position?.stop.price].compactMap { $0.map(ChartFormat.double) }
    let span = ChartPriceSpan.bounds(of: series.candles, shown: shown, lines: drawn, levels: levels)
    let low = span?.lowerBound ?? 0
    let high = span?.upperBound ?? 1
    let pad = max(high - low, high * Tokens.Chart.pricePadding) * Tokens.Chart.pricePadding
    let volumeHeight = lines.volume ? (high - low + pad + pad) * Tokens.Chart.volumeShare : 0
    let bottom = low - pad - volumeHeight
    return PriceScale(
      domain: bottom...(high + pad), volumeBase: bottom, volumeHeight: volumeHeight,
      volumeCeiling: candles.map(\.volume).max() ?? 0)
  }

  /// Where `candle` stands in the plot, in points from its top left: its body's left and right,
  /// and the prices of its high, open, close and low.
  private func growthFrame(_ candle: Candle, _ proxy: ChartProxy) -> GrowingCandle.Frame? {
    guard let left = proxy.position(forX: bodyStart(candle)), let right = proxy.position(forX: bodyEnd(candle)),
      let high = proxy.position(forY: candle.high), let low = proxy.position(forY: candle.low),
      let open = proxy.position(forY: candle.open), let close = proxy.position(forY: candle.close) else { return nil }
    return GrowingCandle.Frame(left: left, right: right, high: high, open: open, close: close, low: low)
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
/// A new minute bar growing up from its low to its full height once, over the chart where its
/// mark will be (the board's `grow`: scale from nothing, fading in, `Motion.standard`); then it
/// calls `done` and the chart draws the bar itself.
private struct GrowingCandle: View {
  /// The candle's place in the plot, in points.
  struct Frame {
    let left: CGFloat
    let right: CGFloat
    let high: CGFloat
    let open: CGFloat
    let close: CGFloat
    let low: CGFloat
  }

  @State private var grown = false
  let candle: Candle
  let frame: Frame
  let done: () -> Void

  var body: some View {
    let colour = candle.isUp ? Palette.candleUp : Palette.candleDown
    let middle = (frame.left + frame.right) / 2
    let top = min(frame.open, frame.close)
    let isGrown = grown
    ZStack(alignment: .topLeading) {
      Rectangle()
        .fill(colour)
        .frame(width: Tokens.Stroke.thin, height: max(frame.low - frame.high, Tokens.Stroke.thin))
        .offset(x: middle - Tokens.Stroke.thin / 2, y: frame.high)
      Rectangle()
        .fill(colour)
        .frame(width: frame.right - frame.left, height: max(abs(frame.close - frame.open), Tokens.Stroke.regular))
        .offset(x: frame.left, y: top)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    // Drawn as a scale, not in layout: Core Animation plays it.
    .visualEffect { effect, proxy in
      effect
        .scaleEffect(x: 1, y: isGrown ? 1 : PopIn.hiddenScale,
          anchor: UnitPoint(x: middle / max(proxy.size.width, 1), y: frame.low / max(proxy.size.height, 1)))
        .opacity(isGrown ? 1 : 0)
    }
    .onAppear {
      withAnimation(Tokens.Motion.standard) { grown = true } completion: { done() }
    }
  }
}

/// What tells a new bar from another chart: the interval, the first candle and the newest one.
private struct GrowthKey: Equatable {
  let timeframe: Timeframe
  let first: Date?
  let last: Date?
}

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
      Text(value.as(Double.self).map(Money.value) ?? String())
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
        .frame(width: axisWidth, alignment: .leading)
    }
  }
}

/// An extended-hours band at drawn times, with its caption.
private struct SessionBand: Identifiable {
  let start: Date
  let end: Date
  let caption: String?

  var id: Date { start }
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
  static let missing = Format.missing
  /// Between the parts of a check: measured, operator, threshold.
  static let space = " "
  /// Between a candle's time and its part of the day in the readout ("19:50 · after").
  static let separator = " · "
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
