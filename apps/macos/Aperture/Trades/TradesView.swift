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
    case days = 0, stats, performance, trades, detail, notTaken, whatIf
  }

  var body: some View {
    // The screen scrolls as one, as Risk and Lab do: taller than the window, an unscrolled stack
    // overflowed upward under the toolbar, and the calendar showed blurred behind the title.
    ScrollView {
      content
    }
    .onChange(of: model.shownDay) { selection = nil }
  }

  private var content: some View {
    HStack(alignment: .top, spacing: Tokens.Space.l) {
      DaysColumn()
        .frame(width: Tokens.Size.sideColumn)
        .rise(step: Order.days.rawValue)
      VStack(alignment: .leading, spacing: Tokens.Space.l) {
        DayStatsRow()
          .rise(step: Order.stats.rawValue)
        PerformanceCard()
          .rise(step: Order.performance.rawValue)
        TradesTable(selection: $selection, showOnChart: showOnChart)
          .rise(step: Order.trades.rawValue)
        TradeDetailCard(trade: model.shownTrades.first { $0.id == selection })
          .rise(step: Order.detail.rawValue)
        NotTakenCard(showOnChart: showOnChart)
          .rise(step: Order.notTaken.rawValue)
        WhatIfCard()
          .rise(step: Order.whatIf.rawValue)
      }
    }
    .padding(Tokens.Space.xl)
    .frame(maxWidth: Tokens.Size.contentMaxWidth)
    .frame(maxWidth: .infinity)
  }

  /// Opens the Chart on `symbol` (the shown day stays).
  private func showOnChart(_ symbol: String) {
    chartSymbol = symbol
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
        ContentUnavailableView {
          Label {
            Text(model.historyError == nil ? L10n.Trades.noDays : L10n.Trades.daysUnavailable)
          } icon: {
            BrandMark.empty(model.historyError == nil ? .brand : .muted)
          }
        }
      } else {
        MonthCalendar()
        DayBars(days: Array(model.days.prefix(Self.shownDays).reversed()), shown: model.shownDay)
          .frame(height: Self.barsHeight)
        // The screen's scroll view scrolls the list too; a nested one would collapse to nothing.
        LazyVStack(spacing: Tokens.Space.xxs) {
          ForEach(model.days) { day in
            Button { select(day.day) } label: {
              DayRow(day: day, isShown: day.day == model.shownDay, isToday: day.day == model.today)
            }
            .buttonStyle(.plain)
          }
        }
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
  let showOnChart: (String) -> Void

  /// The table's height, in points: about eight rows; a busier day scrolls inside the table.
  /// Fixed, because the screen scrolls and a table has no height of its own.
  static let height: CGFloat = 280

  var body: some View {
    Card(L10n.Trades.tradesOfDay) {
      if model.shownTrades.isEmpty {
        ContentUnavailableView {
          Label { Text(model.isLive ? L10n.Trades.noTradesToday : L10n.Trades.noTrades) } icon: { BrandMark.empty() }
        }
        .frame(height: Self.height)
      } else {
        table
          .frame(height: Self.height)
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
        Button { showOnChart(trade.symbol) } label: {
          Label { Text(L10n.Trades.showOnChart) } icon: { Image(systemName: "chart.xyaxis.line") }
        }
      }
    } primaryAction: { ids in
      if let trade = trade(ids) { showOnChart(trade.symbol) }
    }
  }

  private func trade(_ ids: Set<DayTrade.ID>) -> DayTrade? {
    guard let id = ids.first else { return nil }
    return model.shownTrades.first { $0.id == id }
  }
}

/// The selected trade's risk (1 R), price excursion and how fast the broker confirmed its stop.
private struct TradeDetailCard: View {
  let trade: DayTrade?

  /// Accessibility id of the card, for the UI tests.
  static let id = "trades-detail"

