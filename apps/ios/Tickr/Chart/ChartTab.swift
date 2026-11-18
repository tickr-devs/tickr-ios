import SwiftUI
import TickrDesign
import TickrKit

/// The Chart tab: one symbol's candles on one recorded day, with the bot's indicator lines, its
/// entry, exit and stop, and the day's trades. Pick the day with the arrows or the menu, the
/// symbol with the chips, the timeframe under the chart; touch and hold the chart for a candle.
struct ChartTab: View {
  @Environment(AppModel.self) private var app
  @State private var chart = Container.shared.chartModel()
  @State private var lines = CandleChart.Lines()
  @State private var viewport = ChartViewport()

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
      .animation(Tokens.Motion.standard, value: chart.phase)
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
      if let url = app.connection.url, !chart.days.isEmpty, showsContent {
        DayBar(chart: chart, url: url)
          .padding(.horizontal, Tokens.Space.m)
          .padding(.vertical, Tokens.Space.s)
          // On Liquid Glass, as the system's own bars: the chart scrolling under it never shows
          // through the symbol and its price.
          .glassEffect(.regular, in: .rect(cornerRadius: Tokens.Radius.large))
          .padding(.horizontal, Tokens.Space.s)
      }
    }
    .task(id: app.connection.url) {
      guard let url = app.connection.url else { return }
      await chart.load(url, preferring: app.selectedSymbol ?? app.status?.positions.first?.symbol)
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

  @ViewBuilder
  private func content(_ url: URL) -> some View {
    // One placeholder in one place while nothing is drawn yet: two branches showing it would
    // cross-fade two copies, one of them squeezed while it grows in.
    if isLoading {
      loadingView
    } else {
      loaded(url)
    }
  }

  private var isLoading: Bool {
    switch chart.phase {
    case .idle: true
    case .loading: chart.series == nil
    default: false
    }
  }

  @ViewBuilder
  private func loaded(_ url: URL) -> some View {
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
      .rise()
    default:
      if chart.days.isEmpty {
        ContentUnavailableView {
          Label { Text(ChartText.noDaysTitle) } icon: { Image(systemName: "calendar.badge.clock") }
        } description: {
          Text(ChartText.noDaysBody)
        }
        .rise()
      } else {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
          SymbolChips(chart: chart, url: url)
          if let series = chart.series, !series.candles.isEmpty {
            // As on the design: the chart right under the symbols, then its range, timeframe,
            // zoom and lines, then why the bot acted.
            // The bot's trades, position and strategy marks belong to the chosen day: on a longer
            // range they stay off it.
            let oneDay = chart.range == .oneDay
            CandleChart(series: series, times: chart.times, studies: chart.studies, atr: chart.atr,
              trades: oneDay ? chart.trades : [], position: oneDay ? chart.openPosition : nil,
              events: oneDay ? chart.events : [], lines: lines, rangeTitle: RangePicker.title(chart.range),
              pending: chart.pending, livePrice: oneDay ? chart.livePrice : nil, viewport: $viewport)
              // Its panes have a fixed height: past this size the scale's tags and legends would
              // cover each other and the candles.
              .dynamicTypeSize(...CandleChart.largestText)
            ChartControls(chart: chart, series: series, lines: $lines, viewport: $viewport)
            DecisionsCard(decisions: chart.shownDecisions, failure: chart.shownDecisionsFailure)
            DayTrades(trades: chart.trades)
          } else if chart.range != .oneDay {
            RangePicker(chart: chart)
            if let failure = chart.rangeFailure {
              UnavailableState(ChartText.barsUnavailable, message: ChartText.candlesUnavailable, cause: failure)
                .rise()
            } else if let answer = chart.rangeChart, answer.symbol == chart.symbol, answer.range == chart.range,
              answer.interval == chart.timeframe, answer.pending == nil {
              // Only a finished answer can say there are no candles: a pending one (the chart's
              // budget still filling the range) shows loading, never an empty state.
              ContentUnavailableView {
                Label { Text(ChartText.noBarsTitle) } icon: { Image(systemName: "chart.bar.xaxis") }
              } description: {
                if let cause = answer.causeText {
                  Text(ChartText.noCandles(cause))
                } else {
                  Text(ChartText.noCandlesPlain)
                }
              }
              .rise()
            } else {
              loadingView
            }
          } else if chart.pending != nil || chart.needsTodayRead {
            // Today's market data on its way: the chart's budget, or another interval being read.
            loadingView
          } else {
            ContentUnavailableView {
              Label { Text(ChartText.noBarsTitle) } icon: { Image(systemName: "chart.bar.xaxis") }
            } description: {
              Text(ChartText.noBarsBody)
            }
            .rise()
          }
        }
        .rise()
      }
    }
  }

  /// The chart's days are read: neither loading for the first time nor failed.
  private var showsContent: Bool {
    switch chart.phase {
    case .idle, .failed: return false
    case .loading where chart.series == nil: return false
    default: return true
    }
  }

  /// The chart while its bars load (mockup v102): the price, change and day's high, low and
  /// volume as skeleton blocks, the price pane's grid, a faint candle silhouette with its volume,
  /// the price and time axes, and every enabled study pane, as skeleton in the chart's own sizes;
  /// "Loading ABCD · 1 min bars" in its top left. Nothing real until the bars are read.
  private var loadingView: some View {
    LoadingChart(
      caption: chart.pending.map(PendingText.caption) ?? chart.symbol.map {
        ChartText.loadingBars($0, interval: String(localized: ChartFormat.title(chart.timeframe)))
      } ?? L10n.Common.loading,
      lines: lines, pending: chart.pending)
      .transition(.opacity)
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

/// The screen's top bar as on the design: the symbol with its last price and the day's change on
/// one row, the day under it (a menu of every recorded day), and plain blue arrows to the
/// previous and next day. At large text sizes the price goes under the symbol.
private struct DayBar: View {
  @Environment(AppModel.self) private var app
  @Environment(\.dynamicTypeSize) private var typeSize
  let chart: ChartModel
  let url: URL

  var body: some View {
    HStack(alignment: .center, spacing: Tokens.Space.s) {
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        RowStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
          if let symbol = chart.symbol {
            Text(symbol)
              .font(Tokens.Typography.metric)
              .foregroundStyle(Palette.textPrimary)
              .fixedSize()
          }
          quote
        }
        dayMenu
      }
      Spacer(minLength: 0)
      if !typeSize.stacksRows { dayStats }
      // The demo day is the only day, and a single recorded day has no neighbour: no arrows
      // then. Otherwise the arrow that leads nowhere is dimmed and refuses taps.
      if arrows.visible {
        Button {
          if let day = chart.previousDay { Task { await chart.show(day, from: url) } }
        } label: {
          arrow(Symbols.previous)
        }
        .disabled(!arrows.canGoBack)
        .accessibilityLabel(Text(ChartText.previousDay))
        Button {
          if let day = chart.nextDay { Task { await chart.show(day, from: url) } }
        } label: {
          arrow(Symbols.next)
        }
        .disabled(!arrows.canGoForward)
        .accessibilityLabel(Text(ChartText.nextDay))
      }
    }
    .buttonStyle(.glyph)
  }

  private var arrows: DayArrows {
    DayArrows(locked: chart.dayLocked, canGoBack: chart.previousDay != nil, canGoForward: chart.nextDay != nil)
  }

  private func arrow(_ symbol: String) -> some View {
    HeaderIcon(symbol: symbol).foregroundStyle(Palette.textPrimary).dimmedWhenDisabled()
  }

  /// The shown candles' high, low and volume, small and dim beside the arrows, as on the design.
  @ViewBuilder
  private var dayStats: some View {
    if let candles = chart.series?.candles, !candles.isEmpty {
      let high = candles.map(\.high).max() ?? 0
      let low = candles.map(\.low).min() ?? 0
      let volume = candles.map(\.volume).reduce(0, +)
      let rows: [(LocalizedStringResource, String)] = [(ChartText.highShort, Money.price(high)),
        (ChartText.lowShort, Money.price(low)), (ChartText.volumeShort, Volume.compact(volume))]
      Grid(alignment: .trailing, horizontalSpacing: Tokens.Space.xs, verticalSpacing: 0) {
        ForEach(rows.indices, id: \.self) { index in
          GridRow {
            Text(rows[index].0).foregroundStyle(Palette.textQuaternary)
            Text(verbatim: rows[index].1).foregroundStyle(Palette.textSecondary)
          }
        }
      }
      .font(Tokens.Typography.annotation)
      .fixedSize()
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Text(ChartText.dayStats(rows[0].1, rows[1].1, rows[2].1)))
    }
  }

  /// The last price and its change: on today's one-day chart from the previous close
  /// (`DayChange`, as Webull shows a day's change), else from the shown range's first open.
  @ViewBuilder
  private var quote: some View {
    if let candles = chart.series?.candles, let first = candles.first, let last = candles.last {
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
    }
  }

  private func dayLabel(live: Bool) -> some View {
    HStack(spacing: Tokens.Space.xs) {
      if let day = chart.selectedDay {
        Text(verbatim: DayText.day(day.noonInNewYork))
      }
      if live {
        Text(verbatim: Format.separator.trimmingCharacters(in: .whitespaces))
        Text(ChartText.todayLive)
      }
    }
    .fixedSize()
  }

  /// The chosen day, with the live dot while it is today; a tap lists every recorded day.
  private var dayMenu: some View {
    Menu {
      Picker(selection: Binding(
        get: { chart.selectedDay },
        set: { day in if let day { Task { await chart.show(day, from: url) } } }
      )) {
        ForEach(chart.days) { summary in
          Text(verbatim: DayText.day(summary.day.noonInNewYork)).tag(Optional(summary.day))
        }
      } label: {
        Text(ChartText.day)
      }
    } label: {
      HStack(spacing: Tokens.Space.xs) {
        if chart.isToday {
          // One pulse per new minute bar of the shown symbol (a real read), still in between.
          PulseDot(Palette.accent, size: Tokens.Size.dotSmall, event: chart.series?.candles.last?.start)
        }
        // One line: "today · live" gives way first, the date never wraps (the dot still says live).
        ViewThatFits(in: .horizontal) {
          dayLabel(live: chart.isToday)
          dayLabel(live: false)
        }
      }
      .font(Tokens.Typography.annotation)
      .foregroundStyle(Palette.textTertiary)
    }
    // One day to choose from (the demo day, or the only recorded day): the menu would list just
    // the shown day, so it stays a label.
    .disabled(!arrows.visible)
  }
}

