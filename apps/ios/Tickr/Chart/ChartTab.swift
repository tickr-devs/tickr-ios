import SwiftUI
import TickrDesign
import TickrKit

/// The Chart tab: one symbol's candles on one recorded day, with the bot's indicator lines, its
/// entry, exit and stop, and the day's trades. Pick the day with the day capsule's menu (or a swipe
/// across the top bar), the symbol with the chips, the timeframe under the chart; touch and hold the chart for a candle.
/// In landscape (IOS2Landscape board) the chart stands on the left, as tall as the screen allows,
/// the chips and the day's cards on the right, and the chart's controls behind one button in the
/// top bar, in a sheet.
struct ChartTab: View {
  /// In landscape: the chart column's width and the price pane's height, in points (the board's
  /// chart scaled to fit the 390-point height of a 6.1-inch iPhone under the top bar and above the
  /// tab bar, so the chart shows whole without scrolling).
  static let compactChartWidth: CGFloat = 268
  static let compactPriceHeight: CGFloat = 200

  @Environment(AppModel.self) private var app
  @Environment(\.verticalSizeClass) private var verticalSizeClass
  @State private var chart = Container.shared.chartModel()
  @State private var lines = CandleChart.Lines()
  @State private var viewport = ChartViewport()
  /// The chart's controls are open in their sheet (landscape only).
  @State private var showsOptions = false

