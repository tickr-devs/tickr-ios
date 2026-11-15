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
  @Binding var viewport: Viewport
  /// The candle under the pointer, shared with the screen's header readout and the explain card.
  let pointer: ChartPointer

  /// The pointer state, for the shared axis and crosshair of every pane.
  var pointerModel: ChartPointer { pointer }
  @State private var appeared = false
  /// The price pane's width, for spacing the time labels of a range.
  @State private var chartWidth: CGFloat = 0
  @State private var pinchStart: Int?

  /// Height of each study pane (volume, MACD, RSI, stochastic, ATR), in points.
  static let paneHeight: CGFloat = 96
  /// Least heights of the price pane and of a study pane, in points: with many studies in a
  /// short window the study panes shrink first, never the price pane below its least height.
  static let priceMinHeight: CGFloat = 240
  static let paneMinHeight: CGFloat = 56
  /// Most decisions on screen that are labelled; with more, only their diamonds are drawn, and
  /// the labels no longer pile up over the candles.
  static let decisionLabelLimit = 3
  /// Share of a candle's slot its body fills; the rest is the gap between candles.
  static let bodyShare = 0.66
  /// Smallest price range drawn, as a share of the price, so a flat stretch is not a line.
  static let minimumSpan = 0.0005
  /// Width of every pane's value labels, in points: one width keeps the panes' plot areas, and so
  /// their candles and crosshairs, lined up.
  static let axisLabelWidth: CGFloat = 56
  /// Gridlines each pane asks for on its value axis.
  static let priceTicks = 6
  /// Share of the price pane's height a tag covers on the scale (with a gap): an axis price
  /// this close to a tag hides under it.
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
  static let timeLabelSlot: CGFloat = 64
  /// Annotations near an edge move inside the chart instead of being cut off.
  static let keepInside = AnnotationOverflowResolution(x: .fit(to: .chart), y: .fit(to: .chart))
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
      PaneStack(priceMinimum: Self.priceMinHeight, paneHeight: Self.paneHeight, paneMinimum: Self.paneMinHeight) {
        priceChart
          .overlay(alignment: .topLeading) {
            ChartLegend(plot: plot, lines: lines, pointer: pointer)
              .padding(Tokens.Space.s)
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
            .foregroundStyle(color(candle))
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
      valueAxis(ticks: Self.priceTicks, hiding: priceTags.map(\.value), span: scale)
    }
    .chartXAxis(studyPanes.isEmpty ? .automatic : .hidden)
    .chartXAxis { timeAxis }
    .modifier(SharedAxis(chart: self, pane: .price, showsTime: studyPanes.isEmpty, tags: priceTags))
    .onGeometryChange(for: CGFloat.self, of: { $0.size.width }, action: { chartWidth = $0 })
  }

  /// The close as a line with a fill fading down to the bottom of the pane, coloured by whether
  /// the visible stretch ended above where it began.
  @ChartContentBuilder private func lineArea(_ scale: ClosedRange<Double>) -> some ChartContent {
    let tint = visibleTrendUp ? Palette.profit : Palette.loss
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
    var tags = levels.map { AxisTag(value: $0.price, text: Self.price($0.price), color: $0.color) }
    if let last = candles.last {
      tags.append(AxisTag(value: last.close, text: Self.price(last.close), color: color(last)))
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
      AxisTag(value: high, text: String(localized: L10n.Chart.highTag(price(high))), color: Palette.textTertiary,
        plain: true),
      AxisTag(value: low, text: String(localized: L10n.Chart.lowTag(price(low))), color: Palette.textTertiary,
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
        ForEach(candles[drawn]) { candle in
          RectangleMark(
            xStart: .value(Plot.time, bodyStart(candle)),
            xEnd: .value(Plot.time, bodyEnd(candle)),
            yStart: .value(Plot.volume, 0),
            yEnd: .value(Plot.volume, candle.volume))
            .foregroundStyle(color(candle).opacity(Tokens.Opacity.faint))
        }
        line(plot.volumeAverage, name: Plot.volumeAverage, color: Palette.warning)
      }
      .chartYScale(domain: span)
      .chartYAxis { volumeAxis(span: span) }
      .chartXAxis(bottom ? .automatic : .hidden)
      .chartXAxis { timeAxis }
      .modifier(SharedAxis(chart: self, pane: pane, showsTime: bottom, tags: []))
    case .macd:
      Chart {
        ForEach(drawn, id: \.self) { index in
          if let value = plot.macdHistogram[index] {
            BarMark(
              xStart: .value(Plot.time, bodyStart(candles[index])),
              xEnd: .value(Plot.time, bodyEnd(candles[index])),
              y: .value(Plot.price, value))
              .foregroundStyle((value >= 0 ? Palette.profit : Palette.loss).opacity(Tokens.Opacity.medium))
          }
        }
        line(plot.macd, name: Plot.macd, color: Palette.info)
        line(plot.macdSignal, name: Plot.macdSignal, color: Palette.warning)
      }
      .chartYScale(domain: paneSpan([plot.macd, plot.macdSignal, plot.macdHistogram]))
      .chartYAxis { valueAxis(ticks: Self.paneTicks, span: paneSpan([plot.macd, plot.macdSignal, plot.macdHistogram])) }
      .chartXAxis(bottom ? .automatic : .hidden)
      .chartXAxis { timeAxis }
      .modifier(SharedAxis(chart: self, pane: pane, showsTime: bottom, tags: []))
      .overlay { waiting(plot.macd) }
    case .rsi:
      Chart {
        bands(high: Studies.rsiHigh, low: Studies.rsiLow)
        line(plot.rsi, name: Plot.rsi, color: Palette.info)
      }
      .chartYScale(domain: 0...Studies.oscillatorScale)
      .chartYAxis { valueAxis(values: [Studies.rsiLow, Studies.rsiHigh]) }
      .chartXAxis(bottom ? .automatic : .hidden)
      .chartXAxis { timeAxis }
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
      .chartXAxis(bottom ? .automatic : .hidden)
      .chartXAxis { timeAxis }
      .modifier(SharedAxis(chart: self, pane: pane, showsTime: bottom, tags: []))
      .overlay { waiting(plot.stochasticK) }
    case .atr:
      Chart {
        line(plot.atr, name: Plot.atr, color: Palette.seriesATR)
      }
      .chartYScale(domain: paneSpan([plot.atr]))
      .chartYAxis { valueAxis(ticks: Self.paneTicks, span: paneSpan([plot.atr])) }
      .chartXAxis(bottom ? .automatic : .hidden)
      .chartXAxis { timeAxis }
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
            + Text(verbatim: value.formatted(Self.atrFormat)).foregroundStyle(Palette.seriesATRText)
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
          volume, ChartPlot.volumeAveragePeriod, (candles[last].volume / average).formatted(Self.ratioFormat)))
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
    return [AxisTag(value: value, text: value.formatted(Self.valueFormat), color: color)]
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
          Text(verbatim: number.formatted(Self.valueFormat))
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

  /// The price scale, its labels left out where a tag (last price, entry, stop) covers them
  /// (within `tagClearance` of the pane's height from a tagged value), and at the very bottom
  /// (with the same clearance), where the lowest one hung over the pane below.
  private func valueAxis(ticks: Int, hiding tagged: [Double], span: ClosedRange<Double>) -> some AxisContent {
    let clearance = (span.upperBound - span.lowerBound) * Self.tagClearance
    let lowest = span.lowerBound + clearance
    return AxisMarks(position: .trailing, values: .automatic(desiredCount: ticks)) { value in
      AxisGridLine()
      AxisTick()
      AxisValueLabel {
        if let price = value.as(Double.self), price >= lowest,
          !tagged.contains(where: { abs($0 - price) < clearance }) {
          Text(verbatim: price.formatted(Self.valueFormat))
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

  /// The time scale under the bottom pane: on one day, 24-hour market time ("14:30") whatever
  /// the Mac's clock setting; over a longer range, where each session, week, month or quarter
  /// begins (the candles sit back to back there, so clock times would not read).
  @AxisContentBuilder private var timeAxis: some AxisContent {
    if plot.axisMarks.isEmpty {
      AxisMarks(values: .automatic) { value in
        AxisGridLine()
        AxisTick()
        AxisValueLabel {
          if let date = value.as(Date.self) {
            Text(verbatim: Format.marketMinute(date))
          }
        }
      }
    } else {
      let marks = rangeMarks
      let shown = windowDomain
      let byTime = Dictionary(marks.map { ($0.time, $0) }, uniquingKeysWith: { first, _ in first })
      AxisMarks(values: marks.map(\.time)) { value in
        AxisGridLine()
        AxisTick()
        // By time, never by position; near either end of the window a label hangs inward.
        let mark = value.as(Date.self).flatMap { byTime[$0] }
        AxisValueLabel(anchor: Self.unitPoint(mark.map { ChartAxis.anchor(of: $0.time, shown: shown) } ?? .centre)) {
          Text(verbatim: mark?.text ?? Format.missing)
            .fixedSize()
        }
      }
    }
  }

  /// The range's labels in the window, none closer than `timeLabelSlot`; where a year begins
  /// wins over the month before it.
  private var rangeMarks: [ChartAxisMark] {
    let shown = windowDomain
    let inside = plot.axisMarks.filter { shown.contains($0.time) }
    let plotWidth = chartWidth - Self.axisLabelWidth
    guard plotWidth > 0 else { return inside }
    let gap = visibleLength * Double(Self.timeLabelSlot / plotWidth)
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
      Text(verbatim: value.as(Double.self)?.formatted(Self.valueFormat) ?? Format.missing)
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

  // MARK: Geometry

  private var firstStart: Date { candles.first?.start ?? .now }
  private var lastEnd: Date { candles.last?.end ?? .now }

  /// Seconds of time on screen.
  var visibleLength: TimeInterval {
    guard let visible = viewport.shown(total: candles.count) else { return lastEnd.timeIntervalSince(firstStart) }
    return TimeInterval(visible) * series.timeframe.seconds
  }

  /// Opening time of the window on screen; while not scrolled it follows the newest candle.
  var windowStart: Date {
    viewport.position ?? max(firstStart, lastEnd.addingTimeInterval(-visibleLength))
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

  private func color(_ candle: Candle) -> Color { candle.isUp ? Palette.profit : Palette.loss }

  /// Prices of the candles, levels and drawn bands on screen, padded so nothing touches the edge.
  private var priceScale: ClosedRange<Double> {
    let shown = visibleIndices
    var prices = candles[shown].flatMap { [$0.low, $0.high] } + levels.map(\.price)
    if lines.bollinger {
      prices += shown.compactMap { plot.bollingerUpper[$0] } + shown.compactMap { plot.bollingerLower[$0] }
    }
    guard let low = prices.min(), let high = prices.max() else { return 0...1 }
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

  /// Axis labels and study values: two decimals.
  static let valueFormat = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(Money.centsDigits))
  /// The ATR pane's newest value: three decimals, as ATRs of cheap stocks are a few cents.
  static let atrFormat = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(atrDigits))
  static let atrDigits = 3
  /// Relative volume: one decimal ("2.6").
  static let ratioFormat = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(1))
  /// Share of the largest volume on screen left free above it, for the pane's name.
  static let volumeHeadroom = 0.35

  /// "23.4K": a volume in the person's language.
  static func volumeText(_ value: Double) -> String {
    value.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
  }

  /// A price as the readout and tags show it: cents, or four decimals under a dollar.
  static func price(_ value: Double) -> String {
    Money.price(Decimal(value))
  }
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
          Crosshair(pointer: pointer, plot: chart.plot, pane: pane, showsTime: showsTime, proxy: proxy)
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
    if pane == .price {
      content
        .chartXScale(domain: chart.xDomain)
        .chartScrollableAxes(chart.zoomed ? .horizontal : [])
        .chartXVisibleDomain(length: chart.visibleLength)
        .chartScrollPosition(x: chart.scrollPosition)
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
        let frame = geometry[plotFrame]
        ForEach(tags) { tag in
          if let y = proxy.position(forY: tag.value), y >= 0, y <= frame.height {
            Group {
              if tag.plain {
                ExtremeLabel(text: tag.text, color: tag.color)
              } else {
                TagPlate(text: tag.text, color: tag.color)
              }
            }
            .fixedSize()
            .position(x: frame.maxX + CandleChart.axisLabelWidth / 2 + Tokens.Space.xs, y: frame.minY + y)
          }
        }
      }
    }
    .allowsHitTesting(false)
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

  private var candles: [Candle] { plot.candles }

  var body: some View {
    GeometryReader { geometry in
      if let plotFrame = proxy.plotFrame {
        let frame = geometry[plotFrame]
        if let index = pointer.index, candles.indices.contains(index),
          let x = proxy.position(forX: candles[index].middle), x >= 0, x <= frame.width {
          let top = pane == .price ? frame.minY : 0
          let bottom = showsTime ? frame.maxY : geometry.size.height
          Rectangle()
            .fill(Palette.textTertiary.opacity(Tokens.Opacity.medium))
            .frame(width: Tokens.Stroke.hairline, height: bottom - top)
            .position(x: frame.minX + x, y: (top + bottom) / 2)
          if showsTime {
            TagPlate(text: plot.timeText(index), color: Palette.textSecondary)
              .fixedSize()
              .position(x: frame.minX + x, y: frame.maxY + Tokens.Space.s)
          }
        }
        if let hover = pointer.hover, hover.pane == pane, frame.contains(hover.location),
          let value = proxy.value(atY: hover.location.y - frame.minY, as: Double.self) {
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
    .allowsHitTesting(false)
  }

  private func text(_ value: Double) -> String {
    pane == .price ? CandleChart.price(value) : value.formatted(CandleChart.valueFormat)
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
      HStack(spacing: Tokens.Space.m) {
        Text(verbatim: plot.timeText(index))
          .foregroundStyle(Palette.textSecondary)
        value(L10n.Chart.open, CandleChart.price(candle.open))
        value(L10n.Chart.high, CandleChart.price(candle.high))
        value(L10n.Chart.low, CandleChart.price(candle.low))
        value(L10n.Chart.close, CandleChart.price(candle.close))
        if let change = series.candles.change(at: index) {
          Text(verbatim: Self.changeText(change))
            .foregroundStyle(change.amount >= 0 ? Palette.profitText : Palette.lossText)
        }
        value(L10n.Chart.volumeShort, CandleChart.volumeText(candle.volume))
      }
      .font(Tokens.Typography.annotation)
      .monospacedDigit()
      .contentTransition(.numericText())
      .lineLimit(1)
      .fixedSize()
      // One line, cut at the edge when the window is narrow: values that wrapped made the
      // readout's height (and with it the window's least size) change on every pointed candle,
      // and AppKit re-laid the window inside its own layout pass until it threw.
      .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
      .clipped()
    }
  }

  /// "+0.21 (+6.21%)": the change in price and as a percentage, always signed.
  static func changeText(_ change: CandleChange) -> String {
    let amount = change.amount.formatted(
      .number.precision(.fractionLength(Money.centsDigits)).sign(strategy: .always()))
    let percent = change.fraction.formatted(
      .percent.precision(.fractionLength(Money.centsDigits)).sign(strategy: .always()))
    return String(localized: L10n.Chart.change(amount, percent))
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
        HStack(spacing: Tokens.Space.m) {
          ForEach(Array(items.enumerated()), id: \.offset) { _, item in
            HStack(spacing: Tokens.Space.xs) {
              Text(item.name)
              Text(verbatim: CandleChart.price(item.value))
            }
            .foregroundStyle(item.color)
          }
        }
        .font(Tokens.Typography.annotation)
        .monospacedDigit()
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, Tokens.Space.xs)
        .background(Palette.surfaceSunken.opacity(Tokens.Opacity.overlay), in: .rect(cornerRadius: Tokens.Radius.small))
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .clipped()
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
