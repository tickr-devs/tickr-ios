import SwiftUI

// Skeleton shapes both apps lay their loading states out of (mockup v102): text lines, list rows,
// stat tiles, and the chart's candles and study panes. Each stands for the content it replaces;
// put them inside a `Skeleton`, which holds them still under its running bar.

/// Lines of text: a card's paragraphs or a short list. The first line can be a value (a figure).
public struct SkeletonLines: View {
  let count: Int
  let leadingValue: Bool

  /// Widths of successive lines, as shares of the width offered, so the lines read as text of
  /// uneven length (the board's 60 / 85 / 70 %), repeating.
  static let widths = [0.6, 0.85, 0.7, 0.5, 0.78]
  /// The width of a value line, as a share (the board's 45 %).
  static let valueWidth = 0.45

  /// - Parameters:
  ///   - count: how many lines.
  ///   - leadingValue: the first line is a value's block (a price, a total) rather than text.
  public init(_ count: Int, leadingValue: Bool = false) {
    self.count = count
    self.leadingValue = leadingValue
  }

  public var body: some View {
    GeometryReader { proxy in
      VStack(alignment: .leading, spacing: Tokens.Space.s) {
        ForEach(0..<count, id: \.self) { index in
          if leadingValue && index == 0 {
            SkeletonBlock(.value, width: proxy.size.width * Self.valueWidth)
          } else {
            SkeletonBlock(.line, width: proxy.size.width * Self.widths[index % Self.widths.count])
          }
        }
      }
    }
    .frame(height: height)
  }

  /// The lines' height: one block each, a small space apart.
  private var height: CGFloat {
    let blocks = (0..<count).reduce(CGFloat(0)) { sum, index in
      sum + (leadingValue && index == 0 ? Tokens.Loading.valueHeight : Tokens.Loading.lineHeight)
    }
    return blocks + CGFloat(max(count - 1, 0)) * Tokens.Space.s
  }
}

/// Rows of a list: a name on the left (a pill before it when `badge`), a short figure on the
/// right, a divider between rows, each row as tall as `rowHeight`.
public struct SkeletonRows: View {
  let count: Int
  let rowHeight: CGFloat
  let badge: Bool

  /// Widths of successive rows' names and figures, in points, so the rows differ, repeating.
  static let names: [CGFloat] = [64, 48, 80, 56, 72]
  static let figures: [CGFloat] = [44, 36, 52, 40, 30]
  /// Width of a row's pill (a badge or a state), in points.
  public static let pill: CGFloat = 52

  /// - Parameters:
  ///   - count: how many rows.
  ///   - rowHeight: each row's height, the real row's (`Loading.rowHeight` by default).
  ///   - badge: a pill after each name, as the real rows' badges.
  public init(_ count: Int, rowHeight: CGFloat = Tokens.Loading.rowHeight, badge: Bool = false) {
    self.count = count
    self.rowHeight = rowHeight
    self.badge = badge
  }

  public var body: some View {
    VStack(spacing: 0) {
      ForEach(0..<count, id: \.self) { index in
        if index > 0 { SkeletonGridLine() }
        HStack(spacing: Tokens.Space.s) {
          SkeletonBlock(.line, width: Self.names[index % Self.names.count])
          if badge { SkeletonBlock(.pill, width: Self.pill) }
          Spacer(minLength: Tokens.Space.s)
          SkeletonBlock(.line, width: Self.figures[index % Self.figures.count])
        }
        .frame(height: rowHeight)
      }
    }
  }
}

/// Stat tiles side by side: a label line over a value block in each.
public struct SkeletonTiles: View {
  let count: Int

  /// Width of a tile's label line, as a share of the tile; its value block takes `valueWidth`.
  static let labelWidth = 0.55
  static let valueWidth = 0.7

  public init(_ count: Int) {
    self.count = count
  }

