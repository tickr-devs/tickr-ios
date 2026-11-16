import SwiftUI
import TickrDesign
import TickrKit

/// Chart screen: the symbol with its last price and the pointed candle's values on top, the range,
/// interval, chart type, zoom and study chips under it, then the candles of the shown day (or a
/// longer range) with the bot's lines, its trades and the open position's entry and stop, in a
/// card. Beside it, the rail: the symbols to pick from, what the strategy decided at the pointed
/// candle, and the open position. Live days refresh as new M1 bars arrive.
struct ChartView: View {
  @Environment(AppModel.self) private var model
  @Environment(ChartModel.self) private var chart
  @State private var viewport = Viewport.opening
  /// The candle under the pointer: the chart, the header's readout and the explain card share it.
  @State private var pointer = ChartPointer()
  @AppStorage(Keys.symbol) private var picked = ""
  @AppStorage(Keys.timeframe) private var timeframe: Timeframe = .m1
  @AppStorage(Keys.range) private var range: ChartRange = .oneDay
  @AppStorage(Keys.vwap) private var showVWAP = true
  @AppStorage(Keys.fastEMA) private var showFastEMA = true
  @AppStorage(Keys.slowEMA) private var showSlowEMA = true
  @AppStorage(Keys.volume) private var showVolume = true
  @AppStorage(Keys.atr) private var showATR = false
  @AppStorage(Keys.style) private var style: ChartStyle = .candles
  @AppStorage(Keys.movingAverages) private var showMovingAverages = false
  @AppStorage(Keys.bollinger) private var showBollinger = false
  @AppStorage(Keys.macd) private var showMACD = false
  @AppStorage(Keys.rsi) private var showRSI = true
  @AppStorage(Keys.stochastic) private var showStochastic = false
  @AppStorage(Keys.marks) private var showMarks = true
  @AppStorage(Keys.decisions) private var showDecisions = true

  /// Settings keys of the chart's choices; Trades sets `symbol` for "Show on Chart".
  enum Keys {
    /// The symbol the chart shows.
    static let symbol = "chart.symbol"
    /// The candle timeframe.
    static let timeframe = "chart.timeframe"
    /// How far back the chart reaches.
    static let range = "chart.range"
    /// Whether the VWAP line is drawn.
    static let vwap = "chart.vwap"
    /// Whether the fast EMA line is drawn.
    static let fastEMA = "chart.emaFast"
    /// Whether the slow EMA line is drawn.
    static let slowEMA = "chart.emaSlow"
    /// Whether the volume pane is shown.
    static let volume = "chart.volume"
    /// Whether the ATR pane is shown.
    static let atr = "chart.atr"
    /// Candles or a filled close line.
    static let style = "chart.style"
    /// Whether the moving-average lines are drawn.
    static let movingAverages = "chart.movingAverages"
    /// Whether the Bollinger bands are drawn.
    static let bollinger = "chart.bollinger"
    /// Whether the MACD pane is shown.
    static let macd = "chart.macd"
    /// Whether the RSI pane is shown.
    static let rsi = "chart.rsi"
    /// Whether the stochastic pane is shown.
    static let stochastic = "chart.stochastic"
    /// Whether the trades, the position's levels and the decisions are drawn on the price pane.
    static let marks = "chart.marks"
    /// Whether the rail (symbols, the explain card, the position) is shown beside the chart.
    static let decisions = "chart.decisions"
  }

  /// Height of the separators between chip groups, in points.
  static let separatorHeight: CGFloat = 20
  /// Key equivalent of the rail (with ⌥⌘), as for inspectors in Apple's apps.
  static let decisionsKey: KeyEquivalent = "i"
  /// Accessibility id of the rail's toggle, for the UI tests.
  static let decisionsToggleID = "chart-decisions"
  /// SF Symbols of the chip-row buttons.
  static let zoomOutSymbol = "minus"
  static let zoomInSymbol = "plus"
  static let fitSymbol = "arrow.up.left.and.arrow.down.right"
  static let railSymbol = "sidebar.trailing"
  static let candlesSymbol = "chart.bar.fill"
  static let lineSymbol = "chart.xyaxis.line"
  static let menuSymbol = "chevron.down"

