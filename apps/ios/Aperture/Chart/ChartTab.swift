import ApertureDesign
import ApertureKit
import SwiftUI

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
          content(url)
        }
      }
      .padding(.horizontal, Tokens.Space.l)
      .padding(.bottom, Tokens.Space.xl)
      .animation(Tokens.Motion.standard, value: chart.phase)
    }
    .scrollContentBackground(.hidden)
    .background(ApertureBackground())
    .navigationTitle(Text(ChartText.title))
    // The design starts with the symbol; the title stays for VoiceOver and the app switcher.
    .toolbarVisibility(.hidden, for: .navigationBar)
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
      ContentUnavailableView {
        Label { Text(ChartText.failedTitle) } icon: { Image(systemName: "exclamationmark.triangle") }
      } description: {
        Text(cause)
      } actions: {
        Button { Task { await chart.load(url, preferring: chart.symbol) } } label: { Text(ChartText.retry) }
          .buttonStyle(.borderedProminent)
      }
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
          DayHeader(chart: chart, url: url)
          SymbolChips(chart: chart, url: url)
          if let series = chart.series, !series.candles.isEmpty {
            // The controls sit above the chart, as in charting apps, so the panes below never push
            // them under the tab bar.
            ChartControls(chart: chart, series: series, lines: $lines, viewport: $viewport)
            // The bot's trades, position and strategy marks belong to the chosen day's minutes:
            // on a longer range their times fall between drawn candles, so they stay off it.
            let oneDay = chart.range == .oneDay
            CandleChart(series: series, times: chart.times, studies: chart.studies, atr: chart.atr,
              trades: oneDay ? chart.trades : [], position: oneDay ? chart.openPosition : nil,
              events: oneDay ? chart.events : [], lines: lines, fitsAll: !oneDay, viewport: $viewport)
            DayTrades(trades: chart.trades)
            DecisionsCard(decisions: chart.shownDecisions, failure: chart.shownDecisionsFailure)
          } else if chart.range != .oneDay {
            RangePicker(chart: chart)
            if let failure = chart.rangeFailure {
              ContentUnavailableView {
                Label { Text(ChartText.failedTitle) } icon: { Image(systemName: "wifi.exclamationmark") }
              } description: {
                Text(ChartText.candlesUnavailable(failure))
              }
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

/// The symbol with its last price and change over the day, and the day picker.
private struct DayHeader: View {
  let chart: ChartModel
  let url: URL

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      HStack(alignment: .center, spacing: Tokens.Space.s) {
        if let symbol = chart.symbol {
          Text(symbol)
            .font(Tokens.Typography.title)
            .foregroundStyle(Palette.textPrimary)
        }
        dayMenu
        Spacer(minLength: 0)
        Group {
          Button {
            if let day = chart.previousDay { Task { await chart.show(day, from: url) } }
          } label: {
            Image(systemName: "chevron.backward")
          }
          .disabled(chart.previousDay == nil)
          .accessibilityLabel(Text(ChartText.previousDay))
          Button {
            if let day = chart.nextDay { Task { await chart.show(day, from: url) } }
          } label: {
            Image(systemName: "chevron.forward")
          }
          .disabled(chart.nextDay == nil)
          .accessibilityLabel(Text(ChartText.nextDay))
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
      }
      if let candles = chart.series?.candles, let first = candles.first, let last = candles.last {
        // The quote: the last price large, coloured by the day so far, with its change from
        // the day's first open; the day's range and volume beside it.
        let amount = last.close - first.open
        let change = first.open == 0 ? 0 : amount / first.open
        let tone = amount >= 0 ? Palette.profitText : Palette.lossText
        HStack(alignment: .lastTextBaseline, spacing: Tokens.Space.m) {
          VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
            Text(last.close, format: ChartFormat.price)
              .font(Tokens.Typography.hero)
              .foregroundStyle(tone)
              .contentTransition(.numericText(value: last.close))
            HStack(spacing: Tokens.Space.s) {
              Group {
                if amount >= 0 {
                  Image(systemName: "arrowtriangle.up.fill")
                } else {
                  Image(systemName: "arrowtriangle.down.fill")
                }
              }
              .imageScale(.small)
              Text(amount, format: ChartFormat.signedPrice)
              Text(change, format: ChartFormat.change)
            }
            .font(Tokens.Typography.calloutMono)
            .foregroundStyle(tone)
          }
          Spacer(minLength: Tokens.Space.s)
          Grid(alignment: .leading, horizontalSpacing: Tokens.Space.s, verticalSpacing: Tokens.Space.xxs) {
            GridRow {
              Text(ChartText.highLow).foregroundStyle(Palette.textTertiary)
              Text(ChartText.range(
                (candles.map(\.high).max() ?? last.high).formatted(ChartFormat.price),
                (candles.map(\.low).min() ?? last.low).formatted(ChartFormat.price)))
                .foregroundStyle(Palette.textSecondary)
            }
            GridRow {
              Text(ChartText.dayVolume).foregroundStyle(Palette.textTertiary)
              Text(candles.reduce(0) { $0 + $1.volume }, format: ChartFormat.volume)
                .foregroundStyle(Palette.textSecondary)
            }
          }
          .font(Tokens.Typography.captionMono)
        }
      }
    }
    .padding(.top, Tokens.Space.s)
  }

  private func dayLabel(live: Bool) -> some View {
    HStack(spacing: Tokens.Space.xs) {
      if let day = chart.selectedDay {
        Text(day.noonInNewYork, format: ChartFormat.day)
      }
      if live {
        Text(ChartText.todayLive)
          .foregroundStyle(Palette.accentText)
      }
    }
    .lineLimit(1)
    .fixedSize()
  }

  /// The chosen day; a menu of every recorded day.
  private var dayMenu: some View {
    Menu {
      Picker(selection: Binding(
        get: { chart.selectedDay },
        set: { day in if let day { Task { await chart.show(day, from: url) } } }
      )) {
        ForEach(chart.days) { summary in
          Text(summary.day.noonInNewYork, format: ChartFormat.day).tag(Optional(summary.day))
        }
      } label: {
        Text(ChartText.day)
      }
    } label: {
      HStack(spacing: Tokens.Space.xs) {
        if chart.isToday {
          // Still: a menu label does not animate, and a frozen ring would sit over the date.
          PulseDot(Palette.accent, size: Tokens.Size.dotSmall, pulsing: false)
        }
        // One line: "Today · live" gives way first, the date never wraps (the dot still says live).
        ViewThatFits(in: .horizontal) {
          dayLabel(live: chart.isToday)
          dayLabel(live: false)
        }
        Image(systemName: "chevron.up.chevron.down")
          .imageScale(.small)
      }
      .font(Tokens.Typography.captionMono)
      .foregroundStyle(Palette.textTertiary)
    }
  }
}

