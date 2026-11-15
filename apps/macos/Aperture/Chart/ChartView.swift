import ApertureDesign
import ApertureKit
import SwiftUI

/// Chart screen: candles of one symbol on the shown day with the bot's lines, its trades and the
/// open position's entry and stop. Live days refresh as new M1 bars arrive.
struct ChartView: View {
  @Environment(AppModel.self) private var model
  @Environment(ChartModel.self) private var chart
  @State private var viewport = Viewport()
  @AppStorage(Keys.symbol) private var picked = ""
  @AppStorage(Keys.timeframe) private var timeframe: Timeframe = .m1
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
  @AppStorage(Keys.decisions) private var showDecisions = false

  /// Settings keys of the chart's choices; Trades sets `symbol` for "Show on Chart".
  enum Keys {
    /// The symbol the chart shows.
    static let symbol = "chart.symbol"
    /// The candle timeframe.
    static let timeframe = "chart.timeframe"
    /// Whether the VWAP line is drawn.
    static let vwap = "chart.vwap"
    /// Whether the fast EMA line is drawn.
    static let fastEMA = "chart.emaFast"
    /// Whether the slow EMA line is drawn.
    static let slowEMA = "chart.emaSlow"
    /// Whether the volume bars are drawn along the bottom of the price pane.
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
    /// Whether the decisions inspector is shown.
    static let decisions = "chart.decisions"
  }

  /// Width of the symbol picker, in points.
  static let pickerWidth: CGFloat = 150
  /// Height of the separators between control groups, in points.
  static let separatorHeight: CGFloat = 18
  /// Key equivalent of the decisions inspector (with ⌥⌘), as for inspectors in Apple's apps.
  static let decisionsKey: KeyEquivalent = "i"
  /// Accessibility id of the decisions toggle, for the UI tests.
  static let decisionsToggleID = "chart-decisions"

  /// What a read depends on: a change starts a new read and forgets the old bars.
  private struct LoadKey: Equatable {
    let baseURL: URL
    let symbol: String?
    let day: WireDate
    let live: Bool
  }

