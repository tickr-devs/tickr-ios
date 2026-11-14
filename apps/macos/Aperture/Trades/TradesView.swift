import ApertureDesign
import ApertureKit
import Charts
import SwiftUI

/// Trades & days: recorded days on the left; the shown day's figures, its trades and what-if
/// replays on the right. Picking a day here is the same as picking it in the toolbar.
struct TradesView: View {
  @Environment(AppModel.self) private var model
  @AppStorage(ChartView.Keys.symbol) private var chartSymbol = ""
  @State private var selection: DayTrade.ID?

  /// Entrance order of the screen's parts.
  private enum Order: Int {
    case days = 0, stats, trades, whatIf
  }

  var body: some View {
    HStack(alignment: .top, spacing: Tokens.Space.l) {
      DaysColumn()
        .frame(width: Tokens.Size.sideColumn)
        .rise(step: Order.days.rawValue)
      VStack(alignment: .leading, spacing: Tokens.Space.l) {
        DayStatsRow()
          .rise(step: Order.stats.rawValue)
        TradesTable(selection: $selection, showOnChart: showOnChart)
          .rise(step: Order.trades.rawValue)
        WhatIfCard()
          .rise(step: Order.whatIf.rawValue)
      }
    }
    .padding(Tokens.Space.xl)
    .frame(maxWidth: Tokens.Size.contentMaxWidth, maxHeight: .infinity, alignment: .top)
    .onChange(of: model.shownDay) { selection = nil }
  }

  /// Opens the Chart on the trade's symbol (the shown day stays).
  private func showOnChart(_ trade: DayTrade) {
    chartSymbol = trade.symbol
    model.section = .chart
  }
}

// MARK: Days

/// Recorded days, newest first, with a bar per day's result.
private struct DaysColumn: View {
  @Environment(AppModel.self) private var model

  /// Days the result bars cover.
  static let shownDays = 20
  /// Height of the result bars, in points.
  static let barsHeight: CGFloat = 70

  var body: some View {
    Card(L10n.Trades.days) {
      if model.days.isEmpty {
        Footnote(model.historyError == nil ? L10n.Trades.noDays : L10n.Trades.daysUnavailable)
      } else {
        DayBars(days: Array(model.days.prefix(Self.shownDays).reversed()), shown: model.shownDay)
          .frame(height: Self.barsHeight)
        ScrollView {
          LazyVStack(spacing: Tokens.Space.xxs) {
            ForEach(model.days) { day in
              Button { select(day.day) } label: {
                DayRow(day: day, isShown: day.day == model.shownDay, isToday: day.day == model.today)
              }
              .buttonStyle(.plain)
            }
          }
        }
        .scrollIndicators(.never)
      }
    }
  }

  private func select(_ day: WireDate) {
    if day == model.today {
      model.showToday()
    } else {
      model.selectedDay = day
    }
  }
}

/// One bar per day: its gross result, the shown day in full colour.
private struct DayBars: View {
  let days: [DaySummary]
  let shown: WireDate

  /// Share of a day's slot its bar fills.
  static let barShare = 0.6

  var body: some View {
    Chart(days) { day in
      let result = NSDecimalNumber(decimal: day.resultGrossUsd.value).doubleValue
      BarMark(
        x: .value(String(localized: L10n.Trades.day), day.day.text),
        y: .value(String(localized: L10n.Trades.result), result),
        width: .ratio(Self.barShare))
        .foregroundStyle(Palette.result(day.resultGrossUsd.value).opacity(day.day == shown ? 1 : Tokens.Opacity.faint))
        .clipShape(.rect(cornerRadius: Tokens.Radius.small / 2))
    }
    .chartXAxis(.hidden)
    .chartYAxis(.hidden)
    .animation(Tokens.Motion.standard, value: shown)
  }
}

/// A day in the list: date, trades with wins and losses, and its result.
private struct DayRow: View {
  let day: DaySummary
  let isShown: Bool
  let isToday: Bool

  var body: some View {
    HStack(spacing: Tokens.Space.s) {
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        HStack(spacing: Tokens.Space.xs) {
          Text(verbatim: Format.dayLabel(day.day))
            .font(Tokens.Typography.calloutMono)
            .foregroundStyle(Palette.textPrimary)
          if isToday { Badge(L10n.Common.today, color: Palette.accentText) }
        }
        Text(L10n.Trades.closedWinsLosses(day.trades, day.wins, day.losses))
          .font(Tokens.Typography.caption)
          .foregroundStyle(Palette.textQuaternary)
      }
      Spacer(minLength: Tokens.Space.s)
      if !day.hasBars {
        Image(systemName: "chart.bar.xaxis")
          .foregroundStyle(Palette.textQuaternary)
          .help(Text(L10n.Trades.noBarsHelp))
      }
      MoneyText(value: day.resultGrossUsd.value, usd: true, font: Tokens.Typography.calloutMono)
    }
    .padding(.horizontal, Tokens.Space.s)
    .padding(.vertical, Tokens.Space.xs)
    .background(isShown ? Palette.accent.opacity(Tokens.Opacity.wash) : .clear, in: .rect(cornerRadius: Tokens.Radius.small))
    .contentShape(.rect)
    .animation(Tokens.Motion.quick, value: isShown)
  }
}

// MARK: Shown day

/// The shown day's figures: result, trades, average R, best and worst trade.
private struct DayStatsRow: View {
  @Environment(AppModel.self) private var model

  /// Figures shrink to this share of their size before they truncate.
  static let figureMinimumScale = 0.6

  private var results: [Decimal] { model.shownTrades.map(\.resultGrossUsd.value) }

