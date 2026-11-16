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

  /// Least width of this screen, in points: the screen's padding (`Space.xl`) and the trades
  /// card's own padding (`Space.l`) around the trades table at its least width. It is the widest
  /// least width of all screens, so it sets the window's (`RootView.screenMinWidth`).
  static let leastScreenWidth: CGFloat = Tokens.Space.xl * CardArrangement.paddedEdges
    + Tokens.Space.l * CardArrangement.paddedEdges + TradesTable.leastWidth
  /// Narrowest screen, in points, that shows the days column beside the trades: the least screen
  /// with the days column and its gap beside the table (the four figures of the day and the
  /// selected trade beside Not taken need less). Narrower, the days follow the trades (the
  /// toolbar's day picker stays at the top). Derived, not set: a set 1180 left the table 6 points
  /// short of its columns, so the columns were cut to "10:07:…".
  static let sideBySideMinWidth: CGFloat = leastScreenWidth + Tokens.Size.sideColumn + Tokens.Space.l
  /// Width of the selected trade's card beside Not taken, in points.
  static let detailWidth: CGFloat = 330

  /// Entrance order of the screen's parts.
  fileprivate enum Order: Int {
    case days = 0, performance, dayList, stats, trades, detail, notTaken, whatIf
  }

  var body: some View {
    // The screen scrolls as one, as Risk and Lab do: taller than the window, an unscrolled stack
    // overflowed upward under the toolbar, and the calendar showed blurred behind the title.
    ScrollView {
      content
    }
    .plainCardLabels()
    // The first trade of the day is selected until another is picked, so its details show at once.
    .onChange(of: model.shownTrades.map(\.id), initial: true) { _, ids in
      if selection.map({ !ids.contains($0) }) ?? true { selection = ids.first }
    }
  }

  /// The days column beside the day's detail, or after it in a narrow window so the day's trades
  /// are on the first screen. The same two views in both: a resize moves them and never makes
  /// them anew (new ones played their entrance again mid-drag).
  static let arrangements: [CardArrangement] = [
    CardArrangement(minWidth: sideBySideMinWidth - Tokens.Space.xl * CardArrangement.paddedEdges, rows: [
      CardRow(columns: [
        CardColumn(width: .fixed(Tokens.Size.sideColumn), cards: [Part.side.rawValue]),
        CardColumn(width: .share(1), cards: [Part.day.rawValue]),
      ], linesUp: false)
    ]),
    CardArrangement(minWidth: 0, rows: [
      CardRow(columns: [CardColumn(width: .share(1), cards: [Part.day.rawValue])], linesUp: false),
      CardRow(columns: [CardColumn(width: .share(1), cards: [Part.side.rawValue])], linesUp: false),
    ]),
  ]

  /// The selected trade beside the signals not taken, one height, while the day's column holds
  /// the trade's card and a Not taken card of the least width; one above the other otherwise.
  static let detailArrangements: [CardArrangement] = [
    CardArrangement(minWidth: detailWidth + Tokens.Space.l + Tokens.Size.gridColumnMin, rows: [
      CardRow(columns: [
        CardColumn(width: .fixed(detailWidth), cards: [Part.side.rawValue]),
        CardColumn(width: .share(1), cards: [Part.day.rawValue]),
      ])
    ]),
    CardArrangement(minWidth: 0, rows: [
      CardRow(columns: [CardColumn(width: .share(1), cards: [Part.side.rawValue, Part.day.rawValue])], linesUp: false)
    ]),
  ]

  /// Positions of the two parts in a `CardGrid` of this screen: the first (the days column, the
  /// selected trade) and the second (the day's detail, Not taken).
  private enum Part: Int { case side = 0, day }

  private var content: some View {
    CardGrid(arrangements: Self.arrangements, spacing: Tokens.Space.l) {
      sideColumn
      dayDetail
    }
    .padding(Tokens.Space.xl)
    .frame(maxWidth: Tokens.Size.contentMaxWidth)
    .frame(maxWidth: .infinity)
  }

  /// The calendar, the 30-day performance and the day list: beside the day as in the design, or
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
      dayTitle
        .rise(step: Order.stats.rawValue)
      DayStatsRow()
        .rise(step: Order.stats.rawValue)
      TradesTable(selection: $selection, showOnChart: showOnChart)
        .rise(step: Order.trades.rawValue)
      selectedAndNotTaken
      WhatIfCard()
        .rise(step: Order.whatIf.rawValue)
    }
  }

  /// "Today · Mon, Nov 16" (or the recorded day) with its clean-day verdict.
  private var dayTitle: some View {
    HStack(alignment: .center, spacing: Tokens.Space.m) {
      Group {
        if model.isLive {
          Text(L10n.Trades.dayTitleToday(DayText.day(model.shownDay)))
        } else {
          Text(verbatim: DayText.day(model.shownDay))
        }
      }
      .font(Tokens.Typography.heading)
      .foregroundStyle(Palette.textPrimary)
      .accessibilityAddTraits(.isHeader)
      if let clean = model.days.first(where: { $0.day == model.shownDay })?.clean {
        CleanBadge(clean: clean)
      }
    }
  }

  /// As on the board, the selected trade beside the signals that did not become one, one height;
  /// one above the other in a narrow window.
  private var selectedAndNotTaken: some View {
    CardGrid(arrangements: Self.detailArrangements, spacing: Tokens.Space.l) {
      TradeDetailCard(trade: model.shownTrades.first { $0.id == selection })
        .rise(step: Order.detail.rawValue)
      NotTakenCard(showOnChart: showOnChart)
        .rise(step: Order.notTaken.rawValue)
    }
    .filling()
  }

  /// Opens the Chart on `symbol` (the shown day stays).
  private func showOnChart(_ symbol: String) {
    chartSymbol = symbol
    model.section = .chart
  }
}

