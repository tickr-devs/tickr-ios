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
      .padding(.horizontal, Tokens.Space.l)
      .padding(.bottom, Tokens.Space.xl)
      .animation(Tokens.Motion.standard, value: chart.phase)
    }
    .scrollContentBackground(.hidden)
    .background(TickrBackground())
    // The design starts with the symbol: no title row, the tab's name stays for VoiceOver.
    .tabRoot(.chart)
    // The symbol and the day stay on top as the screen's bar: the chart scrolls under it with the
    // system's scroll edge effect, never bare under the status bar.
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
            // The bot's trades, position and strategy marks belong to the chosen day's minutes:
            // on a longer range their times fall between drawn candles, so they stay off it.
            let oneDay = chart.range == .oneDay
            CandleChart(series: series, times: chart.times, studies: chart.studies, atr: chart.atr,
              trades: oneDay ? chart.trades : [], position: oneDay ? chart.openPosition : nil,
              events: oneDay ? chart.events : [], lines: lines, rangeTitle: RangePicker.title(chart.range),
              fitsAll: !oneDay, viewport: $viewport)
              // Its panes have a fixed height: past this size the scale's tags and legends would
              // cover each other and the candles.
              .dynamicTypeSize(...CandleChart.largestText)
            ChartControls(chart: chart, series: series, lines: $lines, viewport: $viewport)
            DecisionsCard(decisions: chart.shownDecisions, failure: chart.shownDecisionsFailure)
            DayTrades(trades: chart.trades)
          } else if chart.range != .oneDay {
            RangePicker(chart: chart)
            if let failure = chart.rangeFailure {
              ReadFailureNote(ChartText.candlesUnavailable, detail: failure)
                .frame(maxWidth: .infinity, alignment: .leading)
                .rise()
            } else if let answer = chart.rangeChart, answer.symbol == chart.symbol, answer.range == chart.range,
              answer.interval == chart.timeframe {
              ContentUnavailableView {
                Label { Text(ChartText.noBarsTitle) } icon: { Image(systemName: "chart.bar.xaxis") }
              } description: {
                Text(ChartText.noCandles(answer.cause ?? ChartFormat.missing))
              }
              .rise()
            } else {
              loadingView
            }
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

  private var loadingView: some View {
    ProgressView { Text(ChartText.loading) }
      .frame(maxWidth: .infinity)
      .padding(.top, Tokens.Space.xxl)
      .transition(.opacity)
  }

  /// Changes whenever a different chart is on screen, restarting the reload loop.
  private var liveKey: LiveKey {
    LiveKey(day: chart.selectedDay, symbol: chart.symbol, isToday: chart.isToday)
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
  /// them again now and then so today's last candle stays current.
  private func followRange() async {
    guard chart.range != .oneDay, let url = app.connection.url else { return }
    repeat {
      await chart.loadRange(url)
      guard chart.timeframe.isIntraday else { return }
      try? await Task.sleep(for: .seconds(ChartModel.rangeReloadSeconds))
    } while !Task.isCancelled
  }

  private struct LiveKey: Hashable {
    let day: WireDate?
    let symbol: String?
    let isToday: Bool
  }

  /// While today's chart is on screen, reload its bars so the last candle stays current.
  private func followToday() async {
    while chart.isToday, !Task.isCancelled {
      try? await Task.sleep(for: .seconds(ChartModel.liveReloadSeconds))
      guard !Task.isCancelled, let url = app.connection.url else { return }
      await chart.reloadBars(url)
    }
  }
}

/// The screen's top bar as on the design: the symbol with its last price and the day's change on
/// one row, the day under it (a menu of every recorded day), and plain blue arrows to the
/// previous and next day. At large text sizes the price goes under the symbol.
private struct DayBar: View {
  /// Symbols of the arrows to the previous and next day.
  static let previousSymbol = "chevron.left"
  static let nextSymbol = "chevron.right"

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
              .lineLimit(1)
              .fixedSize()
          }
          quote
        }
        dayMenu
      }
      Spacer(minLength: 0)
      if !typeSize.stacksRows { dayStats }
      // The demo day is the only day: no arrows to step away from it.
      if !chart.dayLocked {
        Button {
          if let day = chart.previousDay { Task { await chart.show(day, from: url) } }
        } label: {
          arrow(Self.previousSymbol)
        }
        .disabled(chart.previousDay == nil)
        .accessibilityLabel(Text(ChartText.previousDay))
        Button {
          if let day = chart.nextDay { Task { await chart.show(day, from: url) } }
        } label: {
          arrow(Self.nextSymbol)
        }
        .disabled(chart.nextDay == nil)
        .accessibilityLabel(Text(ChartText.nextDay))
      }
    }
    .buttonStyle(.borderless)
  }

  private func arrow(_ symbol: String) -> some View {
    HeaderIcon(symbol: symbol).foregroundStyle(Palette.textPrimary)
  }

  /// The shown candles' high, low and volume, small and dim beside the arrows, as on the design.
  @ViewBuilder
  private var dayStats: some View {
    if let candles = chart.series?.candles, !candles.isEmpty {
      let high = candles.map(\.high).max() ?? 0
      let low = candles.map(\.low).min() ?? 0
      let volume = candles.map(\.volume).reduce(0, +)
      let rows: [(LocalizedStringResource, String)] = [(ChartText.highShort, high.formatted(ChartFormat.price)),
        (ChartText.lowShort, low.formatted(ChartFormat.price)), (ChartText.volumeShort, volume.formatted(ChartFormat.volume))]
      Grid(alignment: .trailing, horizontalSpacing: Tokens.Space.xs, verticalSpacing: 0) {
        ForEach(rows.indices, id: \.self) { index in
          GridRow {
            Text(rows[index].0).foregroundStyle(Palette.textQuaternary)
            Text(verbatim: rows[index].1).foregroundStyle(Palette.textSecondary)
          }
        }
      }
      .font(Tokens.Typography.annotation)
      .lineLimit(1)
      .fixedSize()
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Text(ChartText.dayStats(rows[0].1, rows[1].1, rows[2].1)))
    }
  }

  /// The last price, coloured by the day so far, and its change from the day's first open.
  @ViewBuilder
  private var quote: some View {
    if let candles = chart.series?.candles, let first = candles.first, let last = candles.last {
      let amount = last.close - first.open
      let change = first.open == 0 ? 0 : amount / first.open
      let tone = amount >= 0 ? Palette.profitText : Palette.lossText
      HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
        Text(last.close, format: ChartFormat.price)
          .font(.headline.monospaced().bold())
          .contentTransition(.numericText(value: last.close))
        Text(change, format: ChartFormat.change)
          .font(Tokens.Typography.captionMono)
      }
      .foregroundStyle(tone)
      .lineLimit(1)
      .minimumScaleFactor(Tokens.Shrink.standard)
      .accessibilityElement(children: .combine)
    }
  }

  private func dayLabel(live: Bool) -> some View {
    HStack(spacing: Tokens.Space.xs) {
      if let day = chart.selectedDay {
        Text(verbatim: Format.day(day.noonInNewYork))
      }
      if live {
        Text(verbatim: Format.separator.trimmingCharacters(in: .whitespaces))
        Text(ChartText.todayLive)
      }
    }
    .lineLimit(1)
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
          Text(verbatim: Format.day(summary.day.noonInNewYork)).tag(Optional(summary.day))
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
      .lineLimit(1)
      .minimumScaleFactor(Tokens.Shrink.standard)
      .font(Tokens.Typography.annotation)
      .foregroundStyle(Palette.textTertiary)
    }
    .disabled(chart.dayLocked)
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
              Text(symbol).bold()
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
            .chip(on: selected)
          }
          .buttonStyle(.plain)
          .accessibilityAddTraits(selected ? .isSelected : [])
        }
      }
    }
    .scrollIndicators(.hidden)
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
          styleControl
          following
        }
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
          HStack(spacing: Tokens.Space.s) {
            timeframes
            styleControl
          }
          following
        }
      }
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
          .chip(on: false)
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
          Text(ChartFormat.title(timeframe)).chip(on: selected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
      }
    }
    .fixedSize()
  }

  /// Zoom out, zoom in, and LIVE: the way back to the newest candle, today only.
  private var following: some View {
    HStack(spacing: Tokens.Space.s) {
      Group {
        Button { zoom(by: Tokens.Chart.zoomStep) } label: { HeaderIcon(symbol: "minus") }
          .disabled(!viewport.canZoomOut(series))
          .accessibilityLabel(Text(ChartText.zoomOut))
        Button { zoom(by: 1 / Tokens.Chart.zoomStep) } label: { HeaderIcon(symbol: "plus") }
          .disabled(!viewport.canZoomIn)
          .accessibilityLabel(Text(ChartText.zoomIn))
      }
      .foregroundStyle(Palette.textPrimary)
      .buttonStyle(.borderless)
      if chart.isToday {
        let following = viewport.showsEnd(series)
        Button {
          withAnimation(Tokens.Motion.quick) { viewport.followEnd(series) }
        } label: {
          Text(ChartText.live).textCase(.uppercase).chip(on: following, tint: Palette.accent, text: Palette.accentText)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text(ChartText.liveHint))
        .accessibilityAddTraits(following ? .isSelected : [])
      }
    }
    .fixedSize()
  }

  /// Symbols of the indicator menu's chip ("ƒx ▾").
  static let indicatorsSymbol = "function"
  static let menuSymbol = "chevron.down"

  /// Candles or a line: one chip with the design's glyph of the way the chart draws now; a tap
  /// switches to the other. VoiceOver reads the way it draws now ("Candles" or "Line").
  private var styleControl: some View {
    let candles = lines.style == .candles
    return Button {
      lines.style = candles ? .line : .candles
    } label: {
      DesignGlyphView(candles ? .candles : .line, side: Tokens.Size.chipGlyph)
        .frame(minHeight: Tokens.Size.iconButtonCompact)
        .padding(.horizontal, Tokens.Space.s)
        .background(Palette.info.opacity(TickrTabBar.selectedWash), in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.separatorStrong, lineWidth: Tokens.Stroke.thin))
        .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .fixedSize()
    .accessibilityLabel(Text(candles ? ChartText.candles : ChartText.lineStyle))
  }

  /// A line's chip: washed and outlined in `info` while the chart draws it.
  private func toggle(_ title: LocalizedStringResource, isOn: Binding<Bool>) -> some View {
    Button { isOn.wrappedValue.toggle() } label: {
      Text(title).bold().chip(on: isOn.wrappedValue)
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isOn.wrappedValue ? .isSelected : [])
  }

  private func zoom(by factor: Double) {
    withAnimation(Tokens.Motion.quick) { viewport.zoom(by: factor, series) }
  }
}