  /// What a read depends on: a change starts a new read and forgets the old bars.
  private struct LoadKey: Equatable {
    let baseURL: URL
    let symbol: String?
    let day: WireDate
    let live: Bool
    let range: ChartRange
    let interval: Timeframe
  }

  var body: some View {
    // The rail as a fixed-width pane beside the chart, not an `.inspector` split: on macOS 27
    // every split-view form (nested in the screen, or a column of the window) let the columns'
    // least sizes and safe areas resize each other inside AppKit's layout pass until it threw
    // ("needs another Update Constraints in Window pass").
    HStack(alignment: .top, spacing: Tokens.Space.l) {
      VStack(alignment: .leading, spacing: Tokens.Space.m) {
        header
        controls
        content
          .padding(Tokens.Space.s)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(Palette.surfaceSunken, in: .rect(cornerRadius: Tokens.Radius.large))
          // Nothing the chart draws (crosshair, tags) reaches past its card.
          .clipShape(.rect(cornerRadius: Tokens.Radius.large))
          .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.large)
              .strokeBorder(Palette.separator, lineWidth: Tokens.Stroke.thin))
        historyScroller
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      if showDecisions {
        ChartRail(
          symbol: symbol, symbols: symbols, pick: { picked = $0 }, plot: showsDay ? plot : nil, pointer: pointer,
          decisions: chart.decisions, error: chart.decisionsError, showsDay: showsDay,
          position: model.positions.first { $0.id == symbol })
          .frame(width: ChartRail.width)
          .frame(maxHeight: .infinity, alignment: .top)
          .transition(.move(edge: .trailing).combined(with: .opacity))
      }
    }
    .padding(Tokens.Space.l)
    .animation(Tokens.Motion.standard, value: showDecisions)
    .task(id: LoadKey(
      baseURL: model.baseURL, symbol: symbol, day: model.shownDay, live: model.isLive, range: range,
      interval: interval)
    ) {
      await keepLoading()
    }
    // The Overview read newer bars of this position: the chart shows them too.
    .onChange(of: symbol.flatMap { model.isLive && showsDay ? model.positionBars($0) : nil }) { _, newer in
      if let newer { chart.adopt(newer) }
    }
  }

  // MARK: Data

  /// Symbols with something to show: open positions first, then symbols with recorded bars,
  /// then symbols traded on the shown day, then the watched symbols and the screeners'
  /// candidates (the rail lists them).
  private var symbols: [String] {
    let document = model.isLive ? model.todayDocument : model.dayDocument
    let all = model.positions.map(\.id) + (document?.barSymbols ?? []) + model.shownTrades.map(\.symbol)
      + ChartRail.watched(model.watching) + ChartRail.candidates(model.flow).map(\.symbol)
    var seen = Set<String>()
    return all.filter { seen.insert($0).inserted }
  }

  /// The picked symbol while it has something to show, else the first that does.
  private var symbol: String? { symbols.contains(picked) ? picked : symbols.first }

  /// The picked interval while the range offers it, else the range's shortest.
  private var interval: Timeframe { range.intervals.contains(timeframe) ? timeframe : range.intervals.first ?? .m1 }

  /// Whether the chart shows the shown day's recorded bars (with trades and decisions), not a
  /// longer range of market data.
  private var showsDay: Bool { range == .oneDay }

  private func keepLoading() async {
    chart.clear()
    chart.hasSymbol = symbol != nil
    viewport = Viewport.opening
    pointer.index = nil
    guard let symbol else { return }
    let baseURL = model.baseURL
    let day = model.shownDay
    let live = model.isLive
    chart.shown = ChartModel.Shown(symbol: symbol, range: range, interval: interval)
    guard showsDay else {
      let shownRange = range
      let shownInterval = interval
      // Market data over several sessions or months: it reaches today whatever day is shown, and
      // only intraday candles (five sessions) still change during the day.
      repeat {
        await chart.loadRange(baseURL: baseURL, symbol: symbol, interval: shownInterval, range: shownRange)
        guard shownInterval.isIntraday else { return }
        try? await Task.sleep(for: .seconds(Pace.chartSeconds))
      } while !Task.isCancelled
      return
    }
    repeat {
      await chart.load(baseURL: baseURL, symbol: symbol, day: day)
      // One price for one moment on every screen: the Overview's position card takes these bars.
      if live, let bars = chart.bars { model.noteBars(bars) }
      await chart.loadDecisions(baseURL: baseURL, symbol: symbol, day: day)
      guard live else { return }
      try? await Task.sleep(for: .seconds(Pace.barsSeconds))
    } while !Task.isCancelled
  }

  // MARK: Header

  /// The symbol (a menu of the others), its last price and the day's change, and the pointed
  /// candle's values on the right.
  private var header: some View {
    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.m) {
      symbolMenu
      if let last = plot?.candles.last {
        Text(verbatim: CandleChart.price(last.close))
          .font(Tokens.Typography.quote)
          // Coloured as the day's change beside it when the screeners reported one, so the two
          // never disagree; else by the last candle.
          .foregroundStyle(dayChange.map { Palette.result($0) } ?? (last.isUp ? Palette.profitText : Palette.lossText))
          .contentTransition(.numericText(value: last.close))
          .animation(Tokens.Motion.quick, value: last.close)
      }
      if let change = dayChange {
        Text(verbatim: change.formatted(.percent.precision(.fractionLength(Money.centsDigits)).sign(strategy: .always())))
          .font(Tokens.Typography.calloutMono)
          .foregroundStyle(Palette.result(change))
          .help(Text(L10n.Chart.dayChangeHelp))
      }
      Spacer(minLength: Tokens.Space.m)
      if let plot {
        ChartReadout(plot: plot, pointer: pointer)
          .layoutPriority(-1)
      }
    }
  }

  /// The day's change of the shown symbol from the previous close, when the screeners reported
  /// it (the bars carry no previous close).
  private var dayChange: Decimal? {
    guard let symbol, let pct = model.flow?.chips.first(where: { $0.symbol == symbol })?.changePct else { return nil }
    return pct.value / Self.percentFactor
  }

  /// A percent of 1 is 0.01.
  static let percentFactor: Decimal = 100

  private var symbolMenu: some View {
    Menu {
      ForEach(symbols, id: \.self) { item in
        Button { picked = item } label: { Text(verbatim: item) }
      }
    } label: {
      HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.xs) {
        Text(verbatim: symbol ?? Format.missing)
          .font(Tokens.Typography.metric)
          .foregroundStyle(Palette.textPrimary)
        // The menu's chevron only while there is a symbol to pick: no promise of a menu
        // that would not open.
        if !symbols.isEmpty {
          Image(systemName: Self.menuSymbol)
            .font(Tokens.Typography.chevron)
            .foregroundStyle(Palette.textQuaternary)
        }
      }
      .contentShape(.rect)
    }
    .menuStyle(.button)
    .buttonStyle(.plain)
    .menuIndicator(.hidden)
    .fixedSize()
    .disabled(symbols.isEmpty)
    .help(Text(L10n.Chart.symbolHelp))
    .accessibilityLabel(Text(L10n.Chart.symbol))
    .accessibilityValue(Text(verbatim: symbol ?? Format.missing))
  }

  // MARK: Controls

  /// The range, interval and chart type chips with zoom, the live pill and the rail on the right;
  /// the study chips under them, wrapping in a narrow window.
  private var controls: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      // One row while it fits; in a narrow window the chips wrap onto a second row instead of
      // being squeezed into empty ovals.
      ViewThatFits(in: .horizontal) {
        HStack(spacing: Tokens.Space.xs) {
          rangeChips.fixedSize()
          separator
          intervalChips.fixedSize()
          separator
          styleChips.fixedSize()
          Spacer(minLength: Tokens.Space.s)
          tools
        }
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
          HStack(spacing: Tokens.Space.xs) {
            rangeChips.fixedSize()
            separator
            intervalChips.fixedSize()
          }
          HStack(spacing: Tokens.Space.xs) {
            styleChips.fixedSize()
            Spacer(minLength: Tokens.Space.s)
            tools
          }
        }
      }
      indicatorToggles
    }
    .fixedSize(horizontal: false, vertical: true)
  }

  /// Zoom, the decisions toggle and the live pill, at the right end of the controls.
  private var tools: some View {
    HStack(spacing: Tokens.Space.xs) {
      zoomButtons
      decisionsToggle
      if model.isLive && showsDay { livePill }
    }
    .fixedSize()
  }

  private var separator: some View {
    Rectangle()
      .fill(Palette.separatorStrong)
      .frame(width: Tokens.Stroke.thin, height: Self.separatorHeight)
      .padding(.horizontal, Tokens.Space.xs)
  }

  private var rangeChips: some View {
    HStack(spacing: Tokens.Space.xs) {
      ForEach(ChartRange.allCases, id: \.self) { item in
        Button { range = item } label: { Text(Self.title(item)) }
          .buttonStyle(.chip(selected: range == item))
      }
    }
    .help(Text(L10n.Chart.rangeHelp))
    .accessibilityElement(children: .contain)
    .accessibilityLabel(Text(L10n.Chart.rangeLabel))
  }

  /// "Day", "5D", "1M": the range as charting apps name it.
  static func title(_ range: ChartRange) -> LocalizedStringResource {
    switch range {
    case .oneDay: L10n.Chart.rangeDay
    case .fiveDays: L10n.Chart.rangeFiveDays
    case .oneMonth: L10n.Chart.rangeOneMonth
    case .threeMonths: L10n.Chart.rangeThreeMonths
    case .oneYear: L10n.Chart.rangeOneYear
    }
  }

  /// The range's intervals to pick from; a range with one (a month: daily) shows it as the one
  /// selected chip.
  private var intervalChips: some View {
    HStack(spacing: Tokens.Space.xs) {
      ForEach(range.intervals) { item in
        Button { timeframe = item } label: { Text(Self.title(item)) }
          .buttonStyle(.chip(selected: interval == item))
      }
    }
    .help(Text(L10n.Chart.timeframeHelp))
    .accessibilityElement(children: .contain)
    .accessibilityLabel(Text(L10n.Chart.timeframeLabel))
  }

  /// "1m", "5m", "1h": the interval as charting apps name it.
  static func title(_ timeframe: Timeframe) -> LocalizedStringResource {
    switch timeframe {
    case .d1: L10n.Chart.intervalDay
    case .w1: L10n.Chart.intervalWeek
    case .mo1: L10n.Chart.intervalMonth
    default: timeframe.hours.map(L10n.Chart.intervalHours) ?? L10n.Chart.intervalMinutes(timeframe.minutes ?? 1)
    }
  }

  private var styleChips: some View {
    HStack(spacing: Tokens.Space.xs) {
      Button { style = .candles } label: {
        Label { Text(L10n.Chart.candles) } icon: { Image(systemName: Self.candlesSymbol) }
      }
      .buttonStyle(.chip(selected: style == .candles))
      Button { style = .line } label: {
        Label { Text(L10n.Chart.lineStyle) } icon: { Image(systemName: Self.lineSymbol) }
      }
      .buttonStyle(.chip(selected: style == .line))
    }
    .help(Text(L10n.Chart.styleHelp))
  }

  /// A chip showing one symbol, named for VoiceOver.
  private func chip(
    _ systemImage: String, title: LocalizedStringResource, selected: Bool = false, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) { Image(systemName: systemImage) }
      .buttonStyle(.chip(selected: selected))
      .accessibilityLabel(Text(title))
  }

  /// Lines over the price (the bot's own first, then the studies), then the panes below it, then
  /// the trade marks, each group named as in the design.
  private var indicatorToggles: some View {
    ChipFlow(spacing: Tokens.Space.xs) {
      caption(L10n.Chart.onPrice, help: L10n.Chart.onPriceHelp)
      Toggle(isOn: $showVWAP) { Text(L10n.Chart.vwap) }
      Toggle(isOn: $showFastEMA) { Text(L10n.Chart.ema(Indicators.fastEMAPeriod)) }
      Toggle(isOn: $showSlowEMA) { Text(L10n.Chart.ema(Indicators.slowEMAPeriod)) }
      Toggle(isOn: $showMovingAverages) { Text(L10n.Chart.movingAverageChip) }
        .help(Text(L10n.Chart.movingAverageHelp))
      Toggle(isOn: $showBollinger) { Text(L10n.Chart.bollinger) }
        .help(Text(L10n.Chart.bollingerHelp(Studies.bollingerPeriod)))
      separator
      caption(L10n.Chart.panes, help: L10n.Chart.panesHelp)
      Toggle(isOn: $showVolume) { Text(L10n.Chart.volume) }
      Toggle(isOn: $showATR) { Text(L10n.Chart.atrChip) }
        .help(Text(L10n.Chart.atr(Indicators.atrPeriod)))
      Toggle(isOn: $showRSI) { Text(L10n.Chart.rsiChip) }
        .help(Text(L10n.Chart.rsiHelp(Studies.rsiPeriod)))
      Toggle(isOn: $showMACD) { Text(L10n.Chart.macd) }
        .help(Text(L10n.Chart.macdHelp(Studies.macdFast, Studies.macdSlow, Studies.macdSignal)))
      Toggle(isOn: $showStochastic) { Text(L10n.Chart.stochastic) }
        .help(Text(L10n.Chart.stochasticHelp(Studies.stochasticPeriod, Studies.stochasticSmoothing)))
      separator
      Toggle(isOn: $showMarks) { Text(L10n.Chart.tradesChip) }
        .help(Text(L10n.Chart.tradesChipHelp))
        .disabled(!showsDay)
    }
    .toggleStyle(.chip)
  }

  /// A group's name in the study chips ("ON PRICE", "PANES").
  private func caption(_ title: LocalizedStringResource, help: LocalizedStringResource) -> some View {
    Text(title)
      .textCase(.uppercase)
      .font(Tokens.Typography.annotationBold)
      .tracking(Tokens.Typography.labelTracking)
      .foregroundStyle(Palette.textQuaternary)
      .padding(.trailing, Tokens.Space.xxs)
      .help(Text(help))
  }

  private var zoomButtons: some View {
    HStack(spacing: Tokens.Space.xs) {
      chip(Self.zoomOutSymbol, title: L10n.Chart.zoomOut) { viewport.zoomOut(total: candleCount) }
        .keyboardShortcut(Viewport.zoomOutKey, modifiers: .command)
        .help(Text(L10n.Chart.zoomOutHelp))
        .disabled(viewport.shown(total: candleCount) == nil)
      chip(Self.zoomInSymbol, title: L10n.Chart.zoomIn) { viewport.zoomIn(total: candleCount) }
        .keyboardShortcut(Viewport.zoomInKey, modifiers: .command)
        .help(Text(L10n.Chart.zoomInHelp))
        .disabled(!viewport.canZoomIn(total: candleCount))
      chip(Self.fitSymbol, title: L10n.Chart.fit) { viewport.fit() }
        .keyboardShortcut(Viewport.fitKey, modifiers: .command)
        .help(Text(L10n.Chart.fitHelp))
        .disabled(!viewport.canFit(total: candleCount))
    }
    .disabled(candleCount == 0)
  }

  /// "scroll history": a slider over the candles that moves the zoomed window; at the newest
  /// candles (and disabled) while the whole range is shown.
  private var historyScroller: some View {
    let total = candleCount
    let shown = viewport.shown(total: total) ?? total
    let last = Double(max(total - shown, 0))
    return HStack(spacing: Tokens.Space.m) {
      Text(L10n.Chart.scrollHistory)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
        .fixedSize()
      Slider(
        value: Binding(
          get: {
            guard let plot, let position = viewport.position, let index = plot.index(at: position) else { return last }
            return min(Double(index), last)
          },
          set: { value in
            guard let plot, plot.candles.indices.contains(Int(value)) else { return }
            viewport.position = Int(value) >= Int(last) ? nil : plot.candles[Int(value)].start
          }),
        in: 0...max(last, 1))
      .tint(Palette.highlight)
      .controlSize(.small)
      .disabled(viewport.shown(total: total) == nil)
    }
    .help(Text(L10n.Chart.scrollHistoryHelp))
  }

  /// "● LIVE" while the chart follows the live day; its dot pulses once per new M1 bar.
  private var livePill: some View {
    let shape = RoundedRectangle(cornerRadius: Tokens.Radius.chip, style: .continuous)
    return HStack(spacing: Tokens.Space.xs) {
      PulseDot(Palette.profit, size: Tokens.Size.dotSmall, event: chart.newestBar)
      Text(L10n.Chart.live).textCase(.uppercase)
    }
    .font(Tokens.Typography.label)
    .foregroundStyle(Palette.profitText)
    .padding(.horizontal, Tokens.Space.s)
    .padding(.vertical, Tokens.Space.xs + Tokens.Space.xxs)
    .background(Palette.profit.opacity(Tokens.Opacity.wash), in: shape)
    .overlay(shape.strokeBorder(Palette.profit, lineWidth: Tokens.Stroke.thin))
    .help(Text(L10n.Chart.liveHelp))
    .transition(.opacity)
  }

  private var decisionsToggle: some View {
    Toggle(isOn: $showDecisions) {
      Image(systemName: Self.railSymbol)
    }
    .toggleStyle(.chip)
    .keyboardShortcut(Self.decisionsKey, modifiers: [.command, .option])
    .help(Text(L10n.Chart.decisionsHelp))
    .accessibilityLabel(Text(L10n.Chart.decisions))
    .accessibilityIdentifier(Self.decisionsToggleID)
  }

  // MARK: Content

  /// The shown bars or range as candles and lines; built once per new read, range or interval
  /// (ChartModel).
  private var plot: ChartPlot? { chart.plot(timeframe: interval, range: range) }

  private var candleCount: Int { plot?.candles.count ?? 0 }

  /// Whether the trades, levels and decisions are drawn: one day only, while TRADES is on.
  private var marked: Bool { showsDay && showMarks }

  @ViewBuilder private var content: some View {
    if let symbol, let plot {
      CandleChart(
        plot: plot,
        lines: ChartLines(
          style: style, vwap: showVWAP, fastEMA: showFastEMA, slowEMA: showSlowEMA,
          movingAverages: showMovingAverages, bollinger: showBollinger, volume: showVolume,
          macd: showMACD, rsi: showRSI, stochastic: showStochastic, atr: showATR),
        marks: marked ? ChartMarkers.marks(trades: model.shownTrades.filter { $0.symbol == symbol }) : [],
        // The position's lines start at its entry minute: on one day only, as its trades.
        levels: marked ? ChartMarkers.levels(position: model.positions.first { $0.id == symbol }) : [],
        decisions: marked
          ? ChartMarkers.decisionMarks(decisions: chart.decisions?.decisions ?? [], candles: plot.candles) : [],
        // Only the shown live day and intraday ranges reaching today still change.
        live: model.isLive && (showsDay || interval.isIntraday),
        viewport: $viewport, pointer: pointer)
        // The bot's status arrives every few seconds and redraws this screen; the chart itself
        // only when what it draws changed.
        .equatable()
        .id(ChartID(symbol: symbol, day: model.shownDay, timeframe: interval, range: range))
        .transition(.opacity)
    } else if symbol == nil {
      empty(L10n.Chart.noSymbols, detail: L10n.Chart.noSymbolsDetail, symbol: "chart.xyaxis.line")
    } else if let error = chart.error {
      // Plain words, the cause behind Details; while the link is down the card waits calmly.
      ContentUnavailableView {
        Label { Text(L10n.Chart.barsUnavailable) } icon: { Image(systemName: "wifi.exclamationmark") }
      } description: {
        ReadFailureNote(showsDay ? L10n.Chart.barsUnavailableDetail : L10n.Chart.candlesUnavailableDetail,
          detail: error)
      }
    } else if let symbol, chart.loading || !chart.hasRead(timeframe: interval, range: range) {
      TickrLoader(
        L10n.Chart.loadingBars(symbol, interval: String(localized: Self.title(interval))), size: .large, caption: true)
    } else if !showsDay, let cause = chart.rangeCause {
      empty(L10n.Chart.noBars, detail: L10n.Chart.noCandlesDetail(cause), symbol: "chart.bar.xaxis")
    } else {
      empty(L10n.Chart.noBars, detail: L10n.Chart.noBarsDetail, symbol: "chart.bar.xaxis")
    }
  }

  private func empty(_ title: LocalizedStringResource, detail: LocalizedStringResource, symbol: String) -> some View {
    ContentUnavailableView {
      Label { Text(title) } icon: { Image(systemName: symbol) }
    } description: {
      Text(detail)
    }
  }
}