// MARK: Days

/// The month of recorded days; the calendar labels the card with its month.
private struct DaysColumn: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    if model.days.isEmpty {
      Card(L10n.Trades.days) {
        ContentUnavailableView {
          Label {
            Text(model.historyError == nil ? L10n.Trades.noDays : L10n.Trades.daysUnavailable)
          } icon: {
            BrandMark.empty(model.historyError == nil ? .brand : .muted)
          }
        }
      }
    } else {
      MonthCalendar()
        .padding(Tokens.Space.l)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .tickrCard(radius: Tokens.Radius.large)
    }
  }
}

/// Every recorded day as a list, newest first, under the performance card: the calendar above
/// already picks days, so the long list no longer pushes the performance out of sight.
private struct DayListCard: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    if !model.days.isEmpty {
      Card(L10n.Trades.allDays, trailing: {
        Text(L10n.Trades.allDaysHint)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      }, content: {
        // The screen's scroll view scrolls the list too; a nested one would collapse to nothing.
        LazyVStack(spacing: Tokens.Space.xxs) {
          ForEach(model.days) { day in
            Button { select(day.day) } label: {
              DayRow(day: day, isShown: day.day == model.shownDay, isToday: day.day == model.today)
            }
            .buttonStyle(.plain)
          }
        }
      })
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

/// A day in the list: date, trades with wins and losses, and its result.
private struct DayRow: View {
  let day: DaySummary
  let isShown: Bool
  let isToday: Bool
  /// Under the pointer: the sunken tint of the design's day rows.
  @State private var hovered = false

  var body: some View {
    HStack(spacing: Tokens.Space.s) {
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        HStack(spacing: Tokens.Space.xs) {
          Text(verbatim: DayText.day(day.day))
            .font(Tokens.Typography.calloutMono)
            .foregroundStyle(Palette.textPrimary)
          if isToday { Badge(L10n.Common.today, color: Palette.accentText) }
        }
        Text(L10n.Trades.closedWinsLosses(day.trades, day.wins, day.losses))
          .font(Tokens.Typography.caption)
          .foregroundStyle(Palette.textQuaternary)
      }
      Spacer(minLength: Tokens.Space.s)
      if day.clean.verdict != .unknown {
        CleanDot(verdict: day.clean.verdict)
          .help(Text(verbatim: CleanMark.text(day.clean)))
      }
      if !day.hasBars {
        Image(systemName: "chart.bar.xaxis")
          .foregroundStyle(Palette.textQuaternary)
          .help(Text(L10n.Trades.noBarsHelp))
      }
      MoneyText(value: day.resultGrossUsd.value, usd: true, font: Tokens.Typography.calloutMono)
    }
    .padding(.horizontal, Tokens.Space.s)
    .padding(.vertical, Tokens.Space.s)
    .background(isShown ? Palette.selection : hovered ? Palette.surfaceSunken : .clear,
      in: .rect(cornerRadius: Tokens.Radius.medium))
    .overlay(
      RoundedRectangle(cornerRadius: Tokens.Radius.medium)
        .strokeBorder(isShown ? Palette.separatorStrong : .clear, lineWidth: Tokens.Stroke.thin))
    .contentShape(.rect)
    .onHover { hovered = $0 }
    .animation(Tokens.Motion.quick, value: isShown)
    .animation(Tokens.Motion.quick, value: hovered)
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
  }

  private var result: some View {
    Stat(L10n.Trades.resultGross) {
      MoneyText(value: model.shownResult, usd: true, font: Tokens.Typography.figure)
    }
  }

  private var trades: some View {
    Stat(L10n.Trades.trades) {
      Text(L10n.Trades.closedWinsLosses(model.shownTradeCount, model.shownWins, model.shownLosses))
        .font(Tokens.Typography.figure)
        .foregroundStyle(Palette.textPrimary)
    }
  }

  private var average: some View {
    Stat(L10n.Trades.averageR) {
      Text(verbatim: averageR.map(Risk.text) ?? Format.missing)
        .font(Tokens.Typography.figure)
        .foregroundStyle(averageR.map(Palette.result) ?? Palette.textQuaternary)
    }
  }

