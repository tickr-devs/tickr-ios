import Charts
import SwiftUI
import TickrDesign
import TickrKit

/// The price pane (candles or a filled line, the bot's lines and the chosen studies, with their
/// values in its top left corner) and the volume and study panes below it, which scroll, zoom and
/// point together. One
/// crosshair runs through every pane, with the pointed time on the time axis and the value under
/// the pointer on the hovered pane's value axis. Times read in New York, like the bot.
struct CandleChart: View {
  let plot: ChartPlot
  let lines: ChartLines
  let marks: [ChartMark]
  let levels: [ChartLevel]
  let decisions: [DecisionMark]
  let live: Bool
  /// The live bid of the symbol (GET /quotes) while the live day is shown: the price tag sits at it
  /// instead of the last closed candle's close, as the price above the chart does.
  var livePrice: Double?
  @Binding var viewport: Viewport
  /// The candle under the pointer, shared with the screen's header readout and the explain card.
  let pointer: ChartPointer

  /// The pointer state, for the shared axis and crosshair of every pane.
  var pointerModel: ChartPointer { pointer }
  @State private var appeared = false
  /// The theme on screen: the extended-hours band is stronger in dark (mockup v114).
  @Environment(\.colorScheme) private var colorScheme
  /// How many time labels fit across the price pane, `timeLabelSlot` apart. Kept as a count, not
  /// the pane's width: during a window resize the width changed every frame and each change built
  /// the whole chart again, while the count changes only when a label more or fewer fits.
  @State private var labelSlots = 0
  /// Width of the price pane's plot area, in whole points, for placing the session axis's labels
  /// and the bands' captions (mockup v113).
  @State private var plotWidth: CGFloat = 0
  @State private var pinchStart: Int?
  /// The price pane's height, in points: where the tags sit on its axis, so the axis's own
  /// labels they would cover give way (`AxisLabels`).
  @State private var priceHeight: CGFloat = 0

  /// Most decisions on screen that are labelled; with more, only their diamonds are drawn, and
  /// the labels no longer pile up over the candles.
  static let decisionLabelLimit = 3
  /// Share of a candle's slot its body fills; the rest is the gap between candles.
  static let bodyShare = 0.66
  /// Smallest price range drawn, as a share of the price, so a flat stretch is not a line.
  static let minimumSpan = 0.0005
  /// Width of every pane's value labels, in points: one width keeps the panes' plot areas, and so
  /// their candles and crosshairs, lined up.
  nonisolated static let axisLabelWidth: CGFloat = 56
  /// Gridlines each pane asks for on its value axis.
  static let priceTicks = 6
  /// Share of the price pane's height kept free of axis labels at its bottom (the lowest hung
  /// over the pane below), and within which a high or low beside a plate is left out.
  static let tagClearance = 0.05
  static let paneTicks = 3
  /// Share of a study pane's value range kept free of scale labels at its top and bottom: a
  /// label there hung over the pane above or below ("2.00" on the volume, "-2.00" on the RSI
  /// title).
  static let paneEdgeShare = 0.15
  /// Length of the leader line of the high and low labels on the price axis, in points.
  static let extremeLeader: CGFloat = 6
  /// Symbols of entry and exit marks.
  static let entrySymbol = "arrowtriangle.up.fill"
  static let exitSymbol = "arrowtriangle.down.fill"
  /// Symbols of decision marks: one the strategy acted on, and one that did not trade.
  static let decisionSymbol = "diamond.fill"
  static let observerSymbol = "diamond"
  /// Candles drawn beyond each side of the window while zoomed, as a share of the window, so a
  /// fast scroll never shows a bare edge before the next redraw. Farther candles are not drawn.
  static let drawnMargin = 1.0
  /// Width a range's time label needs with a gap to the next, in points: labels closer than
  /// this are left out ("Mon 9Tue 10").
  nonisolated static let timeLabelSlot: CGFloat = 64
  /// Annotations near an edge move inside the chart instead of being cut off.
  static let keepInside = AnnotationOverflowResolution(x: .fit(to: .plot), y: .fit(to: .plot))
  /// Least distance between the centres of two tags on a value axis, in points: closer tags are
  /// moved apart so none covers another ("Entry 29.55" over the last price).
  static let tagSpacing: CGFloat = 18
  /// Colours of the moving-average lines, in the order of `Studies.movingAveragePeriods`.
  static let movingAverageColors = [Palette.info, Palette.warning, Palette.highlight]

  private var series: ChartSeries { plot.series }
  private var candles: [Candle] { plot.candles }