  /// An iPhone in landscape.
  private var compactHeight: Bool { verticalSizeClass == .compact }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Tokens.Space.m) {
        ConnectionPrompt()
        if let url = app.connection.url {
          content(url).lastKnown(app.connectionState.isLastKnown)
        }
      }
      // The design's gap between the top bar and the symbol chips: without it the chips sat
      // right under the bar's glass.
      .padding(.top, Tokens.Space.m)
      .padding(.horizontal, Tokens.Space.l)
      .padding(.bottom, Tokens.Space.xl)
    }
    .scrollEdgeHints()
    .scrollContentBackground(.hidden)
    .background(TickrBackground())
    // The design starts with the symbol: no title row, the tab's name stays for VoiceOver.
    .tabRoot(.chart)
    // The symbol and the day stay on top as the screen's bar. `tabRoot`'s backdrop
    // (`StatusBarBackdrop`) sits inside this bar's safe area, so it covers the status bar and the
    // bar's own strip: the chart scrolled up never draws under the clock or behind the glass.
    .safeAreaBar(edge: .top) {
      if let url = app.connection.url, showsBoard {
        DayBar(chart: chart, url: url, options: openOptions)
          .padding(.horizontal, Tokens.Space.m)
          .padding(.vertical, Tokens.Space.s)
          // On Liquid Glass, as the system's own bars: the chart scrolling under it never shows
          // through the symbol and its price.
          .glassEffect(.regular, in: .rect(cornerRadius: Tokens.Radius.large))
          // In an iPad window (Stage Manager, a narrow window shows this layout) the window
          // controls sit in the top leading corner: the bar moves past them and narrows to fit.
          // On iPhone there are no controls and nothing moves.
          .containerCornerOffset(.leading, sizeToFit: true)
          .padding(.horizontal, Tokens.Space.s)
      }
    }
    .sheet(isPresented: $showsOptions) {
      let shown = $showsOptions
      CardSheet(title: ChartText.options, subtitle: nil, close: { shown.wrappedValue = false }, rows: {
        ChartControls(chart: chart, series: drawn, lines: $lines, viewport: $viewport)
      })
    }
    // Back in portrait the controls stand under the chart again.
    .onChange(of: compactHeight) { _, compact in
      if !compact { showsOptions = false }
    }
    .task(id: app.connection.url) {
      guard let url = app.connection.url else { return }
      await chart.load(url, preferring: app.selectedSymbol ?? app.status?.positions.first?.symbol)
    }
    // The symbol shown is the app's selected one, so the iPad and the unfolded Duo's Mac screens
    // open on it after a resize or a fold (`AdaptiveRoot`).
    .onChange(of: chart.symbol) { _, symbol in
      if let symbol, app.selectedSymbol != symbol { app.selectedSymbol = symbol }
    }
    // The app's one shown day: another tab's pick shows here.
    .task(id: app.shownDay) {
      guard let url = app.connection.url else { return }
      await chart.follow(url)
    }
    .task(id: liveKey) { await followToday() }
    .task(id: rangeKey) { await followRange() }
    .refreshable {
      guard let url = app.connection.url else { return }
      await chart.load(url, preferring: chart.symbol)
    }
  }

  /// One layout from the first read on (owner, 2026-11-19: no jerky loaders): the bar, the symbol
  /// chips, the chart, its controls and the day's cards keep their places while the days, the
  /// day and its bars load, each piece as skeleton in its own size until it is read; nothing
  /// moves or blinks when the data arrives, and a re-read keeps what is shown.
  @ViewBuilder
  private func content(_ url: URL) -> some View {
    switch chart.phase {
    case .failed(let cause):
      // Plain words, the cause behind Details; while the link is down the card waits calmly and
      // the connection banner above speaks (and retries) for every screen.
      VStack(alignment: .leading, spacing: Tokens.Space.m) {
        ReadFailureNote(ChartText.failedTitle, detail: cause)
        if app.connectionState.failure == nil {
          Button { Task { await chart.load(url, preferring: chart.symbol) } } label: { Text(ChartText.retry) }
            .buttonStyle(.action(.secondary, size: .compact))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(Tokens.Space.l)
      .tickrCard()
    case .loaded where chart.days.isEmpty:
      ContentUnavailableView {
        Label { Text(ChartText.noDaysTitle) } icon: { Image(systemName: "calendar.badge.clock") }
      } description: {
        Text(ChartText.noDaysBody)
      }
    default:
      board(url)
    }
  }

  /// The chart and everything around it, loading or read.
  @ViewBuilder
  private func board(_ url: URL) -> some View {
    if compactHeight {
      // Landscape, as on the board: the chart on the left; the symbols, why the bot acted and
      // the day's trades on the right. The controls are in the top bar's sheet.
      HStack(alignment: .top, spacing: Tokens.Space.m) {
        chartSlot.frame(width: Self.compactChartWidth)
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
          SymbolChips(chart: chart, url: url, loading: chart.day == nil && showsBoard)
          dayCards
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    } else {
      VStack(alignment: .leading, spacing: Tokens.Space.m) {
        SymbolChips(chart: chart, url: url, loading: chart.day == nil && showsBoard)
        // As on the design: the chart right under the symbols, then its range, timeframe, zoom and
        // lines, then why the bot acted.
        chartSlot
        // The controls stay live while the bars load, as on the Mac: another range or interval
        // never takes them away and back.
        ChartControls(chart: chart, series: drawn, lines: $lines, viewport: $viewport)
        dayCards
      }
    }
  }

  /// The chart, or the skeleton standing in the chart's own card, its size.
  private var chartSlot: some View {
    LoadingSlot(drawn) { series in
      // The bot's trades, position and strategy marks belong to the chosen day: on a longer
      // range they stay off it.
      let oneDay = chart.range == .oneDay
      CandleChart(series: series, times: chart.times, studies: chart.studies, readoutShapes: chart.readoutShapes,
        atr: chart.atr, trades: oneDay ? chart.trades : [], position: oneDay ? chart.openPosition : nil,
        events: oneDay ? chart.events : [], lines: lines,
        pending: chart.pending, livePrice: oneDay ? chart.livePrice : nil, viewport: $viewport,
        plotHeight: priceHeight)
        // Its panes have a fixed height: past this size the scale's tags and legends would
        // cover each other and the candles.
        .dynamicTypeSize(...CandleChart.largestText)
    } placeholder: {
      notDrawn
    }
  }

  /// Why the bot acted on the symbol, then its trades of the day.
  @ViewBuilder
  private var dayCards: some View {
    if chart.symbol != nil {
      DecisionsCard(decisions: chart.shownDecisions, failure: chart.shownDecisionsFailure)
    }
    if chart.day != nil {
      DayTrades(symbol: chart.symbol, trades: chart.trades, position: chart.openPosition)
    }
  }

  /// Opens the controls' sheet; nil in portrait, where they stand under the chart.
  private var openOptions: (@MainActor () -> Void)? {
    guard compactHeight else { return nil }
    return { showsOptions = true }
  }

  /// The price pane's height: shorter in landscape, so the chart fits the screen's height.
  private var priceHeight: CGFloat {
    compactHeight ? Self.compactPriceHeight : CandleChart.priceHeight
  }

  /// The candles on screen, nil while there are none to draw.
  private var drawn: ChartSeries? {
    guard let series = chart.series, !series.candles.isEmpty else { return nil }
    return series
  }

  /// What stands in the chart's place while no candle is drawn: the loading chart while bars are
  /// on their way, else why there are none, in the same place.
  @ViewBuilder
  private var notDrawn: some View {
    if chart.range != .oneDay, let failure = chart.rangeFailure {
      UnavailableState(ChartText.barsUnavailable, message: ChartText.candlesUnavailable, cause: failure)
    } else if chart.range != .oneDay, let answer = chart.rangeChart, answer.symbol == chart.symbol,
      answer.range == chart.range, answer.interval == chart.timeframe, answer.pending == nil {
      // Only a finished answer can say there are no candles: a pending one (the chart's budget
      // still filling the range) shows loading, never an empty state.
      ContentUnavailableView {
        Label { Text(ChartText.noBarsTitle) } icon: { Image(systemName: "chart.bar.xaxis") }
      } description: {
        if let cause = answer.causeText {
          Text(ChartText.noCandles(cause))
        } else {
          Text(ChartText.noCandlesPlain)
        }
      }
    } else if chart.range == .oneDay, !barsAwaited {
      ContentUnavailableView {
        Label { Text(ChartText.noBarsTitle) } icon: { Image(systemName: "chart.bar.xaxis") }
      } description: {
        Text(ChartText.noBarsBody)
      }
    } else {
      loadingView
    }
  }

  /// One day's bars are still on their way: the days or the day are being read, the chart's
  /// budget fills today, or today was read in another interval.
  private var barsAwaited: Bool {
    switch chart.phase {
    case .idle, .loading: true
    case .failed: false
    case .loaded: chart.pending != nil || chart.needsTodayRead
    }
  }

  /// Whether the board (bar, chips, chart) is on screen: from the first read on, unless it
  /// failed or no day is recorded.
  private var showsBoard: Bool {
    switch chart.phase {
    case .failed: false
    case .loaded: !chart.days.isEmpty
    case .idle, .loading: true
    }
  }

  /// The chart while its bars load (mockup v102, loader E): the chart's own card with the price
  /// pane's grid, a faint candle silhouette that builds in left to right with its volume, the
  /// price and time axes, and every enabled study pane, as skeleton in the chart's own sizes;
  /// "Loading ABCD · 1 min bars" on the readout's line. Nothing real until the bars are read.
  private var loadingView: some View {
    LoadingChart(
      caption: chart.pending.map(PendingText.caption) ?? chart.symbol.map {
        ChartText.loadingBars($0, interval: String(localized: ChartFormat.title(chart.timeframe)))
      } ?? L10n.Common.loading,
      lines: lines, timeframe: chart.timeframe, pending: chart.pending, plotHeight: priceHeight)
  }

  /// Changes whenever a different chart is on screen, restarting the reload loop.
  private var liveKey: LiveKey {
    LiveKey(day: chart.selectedDay, symbol: chart.symbol, isToday: chart.isToday, timeframe: chart.timeframe)
  }

  /// Changes whenever another symbol, range or interval beyond one day is chosen.
  private var rangeKey: RangeKey {
    RangeKey(url: app.connection.url, symbol: chart.symbol, range: chart.range, timeframe: chart.timeframe)
  }

  private struct RangeKey: Hashable {
    let url: URL?
    let symbol: String?
    let range: ChartRange
    let timeframe: Timeframe
  }

  /// Read the candles of a range beyond one day; while they are intraday (five sessions), read
  /// them again now and then so today's last candle stays current. A cold 5D fills as the chart's
  /// budget allows: asked again when the bot says (`pending`).
  private func followRange() async {
    guard chart.range != .oneDay, let url = app.connection.url else { return }
    repeat {
      let wait = await chart.loadRange(url)
      guard wait != nil || chart.timeframe.isIntraday else { return }
      try? await Task.sleep(for: .seconds(wait ?? ChartModel.rangeReloadSeconds))
    } while !Task.isCancelled
  }

  private struct LiveKey: Hashable {
    let day: WireDate?
    let symbol: String?
    let isToday: Bool
    /// Today's market data is read in the chosen interval: another one is read again.
    let timeframe: Timeframe
  }

  /// While today's chart is on screen, reload it so the last candle stays current: market data
  /// at its own pace (or when the bot says while its budget fills it), the capture at the bars'.
  private func followToday() async {
    if chart.isToday, chart.needsTodayRead, let url = app.connection.url { await chart.reloadBars(url) }
    while chart.isToday, !Task.isCancelled {
      try? await Task.sleep(for: .seconds(chart.todayReloadSeconds))
      guard !Task.isCancelled, let url = app.connection.url else { return }
      await chart.reloadBars(url)
    }
  }
}

/// The screen's top bar as on the design (IOS2Chart): the symbol with its last price and the day's
/// change on one row, "● Live" under it while the day is today, the day's high, low and volume, and
/// the day capsule ("Today ▾"), whose menu lists every recorded day with its result. A sideways
/// swipe across the bar changes the day; the chart under it keeps its own drag for panning. At
/// large text sizes the price goes under the symbol. In landscape a button before the capsule opens
/// the chart's controls.
private struct DayBar: View {
  /// The controls button's glyph (the board's sliders).
  static let optionsSymbol = "slider.horizontal.3"

  @Environment(AppModel.self) private var app
  @Environment(\.dynamicTypeSize) private var typeSize
  let chart: ChartModel
  let url: URL
  /// Opens the chart's controls; nil where they stand under the chart (portrait).
  let options: (@MainActor () -> Void)?

  var body: some View {
    HStack(alignment: .center, spacing: Tokens.Space.s) {
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        RowStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
          // While the day loads every piece stands as skeleton in its own size (sample values
          // laid out, not drawn), so the bar never changes height when the bars arrive.
          Text(verbatim: chart.symbol ?? SkeletonSample.symbol)
            .font(Tokens.Typography.metric)
            .foregroundStyle(Palette.textPrimary)
            .fixedSize()
            .skeleton(chart.symbol == nil, .value)
          quote
        }
        if chart.isToday { live }
      }
      Spacer(minLength: 0)
      if !typeSize.stacksRows { dayStats }
      if let options {
        Button(action: options) {
          Image(systemName: Self.optionsSymbol)
        }
        .buttonStyle(DayButtonStyle())
        .accessibilityLabel(Text(ChartText.options))
        .accessibilityIdentifier(AccessibilityID.chartOptions)
      }
      dayCapsule
        .skeleton(chart.selectedDay == nil)
    }
    .contentShape(.rect)
    // Only the bar: a swipe over the chart pans its candles, never the day.
    .daySwipe(steps, back: { step(to: chart.previousDay) }, forward: { step(to: chart.nextDay) })
  }

  /// Where the day can go: the demo day and a single recorded day go nowhere.
  private var steps: DayArrows {
    DayArrows(locked: chart.dayLocked, canGoBack: chart.previousDay != nil, canGoForward: chart.nextDay != nil)
  }

  private func step(to day: WireDate?) {
    if let day { Task { await chart.show(day, from: url) } }
  }

  /// "● Live" while the shown day is today: one pulse per new minute bar of the shown symbol (a
  /// real read), still in between.
  private var live: some View {
    HStack(spacing: Tokens.Space.xs) {
      PulseDot(Palette.accent, size: Tokens.Size.dotSmall, event: chart.series?.candles.last?.start)
      Text(ChartText.live)
    }
    .font(Tokens.Typography.annotation)
    .foregroundStyle(Palette.textTertiary)
    .fixedSize()
  }

  /// The shown day in full, for VoiceOver ("Mon Nov 16 · today").
  private func fullDay(_ day: WireDate) -> String {
    let text = DayText.day(day.noonInNewYork)
    return day == app.today ? String(localized: L10n.Common.today(text)) : text
  }

  /// The capsule: "Today" on today, else the shown day; a tap opens the menu of recorded days.
  /// With one day to choose from (the demo day, the only recorded day) the day is plain text.
  @ViewBuilder
  private var dayCapsule: some View {
    let caption = chart.isToday ? nil : DayText.day((chart.selectedDay ?? app.today).noonInNewYork)
    let label = Text(DayWords.label(fullDay(chart.selectedDay ?? app.today)))
    if steps.visible || (chart.days.isEmpty && !chart.dayLocked) {
      Menu {
        ForEach(chart.days) { summary in dayItem(summary) }
      } label: {
        DayCapsule(caption: caption)
      }
      .menuStyle(.button)
      .buttonStyle(DayButtonStyle())
      // While the days are read the capsule waits in its place.
      .disabled(chart.days.isEmpty)
      .accessibilityLabel(label)
    } else {
      DayCapsule(caption: caption, opens: false)
        .accessibilityLabel(label)
    }
  }

  /// One recorded day in the menu: the day, its result under it (after fees once known), and a
  /// check on the shown one.
  private func dayItem(_ summary: DaySummary) -> some View {
    let shown = summary.day == chart.selectedDay
    return Button {
      if !shown { Task { await chart.show(summary.day, from: url) } }
    } label: {
      Text(verbatim: fullDay(summary.day))
      if summary.trades > 0 {
        Text(verbatim: Money.signedUSD(summary.resultUsd.value))
      } else {
        Text(ChartText.noTrades)
      }
      if shown { Image(systemName: Self.shownSymbol) }
    }
    .accessibilityAddTraits(shown ? .isSelected : [])
  }

  /// The shown day's mark in the menu.
  static let shownSymbol = "checkmark"

  /// The shown candles' high, low and volume, small and dim beside the day capsule, as on the design.
  private var dayStats: some View {
    let candles = drawnCandles ?? []
    let loading = drawnCandles == nil
    // Sample figures while loading: laid out for their size, drawn as skeleton lines.
    let high = candles.map(\.high).max() ?? SkeletonSample.price
    let low = candles.map(\.low).min() ?? SkeletonSample.price
    let volume = loading ? SkeletonSample.volume : candles.map(\.volume).reduce(0, +)
    let rows: [(LocalizedStringResource, String)] = [(ChartText.highShort, Money.price(high)),
      (ChartText.lowShort, Money.price(low)), (ChartText.volumeShort, Volume.compact(volume))]
    return Grid(alignment: .trailing, horizontalSpacing: Tokens.Space.xs, verticalSpacing: 0) {
      ForEach(rows.indices, id: \.self) { index in
        GridRow {
          Text(rows[index].0).foregroundStyle(Palette.textQuaternary).skeleton(loading)
          Text(verbatim: rows[index].1).foregroundStyle(Palette.textSecondary).skeleton(loading)
        }
      }
    }
    .font(Tokens.Typography.annotation)
    .fixedSize()
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(ChartText.dayStats(rows[0].1, rows[1].1, rows[2].1)))
    .accessibilityHidden(loading)
  }

  /// The candles on screen, nil while none are drawn yet.
  private var drawnCandles: [Candle]? {
    guard let candles = chart.series?.candles, !candles.isEmpty else { return nil }
    return candles
  }

  /// The last price and its change: on today's one-day chart from the previous close
  /// (`DayChange`, as Webull shows a day's change), else from the shown range's first open.
  @ViewBuilder
  private var quote: some View {
    if let candles = drawnCandles, let first = candles.first, let last = candles.last {
      // The live bid where the bot's quotes have one (today, one day shown), else the last close.
      let price = (chart.range == .oneDay ? chart.livePrice : nil) ?? last.close
      let day = chart.range == .oneDay
        ? DayChange.fraction(price: Money.decimal(price), previousClose: chart.previousClose) : nil
      let fromOpen = first.open == 0 ? 0 : Money.decimal((price - first.open) / first.open)
      let change = day ?? fromOpen
      HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
        Text(verbatim: Money.price(price))
          .font(.headline.monospaced().bold())
          .contentTransition(.numericText(value: price))
        Text(verbatim: Percent.signed(fraction: change))
          .font(Tokens.Typography.captionMono)
      }
      .foregroundStyle(Palette.result(change))
      .accessibilityElement(children: .combine)
    } else {
      // The price and change in their own fonts, as skeleton: the same height and place.
      HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
        Text(verbatim: Money.price(SkeletonSample.price))
          .font(.headline.monospaced().bold())
          .skeleton(true, .value)
        Text(verbatim: Percent.signed(fraction: SkeletonSample.change))
          .font(Tokens.Typography.captionMono)
          .skeleton(true)
      }
    }
  }
}