  private var bestWorst: some View {
    Stat(L10n.Trades.bestWorst) {
      HStack(spacing: Tokens.Space.s) {
        if let best = results.max(), let worst = results.min() {
          MoneyText(value: best, usd: true, font: Tokens.Typography.figure)
          MoneyText(value: worst, usd: true, font: Tokens.Typography.figure)
        } else {
          Text(verbatim: Format.missing)
            .font(Tokens.Typography.figure)
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
  /// The row under the pointer, tinted as one.
  @State private var hovered: TradeRow.ID?
  /// Rows that have risen once: the table recycles a row's cells as the screen scrolls, and a row
  /// shown again never rises again.
  @State private var risen: Set<TradeRow.ID> = []
  let showOnChart: (String) -> Void

  /// Least and preferred widths of the table's columns, in points. Each least width holds the
  /// column's widest content and its heading whole, in English and Russian (measured in the
  /// table's fonts: values in 12-point mono, headings and badges in 10-point mono; a heading cell
  /// keeps a few points of inset, a value cell none); the preferred widths are the board's
  /// (MacTrades: 76 · 56 · 34 · 56 · 72 · 68 · reason · 66 · 72), never under the least.
  private enum Column {
    /// "10:07:00" (59.3).
    static let timeMin: CGFloat = 60
    static let time: CGFloat = 76
    /// A five-letter symbol such as "BRK.B" and the heading "SYMBOL" (37.1 each).
    static let symbolMin: CGFloat = 40
    static let symbol: CGFloat = 56
    /// The Russian heading "КОЛ-ВО" (37.1, and the header cell's own inset: at 38 it read
    /// "КОЛ-…"); a four-digit quantity takes 29.7.
    static let quantityMin: CGFloat = 46
    static let quantity: CGFloat = 48
    /// A four-digit price "1234.56" (51.9); the board gives entry, exit and stop their own widths.
    static let priceMin: CGFloat = 52
    static let entry: CGFloat = 56
    static let exit: CGFloat = 72
    static let stop: CGFloat = 68
    /// The reason badge with the widest exit reason, the Russian "ВРЕМЯ УДЕРЖАНИЯ ВЫШЛО" (129.8
    /// and the badge's padding, 146).
    static let reasonMin: CGFloat = 148
    static let reason: CGFloat = 152
    /// "−10.0 R" (51.9).
    static let figureMin: CGFloat = 52
    static let figure: CGFloat = 66
    /// "−$1,234.56" (74.2).
    static let moneyMin: CGFloat = 76
    static let money: CGFloat = 80
    /// The least widths of the nine columns in the table's order.
    static let leastWidths = [timeMin, symbolMin, quantityMin, priceMin, priceMin, priceMin, reasonMin, figureMin, moneyMin]
  }

  /// AppKit's table layout around the columns, in points (measured with Accessibility on macOS
  /// 27): the inset at each edge of the table and the gap between two cells.
  static let edgeInset: CGFloat = 16
  static let cellSpacing: CGFloat = 17

  /// Width the table needs for every column at its least width, in points: below it the columns
  /// are cut.
  static let leastWidth: CGFloat = Column.leastWidths.reduce(0, +)
    + cellSpacing * CGFloat(Column.leastWidths.count - 1) + edgeInset * CardArrangement.paddedEdges

  /// Height of the "no trades" message in place of the table, in points.
  static let emptyHeight: CGFloat = 280
  /// Height of the header and of one row, and the fewest rows the table is tall for, in points.
  static let headerHeight: CGFloat = 32
  static let rowHeight: CGFloat = 28
  static let fewestRows = 2

  /// The table's height: every row of the day, so the screen scrolls as one and no row is cut
  /// inside a box. Set from the trade count, because the screen scrolls and a table has no height
  /// of its own; a fixed height left empty striped rows under a day of two trades.
  private var tableHeight: CGFloat {
    let count = CGFloat(max(rows.count, Self.fewestRows))
    return Self.headerHeight + count * Self.rowHeight
  }

  /// The day's closed trades in the order they closed, then on the live day the positions still
  /// open: a new trade is added under the others and a closing one stays in its place, so no row
  /// moves under the pointer.
  private var rows: [TradeRow] {
    model.shownTrades.map { TradeRow.closed($0) } + (model.isLive ? model.positions.map { TradeRow.open($0) } : [])
  }

  var body: some View {
    Card(L10n.Trades.tradesOfDay, trailing: {
      Text(L10n.Trades.tradesHint)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
    }, content: {
      if rows.isEmpty {
        ContentUnavailableView {
          Label { Text(model.isLive ? L10n.Trades.noTradesToday : L10n.Trades.noTrades) } icon: { BrandMark.empty() }
        }
        .frame(height: Self.emptyHeight)
      } else {
        table
          .frame(height: tableHeight)
      }
    })
  }

  private var table: some View {
    let rows = rows
    // Worked out once per render, in one pass over the rows (not a search per cell).
    let steps = RowEntrance.steps(rows.map(\.id), first: RowEntrance.tradesRows, risen: risen)
    return Table(rows, selection: $selection) {
      TableColumn(Self.header(L10n.Trades.closed)) { row in
        cell(row, step: steps[row.id]) {
          switch row {
          case .open(let position):
            // Not closed yet: when it opened, quieter.
            Text(verbatim: Format.marketTime(position.position.openedAt.date))
              .font(Tokens.Typography.calloutMono)
              .foregroundStyle(Palette.textTertiary)
          case .closed(let trade):
            Text(verbatim: Format.marketTime(trade.closedAt.date)).font(Tokens.Typography.calloutMono)
          }
        }
      }
      .width(min: Column.timeMin, ideal: Column.time)
      TableColumn(Self.header(L10n.Trades.symbol)) { row in
        cell(row, step: steps[row.id]) {
          Text(verbatim: row.symbol).font(Tokens.Typography.calloutMono.weight(.semibold))
        }
      }
      .width(min: Column.symbolMin, ideal: Column.symbol)
      TableColumn(Self.header(L10n.Trades.quantity)) { row in
        cell(row, step: steps[row.id]) {
          Text(verbatim: Format.quantity(row.quantity)).font(Tokens.Typography.calloutMono)
        }
      }
      .width(min: Column.quantityMin, ideal: Column.quantity)
      TableColumn(Self.header(L10n.Trades.entry)) { row in
        cell(row, step: steps[row.id]) {
          Text(verbatim: Format.price(row.entry)).font(Tokens.Typography.calloutMono)
        }
      }
      .width(min: Column.priceMin, ideal: Column.entry)
      TableColumn(Self.header(L10n.Trades.exit)) { row in
        cell(row, step: steps[row.id]) {
          Text(verbatim: Format.price(row.exit)).font(Tokens.Typography.calloutMono)
            .foregroundStyle(row.exit == nil ? Palette.textQuaternary : Palette.textPrimary)
        }
      }
      .width(min: Column.priceMin, ideal: Column.exit)
      TableColumn(Self.header(L10n.Trades.stop)) { row in
        cell(row, step: steps[row.id]) {
          Text(verbatim: Format.price(row.stop)).font(Tokens.Typography.calloutMono)
            .foregroundStyle(row.stopUnverified ? Palette.lossText : Palette.textPrimary)
        }
      }
      .width(min: Column.priceMin, ideal: Column.stop)
      TableColumn(Self.header(L10n.Trades.reason)) { row in
        cell(row, step: steps[row.id]) {
          switch row {
          case .open(let position):
            // A position still open: the OPEN tag, which opens the Chart on it.
            Button { showOnChart(position.id) } label: {
              HStack(spacing: Tokens.Space.xs) {
                // One pulse per thing the bot did to the position (a fill, a stop placed or
                // verified), never a loop.
                PulseDot(Palette.accent, size: Tokens.Size.dotSmall, event: position.event)
                Badge(L10n.Trades.open, color: Palette.accentText)
              }
            }
            .buttonStyle(.plain)
            .help(Text(L10n.Trades.showOnChart))
            .accessibilityLabel(Text(L10n.Trades.openPosition(position.id)))
            .accessibilityIdentifier(TradeRow.openID)
          case .closed(let trade):
            // The reason's own tone, as on the iPhone (v99: strategy exit teal, stopped out pink, other
            // closes grey, a protection failure red).
            Badge(verbatim: Board.exitReasonTitle(trade.exitReason), tone: Tone.exit(trade.exitReason))
          }
        }
      }
      .width(min: Column.reasonMin, ideal: Column.reason)
      TableColumn(Self.header(L10n.Trades.resultR)) { row in
        cell(row, step: steps[row.id]) {
          Text(verbatim: row.resultR.map(Risk.text) ?? Format.missing)
            .font(Tokens.Typography.calloutMono)
            .foregroundStyle(row.resultRColor)
        }
      }
      .width(min: Column.figureMin, ideal: Column.figure)
      TableColumn(Self.header(L10n.Trades.result)) { row in
        cell(row, step: steps[row.id]) {
          if let result = row.result {
            // Greyed while it is as of an older bar, as in the menu-bar panel.
            MoneyText(value: result, usd: true, font: Tokens.Typography.calloutMono, muted: row.isStale)
          } else {
            Text(L10n.Trades.open)
              .textCase(.lowercase)
              .font(Tokens.Typography.calloutMono)
              .foregroundStyle(Palette.textQuaternary)
          }
        }
      }
      .width(min: Column.moneyMin, ideal: Column.money)
    }
    .contextMenu(forSelectionType: TradeRow.ID.self) { ids in
      if let row = row(ids) {
        Button { showOnChart(row.symbol) } label: {
          Label { Text(L10n.Trades.showOnChart) } icon: { Image(systemName: "chart.xyaxis.line") }
        }
      }
    } primaryAction: { ids in
      if let row = row(ids) { showOnChart(row.symbol) }
    }
  }

  /// One cell of `row`: one of the first rows rises in its turn (`step`, see `RowEntrance`) after
  /// the card as the table appears, any other shows at once; and the whole row takes a light tint
  /// under the pointer, as the design's rows. Each cell's tint reaches half the gap to the next, so
  /// the row tints as one.
  private func cell(_ row: TradeRow, step: Int?, @ViewBuilder _ content: () -> some View) -> some View {
    let lit = hovered == row.id
    return content()
      .frame(maxWidth: .infinity, alignment: .leading)
      .background {
        Rectangle().fill(Palette.info.opacity(lit ? Tokens.Opacity.wash : 0))
          .padding(-Self.cellOutset)
          .allowsHitTesting(false)
      }
      .animation(Tokens.Motion.quick, value: lit)
      .onHover { inside in
        if inside { hovered = row.id } else if hovered == row.id { hovered = nil }
      }
      .modifier(EntranceRise(step: step.map { TradesView.Order.trades.rawValue + 1 + $0 }) {
        risen.insert(row.id)
      })
  }

  /// How far a hovered row's tint reaches past each cell, in points: half the table's cell gaps.
  static let cellOutset = EdgeInsets(
    top: Tokens.Space.xs, leading: Tokens.Space.xs / 2, bottom: Tokens.Space.xs, trailing: Tokens.Space.xs / 2)

  /// A column's title as the design's table heads read: mono label type, uppercase.
  private static func header(_ title: LocalizedStringResource) -> Text {
    Text(verbatim: String(localized: title).uppercased())
      .font(Tokens.Typography.label)
      .foregroundStyle(Palette.textQuaternary)
  }

  private func row(_ ids: Set<TradeRow.ID>) -> TradeRow? {
    guard let id = ids.first else { return nil }
    return rows.first { $0.id == id }
  }
}

/// A row of the day's trades table: a position still open on the live day (its live R and
/// result), or a closed trade.
enum TradeRow: Identifiable {
  case open(PositionRow)
  case closed(DayTrade)

  /// Accessibility id of an open position's OPEN tag, for the UI tests.
  static let openID = "trades-open-position"
  /// Prefix of an open row's id, apart from the trade ids of closed rows.
  static let openPrefix = "open-"

  /// The closed trade's id (the selection's), or the open position's.
  var id: DayTrade.ID {
    switch self {
    case .open(let row): Self.openPrefix + row.id
    case .closed(let trade): trade.id
    }
  }

  var symbol: String {
    switch self {
    case .open(let row): row.id
    case .closed(let trade): trade.symbol
    }
  }

  var quantity: Decimal {
    switch self {
    case .open(let row): row.quantity
    case .closed(let trade): trade.quantity.value
    }
  }

  var entry: Decimal {
    switch self {
    case .open(let row): row.entry
    case .closed(let trade): trade.entryPrice.value
    }
  }

  /// The exit price; nil while open.
  var exit: Decimal? {
    switch self {
    case .open: nil
    case .closed(let trade): trade.exitPrice.value
    }
  }

  var stop: Decimal? {
    switch self {
    case .open(let row): row.stop
    case .closed(let trade): trade.stopPrice?.value
    }
  }

  /// An open position whose broker stop is not verified.
  var stopUnverified: Bool {
    if case .open(let row) = self { return !row.position.stop.state.isProtected }
    return false
  }

  /// R now (open, at the newest captured bar) or at the exit.
  var resultR: Decimal? {
    switch self {
    case .open(let row): row.resultR ?? row.latestResultR
    case .closed(let trade): trade.resultR
    }
  }

  /// An open position whose R and result are as of an older bar (`PositionRow.isStale`): they
  /// show greyed, not as the current figures.
  var isStale: Bool {
    if case .open(let row) = self { return row.isStale }
    return false
  }

  /// Colour of the R: by its sign, greyed while stale or missing.
  var resultRColor: Color {
    guard let resultR, !isStale else { return Palette.textQuaternary }
    return Palette.result(resultR)
  }

  /// Gross result in USD now (open) or at the exit; nil while an open one has no bar yet.
  var result: Decimal? {
    switch self {
    case .open(let row): row.unrealized ?? row.latestUnrealized
    case .closed(let trade): trade.resultGrossUsd.value
    }
  }
}

/// The selected trade's risk (1 R), price excursion and how fast the broker confirmed its stop.
private struct TradeDetailCard: View {
  let trade: DayTrade?
  @State private var anotherShown = false

  /// Accessibility id of the card, for the UI tests.
  static let id = "trades-detail"
  /// Symbol of the "Another Strategy…" button.
  static let anotherSymbol = "arrow.triangle.branch"

  var body: some View {
    Group {
      if let trade {
        Card(L10n.Trades.tradeDetail(trade.symbol), trailing: {
          Button {
            anotherShown.toggle()
          } label: {
            Label { Text(L10n.Trades.whatIfStrategy) } icon: { Image(systemName: Self.anotherSymbol) }
          }
          // The design's outlined button in the card's header.
          .buttonStyle(.chip(selected: true))
          .help(Text(L10n.Trades.anotherHelp))
          .popover(isPresented: $anotherShown, arrowEdge: .bottom) {
            AnotherStrategyView(trade: trade)
          }
        }, content: {
          VStack(alignment: .leading, spacing: Tokens.Space.m) {
            Grid(alignment: .leading, horizontalSpacing: Tokens.Space.m, verticalSpacing: Tokens.Space.s) {
              GridRow {
                Text(L10n.Trades.oneR).foregroundStyle(Palette.textSecondary)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .fixedSize(horizontal: false, vertical: true)
                MoneyText(
                  value: trade.plannedLossUsd.value, usd: true, font: Tokens.Typography.calloutMono, colored: false,
                  signed: false)
                  // The values line up on the right, as in the design; the labels take the rest.
                  .gridColumnAlignment(.trailing)
              }
              GridRow {
                Text(L10n.Trades.stopConfirmedAfter).foregroundStyle(Palette.textSecondary)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .fixedSize(horizontal: false, vertical: true)
                  .help(Text(L10n.Trades.stopConfirmedHelp))
                if let seconds = trade.stopConfirmedAfterSeconds {
                  Text(verbatim: Format.seconds(seconds.value)).font(Tokens.Typography.calloutMono)
                } else {
                  notRecorded
                }
              }
              GridRow {
                let sent = EntrySent.line(trade.entry, cause: ApiText.prose(trade.entryCauseCodes, text: trade.entryCause))
                Text(L10n.EntrySent.title).foregroundStyle(Palette.textSecondary)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .fixedSize(horizontal: false, vertical: true)
                let value = Text(verbatim: sent.text)
                  .font(Tokens.Typography.calloutMono)
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
                Text(L10n.Trades.codeVersion).foregroundStyle(Palette.textSecondary)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .fixedSize(horizontal: false, vertical: true)
                if let code = trade.codeVersion {
                  Text(verbatim: CodeVersion.short(code)).font(Tokens.Typography.calloutMono)
                    .help(Text(L10n.Trades.codeVersionHelp(code)))
                } else {
                  notRecorded
                }
              }
              GridRow {
                Text(L10n.Trades.overshoot).foregroundStyle(Palette.textSecondary)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .fixedSize(horizontal: false, vertical: true)
                  .help(Text(L10n.Trades.overshootHelp))
                if let usd = trade.overshootUsd?.value {
                  Text(L10n.Trades.overshootValue(Money.signedUSD(usd), trade.overshootR.map { Risk.text($0.value) }
                    ?? Format.missing))
                    .font(Tokens.Typography.calloutMono)
                    // Neutral, not green: this is profit the trade left behind, not a gain.
                    .foregroundStyle(Palette.textPrimary)
                } else {
                  Text(L10n.Trades.unknown).foregroundStyle(Palette.textQuaternary)
                    .help(Text(verbatim: ApiText.prose(trade.overshootCauseCodes, text: trade.overshootCause) ?? Format.missing))
                }
              }
            }
            .font(Tokens.Typography.callout)
            if let after = WhatIfText.after(trade.pricesAfter) {
              Divider()
              Text(verbatim: after)
                .font(Tokens.Typography.captionMono)
                .foregroundStyle(Palette.textTertiary)
                .help(Text(L10n.Trades.priceAfterExit))
            }
            Spacer(minLength: 0)
            Footnote(L10n.Trades.excursionLowerBound)
          }
          .frame(maxHeight: .infinity, alignment: .top)
        })
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
      if let value {
        MoneyText(value: value.value, usd: true, font: Tokens.Typography.calloutMono)
      } else {
        Text(L10n.Trades.unknown).foregroundStyle(Palette.textQuaternary)
      }
    }
  }

  private var notRecorded: some View {
    Text(L10n.Trades.notRecorded).foregroundStyle(Palette.textQuaternary)
  }
}

/// "Another Strategy…" on one closed trade: a strategy version picked here, replayed by the API
/// on the trade's symbol and day (GET /trades/whatif), next to what the bot did. Simulated; the
/// API refuses it during the session, and that reason is shown as it is.
private struct AnotherStrategyView: View {
  @Environment(AppModel.self) private var model
  let trade: DayTrade
  @State private var version: String?
  @State private var answer: TradeWhatIfAnswer?

  /// Width of the popover, in points.
  static let width: CGFloat = 380
  /// Columns of the result grid: what, R, USD.
  static let columns = 3

  private var day: WireDate { WireDate(newYorkDateOf: trade.openedAt.date) }
  /// Versions the API can replay; the active one last, since the bot already traded it.
  private var versions: [LabVersionV1] {
    let all = model.labReplay?.versions.filter { $0.cause == nil } ?? []
    return all.filter { $0.role != .active } + all.filter { $0.role == .active }
  }
  private var chosen: String? {
    if let version, versions.contains(where: { $0.folder == version }) { return version }
    return versions.first?.folder
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      Text(L10n.Trades.anotherTitle(trade.symbol))
        .font(Tokens.Typography.body)
        .fontWeight(.semibold)
      if model.labReplay == nil {
        if let error = model.labReplayError {
          ReadFailureNote(L10n.ReadFailed.replay, detail: error)
        } else {
          TickrLoader(L10n.Common.loading)
        }
      } else if versions.isEmpty {
        Footnote(L10n.Trades.anotherNoVersions)
      } else {
        Picker(selection: Binding(get: { chosen ?? "" }, set: { version = $0 })) {
          ForEach(versions, id: \.folder) { item in
            Text(L10n.Lab.versionName(item.strategy ?? item.folder, item.version ?? Format.missing)).tag(item.folder)
          }
        } label: {
          Text(L10n.Lab.replayVersion)
        }
        .fixedSize()
      }
      Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Tokens.Space.m, verticalSpacing: Tokens.Space.s) {
        GridRow {
          Text(L10n.Trades.anotherBot).foregroundStyle(Palette.textSecondary)
          botR
          MoneyText(value: trade.resultGrossUsd.value, usd: true, font: Tokens.Typography.calloutMono)
        }
        if chosen != nil { result }
      }
      .font(Tokens.Typography.callout)
      Footnote(L10n.Trades.anotherNote)
    }
    .padding(Tokens.Space.l)
    .frame(width: Self.width, alignment: .leading)
    .task(id: chosen) { await load() }
    .task { if model.labReplay == nil { await model.refreshLabReplay() } }
  }

  /// The bot's own result in R (per share, as the version's).
  @ViewBuilder private var botR: some View {
    if let r = trade.resultR {
      Text(verbatim: Risk.text(r, fractionDigits: StatDigits.r))
        .font(Tokens.Typography.calloutMono)
        .foregroundStyle(Palette.result(r))
    } else {
      Text(verbatim: Format.missing).foregroundStyle(Palette.textQuaternary)
    }
  }

  @ViewBuilder private var result: some View {
    switch answer {
    case nil:
      GridRow {
        TickrLoader(L10n.Common.loading)
        Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
        Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
      }
    case .refused(let cause):
      GridRow {
        Text(verbatim: cause)
          .font(Tokens.Typography.caption)
          .foregroundStyle(Palette.warningText)
          .gridCellColumns(Self.columns)
      }
    case .found(let found):
      if let cause = found.cause {
        GridRow {
          Text(verbatim: cause)
            .font(Tokens.Typography.caption)
            .foregroundStyle(Palette.textTertiary)
            .gridCellColumns(Self.columns)
        }
      } else {
        ForEach(Array(found.trades.enumerated()), id: \.offset) { _, item in
          GridRow {
            Text(L10n.Trades.anotherLeg(Format.marketTime(item.openedAt.date), Format.marketTime(item.closedAt.date),
              WhatIfText.exit(item.exitReason)))
              .font(Tokens.Typography.captionMono)
              .foregroundStyle(Palette.textTertiary)
            Text(verbatim: Risk.text(item.resultR.value, fractionDigits: StatDigits.r))
              .font(Tokens.Typography.captionMono)
              .foregroundStyle(Palette.result(item.resultR.value))
            if let usd = item.resultGrossUsd?.value {
              Text(verbatim: Money.signedUSD(usd))
                .font(Tokens.Typography.captionMono)
                .foregroundStyle(Palette.result(usd))
            } else {
              Text(verbatim: Format.missing).foregroundStyle(Palette.textQuaternary)
            }
          }
        }
        Divider().gridCellUnsizedAxes(.horizontal)
        GridRow {
          Text(L10n.Lab.versionName(found.strategy ?? found.folder, found.version ?? Format.missing))
            .fontWeight(.semibold)
          if let r = found.resultR?.value {
            Text(verbatim: Risk.text(r, fractionDigits: StatDigits.r))
              .font(Tokens.Typography.calloutMono)
              .foregroundStyle(Palette.result(r))
          } else {
            Text(verbatim: Format.missing).foregroundStyle(Palette.textQuaternary)
          }
          if let usd = found.resultGrossUsd?.value {
            MoneyText(value: usd, usd: true, font: Tokens.Typography.calloutMono)
          } else {
            Text(verbatim: Format.missing).foregroundStyle(Palette.textQuaternary)
          }
        }
        if let signals = found.signals {
          GridRow {
            Text(signals.filled + signals.missed + signals.rejected + signals.ignored == .zero
              ? L10n.Trades.anotherNoEntry
              : L10n.Trades.anotherSignals(signals.filled, signals.missed, signals.rejected, signals.ignored))
              .font(Tokens.Typography.caption)
              .foregroundStyle(Palette.textTertiary)
              .gridCellColumns(Self.columns)
          }
        }
      }
    }
  }

  private func load() async {
    guard let chosen else { return }
    answer = nil
    let read = await model.tradeWhatIf(symbol: trade.symbol, day: day, version: chosen)
    guard chosen == self.chosen else { return }
    answer = read
  }
}

/// The active strategy's entry signals of the shown day that did not become a position: refused
/// by the platform (the rule in words, with its detail) or never evaluated, with their what-if
/// levels. Repeats on one symbol for one reason are one row, as on iOS.
private struct NotTakenCard: View {
  @Environment(AppModel.self) private var model
  /// Runs of signals the bot added in the latest read: each flashes once.
  @State private var arrived: Set<SkippedGroup.ID> = []
  let showOnChart: (String) -> Void

  /// A new row's flash reaches a little past it, as the design's row background does.
  static let rowOutset = EdgeInsets(
    top: Tokens.Space.xxs, leading: Tokens.Space.xs, bottom: Tokens.Space.xxs, trailing: Tokens.Space.xs)

  var body: some View {
    Card(L10n.Trades.notTaken, trailing: {
      Text(L10n.Trades.notTakenHint)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
    }, content: {
      if let signals = model.skipped?.signals, !signals.isEmpty {
        let groups = SkippedGroup.make(signals)
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
          ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
            if index > 0 { Divider() }
            SkippedRow(group: group, showOnChart: showOnChart)
              .arrivalFlash(arrived.contains(group.id), color: Palette.info, outset: Self.rowOutset)
          }
        }
        .onArrival(of: groups.map(\.id)) { arrived = $0 }
      } else if let error = model.skippedError {
        ReadFailureNote(L10n.Trades.notTakenUnavailable, detail: error)
      } else if model.skipped != nil {
        Footnote(L10n.Trades.notTakenEmpty)
      } else {
        TickrLoader(L10n.Common.loading)
      }
    })
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
      Badge(L10n.Trades.refused, tone: Tone.refused)
    } else {
      Badge(L10n.Trades.notEvaluated, tone: Tone.notEvaluated)
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
      .font(Tokens.Typography.captionMono)
      .foregroundStyle(Palette.textTertiary)
      .fixedSize(horizontal: false, vertical: true)
    }
  }
}