/// One chip per symbol with captured bars that day, open positions first: a pulsing dot marks an
/// open position, a plain dot a symbol the bot traded.
private struct SymbolChips: View {
  @Environment(AppModel.self) private var app
  let chart: ChartModel
  let url: URL

  var body: some View {
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
  }
}

/// Timeframe, candles or a line, zoom and the way back to the newest candle, then which lines the
/// chart draws.
private struct ChartControls: View {
  let chart: ChartModel
  let series: ChartSeries
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
          .disabled(!viewport.canZoomOut(series))
          .accessibilityLabel(Text(ChartText.zoomOut))
        Button { zoom(by: 1 / Tokens.Chart.zoomStep) } label: { HeaderIcon(symbol: "plus").dimmedWhenDisabled() }
          .disabled(!viewport.canZoomIn)
          .accessibilityLabel(Text(ChartText.zoomIn))
      }
      .foregroundStyle(Palette.textPrimary)
      .buttonStyle(.glyph)
      if chart.isToday {
        let following = viewport.showsEnd(series)
        Button {
          withAnimation(Tokens.Motion.quick) { viewport.followEnd(series) }
        } label: {
          Text(ChartText.live).textCase(.uppercase)
        }
        .buttonStyle(.chip(selected: following, tone: .accent))
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
    withAnimation(Tokens.Motion.quick) { viewport.zoom(by: factor, series) }
  }
}