/// One chip per symbol with captured bars that day, open positions first: a pulsing dot marks an
/// open position, a plain dot a symbol the bot traded.
private struct SymbolChips: View {
  @Environment(AppModel.self) private var app
  let chart: ChartModel
  let url: URL
  /// The day is being read: chips of the real size stand as skeleton pills.
  var loading = false

  /// Skeleton chips while the day loads.
  static let skeletonChips = 4

  var body: some View {
    if loading {
      HStack(spacing: Tokens.Space.s) {
        ForEach(0..<Self.skeletonChips, id: \.self) { _ in
          // A real chip with a sample symbol, laid out for its size and drawn as a pill.
          Text(verbatim: SkeletonSample.symbol)
            .chipFace(selected: false)
            .skeleton(true, .fill)
        }
      }
      .accessibilityHidden(true)
    } else {
      chipRow
    }
  }

  private var chipRow: some View {
    // The chosen symbol stays in view: when the chart opens, and when the symbol or the range
    // changes (the row was left scrolled to its start, the chosen chip off screen).
    ScrollViewReader { proxy in
      chips
        .onAppear { reveal(proxy, animated: false) }
        .onChange(of: chart.symbol) { reveal(proxy, animated: true) }
        .onChange(of: chart.range) { reveal(proxy, animated: false) }
        .onChange(of: chart.symbols) { reveal(proxy, animated: false) }
    }
    .sensoryFeedback(.selection, trigger: chart.symbol)
  }

