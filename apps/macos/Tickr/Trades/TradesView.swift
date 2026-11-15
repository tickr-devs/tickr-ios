import Charts
import SwiftUI
import TickrDesign
import TickrKit

/// Trades & days: recorded days and the 30-day performance on the left; the shown day's figures,
/// its trades, the selected trade beside the signals not taken, and what-if replays on the right.
/// Picking a day here is the same as picking it in the toolbar.
struct TradesView: View {
  @Environment(AppModel.self) private var model
  @AppStorage(ChartView.Keys.symbol) private var chartSymbol = ""
  @State private var selection: DayTrade.ID?
  /// Whether the screen is wide enough for the days column beside the trades.
  @State private var sideBySide = true

  /// Narrowest screen, in points, that shows the days column beside the trades: the column, the
  /// four figures of the day at full size and the trades table's columns at their least widths
  /// (the selected trade beside Not taken needs less). Narrower, the days follow the trades (the
  /// toolbar's day picker stays at the top). Measured on the screen's own width, which the window
  /// sets, so the choice never feeds back into it.
  static let sideBySideMinWidth: CGFloat = 1180

  /// Entrance order of the screen's parts.
  private enum Order: Int {
    case days = 0, performance, dayList, stats, trades, detail, notTaken, whatIf
  }

  var body: some View {
    // The screen scrolls as one, as Risk and Lab do: taller than the window, an unscrolled stack
    // overflowed upward under the toolbar, and the calendar showed blurred behind the title.
    ScrollView {
      content
    }
    .onGeometryChange(for: Bool.self) { [threshold = Self.sideBySideMinWidth] in $0.size.width >= threshold } action: {
      sideBySide = $0
    }
    .onChange(of: model.shownDay) { selection = nil }
  }

  private var content: some View {
    Group {
      if sideBySide {
        HStack(alignment: .top, spacing: Tokens.Space.l) {
          sideColumn.frame(width: Tokens.Size.sideColumn)
          dayDetail
        }
      } else {
        VStack(alignment: .leading, spacing: Tokens.Space.l) {
          dayDetail
          sideColumn
        }
      }
    }
    .padding(Tokens.Space.xl)
    .frame(maxWidth: Tokens.Size.contentMaxWidth)
    .frame(maxWidth: .infinity)
  }

  /// The calendar, the 30-day performance and the day list: beside the day as on the design, or
  /// after it in a narrow window, so the day's trades are on the first screen.
  private var sideColumn: some View {
    VStack(spacing: Tokens.Space.l) {
      DaysColumn()
        .rise(step: Order.days.rawValue)
      PerformanceCard()
        .rise(step: Order.performance.rawValue)
      DayListCard()
        .rise(step: Order.dayList.rawValue)
    }
  }

  /// The shown day's figures, trades, the selected trade with the signals not taken, and
  /// replays.
  private var dayDetail: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.l) {
      if let clean = model.days.first(where: { $0.day == model.shownDay })?.clean {
        CleanBadge(clean: clean)
          .rise(step: Order.stats.rawValue)
      }
      DayStatsRow()
        .rise(step: Order.stats.rawValue)
      TradesTable(selection: $selection, showOnChart: showOnChart)
        .rise(step: Order.trades.rawValue)
      selectedAndNotTaken
      WhatIfCard()
        .rise(step: Order.whatIf.rawValue)
    }
  }

  /// As on the board, the selected trade beside the signals that did not become one; one above
  /// the other in a narrow window.
  @ViewBuilder private var selectedAndNotTaken: some View {
    let detail = TradeDetailCard(trade: model.shownTrades.first { $0.id == selection })
      .rise(step: Order.detail.rawValue)
    let notTaken = NotTakenCard(showOnChart: showOnChart)
      .rise(step: Order.notTaken.rawValue)
    if sideBySide {
      HStack(alignment: .top, spacing: Tokens.Space.l) {
        detail.frame(width: Tokens.Size.sideColumn)
        notTaken
      }
    } else {
      VStack(alignment: .leading, spacing: Tokens.Space.l) {
        detail
        notTaken
      }
    }
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
      }
    }
  }
}