/// The chosen symbol's closed trades of the day.
private struct DayTrades: View {
  let trades: [DayTrade]

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      CardLabel(ChartText.trades)
      if trades.isEmpty {
        Text(ChartText.noTrades)
          .font(Tokens.Typography.callout)
          .foregroundStyle(Palette.textTertiary)
      }
      // The latest trades, then "Show all N ›": a busy symbol trades many times a day.
      CappedList(trades.sorted { $0.closedAt.date > $1.closedAt.date }, id: \.id, title: ChartText.trades,
        limit: Tokens.Lists.comparedRows) { _, trade in tradeRow(trade) }
    }
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, alignment: .leading)
    .tickrCard()
  }

  /// A trade: its times and prices, then its result in dollars and in R.
  private func tradeRow(_ trade: DayTrade) -> some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        HStack(spacing: Tokens.Space.xs) {
          Text(trade.openedAt.date, format: ChartFormat.time)
          Image(systemName: "arrow.right").imageScale(.small)
          Text(trade.closedAt.date, format: ChartFormat.time)
        }
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(Palette.textTertiary)
        HStack(spacing: Tokens.Space.xs) {
          Text(verbatim: Money.price(trade.entryPrice.value))
          Image(systemName: "arrow.right").imageScale(.small)
          Text(verbatim: Money.price(trade.exitPrice.value))
        }
        .font(Tokens.Typography.bodyMono)
        .foregroundStyle(Palette.textSecondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: Tokens.Space.xxs) {
        Text(Money.signedUSD(trade.resultUsd.value))
          .font(Tokens.Typography.bodyMono)
          .foregroundStyle(Palette.result(trade.resultUsd.value))
        if let r = trade.resultR {
          Text(Risk.text(r))
            .font(Tokens.Typography.captionMono)
            .foregroundStyle(Palette.textTertiary)
        }
      }
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