  /// The open position on `symbol` as the status reports it: its quantity and its stop.
  private func positionEvent(_ symbol: String) -> AnyHashable? {
    guard let position = app.status?.positions.first(where: { $0.symbol == symbol }) else { return nil }
    return AnyHashable([AnyHashable(position.quantity.text), AnyHashable(position.stop.state),
      AnyHashable(position.stop.price)])
  }

  private func reveal(_ proxy: ScrollViewProxy, animated: Bool) {
    guard let symbol = chart.symbol else { return }
    withAnimation(animated ? Tokens.Motion.quick : nil) { proxy.scrollTo(symbol, anchor: .center) }
  }

  private var chips: some View {
    ScrollView(.horizontal) {
      HStack(spacing: Tokens.Space.s) {
        ForEach(chart.symbols, id: \.self) { symbol in
          let selected = symbol == chart.symbol
          let open = chart.openSymbols.contains(symbol)
          let traded = chart.day?.trades.contains { $0.symbol == symbol } ?? false
          Button {
            Task { await chart.show(symbol: symbol, from: url) }
          } label: {
            // As on the design, one dot after the symbol: teal for an open position (pulsing only
            // while the status saying so is current), the chip's ink for a symbol the bot traded.
            HStack(spacing: Tokens.Space.xs) {
              Text(symbol)
              if open {
                // One pulse when the position changes at the broker: filled, stop placed or
                // verified, quantity changed; still in between.
                PulseDot(Palette.accent, size: Tokens.Size.dotSmall, pulsing: app.response?.stale == false,
                  event: positionEvent(symbol))
                  .accessibilityLabel(Text(ChartText.openPosition))
              } else if traded {
                Circle()
                  .fill(selected ? Palette.infoText : Palette.textSecondary)
                  .frame(width: Tokens.Size.dotSmall, height: Tokens.Size.dotSmall)
                  .accessibilityLabel(Text(ChartText.traded))
              }
            }
          }
          .buttonStyle(.chip(selected: selected))
        }
      }
    }
    .withoutScrollIndicators()
  }
}