  private var averageR: Decimal? {
    let values = model.shownTrades.compactMap(\.resultR)
    guard !values.isEmpty else { return nil }
    return values.reduce(0, +) / Decimal(values.count)
  }

  var body: some View {
    HStack(spacing: Tokens.Space.l) {
      Stat(L10n.Trades.resultGross) {
        MoneyText(value: model.shownResult, usd: true, font: Tokens.Typography.metric)
      }
      Stat(L10n.Trades.trades) {
        Text(L10n.Trades.closedWinsLosses(model.shownTradeCount, model.shownWins, model.shownLosses))
          .font(Tokens.Typography.metric)
          .foregroundStyle(Palette.textPrimary)
      }
      Stat(L10n.Trades.averageR) {
        Text(verbatim: averageR.map(Risk.text) ?? Format.missing)
          .font(Tokens.Typography.metric)
          .foregroundStyle(averageR.map(Palette.result) ?? Palette.textQuaternary)
      }
      Stat(L10n.Trades.bestWorst) {
        HStack(spacing: Tokens.Space.s) {
          if let best = results.max(), let worst = results.min() {
            MoneyText(value: best, usd: true, font: Tokens.Typography.metric)
            MoneyText(value: worst, usd: true, font: Tokens.Typography.metric)
          } else {
            Text(verbatim: Format.missing)
              .font(Tokens.Typography.metric)
              .foregroundStyle(Palette.textQuaternary)
          }
        }
      }
    }
    .lineLimit(1)
    .minimumScaleFactor(Self.figureMinimumScale)
  }
}

/// A card holding one figure of the shown day.
private struct Stat<Value: View>: View {
  let title: LocalizedStringResource
  @ViewBuilder let value: Value

  init(_ title: LocalizedStringResource, @ViewBuilder value: () -> Value) {
    self.title = title
    self.value = value()
  }

  var body: some View {
    Card(title) { value }
  }
}

/// The shown day's closed trades. Double-click or the context menu opens a trade on the Chart.
private struct TradesTable: View {
  @Environment(AppModel.self) private var model
  @Binding var selection: DayTrade.ID?
  let showOnChart: (DayTrade) -> Void

  /// The table's height before it has rows, in points.
  static let minimumHeight: CGFloat = 240

  var body: some View {
    Card(L10n.Trades.tradesOfDay) {
      if model.shownTrades.isEmpty {
        Footnote(model.isLive ? L10n.Trades.noTradesToday : L10n.Trades.noTrades)
      } else {
        table
          .frame(minHeight: Self.minimumHeight, maxHeight: .infinity)
      }
    }
  }

  private var table: some View {
    Table(model.shownTrades, selection: $selection) {
      TableColumn(Text(L10n.Trades.closed)) { trade in
        Text(verbatim: Format.marketTime(trade.closedAt.date)).font(Tokens.Typography.calloutMono)
      }
      TableColumn(Text(L10n.Trades.symbol)) { trade in
        Text(verbatim: trade.symbol).font(Tokens.Typography.calloutMono.weight(.semibold))
      }
      TableColumn(Text(L10n.Trades.quantity)) { trade in
        Text(verbatim: Format.quantity(trade.quantity.value)).font(Tokens.Typography.calloutMono)
      }
      TableColumn(Text(L10n.Trades.entry)) { trade in
        Text(verbatim: Format.price(trade.entryPrice.value)).font(Tokens.Typography.calloutMono)
      }
      TableColumn(Text(L10n.Trades.exit)) { trade in
        Text(verbatim: Format.price(trade.exitPrice.value)).font(Tokens.Typography.calloutMono)
      }
      TableColumn(Text(L10n.Trades.stop)) { trade in
        Text(verbatim: Format.price(trade.stopPrice?.value)).font(Tokens.Typography.calloutMono)
      }
      TableColumn(Text(L10n.Trades.reason)) { trade in
        Badge(verbatim: Board.exitReasonTitle(trade.exitReason), color: Palette.textTertiary)
      }
      TableColumn(Text(L10n.Trades.resultR)) { trade in
        Text(verbatim: trade.resultR.map(Risk.text) ?? Format.missing)
          .font(Tokens.Typography.calloutMono)
          .foregroundStyle(trade.resultR.map(Palette.result) ?? Palette.textQuaternary)
      }
      TableColumn(Text(L10n.Trades.result)) { trade in
        MoneyText(value: trade.resultGrossUsd.value, usd: true, font: Tokens.Typography.calloutMono)
      }
    }
    .contextMenu(forSelectionType: DayTrade.ID.self) { ids in
      if let trade = trade(ids) {
        Button { showOnChart(trade) } label: {
          Label { Text(L10n.Trades.showOnChart) } icon: { Image(systemName: "chart.xyaxis.line") }
        }
      }
    } primaryAction: { ids in
      if let trade = trade(ids) { showOnChart(trade) }
    }
  }

  private func trade(_ ids: Set<DayTrade.ID>) -> DayTrade? {
    guard let id = ids.first else { return nil }
    return model.shownTrades.first { $0.id == id }
  }
}

/// What-if replays of skipped signals and other strategies: planned, not built yet.
private struct WhatIfCard: View {
  var body: some View {
    Card(L10n.Trades.whatIf, trailing: { PlannedTag(.backlog) }) {
      VStack(alignment: .leading, spacing: Tokens.Space.s) {
        Footnote(L10n.Trades.whatIfDetail)
        HStack(spacing: Tokens.Space.s) {
          Button {} label: { Text(L10n.Trades.whatIfEntered) }
          Button {} label: { Text(L10n.Trades.whatIfStrategy) }
        }
        .disabled(true)
      }
    }
  }
}