/// What the day's skipped setups would have made had each been entered once, from the bot's
/// replays: one slim row, its label on the left.
private struct WhatIfCard: View {
  @Environment(AppModel.self) private var model

  /// Width of the label column, in points.
  static let labelWidth: CGFloat = 56

  var body: some View {
    HStack(alignment: .top, spacing: Tokens.Space.l) {
      Text(L10n.Trades.whatIf)
        .textCase(.uppercase)
        .font(Tokens.Typography.label)
        .tracking(Tokens.Typography.labelTracking)
        .foregroundStyle(Palette.textQuaternary)
        .frame(width: Self.labelWidth, alignment: .leading)
        .accessibilityAddTraits(.isHeader)
      VStack(alignment: .leading, spacing: Tokens.Space.xs) {
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
                .font(Tokens.Typography.calloutMono.bold())
                .foregroundStyle(Palette.result(summary.resultUsd))
              Text(L10n.Trades.whatIfCounts(summary.wins, summary.losses, summary.notReplayed))
                .font(Tokens.Typography.captionMono)
                .foregroundStyle(Palette.textTertiary)
            }
          } else {
            Text(L10n.Trades.whatIfNone)
              .font(Tokens.Typography.callout)
              .foregroundStyle(Palette.textSecondary)
          }
        }
        Text(L10n.Trades.whatIfHelp)
          .font(Tokens.Typography.caption)
          .foregroundStyle(Palette.textTertiary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, alignment: .leading)
    .tickrCard(radius: Tokens.Radius.large)
  }
}