/// Timeframe, candles or a line, zoom and the way back to the newest candle, then which lines the
/// chart draws.
private struct ChartControls: View {
  let chart: ChartModel
  /// The drawn candles; nil while they load, when zoom and LIVE wait dimmed.
  let series: ChartSeries?
  @Binding var lines: CandleChart.Lines
  @Binding var viewport: ChartViewport

  var body: some View {
    @Bindable var chart = chart
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      RangePicker(chart: chart)
      // Timeframes, then zoom and the way back to the newest candle at the end, as on the design,
      // on one line at the phone's width; when they do not fit (large text) the zoom and LIVE take
      // the line under the timeframes. Nothing scrolls sideways.
      ViewThatFits(in: .horizontal) {
        HStack(spacing: Tokens.Space.s) {
          timeframes
          following
        }
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
          timeframes
          following
        }
      }
      // Candles or a line on a row of its own, as on the design.
      styleSwitch
      // The design's four common lines as chips; the rest in the "ƒx" menu.
      ChipFlow(spacing: Tokens.Space.s) {
        toggle(ChartText.vwap, isOn: $lines.vwap)
        toggle(ChartText.emaChip(Indicators.fastEMAPeriod), isOn: $lines.fastEMA)
        toggle(ChartText.volumeChip, isOn: $lines.volume)
        toggle(ChartText.atr(Indicators.atrPeriod), isOn: $lines.atr)
        Menu {
          Section {
            Toggle(isOn: $lines.slowEMA) { Text(ChartText.ema(Indicators.slowEMAPeriod)) }
            Toggle(isOn: $lines.movingAverages) { Text(ChartText.movingAverages) }
            Toggle(isOn: $lines.bollinger) { Text(ChartText.bollinger) }
          } header: {
            Text(ChartText.overlays)
          }
          Section {
            Toggle(isOn: $lines.macd) { Text(ChartText.macdToggle) }
            Toggle(isOn: $lines.stochastic) { Text(ChartText.stochasticToggle) }
            Toggle(isOn: $lines.rsi) { Text(ChartText.rsiToggle) }
          } header: {
            Text(ChartText.panes)
          }
        } label: {
          // "ƒx ▾", as on the design.
          HStack(spacing: Tokens.Space.xxs) {
            Image(systemName: Self.indicatorsSymbol)
            Image(systemName: Self.menuSymbol).imageScale(.small)
          }
          .chipFace(selected: false)
          .accessibilityLabel(Text(ChartText.indicators))
        }
        .menuActionDismissBehavior(.disabled)
      }
    }
    .foregroundStyle(Palette.infoText)
    .sensoryFeedback(.selection, trigger: chart.timeframe)
  }

  /// The range's intervals, as chips.
  private var timeframes: some View {
    HStack(spacing: Tokens.Space.s) {
      ForEach(chart.range.intervals) { timeframe in
        let selected = timeframe == chart.timeframe
        Button { chart.timeframe = timeframe } label: {
          Text(ChartFormat.title(timeframe))
        }
        .buttonStyle(.chip(selected: selected))
      }
    }
    .fixedSize()
  }

  /// Zoom out, zoom in, and LIVE: the way back to the newest candle, today only.
  private var following: some View {
    HStack(spacing: Tokens.Space.s) {
      Group {
        // Dimmed at the zoom's limit: the explicit colour below kept them looking tappable.
        Button { zoom(by: Tokens.Chart.zoomStep) } label: { HeaderIcon(symbol: "minus").dimmedWhenDisabled() }
          .disabled(series.map { !viewport.canZoomOut($0) } ?? true)
          .accessibilityLabel(Text(ChartText.zoomOut))
        Button { zoom(by: 1 / Tokens.Chart.zoomStep) } label: { HeaderIcon(symbol: "plus").dimmedWhenDisabled() }
          .disabled(series == nil || !viewport.canZoomIn)
          .accessibilityLabel(Text(ChartText.zoomIn))
      }
      .foregroundStyle(Palette.textPrimary)
      .buttonStyle(.glyph)
      if chart.isToday {
        let following = series.map { viewport.showsEnd($0) } ?? true
        Button {
          guard let series else { return }
          withAnimation(Tokens.Motion.quick) { viewport.followEnd(series) }
        } label: {
          Text(ChartText.live).textCase(.uppercase)
        }
        .buttonStyle(.chip(selected: following, tone: .accent))
        .disabled(series == nil)
        .accessibilityHint(Text(ChartText.liveHint))
      }
    }
    .fixedSize()
  }

  /// Symbols of the indicator menu's chip ("ƒx ▾").
  static let indicatorsSymbol = "function"
  static let menuSymbol = "chevron.down"

  /// Candles or a line: the apps' segmented switch with the design's glyphs, as on the Mac.
  private var styleSwitch: some View {
    SegmentSwitch(options: [
      SegmentSwitch<CandleChart.Style>.Option(.candles, title: Text(ChartText.candles), glyph: .candles),
      SegmentSwitch<CandleChart.Style>.Option(.line, title: Text(ChartText.lineStyle), glyph: .line),
    ], selection: $lines.style)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(Text(ChartText.chartType))
  }

  /// A line's chip: the apps' on/off chip (`.toggleStyle(.chip)`), chosen while the chart draws it.
  private func toggle(_ title: LocalizedStringResource, isOn: Binding<Bool>) -> some View {
    Toggle(isOn: isOn) { Text(title) }
      .toggleStyle(.chip)
  }

  private func zoom(by factor: Double) {
    guard let series else { return }
    withAnimation(Tokens.Motion.quick) { viewport.zoom(by: factor, series) }
  }
}