  var body: some View {
    Group {
      if let trade {
        Card(L10n.Trades.tradeDetail(trade.symbol)) {
          VStack(alignment: .leading, spacing: Tokens.Space.m) {
            Grid(alignment: .leading, horizontalSpacing: Tokens.Space.l, verticalSpacing: Tokens.Space.s) {
              GridRow {
                Text(L10n.Trades.oneR).foregroundStyle(Palette.textSecondary)
                MoneyText(value: trade.plannedLossUsd.value, usd: true, colored: false, signed: false)
              }
              GridRow {
                Text(L10n.Trades.stopConfirmedAfter).foregroundStyle(Palette.textSecondary)
                  .help(Text(L10n.Trades.stopConfirmedHelp))
                if let seconds = trade.stopConfirmedAfterSeconds {
                  Text(verbatim: Format.seconds(seconds.value)).font(Tokens.Typography.bodyMono)
                } else {
                  notRecorded
                }
              }
              GridRow {
                let sent = EntrySent.line(trade.entry, cause: trade.entryCause)
                Text(L10n.EntrySent.title).foregroundStyle(Palette.textSecondary)
                Text(verbatim: sent.text)
                  .font(Tokens.Typography.bodyMono)
                  .foregroundStyle(sent.color)
                  .help(sent.help.map { Text(verbatim: $0) } ?? Text(L10n.EntrySent.title))
              }
              excursion(L10n.Trades.maeAtLeast, trade.maeUsd)
              excursion(L10n.Trades.mfeAtLeast, trade.mfeUsd)
            }
            Footnote(L10n.Trades.excursionLowerBound)
          }
        }
      } else {
        Card(L10n.Trades.selectedTrade) { Footnote(L10n.Trades.selectTrade) }
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(Self.id)
  }

  private func excursion(_ title: LocalizedStringResource, _ value: DecimalString?) -> some View {
    GridRow {
      Text(title).foregroundStyle(Palette.textSecondary)
      if let value {
        MoneyText(value: value.value, usd: true)
      } else {
        Text(L10n.Trades.unknown).foregroundStyle(Palette.textQuaternary)
      }
    }
  }

  private var notRecorded: some View {
    Text(L10n.Trades.notRecorded).foregroundStyle(Palette.textQuaternary)
  }
}

/// The active strategy's entry signals of the shown day that did not become a position: refused
/// by the platform (the rule in words, with its detail) or never evaluated, with their what-if
/// levels. Repeats on one symbol for one reason are one row, as on iOS.
private struct NotTakenCard: View {
  @Environment(AppModel.self) private var model
  let showOnChart: (String) -> Void

  var body: some View {
    Card(L10n.Trades.notTaken) {
      if let signals = model.skipped?.signals, !signals.isEmpty {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
          ForEach(Array(SkippedGroup.make(signals).enumerated()), id: \.element.id) { index, group in
            if index > 0 { Divider() }
            SkippedRow(group: group, showOnChart: showOnChart)
          }
        }
      } else if let error = model.skippedError {
        Footnote(L10n.Trades.notTakenUnavailable(error))
      } else if model.skipped != nil {
        Footnote(L10n.Trades.notTakenEmpty)
      } else {
        ProgressView().controlSize(.small)
      }
    }
  }
}

/// One run of skipped signals; a click opens the Chart on its symbol.
private struct SkippedRow: View {
  let group: SkippedGroup
  let showOnChart: (String) -> Void

  /// "16:27" or, for repeats, "16:27–16:29 · ×3".
  private var when: String {
    let first = Format.marketMinute(group.first.at.date)
    guard group.count > 1 else { return first }
    return String(localized: L10n.Trades.repeatRange(first, Format.marketMinute(group.latest.at.date), group.count))
  }

  var body: some View {
    let signal = group.latest
    Button { showOnChart(signal.symbol) } label: {
      VStack(alignment: .leading, spacing: Tokens.Space.xs) {
        HStack(spacing: Tokens.Space.s) {
          Text(verbatim: signal.symbol).font(Tokens.Typography.calloutMono.weight(.semibold))
          admission
          Spacer(minLength: 0)
          Text(verbatim: when)
            .font(Tokens.Typography.captionMono)
            .foregroundStyle(Palette.textTertiary)
        }
        if let cause = group.cause {
          CauseText(cause: cause)
            .help(Text(verbatim: cause.code))
        }
        if let entry = signal.entryPrice, let stop = signal.stopPrice {
          Text(L10n.Trades.whatIfLevels(Format.price(entry.value), Format.price(stop.value)))
            .font(Tokens.Typography.captionMono)
            .foregroundStyle(Palette.textTertiary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .help(Text(L10n.Trades.showOnChart))
  }

  @ViewBuilder private var admission: some View {
    if group.latest.admission == .refused {
      Badge(L10n.Trades.refused, color: Palette.warningText)
    } else {
      Badge(L10n.Trades.notEvaluated, color: Palette.textTertiary)
    }
  }
}

/// A refusal in words: the rule, then the bot's detail with its times in New York.
private struct CauseText: View {
  let cause: RefusalCause

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
      if let code = cause.known {
        Text(L10n.Cause.title(code))
          .font(Tokens.Typography.callout)
          .foregroundStyle(Palette.textPrimary)
      }
      Group {
        if let cooldown = cause.cooldown {
          Text(L10n.Cause.cooldownDetail(Format.marketMinute(cooldown.loss), Format.marketMinute(cooldown.until)))
        } else if cause.known == nil {
          // A cause this app has no words for: the bot's own text, times made readable.
          Text(verbatim: cause.detail.isEmpty ? cause.code
            : cause.code + RefusalCause.separator + cause.readable(time: Format.marketMinute))
        } else if !cause.detail.isEmpty {
          Text(verbatim: cause.readable(time: Format.marketMinute))
        }
      }
      .font(Tokens.Typography.caption)
      .foregroundStyle(Palette.textSecondary)
      .fixedSize(horizontal: false, vertical: true)
    }
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

#if DEBUG
#Preview {
  TradesView()
    .environment(PreviewAPI.model())
    .frame(width: PreviewAPI.windowWidth, height: PreviewAPI.windowHeight)
}
#endif