/// Every recorded day as a list, newest first, under the performance card: the calendar above
/// already picks days, so the long list no longer pushes the performance out of sight.
private struct DayListCard: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    if !model.days.isEmpty {
      Card(L10n.Trades.allDays) {
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

  /// One slot per day the bars cover, oldest first: empty slots before the recorded days, so a
  /// few days draw as thin bars on the right, not as one bar across the whole card.
  private var slots: [String] {
    let empty = (0..<max(0, DaysColumn.shownDays - days.count)).map { "\($0)" }
    return empty + days.map(\.day.text)
  }

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
    .chartXScale(domain: slots)
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
      CleanMark(clean: day.clean)
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

  private var results: [Decimal] { model.shownTrades.map(\.resultGrossUsd.value) }

  private var averageR: Decimal? {
    let values = model.shownTrades.compactMap(\.resultR)
    guard !values.isEmpty else { return nil }
    return values.reduce(0, +) / Decimal(values.count)
  }

  /// Four figures in a row; two rows of two when the row would have to shrink them.
  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: Tokens.Space.l) { result; trades; average; bestWorst }
      Grid(horizontalSpacing: Tokens.Space.l, verticalSpacing: Tokens.Space.l) {
        GridRow { result; trades }
        GridRow { average; bestWorst }
      }
    }
    .lineLimit(1)
    .minimumScaleFactor(Tokens.Shrink.tight)
  }

  private var result: some View {
    Stat(L10n.Trades.resultGross) {
      MoneyText(value: model.shownResult, usd: true, font: Tokens.Typography.metric)
    }
  }

  private var trades: some View {
    Stat(L10n.Trades.trades) {
      Text(L10n.Trades.closedWinsLosses(model.shownTradeCount, model.shownWins, model.shownLosses))
        .font(Tokens.Typography.metric)
        .foregroundStyle(Palette.textPrimary)
    }
  }

  private var average: some View {
    Stat(L10n.Trades.averageR) {
      Text(verbatim: averageR.map(Risk.text) ?? Format.missing)
        .font(Tokens.Typography.metric)
        .foregroundStyle(averageR.map(Palette.result) ?? Palette.textQuaternary)
    }
  }

  private var bestWorst: some View {
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

  /// Least and preferred widths of the table's columns, in points: the least keeps a time, a
  /// symbol, a price or a figure whole in a narrow window; the preferred share out a wide one.
  private enum Column {
    /// Least and preferred width of each column, in points: the preferred widths add up to
    /// what a 1000-point window leaves the table, so every column shows without scrolling.
    static let timeMin: CGFloat = 56
    static let time: CGFloat = 64
    static let symbolMin: CGFloat = 52
    static let symbol: CGFloat = 60
    static let quantityMin: CGFloat = 36
    static let quantity: CGFloat = 44
    static let priceMin: CGFloat = 56
    static let price: CGFloat = 64
    static let reasonMin: CGFloat = 96
    static let reason: CGFloat = 130
    static let figureMin: CGFloat = 48
    static let figure: CGFloat = 56
    static let moneyMin: CGFloat = 76
    static let money: CGFloat = 88
  }

  /// The table's height, in points: at most about eight rows; a busier day scrolls inside the
  /// table. Set from the trade count, because the screen scrolls and a table has no height of its
  /// own; a fixed height left empty striped rows under a day of two trades.
  static let height: CGFloat = 280
  /// Height of the header and of one row, and the fewest rows the table is tall for, in points.
  static let headerHeight: CGFloat = 32
  static let rowHeight: CGFloat = 28
  static let fewestRows = 2

  private var tableHeight: CGFloat {
    let rows = CGFloat(max(model.shownTrades.count, Self.fewestRows))
    return min(Self.height, Self.headerHeight + rows * Self.rowHeight)
  }

  var body: some View {
    Card(L10n.Trades.tradesOfDay) {
      // On the live day, positions still open come first: the table holds closed trades only.
      let open = model.isLive ? model.positions : []
      ForEach(open) { row in
        OpenPositionRow(row: row, showOnChart: showOnChart)
        Divider()
      }
      if model.shownTrades.isEmpty && !open.isEmpty {
        Footnote(L10n.Trades.noClosedTrades)
      } else if model.shownTrades.isEmpty {
        ContentUnavailableView {
          Label { Text(model.isLive ? L10n.Trades.noTradesToday : L10n.Trades.noTrades) } icon: { BrandMark.empty() }
        }
        .frame(height: Self.height)
      } else {
        table
          .frame(height: tableHeight)
      }
    }
  }

  private var table: some View {
    Table(model.shownTrades, selection: $selection) {
      TableColumn(Text(L10n.Trades.closed)) { trade in
        Text(verbatim: Format.marketTime(trade.closedAt.date)).font(Tokens.Typography.calloutMono)
      }
      .width(min: Column.timeMin, ideal: Column.time)
      TableColumn(Text(L10n.Trades.symbol)) { trade in
        Text(verbatim: trade.symbol).font(Tokens.Typography.calloutMono.weight(.semibold))
      }
      .width(min: Column.symbolMin, ideal: Column.symbol)
      TableColumn(Text(L10n.Trades.quantity)) { trade in
        Text(verbatim: Format.quantity(trade.quantity.value)).font(Tokens.Typography.calloutMono)
      }
      .width(min: Column.quantityMin, ideal: Column.quantity)
      TableColumn(Text(L10n.Trades.entry)) { trade in
        Text(verbatim: Format.price(trade.entryPrice.value)).font(Tokens.Typography.calloutMono)
      }
      .width(min: Column.priceMin, ideal: Column.price)
      TableColumn(Text(L10n.Trades.exit)) { trade in
        Text(verbatim: Format.price(trade.exitPrice.value)).font(Tokens.Typography.calloutMono)
      }
      .width(min: Column.priceMin, ideal: Column.price)
      TableColumn(Text(L10n.Trades.stop)) { trade in
        Text(verbatim: Format.price(trade.stopPrice?.value)).font(Tokens.Typography.calloutMono)
      }
      .width(min: Column.priceMin, ideal: Column.price)
      TableColumn(Text(L10n.Trades.reason)) { trade in
        Badge(verbatim: Board.exitReasonTitle(trade.exitReason), color: Palette.textTertiary)
      }
      .width(min: Column.reasonMin, ideal: Column.reason)
      TableColumn(Text(L10n.Trades.resultR)) { trade in
        Text(verbatim: trade.resultR.map(Risk.text) ?? Format.missing)
          .font(Tokens.Typography.calloutMono)
          .foregroundStyle(trade.resultR.map(Palette.result) ?? Palette.textQuaternary)
      }
      .width(min: Column.figureMin, ideal: Column.figure)
      TableColumn(Text(L10n.Trades.result)) { trade in
        MoneyText(value: trade.resultGrossUsd.value, usd: true, font: Tokens.Typography.calloutMono)
      }
      .width(min: Column.moneyMin, ideal: Column.money)
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

/// A position still open on the live day, in the columns of the closed trades; a click opens the
/// Chart on its symbol.
struct OpenPositionRow: View {
  let row: PositionRow
  let showOnChart: (String) -> Void

  /// Accessibility id of an open position's row, for the UI tests.
  static let id = "trades-open-position"

  var body: some View {
    Button { showOnChart(row.position.symbol) } label: {
      HStack(spacing: Tokens.Space.m) {
        Badge(L10n.Trades.open, color: Palette.accentText)
        Text(verbatim: Format.marketTime(row.position.openedAt.date))
        Text(verbatim: row.position.symbol).fontWeight(.semibold)
        Text(verbatim: Format.quantity(row.quantity))
        Text(verbatim: Format.price(row.entry))
        Text(verbatim: Format.price(row.stop))
          .foregroundStyle(row.position.stop.state == .verified ? Palette.textPrimary : Palette.lossText)
        Spacer(minLength: 0)
        Text(verbatim: row.resultR.map(Risk.text) ?? Format.missing)
          .foregroundStyle(row.resultR.map(Palette.result) ?? Palette.textQuaternary)
      }
      .font(Tokens.Typography.calloutMono)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .help(Text(L10n.Trades.showOnChart))
    .accessibilityIdentifier(Self.id)
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
                let sent = EntrySent.line(trade.entry, cause: ApiText.prose(trade.entryCauseCodes, text: trade.entryCause))
                Text(L10n.EntrySent.title).foregroundStyle(Palette.textSecondary)
                let value = Text(verbatim: sent.text)
                  .font(Tokens.Typography.bodyMono)
                  .foregroundStyle(sent.color)
                // A tooltip only when there is something to add (the bot's cause of a missing record).
                if let help = sent.help {
                  value.help(Text(verbatim: help))
                } else {
                  value
                }
              }
              excursion(L10n.Trades.maeAtLeast, trade.maeUsd)
              excursion(L10n.Trades.mfeAtLeast, trade.mfeUsd)
              GridRow {
                Text(L10n.Trades.overshoot).foregroundStyle(Palette.textSecondary)
                  .help(Text(L10n.Trades.overshootHelp))
                if let usd = trade.overshootUsd?.value {
                  Text(L10n.Trades.overshootValue(Money.signedUSD(usd), trade.overshootR.map { Risk.text($0.value) }
                    ?? Format.missing))
                    .font(Tokens.Typography.bodyMono)
                    // Neutral, not green: this is profit the trade left behind, not a gain.
                    .foregroundStyle(Palette.textPrimary)
                } else {
                  Text(L10n.Trades.unknown).foregroundStyle(Palette.textQuaternary)
                    .help(Text(verbatim: ApiText.prose(trade.overshootCauseCodes, text: trade.overshootCause) ?? Format.missing))
                }
              }
            }
            if let after = WhatIfText.after(trade.pricesAfter) {
              Divider()
              Text(verbatim: after)
                .font(Tokens.Typography.captionMono)
                .foregroundStyle(Palette.textTertiary)
                .help(Text(L10n.Trades.priceAfterExit))
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
        }
        // The what-if is the setup's first signal: a repeat would not have been a second trade.
        let setup = group.first
        if let entry = setup.entryPrice, let stop = setup.stopPrice {
          Text(L10n.Trades.whatIfLevels(Format.price(entry.value), Format.price(stop.value)))
            .font(Tokens.Typography.captionMono)
            .foregroundStyle(Palette.textTertiary)
        }
        let result = WhatIfText.result(setup.whatIf)
        HStack(spacing: Tokens.Space.xs) {
          Circle()
            .fill(result.color)
            .frame(width: Tokens.Size.dotSmall, height: Tokens.Size.dotSmall)
          Text(verbatim: result.text)
            .font(Tokens.Typography.captionMono)
            .foregroundStyle(result.color)
        }
        .help(Text(verbatim: WhatIfText.after(setup.pricesAfter)
          ?? ApiText.prose(setup.pricesAfterCauseCodes, text: setup.pricesAfterCause) ?? Format.missing))
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
      Group {
        if let code = cause.known {
          Text(L10n.Cause.title(code))
        } else if cause.hasCode {
          // A code this app has no words for is never shown; its detail follows.
          Text(L10n.Cause.other)
        }
      }
      .font(Tokens.Typography.callout)
      .foregroundStyle(Palette.textPrimary)
      Group {
        if let cooldown = cause.cooldown {
          Text(L10n.Cause.cooldownDetail(Format.marketMinute(cooldown.loss), Format.marketMinute(cooldown.until)))
        } else if cause.known == nil, !cause.hasCode {
          // Prose the bot wrote without a code: as written, times made readable.
          Text(verbatim: cause.detail.isEmpty ? cause.code
            : cause.code + RefusalCause.separator + cause.readable(time: Format.marketMinute))
        } else if cause.known == nil {
          if !cause.detail.isEmpty {
            Text(verbatim: cause.readable(time: Format.marketMinute))
          }
        } else if let phrase = cause.phrase {
          Text(verbatim: phrase)
            .help(Text(verbatim: cause.readable(time: Format.marketMinute)))
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

/// What the day's skipped setups would have made had each been entered once, from the bot's
/// replays; replaying the day under another strategy is still planned.
private struct WhatIfCard: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    Card(L10n.Trades.whatIf) {
      VStack(alignment: .leading, spacing: Tokens.Space.s) {
        if let signals = model.skipped?.signals {
          if let summary = WhatIfSummary.make(SkippedGroup.make(signals)) {
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
              Text(L10n.Trades.whatIfSummary)
                .font(Tokens.Typography.callout)
                .foregroundStyle(Palette.textSecondary)
              Text(verbatim: Risk.text(summary.resultR))
                .font(Tokens.Typography.chipValue)
                .foregroundStyle(Palette.result(summary.resultR))
              Text(verbatim: Money.signedUSD(summary.resultUsd))
                .font(Tokens.Typography.calloutMono)
                .foregroundStyle(Palette.result(summary.resultUsd))
            }
            Text(L10n.Trades.whatIfCounts(summary.wins, summary.losses, summary.notReplayed))
              .font(Tokens.Typography.captionMono)
              .foregroundStyle(Palette.textTertiary)
          } else {
            Footnote(L10n.Trades.whatIfNone)
          }
        }
        Footnote(L10n.Trades.whatIfHelp)
        HStack(spacing: Tokens.Space.s) {
          Button {} label: { Text(L10n.Trades.whatIfStrategy) }
            .disabled(true)
          PlannedTag(.backlog)
        }
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
