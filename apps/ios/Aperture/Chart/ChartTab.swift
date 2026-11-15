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
    .refreshable {
      guard let url = app.connection.url else { return }
      await chart.load(url, preferring: chart.symbol)
    }
  }

  @ViewBuilder
  private func content(_ url: URL) -> some View {
    switch chart.phase {
    case .idle:
      loadingView
    case .loading where chart.series == nil:
      loadingView
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
            CandleChart(series: series, atr: chart.atr, trades: chart.trades, position: chart.openPosition,
              events: chart.events, lines: lines, viewport: $viewport)
            ChartControls(chart: chart, series: series, lines: $lines, viewport: $viewport)
            DayTrades(trades: chart.trades)
            DecisionsCard(decisions: chart.shownDecisions, failure: chart.shownDecisionsFailure)
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
  }

  /// Changes whenever a different chart is on screen, restarting the reload loop.
  private var liveKey: LiveKey {
    LiveKey(day: chart.selectedDay, symbol: chart.symbol, isToday: chart.isToday)
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
    HStack(alignment: .center, spacing: Tokens.Space.s) {
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        if let symbol = chart.symbol, let candles = chart.series?.candles, let first = candles.first,
          let last = candles.last {
          HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
            Text(symbol)
              .font(Tokens.Typography.metric)
              .foregroundStyle(Palette.textPrimary)
            Text(last.close, format: ChartFormat.price)
              .font(Tokens.Typography.bodyMono)
              .foregroundStyle(Palette.textSecondary)
              .contentTransition(.numericText(value: last.close))
            let change = first.open == 0 ? 0 : (last.close - first.open) / first.open
            Text(change, format: ChartFormat.change)
              .font(Tokens.Typography.calloutMono)
              .foregroundStyle(change >= 0 ? Palette.profitText : Palette.lossText)
          }
        }
        dayMenu
      }
      Spacer(minLength: 0)
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
    .padding(.top, Tokens.Space.s)
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
        if let day = chart.selectedDay {
          Text(day.noonInNewYork, format: ChartFormat.day)
        }
        if chart.isToday {
          Text(ChartText.todayLive)
            .foregroundStyle(Palette.accentText)
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
      HStack(spacing: Tokens.Space.s) {
        ForEach(Timeframe.allCases) { timeframe in
          let selected = timeframe == chart.timeframe
          Button { chart.timeframe = timeframe } label: {
            Text(ChartFormat.title(timeframe)).chip(on: selected)
          }
          .buttonStyle(.plain)
          .accessibilityAddTraits(selected ? .isSelected : [])
        }
        Spacer(minLength: Tokens.Space.s)
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
      }
      ScrollView(.horizontal) {
        HStack(spacing: Tokens.Space.s) {
          Toggle(isOn: $lines.vwap) { Text(ChartText.vwap) }
            .tint(Palette.seriesVWAP)
          Toggle(isOn: $lines.fastEMA) { Text(ChartText.ema(Indicators.fastEMAPeriod)) }
            .tint(Palette.seriesFastEMA)
          Toggle(isOn: $lines.slowEMA) { Text(ChartText.ema(Indicators.slowEMAPeriod)) }
            .tint(Palette.seriesSlowEMA)
          Toggle(isOn: $lines.volume) { Text(ChartText.volume) }
            .tint(Palette.info)
          Toggle(isOn: $lines.atr) { Text(ChartText.atr(Indicators.atrPeriod)) }
            .tint(Palette.seriesATR)
        }
        .toggleStyle(ChipToggleStyle())
      }
      .scrollIndicators(.hidden)
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

/// A line toggle as a chip: a dot of the line's colour (the toggle's tint), blue border when on.
private struct ChipToggleStyle: ToggleStyle {
  func makeBody(configuration: Configuration) -> some View {
    Button { configuration.isOn.toggle() } label: {
      HStack(spacing: Tokens.Space.xs) {
        Circle()
          .fill(.tint)
          .frame(width: Tokens.Size.dotSmall, height: Tokens.Size.dotSmall)
        configuration.label
      }
      .chip(on: configuration.isOn)
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(configuration.isOn ? .isSelected : [])
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