  /// The panes below the price pane, top to bottom.
  private var studyPanes: [ChartPane] {
    [
      lines.volume ? .volume : nil, lines.macd ? .macd : nil, lines.rsi ? .rsi : nil,
      lines.stochastic ? .stochastic : nil, lines.atr ? .atr : nil,
    ]
    .compactMap { $0 }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      PaneStack {
        // The legend in its own row above the plot, never over it: the marks' plates are kept
        // inside the plot, so a plate near the top ("ENTER · OBSERVER") can no longer sit on the
        // lines' values.
        VStack(alignment: .leading, spacing: 0) {
          ChartLegend(plot: plot, lines: lines, pointer: pointer)
            .padding([.horizontal, .top], Tokens.Space.s)
          priceChart
        }
        ForEach(studyPanes, id: \.self) { pane in
          studyChart(pane)
            .overlay(alignment: .top) {
              Rectangle().fill(Palette.separator).frame(height: Tokens.Stroke.hairline)
            }
            .overlay(alignment: .topLeading) { paneName(pane) }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
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

  // MARK: Price pane

  private var priceChart: some View {
    let scale = priceScale
    return Chart {
      sessionMarks(span: scale, captions: true)
      if lines.style == .line {
        lineArea(scale)
      } else {
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
            .foregroundStyle(candle.isUp ? Palette.candleUpBody : Palette.candleDown)
        }
      }
      if lines.bollinger {
        line(plot.bollingerUpper, name: Plot.bollingerUpper, color: Palette.accent.opacity(Tokens.Opacity.medium))
        line(plot.bollingerMiddle, name: Plot.bollingerMiddle, color: Palette.accent)
        line(plot.bollingerLower, name: Plot.bollingerLower, color: Palette.accent.opacity(Tokens.Opacity.medium))
      }
      if lines.movingAverages {
        ForEach(Array(plot.movingAverages.enumerated()), id: \.offset) { item in
          line(item.element, name: Plot.movingAverages[item.offset], color: Self.movingAverageColors[item.offset])
        }
      }
      if lines.vwap { line(plot.series.vwap, name: Plot.vwap, color: Palette.seriesVWAP) }
      if lines.fastEMA { line(series.fastEMA, name: Plot.fastEMA, color: Palette.seriesFastEMA) }
      if lines.slowEMA { line(series.slowEMA, name: Plot.slowEMA, color: Palette.seriesSlowEMA) }
      ForEach(levels) { level in
        RuleMark(
          xStart: .value(Plot.time, max(level.since, windowStart)),
          xEnd: .value(Plot.time, lastEnd),
          y: .value(Plot.price, level.price))
          .foregroundStyle(level.color)
          .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.thin, dash: Tokens.Stroke.dash))
          // Where the line begins on screen (the entry, or the left edge), on a plate so candles
          // under it never hide it; at the right end it ran into the price tags on the scale.
          .annotation(position: .top, alignment: .leading, overflowResolution: Self.keepInside) {
            Text(level.label)
              .font(Tokens.Typography.annotationBold)
              .foregroundStyle(level.textColor)
              .padding(.horizontal, Tokens.Space.xxs)
              .background(Palette.surface.opacity(Tokens.Opacity.overlay), in: .rect(cornerRadius: Tokens.Radius.small))
              .fixedSize()
          }
      }
      ForEach(marks) { mark in
        PointMark(x: .value(Plot.time, mark.time), y: .value(Plot.price, mark.price))
          .symbol {
            Image(systemName: mark.kind == .entry ? Self.entrySymbol : Self.exitSymbol)
              .font(Tokens.Typography.annotation)
              .foregroundStyle(mark.color)
          }
          .annotation(position: mark.kind == .entry ? .bottom : .top, overflowResolution: Self.keepInside) {
            MarkPlate(text: mark.label, color: mark.color, textColor: mark.textColor)
          }
      }
      ForEach(decisions) { mark in
        PointMark(x: .value(Plot.time, mark.time), y: .value(Plot.price, mark.price))
          .symbol {
            Image(systemName: mark.hollow ? Self.observerSymbol : Self.decisionSymbol)
              .font(Tokens.Typography.annotation)
              .foregroundStyle(mark.color)
          }
          .annotation(position: .top, overflowResolution: Self.keepInside) {
            if labelsDecisions {
              MarkPlate(text: mark.label, color: mark.color, textColor: mark.color)
            }
          }
      }
      if let last = candles.last {
        RuleMark(y: .value(Plot.price, last.close))
          .foregroundStyle(color(last).opacity(live ? Tokens.Opacity.border : Tokens.Opacity.faint))
          .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.hairline, dash: Tokens.Stroke.dashFine))
      }
    }
    .chartYScale(domain: scale)
    .chartYAxis {
      valueAxis(ticks: Self.priceTicks, hiding: shownTagValues(span: scale), span: scale)
    }
    .chartXAxis { timeAxis(labels: studyPanes.isEmpty) }
    .modifier(SharedAxis(chart: self, pane: .price, showsTime: studyPanes.isEmpty, tags: priceTags))
    .onGeometryChange(for: Int.self, of: { Self.slotCount(chartWidth: $0.size.width) }, action: { labelSlots = $0 })
    .onGeometryChange(for: CGFloat.self, of: { max($0.size.width - Self.axisLabelWidth, 0).rounded(.down) },
      action: { plotWidth = $0 })
    .onGeometryChange(for: CGFloat.self, of: { $0.size.height }, action: { priceHeight = $0 })
  }

  /// Where the price tags are drawn on the axis, in prices: placed apart as `AxisTags` draws
  /// them (`AxisLabels.placed`), a high or low beside a plate left out.
  private func shownTagValues(span: ClosedRange<Double>) -> [Double] {
    let tags = priceTags
    let range = span.upperBound - span.lowerBound
    guard priceHeight > 0, range > 0 else { return tags.map(\.value) }
    let perPoint = range / Double(priceHeight)
    let placed = AxisLabels.placed(
      tags.map { AxisLabels.Tag(y: (span.upperBound - $0.value) / perPoint, plain: $0.plain) },
      spacing: Double(Self.tagSpacing))
    return placed.compactMap { $0.map { span.upperBound - $0 * perPoint } }
  }

  /// The close as a line with a fill fading down to the bottom of the pane, coloured by whether
  /// the visible stretch ended above where it began.
  @ChartContentBuilder private func lineArea(_ scale: ClosedRange<Double>) -> some ChartContent {
    let tint = visibleTrendUp ? Palette.candleUp : Palette.candleDown
    ForEach(candles[drawn]) { candle in
      AreaMark(
        x: .value(Plot.time, candle.middle),
        yStart: .value(Plot.price, scale.lowerBound),
        yEnd: .value(Plot.price, candle.close))
        .foregroundStyle(
          LinearGradient(
            colors: [tint.opacity(Tokens.Opacity.faint), tint.opacity(Tokens.Opacity.wash)],
            startPoint: .top, endPoint: .bottom))
      LineMark(
        x: .value(Plot.time, candle.middle),
        y: .value(Plot.price, candle.close),
        series: .value(Plot.series, Plot.close))
        .foregroundStyle(tint)
        .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.regular))
    }
  }

  /// The last close, tagged on the price axis in the colour of its candle, the position's
  /// levels, and the highest high and lowest low on screen ("H 13.32", plain, as in the design).
  private var priceTags: [AxisTag] {
    var tags = levels.map { AxisTag(value: $0.price, text: Money.price($0.price), color: $0.color) }
    if let last = candles.last {
      let price = livePrice ?? last.close
      tags.append(AxisTag(value: price, text: Money.price(price), color: color(last)))
    }
    // A high or low next to a plate (the last price at the day's high) would sit under it.
    let span = priceScale
    let clearance = (span.upperBound - span.lowerBound) * Self.tagClearance
    let extremes = Self.extremeTags(candles, in: visibleIndices).filter { extreme in
      !tags.contains { abs($0.value - extreme.value) < clearance }
    }
    return tags + extremes
  }

  /// "H 13.32" at the highest high and "L 11.78" at the lowest low of the candles in `range`, as
  /// plain tags on the price axis (out of the way of the legend in the plot's top left corner).
  static func extremeTags(_ candles: [Candle], in range: Range<Int>) -> [AxisTag] {
    guard let found = candles.extremes(in: range) else { return [] }
    let high = candles[found.high].high
    let low = candles[found.low].low
    let tags = [
      AxisTag(value: high, text: String(localized: L10n.Chart.highTag(Money.price(high))), color: Palette.textTertiary,
        plain: true),
      AxisTag(value: low, text: String(localized: L10n.Chart.lowTag(Money.price(low))), color: Palette.textTertiary,
        plain: true),
    ]
    // A flat stretch has one price: one tag.
    return high == low ? [tags[0]] : tags
  }

  // MARK: Study panes

  @ViewBuilder private func studyChart(_ pane: ChartPane) -> some View {
    let bottom = pane == studyPanes.last
    switch pane {
    case .volume:
      let span = volumeSpan
      Chart {
        sessionMarks(span: span, captions: false)
        ForEach(candles[drawn]) { candle in
          RectangleMark(
            xStart: .value(Plot.time, bodyStart(candle)),
            xEnd: .value(Plot.time, bodyEnd(candle)),
            yStart: .value(Plot.volume, 0),
            yEnd: .value(Plot.volume, candle.volume))
            // Extended hours' volume lighter than the regular session's (mockup v113).
            .foregroundStyle(color(candle).opacity(
              Tokens.Opacity.faint * (candle.extended ? Tokens.Chart.extendedVolumeShare : 1)))
        }
        line(plot.volumeAverage, name: Plot.volumeAverage, color: Palette.warning)
      }
      .chartYScale(domain: span)
      .chartYAxis { volumeAxis(span: span) }
      .chartXAxis { timeAxis(labels: bottom) }
      .modifier(SharedAxis(chart: self, pane: pane, showsTime: bottom, tags: []))
    case .macd:
      Chart {
        ForEach(drawn, id: \.self) { index in
          if let value = plot.macdHistogram[index] {
            BarMark(
              xStart: .value(Plot.time, bodyStart(candles[index])),
              xEnd: .value(Plot.time, bodyEnd(candles[index])),
              y: .value(Plot.price, value))
              .foregroundStyle(Tone.result(Money.decimal(value)).fill.opacity(Tokens.Opacity.medium))
          }
        }
        line(plot.macd, name: Plot.macd, color: Palette.info)
        line(plot.macdSignal, name: Plot.macdSignal, color: Palette.warning)
      }
      .chartYScale(domain: paneSpan([plot.macd, plot.macdSignal, plot.macdHistogram]))
      .chartYAxis { valueAxis(ticks: Self.paneTicks, span: paneSpan([plot.macd, plot.macdSignal, plot.macdHistogram])) }
      .chartXAxis { timeAxis(labels: bottom) }
      .modifier(SharedAxis(chart: self, pane: pane, showsTime: bottom, tags: []))
      .overlay { waiting(plot.macd) }
    case .rsi:
      Chart {
        bands(high: Studies.rsiHigh, low: Studies.rsiLow)
        line(plot.rsi, name: Plot.rsi, color: Palette.info)
      }
      .chartYScale(domain: 0...Studies.oscillatorScale)
      .chartYAxis { valueAxis(values: [Studies.rsiLow, Studies.rsiHigh]) }
      .chartXAxis { timeAxis(labels: bottom) }
      .modifier(SharedAxis(chart: self, pane: pane, showsTime: bottom, tags: lastTag(plot.rsi, color: Palette.info)))
      .overlay { waiting(plot.rsi) }
    case .stochastic:
      Chart {
        bands(high: Studies.stochasticHigh, low: Studies.stochasticLow)
        line(plot.stochasticK, name: Plot.stochasticK, color: Palette.info)
        line(plot.stochasticD, name: Plot.stochasticD, color: Palette.warning)
      }
      .chartYScale(domain: 0...Studies.oscillatorScale)
      .chartYAxis { valueAxis(values: [Studies.stochasticLow, Studies.stochasticHigh]) }
      .chartXAxis { timeAxis(labels: bottom) }
      .modifier(SharedAxis(chart: self, pane: pane, showsTime: bottom, tags: []))
      .overlay { waiting(plot.stochasticK) }
    case .atr:
      Chart {
        line(plot.atr, name: Plot.atr, color: Palette.seriesATR)
      }
      .chartYScale(domain: paneSpan([plot.atr]))
      .chartYAxis { valueAxis(ticks: Self.paneTicks, span: paneSpan([plot.atr])) }
      .chartXAxis { timeAxis(labels: bottom) }
      .modifier(SharedAxis(chart: self, pane: pane, showsTime: bottom, tags: []))
      .overlay {
        if !plot.atr.contains(where: { $0 != nil }) {
          Text(L10n.Chart.atrWaiting(Indicators.atrPeriod))
            .font(Tokens.Typography.caption)
            .foregroundStyle(Palette.textQuaternary)
        }
      }
    case .price:
      EmptyView()
    }
  }

  /// A note over a study pane whose line has no value yet: too few candles for its period (a
  /// month of daily candles under MACD's 26, say), instead of an empty pane.
  @ViewBuilder private func waiting(_ values: [Double?]) -> some View {
    if !values.contains(where: { $0 != nil }) {
      Text(L10n.Chart.studyWaiting)
        .font(Tokens.Typography.caption)
        .foregroundStyle(Palette.textQuaternary)
        .allowsHitTesting(false)
    }
  }

  /// Whether the decisions on screen are few enough to label.
  private var labelsDecisions: Bool {
    let shown = windowStart...windowStart.addingTimeInterval(visibleLength)
    return decisions.filter { shown.contains($0.time) }.count <= Self.decisionLabelLimit
  }

  /// The pane's name in its top left corner; the volume pane adds the newest candle's volume,
  /// the span of its average and the relative volume, the ATR pane its newest value.
  private func paneName(_ pane: ChartPane) -> some View {
    HStack(spacing: Tokens.Space.xs) {
      switch pane {
      case .volume: volumeName
      case .macd: Text(L10n.Chart.macd)
      case .rsi: Text(L10n.Chart.rsi(Studies.rsiPeriod))
      case .stochastic: Text(L10n.Chart.stochastic)
      case .atr:
        if let value = plot.atr.last(where: { $0 != nil }) ?? nil {
          Text(L10n.Chart.atr(Indicators.atrPeriod)) + Text(verbatim: Format.itemSeparator)
            + Text(verbatim: Money.value(value)).foregroundStyle(Palette.seriesATRText)
        } else {
          Text(L10n.Chart.atr(Indicators.atrPeriod))
        }
      case .price: EmptyView()
      }
    }
    .font(Tokens.Typography.annotation)
    .foregroundStyle(Palette.textQuaternary)
    .padding(Tokens.Space.xs)
    .allowsHitTesting(false)
  }

  /// "VOL 23.4K · avg 20 · rel. volume 2.6×" for the newest candle; the volume alone until the
  /// average has its first value.
  @ViewBuilder private var volumeName: some View {
    if let last = candles.indices.last {
      let volume = Self.volumeText(candles[last].volume)
      if let average = plot.volumeAverage[last], average > 0 {
        Text(L10n.Chart.volumePane(
          volume, ChartPlot.volumeAveragePeriod, Money.number(candles[last].volume / average, fractionDigits: Self.ratioDigits)))
      } else {
        Text(L10n.Chart.volumePaneShort(volume))
      }
    }
  }

  /// Dashed lines at an oscillator's overbought and oversold levels.
  @ChartContentBuilder private func bands(high: Double, low: Double) -> some ChartContent {
    ForEach([high, low], id: \.self) { level in
      RuleMark(y: .value(Plot.price, level))
        .foregroundStyle(Palette.warning.opacity(Tokens.Opacity.border))
        .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.thin, dash: Tokens.Stroke.dashFine))
    }
  }

  /// The newest defined value of a line, tagged on its pane's value axis.
  private func lastTag(_ values: [Double?], color: Color) -> [AxisTag] {
    guard let value = values.last(where: { $0 != nil }) ?? nil else { return [] }
    return [AxisTag(value: value, text: Money.value(value), color: color)]
  }

  /// A pane's value scale on the right, its labels all `axisLabelWidth` wide: scales of different
  /// widths (prices, MACD, RSI) gave each pane a plot area of its own width, so the same minute,
  /// and the crosshair on it, sat at a different x in each pane.
  /// Labels within `paneEdgeShare` of the top or bottom of `span` are left out (the gridline stays).
  private func valueAxis(ticks: Int, span: ClosedRange<Double>) -> some AxisContent {
    let clearance = (span.upperBound - span.lowerBound) * Self.paneEdgeShare
    let shown = (span.lowerBound + clearance)...(span.upperBound - clearance)
    return AxisMarks(position: .trailing, values: .automatic(desiredCount: ticks)) { value in
      AxisGridLine()
      AxisTick()
      AxisValueLabel {
        if let number = value.as(Double.self), shown.contains(number) {
          Text(verbatim: Money.value(number))
            .frame(width: Self.axisLabelWidth, alignment: .leading)
        } else {
          Color.clear.frame(width: Self.axisLabelWidth)
        }
      }
    }
  }

  /// A study's value range over the candles on screen, padded like the prices; a flat or empty
  /// study gets one unit either side.
  private func paneSpan(_ lines: [[Double?]]) -> ClosedRange<Double> {
    let values = visibleIndices.flatMap { index in lines.compactMap { $0[index] } }
    guard let low = values.min(), let high = values.max() else { return -1...1 }
    guard high > low else { return (low - 1)...(high + 1) }
    let pad = (high - low) * Tokens.Chart.pricePadding
    return (low - pad)...(high + pad)
  }

  /// The price scale, its labels left out where a tag shown at `tagged` (last price, entry,
  /// stop, high, low) would overlap them (`AxisLabels`, mockup v103: "11.80" never under
  /// "L 11.78"), and at the very bottom (within `tagClearance`), where the lowest one hung over
  /// the pane below.
  private func valueAxis(ticks: Int, hiding tagged: [Double], span: ClosedRange<Double>) -> some AxisContent {
    let range = span.upperBound - span.lowerBound
    let lowest = span.lowerBound + range * Self.tagClearance
    let clearance = AxisLabels.clearance(labelHeight: Double(Tokens.Chart.axisLabelHeight),
      tagHeight: Double(Tokens.Chart.levelTagHeight), span: range, height: Double(priceHeight))
    return AxisMarks(position: .trailing, values: .automatic(desiredCount: ticks)) { value in
      AxisGridLine()
      AxisTick()
      AxisValueLabel {
        if let price = value.as(Double.self), price >= lowest,
          AxisLabels.shows(price, tags: tagged, clearance: clearance) {
          Text(verbatim: Money.price(price))
            .frame(width: Self.axisLabelWidth, alignment: .leading)
        } else {
          Color.clear.frame(width: Self.axisLabelWidth)
        }
      }
    }
  }

  /// The volume scale: compact figures ("40K"), its top and bottom labels left out as on the
  /// study panes.
  private func volumeAxis(span: ClosedRange<Double>) -> some AxisContent {
    let clearance = (span.upperBound - span.lowerBound) * Self.paneEdgeShare
    let shown = (span.lowerBound + clearance)...(span.upperBound - clearance)
    return AxisMarks(position: .trailing, values: .automatic(desiredCount: Self.paneTicks)) { value in
      AxisGridLine()
      AxisTick()
      AxisValueLabel {
        if let number = value.as(Double.self), shown.contains(number) {
          Text(verbatim: Self.volumeText(number))
            .frame(width: Self.axisLabelWidth, alignment: .leading)
        } else {
          Color.clear.frame(width: Self.axisLabelWidth)
        }
      }
    }
  }

  /// A value scale with gridlines at exactly `values` (an oscillator's band levels).
  private func valueAxis(values: [Double]) -> some AxisContent {
    AxisMarks(position: .trailing, values: values) { value in
      axisMark(value)
    }
  }

  /// The time gridlines every pane draws, through the middle of the candles they name, so they
  /// line up with the candles and the crosshair in every pane; `labels` only under the bottom
  /// pane. On one day, round 24-hour market times ("14:30", never "14:31") whatever the Mac's
  /// clock setting; over a longer range, where each session, week, month or quarter begins (the
  /// candles sit back to back there, so clock times would not read).
  @AxisContentBuilder private func timeAxis(labels: Bool) -> some AxisContent {
    if plot.sessions != nil {
      sessionTimeAxis(labels: labels)
    } else {
      rangeTimeAxis(labels: labels)
    }
  }

  /// A month or longer: gridlines and labels through the middle of the candles that open a week,
  /// month or quarter.
  @AxisContentBuilder private func rangeTimeAxis(labels: Bool) -> some AxisContent {
    let marks = rangeMarks
    let shown = windowDomain
    let byMiddle = Dictionary(marks.compactMap { mark in plot.index(at: mark.time).map { (candles[$0].middle, mark) } },
      uniquingKeysWith: { first, _ in first })
    if labels {
      AxisMarks(values: Array(byMiddle.keys)) { value in
        AxisGridLine()
        AxisTick()
        // By time, never by position; near either end of the window a label hangs inward.
        let mark = value.as(Date.self).flatMap { byMiddle[$0] }
        AxisValueLabel(anchor: Self.unitPoint(mark.map { ChartAxis.anchor(of: $0.time, shown: shown) } ?? .centre)) {
          Text(verbatim: mark?.text ?? Format.missing)
            .fixedSize()
        }
      }
    } else {
      AxisMarks(values: Array(byMiddle.keys)) { _ in
        AxisGridLine()
      }
    }
  }

  /// Day and 5D (mockup v113): the session labels at the boundaries ("Pre 04:00", "09:30",
  /// "16:00", "After 20:00"; a day's name over five days) and round clock times between them,
  /// none closer than `Tokens.Chart.axisLabelGap`; gridlines at the round times only (the
  /// boundaries are their own dashed lines).
  @AxisContentBuilder private func sessionTimeAxis(labels: Bool) -> some AxisContent {
    let marks = sessionMarks
    let byTime = Dictionary(marks.map { ($0.time, $0) }, uniquingKeysWith: { first, _ in first })
    AxisMarks(values: marks.map(\.time)) { value in
      let mark = value.as(Date.self).flatMap { byTime[$0] }
      if mark?.strong == false {
        AxisGridLine()
      }
      if labels {
        AxisTick()
        // Moved by its offset to where `AxisLabelPlacer` put it (centred on a boundary).
        AxisValueLabel(
          centered: false, anchor: mark?.anchor == .trailing ? .topTrailing : .topLeading,
          collisionResolution: .disabled, horizontalSpacing: 0
        ) {
          Text(verbatim: mark?.text ?? Format.missing)
            .font(Tokens.Chart.sessionAxisLabel)
            .foregroundStyle(mark?.strong == true ? Palette.textTertiary : Palette.textQuaternary)
            .fixedSize()
            .offset(x: mark?.offset ?? 0)
        }
      }
    }
  }

  /// The session axis's labels on screen, placed in order (sessions, the end, round times) so
  /// none overlaps another; a session label too wide for its room takes its short form.
  private var sessionMarks: [ChartAxisMark] {
    guard let sessions = plot.sessions, plotWidth > 0, visibleLength > 0 else { return [] }
    let shown = windowDomain
    let perSecond = Double(plotWidth) / visibleLength
    let step = SessionAxis.hourStep(
      timeframe: series.timeframe, pointsPerSlot: series.timeframe.seconds * perSecond,
      least: Double(Tokens.Chart.hourLabelSpacing))
    let labels = sessions.labels(
      range: plot.range, candles: plot.real, extendedClose: plot.extendedClose, hourStep: step)
    let font = NSFont.monospacedSystemFont(ofSize: Tokens.Chart.sessionAxisLabelSize, weight: .regular)
    let texts = labels.map { SessionAxisText.texts($0.kind, dayName: Format.chartSessionDay) }
    let items = zip(labels, texts).map { label, forms in
      AxisLabelPlacer.Item(
        x: plot.slotTime(label.slot).timeIntervalSince(shown.lowerBound) * perSecond,
        widths: forms.map { Double(TextMeasure.width($0, font: font)) }, anchor: label.anchor,
        required: SessionAxisText.isSession(label.kind))
    }
    return AxisLabelPlacer.place(
      items, width: Double(plotWidth), gap: Double(Tokens.Chart.axisLabelGap), inset: Double(Tokens.Chart.axisLabelInset)
    ).map { placed in
      let label = labels[placed.item]
      // Charts hangs a trailing label's right edge from its tick and every other label's left
      // edge (whatever its anchor): the offset moves it to where the placer put it.
      let item = items[placed.item]
      let edge = label.anchor == .trailing ? placed.left + item.widths[placed.text] : placed.left
      return ChartAxisMark(
        time: plot.slotTime(label.slot), text: texts[placed.item][placed.text], anchor: label.anchor,
        strong: SessionAxisText.isSession(label.kind), offset: CGFloat(edge - item.x))
    }
  }

  /// The extended-hours bands behind the candles (pre-market and after-hours, a `textPrimary`
  /// tint) with their "PRE" / "AFTER" captions where the band is wide enough, and the dashed
  /// boundaries between the parts of the day (mockup v113). `span`: the pane's value range.
  @ChartContentBuilder private func sessionMarks(span: ClosedRange<Double>, captions: Bool) -> some ChartContent {
    ForEach(sessionBands) { band in
      RectangleMark(
        xStart: .value(Plot.time, band.start), xEnd: .value(Plot.time, band.end),
        yStart: .value(Plot.price, span.lowerBound), yEnd: .value(Plot.price, span.upperBound))
        .foregroundStyle(Palette.textPrimary.opacity(Tokens.Chart.extendedBandOpacity(colorScheme)))
        .annotation(position: .overlay, alignment: .topLeading) {
          if captions, let caption = band.caption, fits(caption, from: band.start, to: band.end) {
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
    (plot.sessions?.bands ?? []).map { band in
      SessionBand(
        start: plot.slotTime(band.segment.first), end: plot.slotTime(band.end),
        caption: SessionAxisText.caption(band.segment.session).map { String(localized: $0) })
    }
  }

  /// Where the parts of the day meet, at drawn times; none at the chart's left edge.
  private var sessionBoundaries: [Date] { (plot.sessions?.boundaries ?? []).map(plot.slotTime) }

  /// Whether a band's caption fits inside it on screen, with its inset on both sides.
  private func fits(_ caption: String, from start: Date, to end: Date) -> Bool {
    guard plotWidth > 0, visibleLength > 0 else { return false }
    let font = NSFont.monospacedSystemFont(ofSize: Tokens.Chart.bandCaptionSize, weight: .semibold)
    let width = TextMeasure.width(caption, font: font, kern: Tokens.Chart.bandCaptionSize * Tokens.Chart.bandCaptionTracking)
    let shown = Double(plotWidth) * end.timeIntervalSince(start) / visibleLength
    return shown >= Double(width + Tokens.Chart.bandCaptionInset + Tokens.Chart.bandCaptionInset)
  }

  /// Time labels `timeLabelSlot` apart that fit across a price pane `chartWidth` wide (its value
  /// scale takes `axisLabelWidth` of it).
  nonisolated static func slotCount(chartWidth: CGFloat) -> Int {
    let plotWidth = chartWidth - axisLabelWidth
    return plotWidth > 0 ? Int(plotWidth / timeLabelSlot) : 0
  }

  /// The range's labels in the window, none closer than `timeLabelSlot`; where a year begins
  /// wins over the month before it.
  private var rangeMarks: [ChartAxisMark] {
    let shown = windowDomain
    let inside = plot.axisMarks.filter { shown.contains($0.time) }
    guard labelSlots > 0 else { return inside }
    let gap = visibleLength / Double(labelSlots)
    return ChartAxis.spaced(inside.map(\.time), gap: gap, shown: shown, preferred: { inside[$0].major })
      .map { inside[$0] }
  }

  /// Where a time label's top hangs from its tick.
  private static func unitPoint(_ anchor: ChartAxis.Anchor) -> UnitPoint {
    switch anchor {
    case .leading: .topLeading
    case .centre: .top
    case .trailing: .topTrailing
    }
  }

  @AxisMarkBuilder private func axisMark(_ value: AxisValue) -> some AxisMark {
    AxisGridLine()
    AxisTick()
    AxisValueLabel {
      Text(verbatim: value.as(Double.self).map(Money.value) ?? Format.missing)
        .frame(width: Self.axisLabelWidth, alignment: .leading)
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

  // MARK: Pointed candle

  /// What the crosshair marks on the candle at `index` in `pane`: the candle (or volume bar)
  /// outlined, and a dot on every line drawn there (the close in the line style, the bot's lines,
  /// the studies).
  func pointedMarks(_ pane: ChartPane, _ index: Int) -> PointedMarks {
    guard candles.indices.contains(index) else { return PointedMarks(box: nil, dots: []) }
    let candle = candles[index]
    var dots: [PointedDot] = []
    func add(_ values: [Double?], _ color: Color) {
      if values.indices.contains(index), let value = values[index] { dots.append(PointedDot(value: value, color: color)) }
    }
    var box: PointedBox?
    switch pane {
    case .price:
      if lines.style == .line {
        dots.append(PointedDot(value: candle.close, color: visibleTrendUp ? Palette.candleUp : Palette.candleDown))
      } else {
        box = PointedBox(start: bodyStart(candle), end: bodyEnd(candle), top: candle.high, bottom: candle.low)
      }
      if lines.bollinger { add(plot.bollingerMiddle, Palette.accent) }
      if lines.movingAverages {
        for (offset, values) in plot.movingAverages.enumerated() { add(values, Self.movingAverageColors[offset]) }
      }
      if lines.vwap { add(series.vwap, Palette.seriesVWAP) }
      if lines.fastEMA { add(series.fastEMA, Palette.seriesFastEMA) }
      if lines.slowEMA { add(series.slowEMA, Palette.seriesSlowEMA) }
    case .volume:
      box = PointedBox(start: bodyStart(candle), end: bodyEnd(candle), top: candle.volume, bottom: 0)
      add(plot.volumeAverage, Palette.warning)
    case .macd:
      add(plot.macd, Palette.info)
      add(plot.macdSignal, Palette.warning)
    case .rsi:
      add(plot.rsi, Palette.info)
    case .stochastic:
      add(plot.stochasticK, Palette.info)
      add(plot.stochasticD, Palette.warning)
    case .atr:
      add(plot.atr, Palette.seriesATR)
    }
    return PointedMarks(box: box, dots: dots)
  }

  // MARK: Geometry

  private var firstStart: Date { candles.first?.start ?? .now }
  /// Where the time axis ends: after the newest candle, or on today's Day chart at the extended
  /// close, the rest of the day kept empty (mockup v113).
  private var lastEnd: Date { candles.isEmpty ? .now : plot.drawnEnd }
  /// After the newest candle, which a zoomed window follows.
  private var newestEnd: Date { candles.last?.end ?? .now }

  /// Seconds of time on screen.
  var visibleLength: TimeInterval {
    guard let visible = viewport.shown(total: candles.count) else { return lastEnd.timeIntervalSince(firstStart) }
    return TimeInterval(visible) * series.timeframe.seconds
  }

  /// Opening time of the window on screen; while not scrolled it follows the newest candle.
  var windowStart: Date {
    viewport.position ?? max(firstStart, newestEnd.addingTimeInterval(-visibleLength))
  }

  var xDomain: ClosedRange<Date> { firstStart...lastEnd }
  /// The stretch on screen: the whole day, or the zoomed window.
  var windowDomain: ClosedRange<Date> {
    guard zoomed else { return xDomain }
    return windowStart...windowStart.addingTimeInterval(visibleLength)
  }
  var zoomed: Bool { viewport.shown(total: candles.count) != nil }

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

  /// Candles on screen.
  private var visibleIndices: Range<Int> {
    plot.indices(from: windowStart, to: windowStart.addingTimeInterval(visibleLength))
  }

  /// Whether the visible stretch closed at or above where it opened.
  private var visibleTrendUp: Bool {
    let shown = visibleIndices
    guard let first = shown.first, let last = shown.last else { return true }
    return candles[last].close >= candles[first].open
  }

  private var gap: TimeInterval { series.timeframe.seconds * (1 - Self.bodyShare) / 2 }
  private func bodyStart(_ candle: Candle) -> Date { candle.start.addingTimeInterval(gap) }
  private func bodyEnd(_ candle: Candle) -> Date { candle.end.addingTimeInterval(-gap) }

  /// A candle's colour (its wick, last-price line and tag), as the Chart board: teal up, pink down.
  private func color(_ candle: Candle) -> Color { candle.isUp ? Palette.candleUp : Palette.candleDown }

  /// Prices of the candles and levels on screen and of every line drawn over them (Bollinger
  /// bands, moving averages, VWAP, EMAs), so no line runs off the plot, padded so nothing touches
  /// the edge.
  private var priceScale: ClosedRange<Double> {
    var drawn: [[Double?]] = []
    if lines.bollinger { drawn += [plot.bollingerUpper, plot.bollingerLower] }
    if lines.movingAverages { drawn += plot.movingAverages }
    if lines.vwap { drawn.append(series.vwap) }
    if lines.fastEMA { drawn.append(series.fastEMA) }
    if lines.slowEMA { drawn.append(series.slowEMA) }
    guard let prices = ChartPriceSpan.bounds(
      of: candles, shown: visibleIndices, lines: drawn, levels: levels.map(\.price)) else { return 0...1 }
    let low = prices.lowerBound
    let high = prices.upperBound
    let span = max(high - low, high * Self.minimumSpan)
    let pad = span * Tokens.Chart.pricePadding
    return (low - pad)...(high + pad)
  }

  /// Zero to the largest volume on screen, with room above it for the pane's name.
  private var volumeSpan: ClosedRange<Double> {
    let ceiling = candles[visibleIndices].map(\.volume).max() ?? 0
    return 0...max(ceiling * (1 + Self.volumeHeadroom), 1)
  }

  private var pinch: some Gesture {
    MagnifyGesture()
      .onChanged { value in
        let start = pinchStart ?? viewport.shown(total: candles.count) ?? candles.count
        pinchStart = start
        viewport.show(Int((Double(start) / value.magnification).rounded()), total: candles.count)
      }
      .onEnded { _ in pinchStart = nil }
  }

  /// Relative volume: one decimal ("2.6").
  static let ratioDigits = 1
  /// Share of the largest volume on screen left free above it, for the pane's name.
  static let volumeHeadroom = 0.35

  /// "23.4K": a volume, as on the iPhone (`Volume.compact`).
  static func volumeText(_ value: Double) -> String {
    Volume.compact(value)
  }
}

/// The pointed candle's outline in a pane: its slot's body width, from `bottom` to `top`.
struct PointedBox {
  let start: Date
  let end: Date
  let top: Double
  let bottom: Double
}

/// A dot on a line at the pointed candle.
struct PointedDot {
  let value: Double
  let color: Color
}

/// What the crosshair marks at the pointed candle in one pane.
struct PointedMarks {
  let box: PointedBox?
  let dots: [PointedDot]
}

/// An extended-hours band at drawn times, with its caption.
private struct SessionBand: Identifiable {
  let start: Date
  let end: Date
  let caption: String?

  var id: Date { start }
}

/// One defined value of an indicator line.
private struct LinePoint: Identifiable {
  let time: Date
  let value: Double

  var id: Date { time }
}

/// A value tagged on a pane's value axis (the last price, the current RSI).
struct AxisTag: Identifiable {
  let value: Double
  let text: String
  let color: Color
  /// Plain text after a short leader (the high and low on screen), not a coloured plate.
  var plain = false

  var id: String { "\(value) \(text)" }
}

/// The time axis every pane shares (same domain, window and pointer), the pointer's hover in the
/// pane, and the crosshair and axis tags drawn over it.
private struct SharedAxis: ViewModifier {
  let chart: CandleChart
  let pane: ChartPane
  /// Whether this pane shows the time axis (the bottom pane), and so the pointed time's tag.
  let showsTime: Bool
  let tags: [AxisTag]

  func body(content: Content) -> some View {
    let pointer = chart.pointerModel
    scrolling(content)
      .chartXSelection(value: chart.selection)
      .onContinuousHover { phase in
        switch phase {
        case .active(let location): pointer.move(in: pane, to: location)
        case .ended: pointer.leave(pane)
        }
      }
      .chartOverlay { proxy in
        ZStack {
          AxisTags(tags: tags, proxy: proxy)
          Crosshair(pointer: pointer, plot: chart.plot, pane: pane, showsTime: showsTime, proxy: proxy,
            marks: { chart.pointedMarks(pane, $0) })
        }
      }
  }
}

extension SharedAxis {
  /// Only the price pane scrolls; the panes below draw the window it shows. A scrolling chart
  /// is an AppKit scroll view, and three or four of them bound to one scroll position set each
  /// other's position inside a layout pass until AppKit threw ("needs another Update
  /// Constraints in Window pass"), on opening the chart with several panes.
  @ViewBuilder func scrolling(_ content: Content) -> some View {
    // Every pane's marks are clipped to its plot: a line or marker off the value scale ends at
    // the plot's edge instead of running over the controls above the chart. Labels stay inside
    // by their own fit (`keepInside`); the crosshair and axis tags are an overlay, not clipped.
    if pane == .price {
      content
        .chartXScale(domain: chart.xDomain)
        .chartScrollableAxes(chart.zoomed ? .horizontal : [])
        .chartXVisibleDomain(length: chart.visibleLength)
        .chartScrollPosition(x: chart.scrollPosition)
        .chartPlotStyle { $0.clipped() }
    } else {
      content
        .chartXScale(domain: chart.windowDomain)
        .chartPlotStyle { $0.clipped() }
    }
  }
}

/// A tag on the value axis: the value on a rounded plate of the line's colour.
private struct TagPlate: View {
  let text: String
  let color: Color

  var body: some View {
    Text(verbatim: text)
      .font(Tokens.Typography.annotationBold)
      .monospacedDigit()
      .foregroundStyle(Palette.background)
      .padding(.horizontal, Tokens.Space.xs)
      .padding(.vertical, Tokens.Space.xxs)
      .background(color, in: .rect(cornerRadius: Tokens.Radius.small))
  }
}

/// The pane's fixed tags (last price, current RSI), on its value axis.
private struct AxisTags: View {
  let tags: [AxisTag]
  let proxy: ChartProxy

  var body: some View {
    GeometryReader { geometry in
      if let plotFrame = proxy.plotFrame {
        let plot = geometry[plotFrame]
        let frame = plot.intersection(CGRect(origin: .zero, size: geometry.size))
        if !frame.isNull {
          ForEach(Self.placed(tags, proxy: proxy, height: plot.height), id: \.tag.id) { item in
            Group {
              if item.tag.plain {
                ExtremeLabel(text: item.tag.text, color: item.tag.color)
              } else {
                TagPlate(text: item.tag.text, color: item.tag.color)
              }
            }
            .fixedSize()
            .position(x: frame.maxX + CandleChart.axisLabelWidth / 2 + Tokens.Space.xs, y: plot.minY + item.y)
          }
        }
      }
    }
    .allowsHitTesting(false)
  }

  /// The tags inside the plot with where each sits, moved apart top to bottom so no two are
  /// closer than `CandleChart.tagSpacing`; a coloured plate (last price, entry, stop) keeps its
  /// place and a plain high or low moves out of its way.
  static func placed(_ tags: [AxisTag], proxy: ChartProxy, height: CGFloat) -> [(tag: AxisTag, y: CGFloat)] {
    let inside: [(tag: AxisTag, y: CGFloat)] = tags.compactMap { tag in
      guard let y = proxy.position(forY: tag.value), y >= 0, y <= height else { return nil }
      return (tag: tag, y: y)
    }
    // The axis's own labels give way to the very places drawn here (`AxisLabels`).
    let shown = AxisLabels.placed(inside.map { AxisLabels.Tag(y: Double($0.y), plain: $0.tag.plain) },
      spacing: Double(CandleChart.tagSpacing))
    return zip(inside, shown).compactMap { item, y in y.map { (tag: item.tag, y: CGFloat($0)) } }
  }
}

/// The crosshair in one pane: a vertical line through the pointed candle that runs on through
/// the panes above and below (they draw their own part), and in the hovered pane a horizontal
/// line with the value under the pointer tagged on the value axis. The bottom pane tags the
/// pointed time on the time axis. Drawn over a pane rather than as marks in it, so moving the
/// pointer redraws a few lines instead of the whole chart.
private struct Crosshair: View {
  let pointer: ChartPointer
  let plot: ChartPlot
  let pane: ChartPane
  let showsTime: Bool
  let proxy: ChartProxy
  /// The outline and dots to draw at a pointed candle.
  let marks: (Int) -> PointedMarks

  /// Side of a dot on a line at the pointed candle, in points.
  static let dotSide: CGFloat = 7

  private var candles: [Candle] { plot.candles }

  var body: some View {
    GeometryReader { geometry in
      if let plotFrame = proxy.plotFrame {
        // The part of the plot on screen: a scrolling pane's plot is as wide as the whole day, so
        // its own frame reached past the chart card.
        let frame = geometry[plotFrame].intersection(CGRect(origin: .zero, size: geometry.size))
        if !frame.isNull, let index = pointer.index, candles.indices.contains(index),
          let position = proxy.position(forX: candles[index].middle) {
          let x = geometry[plotFrame].minX + position
          if x >= frame.minX, x <= frame.maxX {
            let top = pane == .price ? frame.minY : 0
            let bottom = showsTime ? frame.maxY : geometry.size.height
            Rectangle()
              .fill(Palette.textTertiary.opacity(Tokens.Opacity.medium))
              .frame(width: Tokens.Stroke.hairline, height: bottom - top)
              .position(x: x, y: (top + bottom) / 2)
            highlight(marks(index), origin: geometry[plotFrame].origin)
            if showsTime {
              TagPlate(text: plot.timeText(index), color: Palette.textSecondary)
                .fixedSize()
                .position(x: x, y: frame.maxY + Tokens.Space.s)
            }
          }
        }
        if !frame.isNull, let hover = pointer.hover, hover.pane == pane, frame.contains(hover.location),
          let value = proxy.value(atY: hover.location.y - geometry[plotFrame].minY, as: Double.self) {
          Rectangle()
            .fill(Palette.textTertiary.opacity(Tokens.Opacity.medium))
            .frame(width: frame.width, height: Tokens.Stroke.hairline)
            .position(x: frame.midX, y: hover.location.y)
          TagPlate(text: text(value), color: Palette.textSecondary)
            .fixedSize()
            .position(x: frame.maxX + CandleChart.axisLabelWidth / 2 + Tokens.Space.xs, y: hover.location.y)
        }
      }
    }
    .clipped()
    .allowsHitTesting(false)
  }

  /// The pointed candle outlined and a dot on each line, at the plot's `origin` in this view.
  @ViewBuilder private func highlight(_ marks: PointedMarks, origin: CGPoint) -> some View {
    if let box = marks.box, let left = proxy.position(forX: box.start), let right = proxy.position(forX: box.end),
      let top = proxy.position(forY: box.top), let bottom = proxy.position(forY: box.bottom) {
      RoundedRectangle(cornerRadius: Tokens.Radius.small)
        .strokeBorder(Palette.textPrimary.opacity(Tokens.Opacity.medium), lineWidth: Tokens.Stroke.thin)
        .frame(width: max(right - left, Tokens.Stroke.thin) + Tokens.Space.xs,
          height: abs(bottom - top) + Tokens.Space.xs)
        .position(x: origin.x + (left + right) / 2, y: origin.y + (top + bottom) / 2)
    }
    ForEach(Array(marks.dots.enumerated()), id: \.offset) { _, dot in
      if let x = proxy.position(forX: plotTime(marks)), let y = proxy.position(forY: dot.value) {
        Circle()
          .fill(dot.color)
          .overlay(Circle().strokeBorder(Palette.surface, lineWidth: Tokens.Stroke.thin))
          .frame(width: Self.dotSide, height: Self.dotSide)
          .position(x: origin.x + x, y: origin.y + y)
      }
    }
  }

  /// The pointed candle's middle, where its line values sit.
  private func plotTime(_ marks: PointedMarks) -> Date {
    guard let index = pointer.index, candles.indices.contains(index) else { return .distantPast }
    return candles[index].middle
  }

  private func text(_ value: Double) -> String {
    switch pane {
    case .price: Money.price(value)
    // Volume as on its scale ("240K"), never "240,525.83".
    case .volume: CandleChart.volumeText(value)
    default: Money.value(value)
    }
  }
}

/// The highest high or lowest low on screen on the price axis: a short leader from the plot,
/// then "H 13.32".
private struct ExtremeLabel: View {
  let text: String
  let color: Color

  var body: some View {
    HStack(spacing: Tokens.Space.xxs) {
      Rectangle()
        .fill(color)
        .frame(width: CandleChart.extremeLeader, height: Tokens.Stroke.thin)
      Text(verbatim: text)
    }
    .font(Tokens.Typography.annotation)
    .foregroundStyle(color)
    .frame(width: CandleChart.axisLabelWidth + Tokens.Space.s, alignment: .leading)
  }
}

/// Values of the candle under the pointer (or the newest), in the screen's header: time, open,
/// high, low, close, change from the previous close and volume. It alone reads the pointer's
/// candle, so a pointer move redraws this line and not the panes.
struct ChartReadout: View {
  let plot: ChartPlot
  let pointer: ChartPointer

  private var series: ChartSeries { plot.series }

  var body: some View {
    let pointed = pointer.index.flatMap { series.candles.indices.contains($0) ? $0 : nil }
    if let index = pointed ?? series.candles.indices.last {
      let candle = series.candles[index]
      // As many values as fit on a line, the rest on the next: none is cut in a narrow window.
      // (The screen's least size is fixed, so a readout that changes height moves no window.)
      ChipFlow(spacing: Tokens.Space.m) {
        Text(verbatim: plot.timeText(index))
          .foregroundStyle(Palette.textSecondary)
        value(L10n.Chart.open, Money.price(candle.open))
        value(L10n.Chart.high, Money.price(candle.high))
        value(L10n.Chart.low, Money.price(candle.low))
        value(L10n.Chart.close, Money.price(candle.close))
        if let change = series.candles.change(at: index) {
          Text(verbatim: Self.changeText(change))
            .foregroundStyle(Palette.result(Money.decimal(change.amount)))
        }
        value(L10n.Chart.volumeShort, CandleChart.volumeText(candle.volume))
      }
      .font(Tokens.Typography.annotation)
      .monospacedDigit()
      .contentTransition(.numericText())
      .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
    }
  }

  /// "+0.21 (+6.21%)": the change in price and as a percentage, signed (zero unsigned).
  static func changeText(_ change: CandleChange) -> String {
    String(localized: L10n.Chart.change(Money.priceChange(change.amount, at: change.price),
      Percent.signed(fraction: change.fraction)))
  }

  private func value(_ name: LocalizedStringResource, _ text: String) -> some View {
    HStack(spacing: Tokens.Space.xs) {
      Text(name).foregroundStyle(Palette.textQuaternary)
      Text(verbatim: text).foregroundStyle(Palette.textTertiary)
    }
  }
}

/// The drawn lines and studies with their values at the pointed (or newest) candle, in their
/// colours, in the price pane's top left corner.
private struct ChartLegend: View {
  let plot: ChartPlot
  let lines: ChartLines
  let pointer: ChartPointer

  private var series: ChartSeries { plot.series }

  var body: some View {
    let pointed = pointer.index.flatMap { series.candles.indices.contains($0) ? $0 : nil }
    if let index = pointed ?? series.candles.indices.last {
      let items = entries(index)
      if !items.isEmpty {
        // As many lines' values as fit across, the rest on the next row: none is cut.
        ChipFlow(spacing: Tokens.Space.m) {
          ForEach(Array(items.enumerated()), id: \.offset) { _, item in
            HStack(spacing: Tokens.Space.xs) {
              Text(item.name)
              Text(verbatim: Money.price(item.value))
            }
            .foregroundStyle(item.color)
          }
        }
        .font(Tokens.Typography.annotation)
        .monospacedDigit()
        .padding(.horizontal, Tokens.Space.xs)
        .background(Palette.surfaceSunken.opacity(Tokens.Opacity.overlay), in: .rect(cornerRadius: Tokens.Radius.small))
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .allowsHitTesting(false)
      }
    }
  }

  private func entries(_ index: Int) -> [ReadoutEntry] {
    var items: [ReadoutEntry] = []
    func add(_ name: LocalizedStringResource, _ value: Double?, _ color: Color) {
      if let value { items.append(ReadoutEntry(name: name, value: value, color: color)) }
    }
    if lines.vwap { add(L10n.Chart.vwap, series.vwap[index], Palette.warningText) }
    if lines.fastEMA { add(L10n.Chart.ema(Indicators.fastEMAPeriod), series.fastEMA[index], Palette.accentText) }
    if lines.slowEMA { add(L10n.Chart.ema(Indicators.slowEMAPeriod), series.slowEMA[index], Palette.highlightText) }
    if lines.movingAverages {
      for (offset, period) in Studies.movingAveragePeriods.enumerated() {
        add(L10n.Chart.movingAverage(period), plot.movingAverages[offset][index], CandleChart.movingAverageColors[offset])
      }
    }
    if lines.bollinger {
      add(L10n.Chart.bollingerUpper, plot.bollingerUpper[index], Palette.accentText)
      add(L10n.Chart.bollingerMiddle, plot.bollingerMiddle[index], Palette.accentText)
      add(L10n.Chart.bollingerLower, plot.bollingerLower[index], Palette.accentText)
    }
    if lines.macd {
      add(L10n.Chart.macd, plot.macd[index], Palette.infoText)
      add(L10n.Chart.macdSignal, plot.macdSignal[index], Palette.warningText)
      add(L10n.Chart.macdHistogram, plot.macdHistogram[index], Palette.textSecondary)
    }
    if lines.rsi { add(L10n.Chart.rsi(Studies.rsiPeriod), plot.rsi[index], Palette.infoText) }
    if lines.stochastic {
      add(L10n.Chart.stochasticK, plot.stochasticK[index], Palette.infoText)
      add(L10n.Chart.stochasticD, plot.stochasticD[index], Palette.warningText)
    }
    if lines.atr { add(L10n.Chart.atr(Indicators.atrPeriod), plot.atr[index], Palette.seriesATRText) }
    return items
  }
}

/// A trade's or a decision's label on the price pane: bold mono on a plate washed in its colour.
private struct MarkPlate: View {
  let text: LocalizedStringResource
  let color: Color
  let textColor: Color

  var body: some View {
    Text(text)
      .textCase(.uppercase)
      .font(Tokens.Typography.annotationBold)
      .foregroundStyle(textColor)
      .padding(.horizontal, Tokens.Space.xs)
      .padding(.vertical, Tokens.Space.xxs)
      .background(color.opacity(Tokens.Opacity.wash), in: .rect(cornerRadius: Tokens.Radius.small))
      .background(Palette.surface.opacity(Tokens.Opacity.overlay), in: .rect(cornerRadius: Tokens.Radius.small))
      .fixedSize()
  }
}

/// One value in the readout's second row.
private struct ReadoutEntry {
  let name: LocalizedStringResource
  let value: Double
  let color: Color
}

/// Localized names of the plotted values (VoiceOver and Audio Graphs read them). Looked up once:
/// every mark names its values, and a lookup per mark per redraw cost thousands of lookups.
private enum Plot {
  static let time = String(localized: L10n.Chart.axisTime)
  static let price = String(localized: L10n.Chart.axisPrice)
  static let series = String(localized: L10n.Chart.axisSeries)
  static let close = String(localized: L10n.Chart.closeLine)
  static let vwap = String(localized: L10n.Chart.vwap)
  static let fastEMA = String(localized: L10n.Chart.ema(Indicators.fastEMAPeriod))
  static let slowEMA = String(localized: L10n.Chart.ema(Indicators.slowEMAPeriod))
  static let atr = String(localized: L10n.Chart.atr(Indicators.atrPeriod))
  static let volume = String(localized: L10n.Chart.volume)
  static let volumeAverage = String(localized: L10n.Chart.volumeAverage(ChartPlot.volumeAveragePeriod))
  static let movingAverages = Studies.movingAveragePeriods.map { String(localized: L10n.Chart.movingAverage($0)) }
  static let bollingerUpper = String(localized: L10n.Chart.bollingerUpper)
  static let bollingerMiddle = String(localized: L10n.Chart.bollingerMiddle)
  static let bollingerLower = String(localized: L10n.Chart.bollingerLower)
  static let macd = String(localized: L10n.Chart.macd)
  static let macdSignal = String(localized: L10n.Chart.macdSignal)
  static let rsi = String(localized: L10n.Chart.rsi(Studies.rsiPeriod))
  static let stochasticK = String(localized: L10n.Chart.stochasticK)
  static let stochasticD = String(localized: L10n.Chart.stochasticD)
}

extension Candle {
  /// The middle of the candle's time slot, where its wick is drawn.
  var middle: Date { start.addingTimeInterval(end.timeIntervalSince(start) / 2) }
}

/// Two charts are the same when they draw the same thing. ChartView is redrawn on every status
/// read (about once a second while live), which built the whole chart again with its candles and
/// studies: about half a core with the chart open and nothing changing (Instruments, 2026-11-15).
extension CandleChart: @MainActor Equatable {
  static func == (lhs: CandleChart, rhs: CandleChart) -> Bool {
    lhs.plot.revision == rhs.plot.revision && lhs.plot.range == rhs.plot.range
      && lhs.plot.starts == rhs.plot.starts && lhs.lines == rhs.lines && lhs.live == rhs.live
      && lhs.viewport == rhs.viewport
      && lhs.marks.map(\.key) == rhs.marks.map(\.key)
      && lhs.levels.map(\.key) == rhs.levels.map(\.key)
      && lhs.decisions.map(\.key) == rhs.decisions.map(\.key)
  }
}