#if DEBUG
#Preview {
  TradesView()
    .environment(PreviewAPI.model())
    .frame(width: PreviewAPI.windowWidth, height: PreviewAPI.windowHeight)
}
#endif

/// Which of a table's rows rise as it appears, and in what turn: the first `first` rows not yet
/// risen, by their place in the table; every other row shows at once. One pass over the rows.
enum RowEntrance {
  /// Rows of the Trades table that rise one after another as it appears, about a window's worth:
  /// later rows show at once, so a long day never waits seconds for its last rows.
  static let tradesRows = 10

  static func steps<ID: Hashable>(_ ids: [ID], first: Int, risen: Set<ID>) -> [ID: Int] {
    var steps: [ID: Int] = [:]
    for (index, id) in ids.prefix(first).enumerated() where !risen.contains(id) {
      steps[id] = index
    }
    return steps
  }
}

/// A table cell's entrance, fixed when the cell is made: rises at `step` (`rise(step:)`), or shows
/// at once without one. A recycled cell made again for a row that has risen gets no step, and a
/// later render never changes a made cell's choice. `appeared` records the rise.
private struct EntranceRise: ViewModifier {
  @State private var step: Int?
  let appeared: () -> Void

  init(step: Int?, appeared: @escaping () -> Void) {
    _step = State(initialValue: step)
    self.appeared = appeared
  }

  func body(content: Content) -> some View {
    if let step {
      content.rise(step: step).onAppear(perform: appeared)
    } else {
      content
    }
  }
}