  public var body: some View {
    HStack(spacing: Tokens.Space.s) {
      ForEach(0..<count, id: \.self) { _ in
        GeometryReader { proxy in
          VStack(alignment: .leading, spacing: Tokens.Space.s) {
            SkeletonBlock(.line, width: proxy.size.width * Self.labelWidth)
            SkeletonBlock(.value, width: proxy.size.width * Self.valueWidth)
          }
          .padding(Tokens.Space.s)
        }
        .frame(height: Tokens.Loading.lineHeight + Tokens.Loading.valueHeight + Tokens.Space.s + Tokens.Space.s + Tokens.Space.s)
        .background(Palette.surfaceSunken, in: .rect(cornerRadius: Tokens.Radius.medium))
      }
    }
  }
}

// MARK: - charts

/// The price pane of a chart while its bars load: the axis grid, a faint candle silhouette, the
/// price axis's labels on the right and, when `showsTime`, the time axis's under it; with
/// `volume`, faint volume bars along its bottom (the phone's chart draws volume in its price
/// pane). The candles follow a fixed gentle wave: a shape, never a price.
public struct SkeletonCandles: View {
  let candles: Int
  let rows: Int
  let columns: Int
  let axisWidth: CGFloat
  let showsTime: Bool
  let volume: Bool
  let builds: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase

  /// The silhouette's wave: its middle and swing as shares of the plot's height, the swing of a
  /// candle's body and of its wicks, and the wave's pace (radians a candle) — two slow waves so
  /// it reads as a day of prices, not a sine.
  static let middle = 0.5
  static let swing = 0.22
  static let ripple = 0.06
  static let slowPace = 0.11
  static let fastPace = 0.47
  static let body = 0.05
  static let wick = 0.035
  /// Share of a candle's slot its body fills, as on the real chart.
  static let bodyShare = 0.62
  /// Volume bars: their tallest as a share of the plot, and the share the shortest keeps.
  static let volumeShare = 0.16
  static let volumeLeast = 0.25
  /// Width of a label on the price and time axes, in points.
  static let priceLabel: CGFloat = 32
  static let timeLabel: CGFloat = 30
  /// Space between the plot and the price axis's labels, in points.
  static let axisGap: CGFloat = 6

  /// - Parameters:
  ///   - candles: candles in the silhouette (the real chart's opening count).
  ///   - rows / columns: the axis grid's lines across and down.
  ///   - axisWidth: the price axis's width on the right, the real chart's.
  ///   - showsTime: the time axis's labels under the plot.
  ///   - volume: faint volume bars along the bottom of the plot.
  ///   - builds: the candles build in left to right, hold and fade, over and over (loader E,
  ///     `build(_:of:at:)`); still, every candle shown, when false or under Reduce Motion.
  public init(
    candles: Int, rows: Int, columns: Int, axisWidth: CGFloat, showsTime: Bool = true, volume: Bool = false,
    builds: Bool = false
  ) {
    self.candles = candles
    self.rows = rows
    self.columns = columns
    self.axisWidth = axisWidth
    self.showsTime = showsTime
    self.volume = volume
    self.builds = builds
  }

  public var body: some View {
    let still = !builds || reduceMotion || scenePhase != .active
    // decorative: the candles build while the chart's bars load, only while it shows (loader E).
    TimelineView(.animation(paused: still)) { timeline in
      let phase = still ? Tokens.Loading.buildRestPhase : Self.phase(at: timeline.date)
      Canvas { context, size in
        let timeRoom = showsTime ? Tokens.Loading.lineHeight + Tokens.Space.s : 0
        let plot = CGRect(x: 0, y: 0, width: max(size.width - axisWidth, 0),
          height: max(size.height - timeRoom, 0))
        drawGrid(&context, plot: plot)
        drawCandles(&context, plot: plot, phase: phase)
        if volume { drawVolume(&context, plot: plot) }
        drawAxes(&context, plot: plot, size: size)
      }
    }
    .accessibilityHidden(true)
  }