/// One chip per symbol with captured bars that day, open positions first: a pulsing dot marks an
/// open position, a plain dot a symbol the bot traded.
private struct SymbolChips: View {
  @Environment(AppModel.self) private var app
  let chart: ChartModel
  let url: URL

  var body: some View {
    ScrollView(.horizontal) {
      HStack(spacing: Tokens.Space.s) {
        ForEach(chart.symbols, id: \.self) { symbol in
          let selected = symbol == chart.symbol
          let open = chart.openSymbols.contains(symbol)
          let traded = chart.day?.trades.contains { $0.symbol == symbol } ?? false
          Button {
            Task { await chart.show(symbol: symbol, from: url) }
          } label: {
            HStack(spacing: Tokens.Space.xs) {
              if open {
                // Pulses only while the status saying it is open is current.
                PulseDot(Palette.accent, size: Tokens.Size.dotSmall, pulsing: app.response?.stale == false)
                  .accessibilityLabel(Text(ChartText.openPosition))
              }
              Text(symbol)
              if traded {
                Circle()
                  .fill(Palette.info)
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
    .sensoryFeedback(.selection, trigger: chart.symbol)
  }
}

/// Timeframe, zoom and the way back to the newest candle, then which lines the chart draws.
private struct ChartControls: View {
  let chart: ChartModel
  let series: ChartSeries
  @Binding var lines: CandleChart.Lines
  @Binding var viewport: ChartViewport

  var body: some View {
    @Bindable var chart = chart
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      RangePicker(chart: chart)
      ScrollView(.horizontal) {
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
      }
      .scrollIndicators(.hidden)
      HStack(spacing: Tokens.Space.s) {
        Picker(selection: $lines.style) {
          Label { Text(ChartText.candles) } icon: { Image(systemName: "chart.bar.fill") }
            .tag(CandleChart.Style.candles)
          Label { Text(ChartText.lineStyle) } icon: { Image(systemName: "chart.xyaxis.line") }
            .tag(CandleChart.Style.line)
        } label: {
          Text(ChartText.lineStyle)
        }
        .pickerStyle(.segmented)
        .labelStyle(.iconOnly)
        .fixedSize()
        Group {
          Button { zoom(by: ChartViewport.zoomStep) } label: { Image(systemName: "minus") }
            .disabled(!viewport.canZoomOut(series))
            .accessibilityLabel(Text(ChartText.zoomOut))
          Button { zoom(by: 1 / ChartViewport.zoomStep) } label: { Image(systemName: "plus") }
            .disabled(!viewport.canZoomIn)
            .accessibilityLabel(Text(ChartText.zoomIn))
        }
        .buttonStyle(.borderless)
        .frame(minWidth: Tokens.Size.iconWell, minHeight: Tokens.Size.iconWell)
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
        Spacer(minLength: Tokens.Space.s)
        Menu {
          Section {
            Toggle(isOn: $lines.vwap) { Text(ChartText.vwap) }
            Toggle(isOn: $lines.fastEMA) { Text(ChartText.ema(Indicators.fastEMAPeriod)) }
            Toggle(isOn: $lines.slowEMA) { Text(ChartText.ema(Indicators.slowEMAPeriod)) }
            Toggle(isOn: $lines.movingAverages) { Text(ChartText.movingAverages) }
            Toggle(isOn: $lines.bollinger) { Text(ChartText.bollinger) }
            Toggle(isOn: $lines.volume) { Text(ChartText.volume) }
          } header: {
            Text(ChartText.overlays)
          }
          Section {
            Toggle(isOn: $lines.macd) { Text(ChartText.macdToggle) }
            Toggle(isOn: $lines.stochastic) { Text(ChartText.stochasticToggle) }
            Toggle(isOn: $lines.rsi) { Text(ChartText.rsiToggle) }
            Toggle(isOn: $lines.atr) { Text(ChartText.atr(Indicators.atrPeriod)) }
          } header: {
            Text(ChartText.panes)
          }
        } label: {
          Label { Text(ChartText.indicators) } icon: { Image(systemName: "square.grid.2x2") }
            .labelStyle(.iconOnly)
            .chip(on: true)
        }
        .menuActionDismissBehavior(.disabled)
      }
    }
    .foregroundStyle(Palette.infoText)
    .sensoryFeedback(.selection, trigger: chart.timeframe)
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
      .foregroundStyle(on ? text : Palette.textTertiary)
      .padding(.horizontal, Tokens.Space.m)
      .padding(.vertical, Tokens.Space.s)
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
              Text(trade.entryPrice.description)
              Image(systemName: "arrow.right").imageScale(.small)
              Text(trade.exitPrice.description)
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
    .apertureCard()
  }
}

/// How far back the chart reaches: the chosen day, five sessions, one or three months, a year.
private struct RangePicker: View {
  let chart: ChartModel

  var body: some View {
    Picker(selection: Binding(get: { chart.range }, set: { chart.choose(range: $0) })) {
      ForEach(ChartRange.allCases, id: \.self) { range in
        Text(Self.title(range)).tag(range)
      }
    } label: {
      Text(ChartText.range)
    }
    .pickerStyle(.segmented)
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
