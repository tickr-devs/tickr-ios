import ApertureDesign
import ApertureKit
import SwiftUI

/// Chart screen: candles of one symbol on the shown day with the bot's lines, its trades and the
/// open position's entry and stop. Live days refresh as new M1 bars arrive.
struct ChartView: View {
  @Environment(AppModel.self) private var model
  @State private var chart = ChartModel()
  @State private var viewport = Viewport()
  @AppStorage(Keys.symbol) private var picked = ""
  @AppStorage(Keys.timeframe) private var timeframe: Timeframe = .m1
  @AppStorage(Keys.vwap) private var showVWAP = true
  @AppStorage(Keys.fastEMA) private var showFastEMA = true
  @AppStorage(Keys.slowEMA) private var showSlowEMA = true
  @AppStorage(Keys.volume) private var showVolume = true
  @AppStorage(Keys.atr) private var showATR = false

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
    /// Whether the volume pane is shown.
    static let volume = "chart.volume"
    /// Whether the ATR pane is shown.
    static let atr = "chart.atr"
  }

  /// Width of the symbol picker, in points.
  static let pickerWidth: CGFloat = 150
  /// Height of the separators between control groups, in points.
  static let separatorHeight: CGFloat = 18

  /// What a read depends on: a change starts a new read and forgets the old bars.
  private struct LoadKey: Equatable {
    let baseURL: URL
    let symbol: String?
    let day: WireDate
    let live: Bool
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      controls
      content
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .padding(Tokens.Space.xl)
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
    viewport = Viewport()
    guard let symbol else { return }
    let baseURL = model.baseURL
    let day = model.shownDay
    let live = model.isLive
    repeat {
      await chart.load(baseURL: baseURL, symbol: symbol, day: day)
      guard live else { return }
      try? await Task.sleep(for: .seconds(Pace.barsSeconds))
    } while !Task.isCancelled
  }

  // MARK: Controls

  private var controls: some View {
    HStack(spacing: Tokens.Space.m) {
      Picker(selection: Binding(get: { symbol ?? picked }, set: { picked = $0 })) {
        ForEach(symbols, id: \.self) { item in
          Text(verbatim: item).tag(item)
        }
      } label: {
        Text(L10n.Chart.symbol)
      }
      .frame(width: Self.pickerWidth)
      .disabled(symbols.isEmpty)

      Picker(selection: $timeframe) {
        ForEach(Timeframe.allCases) { item in
          Text(L10n.Chart.timeframe(item.rawValue)).tag(item)
        }
      } label: {
        Text(L10n.Chart.timeframeLabel)
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .fixedSize()
      .help(Text(L10n.Chart.timeframeHelp))

      Divider().frame(height: Self.separatorHeight)

      HStack(spacing: Tokens.Space.xs) {
        Toggle(isOn: $showVWAP) { Text(L10n.Chart.vwap) }
        Toggle(isOn: $showFastEMA) { Text(L10n.Chart.ema(Indicators.fastEMAPeriod)) }
        Toggle(isOn: $showSlowEMA) { Text(L10n.Chart.ema(Indicators.slowEMAPeriod)) }
        Toggle(isOn: $showVolume) { Text(L10n.Chart.volume) }
        Toggle(isOn: $showATR) { Text(L10n.Chart.atr(Indicators.atrPeriod)) }
      }
      .toggleStyle(.button)

      Spacer(minLength: Tokens.Space.m)

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
      .disabled(candleCount == 0)
    }
    .animation(Tokens.Motion.quick, value: symbols)
  }

  // MARK: Content

  private var series: ChartSeries? {
    guard let bars = chart.bars, !bars.bars.isEmpty else { return nil }
    return ChartSeries(bars: bars.bars, timeframe: timeframe)
  }

  private var candleCount: Int { series?.candles.count ?? 0 }

  @ViewBuilder private var content: some View {
    if let symbol, let bars = chart.bars, let series {
      CandleChart(
        series: series,
        atr: ChartSeries.atr(bars: bars.bars, timeframe: timeframe),
        lines: ChartLines(
          vwap: showVWAP, fastEMA: showFastEMA, slowEMA: showSlowEMA, volume: showVolume, atr: showATR),
        marks: ChartMarkers.marks(trades: model.shownTrades.filter { $0.symbol == symbol }),
        levels: ChartMarkers.levels(position: model.positions.first { $0.id == symbol }),
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

/// Which lines and panes the chart draws.
struct ChartLines: Equatable {
  let vwap: Bool
  let fastEMA: Bool
  let slowEMA: Bool
  let volume: Bool
  let atr: Bool
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
    .frame(width: PreviewAPI.windowWidth, height: PreviewAPI.windowHeight)
}
#endif