/// The chosen symbol's trades of the day, in words as on the board (mockup IOSChart): the open
/// position first ("Bought 10 @ 12.34 · stop 11.90 · Verified", open), then each closed trade
/// ("Bought 15 @ 8.71 → sold 8.95", its result). The header leads to Activity, on the same day.
private struct DayTrades: View {
  @Environment(AppModel.self) private var app
  let symbol: String?
  let trades: [DayTrade]
  let position: Position?

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      HStack(alignment: .center, spacing: Tokens.Space.s) {
        CardLabel(symbol.map(ChartText.tradesIn) ?? ChartText.trades)
        Spacer(minLength: Tokens.Space.s)
        HeaderLink(ChartText.activity) { app.selectedTab = .activity }
      }
      if trades.isEmpty && position == nil {
        Text(ChartText.noTrades)
          .font(Tokens.Typography.callout)
          .foregroundStyle(Palette.textTertiary)
      }
      if let position { openRow(position) }
      // The latest trades, then "Show all N ›": a busy symbol trades many times a day.
      CappedList(trades.sorted { $0.closedAt.date > $1.closedAt.date }, id: \.id, title: ChartText.trades,
        limit: Tokens.Lists.comparedRows) { _, trade in closedRow(trade) }
    }
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, alignment: .leading)
    .tickrCard()
  }

  /// The open position: when it filled, what was bought and its stop in the stop's state colour.
  private func openRow(_ position: Position) -> some View {
    let state = position.stop.state
    var line = AttributedString(String(localized: ChartText.bought(position.quantity.text,
      Money.price(position.entryPrice.value))))
    line.swiftUI.foregroundColor = Palette.textSecondary
    var stop = AttributedString(Format.separator + String(localized: L10n.Activity.stopDetail(
      position.stop.price.map { Money.price($0.value) } ?? Format.missing, Board.stopStateTitle(state))))
    stop.swiftUI.foregroundColor = state.tone.text
    return row(time: (position.entry.filledAt ?? position.openedAt).date, what: line + stop) {
      Text(ChartText.openResult)
        .foregroundStyle(Tone.openPosition.text)
    }
  }

  /// A closed trade: when it opened, what was bought and sold, its result in dollars.
  private func closedRow(_ trade: DayTrade) -> some View {
    var line = AttributedString(String(localized: ChartText.boughtSold(trade.quantity.text,
      Money.price(trade.entryPrice.value), Money.price(trade.exitPrice.value))))
    line.swiftUI.foregroundColor = Palette.textSecondary
    return row(time: trade.openedAt.date, what: line) {
      Text(verbatim: Money.signedUSD(trade.resultUsd.value))
        .foregroundStyle(Palette.result(trade.resultUsd.value))
    }
  }

  /// One line of the list: the time, the words (wrapping, never cut) and the result at the end.
  private func row<Result: View>(time: Date, what: AttributedString, @ViewBuilder result: () -> Result) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
      Text(time, format: ChartFormat.time)
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(Palette.textTertiary)
      Text(what)
        .font(Tokens.Typography.callout)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: Tokens.Space.s)
      result()
        .font(Tokens.Typography.bodyMono.bold())
    }
    .accessibilityElement(children: .combine)
  }
}