/// Identity of a drawn chart: a new symbol, day, timeframe or range redraws it from the start.
private struct ChartID: Hashable {
  let symbol: String
  let day: WireDate
  let timeframe: Timeframe
  let range: ChartRange
}

/// Which lines and panes the chart draws, and how it draws the price.
struct ChartLines: Equatable {
  let style: ChartStyle
  let vwap: Bool
  let fastEMA: Bool
  let slowEMA: Bool
  let movingAverages: Bool
  let bollinger: Bool
  /// The volume pane under the price pane.
  let volume: Bool
  let macd: Bool
  let rsi: Bool
  let stochastic: Bool
  let atr: Bool
}

/// How the price pane draws prices. Raw values are the stored setting.
enum ChartStyle: String, CaseIterable, Sendable {
  case candles
  case line
}

/// The visible window of the chart: how many candles fit, and where it is scrolled.
struct Viewport: Equatable {
  /// Candles on screen; nil shows the whole day.
  var visible: Int?
  /// Opening time of the first candle on screen; nil follows the newest candle.
  var position: Date?

  /// The closest zoom still shows this many candles.
  static let minimumVisible = 12
  /// Candles a chart opens on, the newest ones: at the design's candle width (about 9 points a
  /// candle across the plot) bodies and wicks stay clear, where a whole day of one-minute
  /// candles drew hairlines. Fit shows the whole range; the slider and the trackpad scroll back.
  static let openingCandles = 90
  /// The window a chart opens on: the newest `openingCandles`.
  static let opening = Viewport(visible: openingCandles)