/// The Chart tab while its bars load (see `ChartTab.loadingView`).
private struct LoadingChart: View {
  let caption: LocalizedStringResource
  let lines: CandleChart.Lines
  /// How far a read the chart's request budget holds back has got, shown as a progress line.
  var pending: ChartPendingV1?

  /// The silhouette's candles and the price pane's grid lines across and down, as the board's.
  static let candles = 34
  static let rows = 5
  static let columns = 4
  /// Widths of the header's blocks, in points: the price, its change, and the day's high, low
  /// and volume figures (the board's).
  static let price: CGFloat = 54
  static let priceHeight: CGFloat = 18
  static let change: CGFloat = 48
  static let dayFigure: CGFloat = 34

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      Skeleton(nil) {
        HStack(alignment: .center, spacing: Tokens.Space.s) {
          SkeletonBlock(.block(height: Self.priceHeight), width: Self.price)
          SkeletonBlock(.line, width: Self.change)
          Spacer(minLength: Tokens.Space.s)
          VStack(alignment: .trailing, spacing: Tokens.Space.xs) {
            ForEach(0..<Tokens.Loading.lines, id: \.self) { _ in
              SkeletonBlock(.line, width: Self.dayFigure)
            }
          }
        }
      }
      Skeleton(nil) {
        SkeletonCandles(candles: Self.candles, rows: Self.rows, columns: Self.columns,
          axisWidth: CandleChart.axisLabelWidth, showsTime: true, volume: lines.volume)
          .padding(Tokens.Space.s)
          .frame(height: CandleChart.priceHeight)
      }
      .overlay(alignment: .topLeading) {
        Text(caption)
          .font(Tokens.Typography.captionMono)
          .foregroundStyle(Palette.textQuaternary)
          .fixedSize(horizontal: false, vertical: true)
          .padding(Tokens.Space.s)
      }
      .overlay(alignment: .top) {
        if let pending {
          ProgressLine(fraction: pending.fraction, label: PendingText.caption(pending))
        }
      }
      .tickrCard()
      ForEach(lines.panes, id: \.self) { _ in
        Skeleton(nil) {
          SkeletonPane(axisWidth: CandleChart.axisLabelWidth)
            .frame(height: CandleChart.paneHeight)
        }
        .tickrCard()
      }
    }
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