/// How far back the chart reaches: the chosen day, five sessions, one or three months, a year.
private struct RangePicker: View {
  let chart: ChartModel

  var body: some View {
    SegmentSwitch(options: ChartRange.allCases.map { ($0, Text(Self.title($0))) },
      selection: Binding(get: { chart.range }, set: { chart.choose(range: $0) }))
      .accessibilityElement(children: .contain)
      .accessibilityLabel(Text(ChartText.range))
      .sensoryFeedback(.selection, trigger: chart.range)
  }

  static func title(_ range: ChartRange) -> LocalizedStringResource {
    switch range {
    case .oneDay: ChartText.rangeDay
    case .fiveDays: ChartText.rangeFiveDays
    case .oneMonth: ChartText.rangeOneMonth
    case .threeMonths: ChartText.rangeThreeMonths
    case .oneYear: ChartText.rangeOneYear
    }
  }
}

/// The Chart tab while its bars load (see `ChartTab.loadingView`): the chart's own card in the
/// chart's own sizes (`CandleChart`): the readout's line with the caption, the legend's line when
/// the chart draws one, the price pane and every enabled study pane, so the chart takes its place
/// without a jump.
private struct LoadingChart: View {
  let caption: LocalizedStringResource
  let lines: CandleChart.Lines
  /// The chosen interval, which the legend's lines depend on.
  let timeframe: Timeframe
  /// How far a read the chart's request budget holds back has got, shown as a progress line.
  var pending: ChartPendingV1?
  /// Height of the price pane, the chart's own (`CandleChart.plotHeight`).
  var plotHeight = CandleChart.priceHeight