  /// Candles on screen out of `total`; nil when the window holds them all (a range shorter than
  /// the window shows whole).
  func shown(total: Int) -> Int? {
    guard let visible, visible < total else { return nil }
    return visible
  }
  /// Key equivalents of the zoom buttons (with ⌘), as in Apple's apps.
  static let zoomInKey: KeyEquivalent = "="
  static let zoomOutKey: KeyEquivalent = "-"
  static let fitKey: KeyEquivalent = "0"

  /// Zoom in would show fewer candles: more than `minimumVisible` are on screen.
  func canZoomIn(total: Int) -> Bool { (shown(total: total) ?? total) > Self.minimumVisible }

  /// Fit would change the window: it is zoomed in or scrolled back from the newest candle.
  func canFit(total: Int) -> Bool { shown(total: total) != nil || position != nil }

  /// Shows fewer candles, down to `minimumVisible`.
  mutating func zoomIn(total: Int) {
    let next = max(Self.minimumVisible, Int((Double(shown(total: total) ?? total) / Tokens.Chart.zoomStep).rounded()))
    visible = next >= total ? nil : next
  }

  /// Shows more candles, up to the whole day.
  mutating func zoomOut(total: Int) {
    guard let visible = shown(total: total) else {
      visible = nil
      return
    }
    let next = Int((Double(visible) * Tokens.Chart.zoomStep).rounded())
    self.visible = next >= total ? nil : next
  }

  /// Shows `count` candles (a pinch), within `minimumVisible` and the whole day.
  mutating func show(_ count: Int, total: Int) {
    let next = max(Self.minimumVisible, count)
    visible = next >= total ? nil : next
  }

  /// Shows the whole day.
  mutating func fit() {
    visible = nil
    position = nil
  }
}

#if DEBUG
#Preview {
  ChartView()
    .environment(PreviewAPI.model())
    .environment(ChartModel())
    .frame(width: PreviewAPI.windowWidth, height: PreviewAPI.windowHeight)
}
#endif