/// The design's capsule chip: monospaced, with a coloured border and wash while it is on.
private struct ChipLook: ViewModifier {
  let on: Bool
  let tint: Color
  let text: Color

  func body(content: Content) -> some View {
    content
      .font(Tokens.Typography.captionMono)
      .lineLimit(1)
      .fixedSize()
      .foregroundStyle(on ? text : Palette.textSecondary)
      .padding(.horizontal, Tokens.Space.m)
      .padding(.vertical, Tokens.Space.xs + Tokens.Space.xxs)
      .background(on ? tint.opacity(Tokens.Opacity.wash) : Palette.surface, in: Capsule())
      .overlay {
        Capsule().strokeBorder(on ? tint : Palette.separatorStrong, lineWidth: Tokens.Stroke.thin)
      }
      .contentShape(Capsule())
  }
}

private extension View {
  func chip(on: Bool, tint: Color = Palette.info, text: Color = Palette.infoText) -> some View {
    modifier(ChipLook(on: on, tint: tint, text: text))
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
      ForEach(trades) { trade in
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
            Text(Money.signedUSD(trade.resultGrossUsd.value))
              .font(Tokens.Typography.bodyMono)
              .foregroundStyle(Palette.result(trade.resultGrossUsd.value))
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
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, alignment: .leading)
    .tickrCard()
  }
}

/// How far back the chart reaches: the chosen day, five sessions, one or three months, a year.
private struct RangePicker: View {
  let chart: ChartModel

  var body: some View {
    SegmentChips(options: ChartRange.allCases.map { ($0, Text(Self.title($0))) },
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