  /// The silhouette's candles and the price pane's grid lines across and down, as the board's.
  static let candles = 34
  static let rows = 5
  static let columns = 4

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      // The readout's line: "Loading ABCD · 1 min bars" over the chart's own caption, laid out
      // but not drawn, so the line is as tall as the readout it gives way to: one line, always.
      ZStack(alignment: .topLeading) {
        CandleChart.caption
          .hidden()
        Text(caption)
          .foregroundStyle(Palette.textQuaternary)
          .fixedSize()
      }
      .font(Tokens.Typography.captionMono)
      .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
      // The legend's names in their own row, values to come, as skeleton of their own size.
      CandleChart.legend(CandleChart.priceLegend(lines, intraday: timeframe.isIntraday))
        .skeleton(true)
      Skeleton(nil) {
        VStack(spacing: 0) {
          SkeletonCandles(candles: Self.candles, rows: Self.rows, columns: Self.columns,
            axisWidth: CandleChart.axisLabelWidth, showsTime: true, volume: lines.volume, builds: true)
            .frame(height: plotHeight)
          ForEach(lines.panes, id: \.self) { _ in
            SkeletonPane(axisWidth: CandleChart.axisLabelWidth)
              .frame(height: CandleChart.paneHeight)
              .overlay(alignment: .top) { SkeletonGridLine() }
          }
        }
      }
    }
    .padding(Tokens.Space.l)
    .tickrCard()
    .overlay(alignment: .top) {
      if let pending {
        ProgressLine(fraction: pending.fraction, label: PendingText.caption(pending))
      }
    }
    .dynamicTypeSize(...CandleChart.largestText)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(caption))
    .accessibilityAddTraits(.updatesFrequently)
  }
}

/// What a chart the request budget fills says (a cold 5D): "Loading 3 of 5 days"; the waiting
/// note for a read of one.
enum PendingText {
  static func caption(_ pending: ChartPendingV1) -> LocalizedStringResource {
    pending.total > 1 ? ChartSessionWords.loadingDays(pending.read, pending.total) : ChartSessionWords.waitingForBudget
  }
}