  /// Where the build is at `date`, as a share of its cycle (`Loading.buildSeconds`): a function of
  /// the wall clock, so every loading chart builds together and one built again goes on.
  public static func phase(at date: Date) -> Double {
    let seconds = Tokens.Loading.buildSeconds
    return date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: seconds) / seconds
  }

  /// A candle's look at `phase` of the build: its opacity and its height as a share of its own.
  /// Candle `index` of `count` rises in (from `Loading.buildLowScale` and clear, eased) starting
  /// at `buildStart` plus its share of `buildSpread`, so they rise left to right; all hold until
  /// `buildHoldEnd`, then fade out together by `buildFadeEnd` and stay clear to the cycle's end.
  public static func build(_ index: Int, of count: Int, at phase: Double) -> (opacity: Double, scale: Double) {
    let start = Tokens.Loading.buildStart + Double(index) * Tokens.Loading.buildSpread / Double(max(count, 1))
    let low = Tokens.Loading.buildLowScale
    if phase < start { return (0, low) }
    if phase < start + Tokens.Loading.buildRise {
      let rise = Tokens.Loading.buildRiseCurve.value(at: (phase - start) / Tokens.Loading.buildRise)
      return (rise, low + (1 - low) * rise)
    }
    if phase < Tokens.Loading.buildHoldEnd { return (1, 1) }
    if phase < Tokens.Loading.buildFadeEnd {
      let span = Tokens.Loading.buildFadeEnd - Tokens.Loading.buildHoldEnd
      let fade = Tokens.Loading.buildFadeCurve.value(at: (phase - Tokens.Loading.buildHoldEnd) / span)
      return (1 - fade, 1)
    }
    return (0, 1)
  }

  private func drawGrid(_ context: inout GraphicsContext, plot: CGRect) {
    var grid = Path()
    for row in 1...max(rows, 1) {
      let y = plot.minY + plot.height * CGFloat(row) / CGFloat(rows + 1)
      grid.addRect(CGRect(x: plot.minX, y: y, width: plot.width, height: Tokens.Stroke.hairline))
    }
    for column in 1...max(columns, 1) {
      let x = plot.minX + plot.width * CGFloat(column) / CGFloat(columns + 1)
      grid.addRect(CGRect(x: x, y: plot.minY, width: Tokens.Stroke.hairline, height: plot.height))
    }
    // The plot's right edge, where the price axis begins.
    grid.addRect(CGRect(x: plot.maxX, y: plot.minY, width: Tokens.Stroke.hairline, height: plot.height))
    context.fill(grid, with: .color(SkeletonGridLine.color))
  }

  private func drawCandles(_ context: inout GraphicsContext, plot: CGRect, phase: Double) {
    guard candles > 0 else { return }
    let slot = plot.width / CGFloat(candles)
    for index in 0..<candles {
      let look = Self.build(index, of: candles, at: phase)
      guard look.opacity > 0 else { continue }
      var shape = Path()
      let wave = Self.wave(index)
      let middle = plot.minY + plot.height * (1 - wave)
      let half = plot.height * Self.body * (1 + abs(sin(Double(index) * Self.fastPace))) / 2 * look.scale
      let reach = half + plot.height * Self.wick * look.scale
      let x = plot.minX + slot * CGFloat(index)
      let width = slot * Self.bodyShare
      let centre = x + slot / 2
      shape.addRect(CGRect(x: centre - Tokens.Stroke.thin / 2, y: middle - reach, width: Tokens.Stroke.thin,
        height: reach + reach))
      shape.addRoundedRect(in: CGRect(x: centre - width / 2, y: middle - half, width: width, height: half + half),
        cornerSize: CGSize(width: Tokens.Stroke.regular, height: Tokens.Stroke.regular))
      context.fill(shape, with: .color(SkeletonBlock.fill.opacity(look.opacity)))
    }
  }

  private func drawVolume(_ context: inout GraphicsContext, plot: CGRect) {
    guard candles > 0 else { return }
    let slot = plot.width / CGFloat(candles)
    var bars = Path()
    for index in 0..<candles {
      let share = Self.volumeLeast + (1 - Self.volumeLeast) * abs(sin(Double(index) * Self.fastPace))
      let height = plot.height * Self.volumeShare * share
      let width = slot * Self.bodyShare
      bars.addRect(CGRect(x: plot.minX + slot * CGFloat(index) + (slot - width) / 2, y: plot.maxY - height,
        width: width, height: height))
    }
    context.fill(bars, with: .color(SkeletonBlock.fill.opacity(Tokens.Opacity.medium)))
  }

  private func drawAxes(_ context: inout GraphicsContext, plot: CGRect, size: CGSize) {
    var labels = Path()
    let radius = CGSize(width: Tokens.Loading.lineRadius, height: Tokens.Loading.lineRadius)
    let labelWidth = min(Self.priceLabel, max(axisWidth - Self.axisGap - Self.axisGap, 0))
    for row in 1...max(rows, 1) {
      let y = plot.minY + plot.height * CGFloat(row) / CGFloat(rows + 1)
      labels.addRoundedRect(in: CGRect(x: plot.maxX + Self.axisGap, y: y - Tokens.Loading.lineHeight / 2,
        width: labelWidth, height: Tokens.Loading.lineHeight), cornerSize: radius)
    }
    if showsTime {
      for column in 1...max(columns, 1) {
        let x = plot.minX + plot.width * CGFloat(column) / CGFloat(columns + 1)
        labels.addRoundedRect(in: CGRect(x: x - Self.timeLabel / 2, y: size.height - Tokens.Loading.lineHeight,
          width: Self.timeLabel, height: Tokens.Loading.lineHeight), cornerSize: radius)
      }
    }
    context.fill(labels, with: .color(SkeletonBlock.fill))
  }

  /// Height of the silhouette at candle `index`, as a share of the plot (0 bottom, 1 top).
  static func wave(_ index: Int) -> Double {
    let step = Double(index)
    return middle + swing * sin(step * slowPace) + ripple * sin(step * fastPace)
  }
}