  var body: some View {
    // The decisions as a fixed-width pane beside the chart, not an `.inspector` split: on
    // macOS 27 every split-view form (nested in the screen, or a column of the window) let the
    // columns' least sizes and safe areas resize each other inside AppKit's layout pass until it
    // threw ("needs another Update Constraints in Window pass").
    HStack(spacing: 0) {
      VStack(alignment: .leading, spacing: Tokens.Space.m) {
        controls
        content
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .padding(Tokens.Space.xl)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      if showDecisions {
        Divider()
        DecisionsInspector(decisions: chart.decisions, error: chart.decisionsError, hasSymbol: chart.hasSymbol)
          .frame(width: DecisionsInspector.width)
          .transition(.move(edge: .trailing))
      }
    }
    .animation(Tokens.Motion.standard, value: showDecisions)
    .task(id: LoadKey(baseURL: model.baseURL, symbol: symbol, day: model.shownDay, live: model.isLive)) {
      await keepLoading()
    }
  }

  // MARK: Data

  /// Symbols with something to show: open positions first, then symbols with recorded bars,
  /// then symbols traded on the shown day.
  private var symbols: [String] {
    let document = model.isLive ? model.todayDocument : model.dayDocument
    let all = model.positions.map(\.id) + (document?.barSymbols ?? []) + model.shownTrades.map(\.symbol)
    var seen = Set<String>()
    return all.filter { seen.insert($0).inserted }
  }

  /// The picked symbol while it has something to show, else the first that does.
  private var symbol: String? { symbols.contains(picked) ? picked : symbols.first }

  private func keepLoading() async {
    chart.clear()
    chart.hasSymbol = symbol != nil
    viewport = Viewport()
    guard let symbol else { return }
    let baseURL = model.baseURL
    let day = model.shownDay
    let live = model.isLive
    repeat {
      await chart.load(baseURL: baseURL, symbol: symbol, day: day)
      await chart.loadDecisions(baseURL: baseURL, symbol: symbol, day: day)
      guard live else { return }
      try? await Task.sleep(for: .seconds(Pace.barsSeconds))
    } while !Task.isCancelled
  }

  // MARK: Controls

  /// The symbol, interval, chart type, zoom and inspector on top; the indicator chips under them
  /// in a row that scrolls sideways when the window is narrow, so the chips never widen the
  /// window and push the sidebar or the inspector off screen.
  private var controls: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      ViewThatFits(in: .horizontal) {
        HStack(spacing: Tokens.Space.m) {
          symbolPicker
          timeframePicker
          stylePicker
          Spacer(minLength: Tokens.Space.m)
          zoomButtons
          decisionsToggle
        }
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
          HStack(spacing: Tokens.Space.m) {
            symbolPicker
            Spacer(minLength: Tokens.Space.m)
            zoomButtons
            decisionsToggle
          }
          HStack(spacing: Tokens.Space.m) {
            timeframePicker
            stylePicker
          }
        }
      }
      ScrollView(.horizontal) {
        indicatorToggles
      }
      .scrollIndicators(.never)
    }
    .animation(Tokens.Motion.quick, value: symbols)
  }

  private var symbolPicker: some View {
    Picker(selection: Binding(get: { symbol ?? picked }, set: { picked = $0 })) {
      ForEach(symbols, id: \.self) { item in
        Text(verbatim: item).tag(item)
      }
    } label: {
      Text(L10n.Chart.symbol)
    }
    .frame(width: Self.pickerWidth)
    .disabled(symbols.isEmpty)
  }

  private var timeframePicker: some View {
    Picker(selection: $timeframe) {
      ForEach(ChartRange.oneDay.intervals) { item in
        Text(Self.title(item)).tag(item)
      }
    } label: {
      Text(L10n.Chart.timeframeLabel)
    }
    .pickerStyle(.segmented)
    .labelsHidden()
    .fixedSize()
    .help(Text(L10n.Chart.timeframeHelp))
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

  private var stylePicker: some View {
    Picker(selection: $style) {
      Label { Text(L10n.Chart.candles) } icon: { Image(systemName: "chart.bar.fill") }
        .tag(ChartStyle.candles)
      Label { Text(L10n.Chart.lineStyle) } icon: { Image(systemName: "chart.xyaxis.line") }
        .tag(ChartStyle.line)
    } label: {
      Text(L10n.Chart.styleLabel)
    }
    .pickerStyle(.segmented)
    .labelStyle(.iconOnly)
    .labelsHidden()
    .fixedSize()
    .help(Text(L10n.Chart.styleHelp))
  }

  /// Lines over the price (the bot's own first, then the studies), then the panes below it.
  private var indicatorToggles: some View {
    HStack(spacing: Tokens.Space.xs) {
      Toggle(isOn: $showVWAP) { Text(L10n.Chart.vwap) }
      Toggle(isOn: $showFastEMA) { Text(L10n.Chart.ema(Indicators.fastEMAPeriod)) }
      Toggle(isOn: $showSlowEMA) { Text(L10n.Chart.ema(Indicators.slowEMAPeriod)) }
      Toggle(isOn: $showMovingAverages) { Text(L10n.Chart.movingAverageChip) }
        .help(Text(L10n.Chart.movingAverageHelp))
      Toggle(isOn: $showBollinger) { Text(L10n.Chart.bollinger) }
        .help(Text(L10n.Chart.bollingerHelp(Studies.bollingerPeriod)))
      Toggle(isOn: $showVolume) { Text(L10n.Chart.volume) }
      Divider().frame(height: Self.separatorHeight)
      Toggle(isOn: $showMACD) { Text(L10n.Chart.macd) }
        .help(Text(L10n.Chart.macdHelp(Studies.macdFast, Studies.macdSlow, Studies.macdSignal)))
      Toggle(isOn: $showRSI) { Text(L10n.Chart.rsiChip) }
        .help(Text(L10n.Chart.rsiHelp(Studies.rsiPeriod)))
      Toggle(isOn: $showStochastic) { Text(L10n.Chart.stochastic) }
        .help(Text(L10n.Chart.stochasticHelp(Studies.stochasticPeriod, Studies.stochasticSmoothing)))
      Toggle(isOn: $showATR) { Text(L10n.Chart.atr(Indicators.atrPeriod)) }
    }
    .toggleStyle(.button)
  }

  private var zoomButtons: some View {
    ControlGroup {
      Button { viewport.zoomOut(total: candleCount) } label: {
        Label { Text(L10n.Chart.zoomOut) } icon: { Image(systemName: "minus.magnifyingglass") }
      }
      .keyboardShortcut(Viewport.zoomOutKey, modifiers: .command)
      .help(Text(L10n.Chart.zoomOutHelp))
      .disabled(viewport.visible == nil)
      Button { viewport.fit() } label: {
        Label { Text(L10n.Chart.fit) } icon: { Image(systemName: "arrow.left.and.right") }
      }
      .keyboardShortcut(Viewport.fitKey, modifiers: .command)
      .help(Text(L10n.Chart.fitHelp))
      Button { viewport.zoomIn(total: candleCount) } label: {
        Label { Text(L10n.Chart.zoomIn) } icon: { Image(systemName: "plus.magnifyingglass") }
      }
      .keyboardShortcut(Viewport.zoomInKey, modifiers: .command)
      .help(Text(L10n.Chart.zoomInHelp))
    }
    .labelStyle(.iconOnly)
    .fixedSize()
    .disabled(candleCount == 0)
  }

  private var decisionsToggle: some View {
    Toggle(isOn: $showDecisions) {
      Label { Text(L10n.Chart.decisions) } icon: { Image(systemName: "sidebar.trailing") }
    }
    .toggleStyle(.button)
    .labelStyle(.iconOnly)
    .keyboardShortcut(Self.decisionsKey, modifiers: [.command, .option])
    .help(Text(L10n.Chart.decisionsHelp))
    .accessibilityIdentifier(Self.decisionsToggleID)
  }

  // MARK: Content

  /// The shown bars as candles and lines; built once per new bars or timeframe (ChartModel).
  private var plot: ChartPlot? { chart.plot(timeframe: timeframe) }

  private var candleCount: Int { plot?.candles.count ?? 0 }

  @ViewBuilder private var content: some View {
    if let symbol, let plot {
      CandleChart(
        plot: plot,
        lines: ChartLines(
          style: style, vwap: showVWAP, fastEMA: showFastEMA, slowEMA: showSlowEMA,
          movingAverages: showMovingAverages, bollinger: showBollinger, volume: showVolume,
          macd: showMACD, rsi: showRSI, stochastic: showStochastic, atr: showATR),
        marks: ChartMarkers.marks(trades: model.shownTrades.filter { $0.symbol == symbol }),
        levels: ChartMarkers.levels(position: model.positions.first { $0.id == symbol }),
        decisions: showDecisions
          ? ChartMarkers.decisionMarks(decisions: chart.decisions?.decisions ?? [], candles: plot.candles) : [],
        live: model.isLive,
        viewport: $viewport)
        .id(ChartID(symbol: symbol, day: model.shownDay, timeframe: timeframe))
        .transition(.opacity)
    } else if symbol == nil {
      empty(L10n.Chart.noSymbols, detail: L10n.Chart.noSymbolsDetail, symbol: "chart.xyaxis.line")
    } else if let error = chart.error {
      empty(L10n.Chart.barsUnavailable, detail: L10n.Chart.barsUnavailableDetail(error), symbol: "wifi.exclamationmark")
    } else if chart.loading || chart.bars == nil {
      ProgressView { Text(L10n.Chart.loading) }
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

/// Identity of a drawn chart: a new symbol, day or timeframe redraws it from the start.
private struct ChartID: Hashable {
  let symbol: String
  let day: WireDate
  let timeframe: Timeframe
}

/// Which lines and panes the chart draws, and how it draws the price.
struct ChartLines: Equatable {
  let style: ChartStyle
  let vwap: Bool
  let fastEMA: Bool
  let slowEMA: Bool
  let movingAverages: Bool
  let bollinger: Bool
  /// Volume bars along the bottom of the price pane.
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

  /// Each zoom step shows this many times fewer (or more) candles.
  static let zoomStep = 1.5
  /// The closest zoom still shows this many candles.
  static let minimumVisible = 12
  /// Key equivalents of the zoom buttons (with ⌘), as in Apple's apps.
  static let zoomInKey: KeyEquivalent = "="
  static let zoomOutKey: KeyEquivalent = "-"
  static let fitKey: KeyEquivalent = "0"

  /// Shows fewer candles, down to `minimumVisible`.
  mutating func zoomIn(total: Int) {
    let next = max(Self.minimumVisible, Int((Double(visible ?? total) / Self.zoomStep).rounded()))
    visible = next >= total ? nil : next
  }

  /// Shows more candles, up to the whole day.
  mutating func zoomOut(total: Int) {
    guard let visible else { return }
    let next = Int((Double(visible) * Self.zoomStep).rounded())
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