/// A study pane (volume, ATR, RSI, MACD, stochastic) while the chart's bars load: its legend's
/// line at the top left and a faint band across the middle, the price axis's width left free.
public struct SkeletonPane: View {
  let axisWidth: CGFloat

  /// Width of the legend's line, in points (the board's 110).
  static let legend: CGFloat = 110
  /// Height of the band across the pane, in points (the board's 6).
  static let band: CGFloat = 6

  public init(axisWidth: CGFloat) {
    self.axisWidth = axisWidth
  }

  public var body: some View {
    ZStack(alignment: .topLeading) {
      SkeletonBlock(.block(height: Self.band))
        .padding(.trailing, axisWidth)
        .frame(maxHeight: .infinity)
      SkeletonBlock(.line, width: Self.legend)
        .padding(.top, Tokens.Space.xs + Tokens.Space.xxs)
    }
    .padding(.horizontal, Tokens.Space.s)
    .accessibilityHidden(true)
  }
}

/// The time axis's labels under a chart's bottom pane while its bars load: one block under each
/// of the grid's `columns` lines, the price axis's width left free on the right.
public struct SkeletonTimeAxis: View {
  let columns: Int
  let axisWidth: CGFloat

  public init(columns: Int, axisWidth: CGFloat) {
    self.columns = columns
    self.axisWidth = axisWidth
  }

  public var body: some View {
    Canvas { context, size in
      let width = max(size.width - axisWidth, 0)
      let radius = CGSize(width: Tokens.Loading.lineRadius, height: Tokens.Loading.lineRadius)
      var labels = Path()
      for column in 1...max(columns, 1) {
        let x = width * CGFloat(column) / CGFloat(columns + 1)
        labels.addRoundedRect(in: CGRect(x: x - SkeletonCandles.timeLabel / 2,
          y: (size.height - Tokens.Loading.lineHeight) / 2, width: SkeletonCandles.timeLabel,
          height: Tokens.Loading.lineHeight), cornerSize: radius)
      }
      context.fill(labels, with: .color(SkeletonBlock.fill))
    }
    .accessibilityHidden(true)
  }
}
