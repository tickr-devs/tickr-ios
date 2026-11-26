import Charts
import SwiftUI
import TickrDesign
import TickrKit

/// Trades & days (MacTrades v134): recorded days and the 30-day performance on the left; the
/// shown day's figures, its trades, and the selected trade beside the signals not taken (with what
/// they would have made) on the right.
/// Picking a day here is the same as picking it in the toolbar.
struct TradesView: View {
  @Environment(AppModel.self) private var model
  @AppStorage(ChartView.Keys.symbol) private var chartSymbol = ""
  @State private var selection: DayTrade.ID?

  /// Padding around the screen's content, in points: the board's 16 (top, bottom) and 12 (sides)
  /// (MacTrades v106, `main` padding 16px 12px), which lets the trades table, never cut or
  /// wrapped, sit beside the days column at the first window size (1440, the sidebar at its
  /// preferred width).
  static let verticalPadding: CGFloat = Tokens.Space.l
  static let horizontalPadding: CGFloat = Tokens.Space.m
  /// Gap between the days column and the day, and between the cards of each, in points: the
  /// board's 14 (MacTrades v106, `gap:14px`) on the spacing scale.
  static let columnGap: CGFloat = Tokens.Space.m
  /// Width of the days column (calendar, performance in R, all days) beside the day, in points:
  /// the shared side column, the board's 378 (MacTrades v106, `grid-template-columns:378px 1fr`).
  static let daysColumnWidth: CGFloat = Tokens.Size.sideColumn

  /// Least width of this screen, in points: the screen's padding and the trades card's own
  /// padding (`Space.l`) around the trades table at its least width. It is the widest least width
  /// of all screens, so it sets the window's (`RootView.screenMinWidth`).
  static let leastScreenWidth: CGFloat = horizontalPadding * CardArrangement.paddedEdges
    + Tokens.Space.l * CardArrangement.paddedEdges + TradesTable.leastWidth
  /// Narrowest screen, in points, that shows the days column beside the day, as the board does:
  /// the least screen with the days column and its gap beside the table (the four figures of the
  /// day and the selected trade beside Not taken need less). Narrower, the board has no layout,
  /// so the days follow the day's detail in one column (the toolbar's day picker stays at the
  /// top). Derived, not set: a set 1180 left the table 6 points short of its columns, so the
  /// columns were cut to "10:07:…". With the sidebar at its preferred width the window's first
  /// width (`TickrMacApp.defaultWidth`) is wide enough, as on the board.
  static let sideBySideMinWidth: CGFloat = leastScreenWidth + daysColumnWidth + columnGap
  /// Width of the selected trade's card beside Not taken, in points: the board's 360 (MacTrades v134).
  static let detailWidth: CGFloat = 360

  /// Entrance order of the screen's parts.
  fileprivate enum Order: Int {
    case days = 0, performance, stats, trades, detail, notTaken
  }

  /// The screen's size, read from its scroll area: whether the days column fits beside the day,
  /// and how tall each column's own scroll area is.
  @State private var screenSize: CGSize = .zero
  /// Each column's content height, in points: a column's height while the screen scrolls as one.
  @State private var columnHeights: [Part: CGFloat] = [:]

  /// Whether the days column sits beside the day: the screen's content (at most
  /// `contentMaxWidth`) holds both.
  private var sideBySide: Bool {
    min(screenSize.width, Tokens.Size.contentMaxWidth) >= Self.sideBySideMinWidth
  }

  var body: some View {
    let beside = sideBySide
    // Beside the day, each column scrolls on its own, as the board's days column holds still while
    // the day's trades scroll; one above the other, the screen scrolls as one, as Risk and Lab do
    // (an unscrolled stack overflowed upward under the toolbar). The same scroll views in both,
    // only their axes and heights changed: a resize never makes the cards anew (new ones played
    // their entrance again mid-drag).
    ScrollViewReader { proxy in
      ScrollView(beside ? [] : .vertical) {
        CardGrid(arrangements: Self.arrangements, spacing: Self.columnGap) {
          column(.side, beside: beside) { sideColumn }
          column(.day, beside: beside) { dayDetail }
        }
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.vertical, beside ? 0 : Self.verticalPadding)
        .frame(maxWidth: Tokens.Size.contentMaxWidth)
        .frame(maxWidth: .infinity)
      }
      .scrollEdgeHints()
      // A picked day is shown from its title: the pick is often made below it.
      .onChange(of: model.shownDay) {
        withAnimation(Tokens.Motion.standard) { proxy.scrollTo(Self.dayTopID, anchor: .top) }
      }
    }
    .onGeometryChange(for: CGSize.self) { $0.size } action: { screenSize = $0 }
    .plainCardLabels()
    // The first trade of the day is selected until another is picked, so its details show at once.
    .onChange(of: model.shownTrades.map(\.id), initial: true) { _, ids in
      if selection.map({ !ids.contains($0) }) ?? true { selection = ids.first }
    }
  }

  /// One of the two columns (`part`): its own vertical scroll area, the screen's height, while
  /// beside the other; one above the other, a still area as tall as its content, inside the
  /// screen's scroll area. Its content is always laid out at its own height (a scroll area offers
  /// it no height), which is what the still area is set to.
  private func column(_ part: Part, beside: Bool, @ViewBuilder _ content: () -> some View) -> some View {
    ScrollView(.vertical) {
      content()
        .padding(.vertical, beside ? Self.verticalPadding : 0)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { columnHeights[part] = $0 }
    }
    .scrollEdgeHints()
    .scrollDisabled(!beside)
    .frame(height: beside ? screenSize.height : columnHeights[part] ?? 0)
  }

  /// The days column beside the day's detail, or after it in a narrow window so the day's trades
  /// are on the first screen. The same two views in both: a resize moves them and never makes
  /// them anew (new ones played their entrance again mid-drag).
  static let arrangements: [CardArrangement] = [
    CardArrangement(minWidth: sideBySideMinWidth - horizontalPadding * CardArrangement.paddedEdges, rows: [
      CardRow(columns: [
        CardColumn(width: .fixed(daysColumnWidth), cards: [Part.side.rawValue]),
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

  /// The calendar and the 30-day performance: beside the day as in the design, or
  /// after it in a narrow window, so the day's trades are on the first screen.
  private var sideColumn: some View {
    VStack(spacing: Self.columnGap) {
      DaysColumn()
        .rise(step: Order.days.rawValue)
      PerformanceCard()
        .rise(step: Order.performance.rawValue)
    }
  }

  /// The shown day's figures, trades, and the selected trade with the signals not taken.
  /// A picked past day shows its title at once, then its trades once read: a skeleton while they
  /// are, the unavailable state with its cause when they could not be (never the day before's
  /// figures, nor zeros that read as an empty day).
  private var dayDetail: some View {
    VStack(alignment: .leading, spacing: Self.columnGap) {
      dayTitle
        .id(Self.dayTopID)
        .rise(step: Order.stats.rawValue)
      switch model.shownDayState {
      case .failed(let cause):
        DayUnavailable(day: model.shownDay, cause: cause)
      case .loading:
        Skeleton(L10n.Trades.loadingDay(DayText.day(model.shownDay))) {
          VStack(alignment: .leading, spacing: Self.columnGap) {
            SkeletonTiles(Tokens.Loading.tiles)
            SkeletonRows(Tokens.Loading.manyRows, badge: true)
          }
        }
        .accessibilityIdentifier(Self.dayLoadingID)
      case .live, .loaded:
        DayStatsRow()
          .rise(step: Order.stats.rawValue)
        TradesTable(selection: $selection, showOnChart: showOnChart)
          .rise(step: Order.trades.rawValue)
        selectedAndNotTaken
      }
    }
    // A picked day's cards take its skeleton's place without rising (design-system "Loading").
    .loadsInPlace(model.shownDayState != .loading)
  }

  /// Scroll id of the shown day's title: a picked day scrolls it into view, so the change is
  /// seen even when the pick was made far below it (the days column under the day in a narrow
  /// window, or the day's own column scrolled down).
  static let dayTopID = "trades-day-top"
  /// Accessibility ids of the day's title and of its loading skeleton, for the UI tests.
  static let dayTitleID = "trades-day-title"
  static let dayLoadingID = "trades-day-loading"

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
      .accessibilityIdentifier(Self.dayTitleID)
      if let clean = model.days.first(where: { $0.day == model.shownDay })?.clean {
        CleanBadge(clean: clean, showsNote: true)
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

/// A picked past day whose trades could not be read: the shared unavailable state with the
/// cause in the person's language, and a way to read the day again.
private struct DayUnavailable: View {
  @Environment(AppModel.self) private var model
  let day: WireDate
  let cause: String

  /// Accessibility id, for the UI tests.
  static let id = "trades-day-unavailable"

  var body: some View {
    Card(L10n.Trades.tradesOfDay) {
      VStack(spacing: Tokens.Space.m) {
        UnavailableState(L10n.Trades.dayUnavailable(DayText.day(day)), message: L10n.Trades.dayUnavailableDetail,
          cause: cause)
        Button { model.retryShownDay() } label: { Text(L10n.Trades.retryDay) }
          .buttonStyle(.action(.secondary, size: .compact))
      }
      .frame(maxWidth: .infinity)
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(Self.id)
  }
}

// MARK: Days

/// The month of recorded days; the calendar labels the card with its month.
private struct DaysColumn: View {
  @Environment(AppModel.self) private var model

  /// The calendar card's padding, in points: the board's 12 (top, bottom) and 10 (sides)
  /// (MacTrades v106), which leaves each day tile room for "−$1,234.56" in a 378-point column.
  static let verticalInset: CGFloat = Tokens.Space.m
  static let horizontalInset: CGFloat = Tokens.Space.s + Tokens.Space.xxs

  var body: some View {
    if model.days.isEmpty {
      Card(L10n.Trades.days) {
        EmptyState(model.historyError == nil ? L10n.Trades.noDays : L10n.Trades.daysUnavailable,
          symbol: model.historyError == nil ? EmptyState.nothingSymbol : EmptyState.unavailableSymbol)
      }
    } else {
      MonthCalendar()
        .padding(.vertical, Self.verticalInset)
        .padding(.horizontal, Self.horizontalInset)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .tickrCard(radius: Tokens.Radius.large)
    }
  }
}

// MARK: Shown day

/// The shown day's figures: result, trades, average R (MacTrades v134; each trade's best and
/// worst are in the table).
private struct DayStatsRow: View {
  @Environment(AppModel.self) private var model

  private var averageR: Decimal? {
    let values = model.shownTrades.compactMap(\.resultR)
    guard !values.isEmpty else { return nil }
    return values.reduce(0, +) / Decimal(values.count)
  }

  /// Three figures in a row; one under the other when the row would have to shrink them.
  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: Tokens.Space.l) { result; trades; average }
      VStack(spacing: Tokens.Space.l) { result; trades; average }
    }
  }

  private var result: some View {
    Stat(L10n.Trades.resultGross) {
      MoneyText(value: model.shownResult, font: Tokens.Typography.figure)
    }
  }

  private var trades: some View {
    // As the board: the count, and its wins and losses beside it in a smaller, quieter type.
    Stat(L10n.Trades.trades) {
      HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
        Text(verbatim: String(model.shownTradeCount))
          .font(Tokens.Typography.figure)
          .foregroundStyle(Palette.textPrimary)
        Text(L10n.Trades.winsLosses(model.shownWins, model.shownLosses))
          .font(Tokens.Typography.calloutMono.weight(.semibold))
          .foregroundStyle(Palette.textTertiary)
      }
    }
  }

  private var average: some View {
    Stat(L10n.Trades.averageR) {
      Text(verbatim: averageR.map(Risk.text) ?? Format.missing)
        .font(Tokens.Typography.figure)
        .foregroundStyle(averageR.map(Palette.result) ?? Palette.textQuaternary)
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
  @Environment(\.dynamicTypeSize) private var typeSize
  @Binding var selection: DayTrade.ID?
  /// The row under the pointer, tinted as one.
  @State private var hovered: TradeRow.ID?
  /// Rows that have risen once: the table recycles a row's cells as the screen scrolls, and a row
  /// shown again never rises again.
  @State private var risen: Set<TradeRow.ID> = []
  let showOnChart: (String) -> Void

  /// Least and preferred widths of the table's four columns, in points (MacTrades v134: time,
  /// symbol, exit, result). Each least width holds the column's widest content and its heading
  /// whole, in English and Spanish (values in 12-point mono, headings and badges in 10-point mono;
  /// a heading cell keeps a few points of inset, a value cell none).
  private enum Column {
    /// "10:07:00" (59.3).
    static let timeMin: CGFloat = 60
    static let time: CGFloat = 76
    /// The heading "SYMBOL" (37.1, and the header cell's own inset: at 40 it read "SYMB…"); a
    /// five-letter symbol such as "BRK.B" takes 37.1.
    static let symbolMin: CGFloat = 46
    static let symbol: CGFloat = 56
    /// The widest exit: an open position's OPEN tag (44) with its line in 11-point mono,
    /// "1234 @ 1234.56 · stop 1234.56 ✓" (31 characters, 205), or the widest exit reason badge,
    /// 21 characters (146): the Spanish "MUCHO TIEMPO SIN STOP".
    static let reasonMin: CGFloat = 260
    static let reason: CGFloat = 300
    /// "−$1,234.56" (74.2).
    static let moneyMin: CGFloat = 76
    static let money: CGFloat = 88
    /// The least widths of the four columns in the table's order.
    static let leastWidths = [timeMin, symbolMin, reasonMin, moneyMin]
  }

  /// AppKit's table layout around the columns, in points (measured with Accessibility on macOS
  /// 27): the inset at each edge of the table and the gap between two cells.
  static let edgeInset: CGFloat = 16
  static let cellSpacing: CGFloat = 17

  /// Width the table needs for every column at its least width, in points: below it the columns
  /// are cut.
  static let leastWidth: CGFloat = Column.leastWidths.reduce(0, +)
    + cellSpacing * CGFloat(Column.leastWidths.count - 1) + edgeInset * CardArrangement.paddedEdges

  #if os(iOS)
  /// How much larger iOS draws the table's text (callout, at the screen's Dynamic Type size) than
  /// the Mac's 12 points it was measured in: the table's least width grows with it.
  static func typeGrowth(_ size: DynamicTypeSize) -> CGFloat {
    TextMeasure.pointSize(.callout, at: size) / macCalloutSize
  }
  /// The Mac's callout size, in points (Apple's macOS type sizes), the table's values' font there.
  static let macCalloutSize: CGFloat = 12
  #endif

  /// Height of the "no trades" message in place of the table, in points.
  static let emptyHeight: CGFloat = 280
  /// Accessibility id of that message, for the UI tests.
  static let emptyID = "trades-empty"
  /// The table's vertical geometry, in points, as AppKit lays it out (read with Accessibility,
  /// 2026-11-16, 3 and 9 rows): the first row starts `headerHeight` under the table's top (the
  /// 28-point header and the gap under it), rows are `rowHeight` apart, and `bottomInset` stays
  /// under the last row. The fewest rows the table is tall for. With 32 and 28 the table was 10
  /// points plus one per row too short and scrolled inside its card.
  static let headerHeight: CGFloat = 33
  static let rowHeight: CGFloat = 29
  static let bottomInset: CGFloat = 10
  static let fewestRows = 2

  /// The table's height: every row of the day, so the screen scrolls as one and no row is cut
  /// inside a box. Set from the trade count, because the screen scrolls and a table has no height
  /// of its own; a fixed height left empty striped rows under a day of two trades.
  private var tableHeight: CGFloat {
    let count = CGFloat(max(rows.count, Self.fewestRows))
    return Self.headerHeight + count * Self.rowHeight + Self.bottomInset
  }

  /// The day's closed trades in the order they closed, then on the live day the positions still
  /// open: a new trade is added under the others and a closing one stays in its place, so no row
  /// moves under the pointer.
  private var rows: [TradeRow] {
    model.shownTrades.map { TradeRow.closed($0) } + (model.isLive ? model.positions.map { TradeRow.open($0) } : [])
  }

  var body: some View {
    Card(L10n.Trades.tradesOfDay, trailing: { EmptyView() }, content: {
      if rows.isEmpty {
        Group {
          if model.isLive {
            EmptyState(L10n.Trades.noTradesToday)
          } else {
            EmptyState(L10n.Trades.noTradesOn(DayText.day(model.shownDay)), detail: L10n.Trades.noTradesOnDetail)
          }
        }
        .frame(height: Self.emptyHeight)
        .accessibilityIdentifier(Self.emptyID)
      } else {
        #if os(macOS)
        table
          .frame(height: tableHeight)
        #else
        // iOS draws the table's text a little larger than the Mac its columns were measured on:
        // on an iPad in portrait the table scrolls sideways rather than cut a column.
        ScrollView(.horizontal) {
          table
            .frame(minWidth: Self.leastWidth * Self.typeGrowth(typeSize), minHeight: tableHeight, maxHeight: tableHeight)
        }
        .withoutScrollIndicators()
        .frame(height: tableHeight)
        #endif
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
          SymbolText(row.symbol).font(Tokens.Typography.calloutMono.weight(.semibold))
        }
      }
      .width(min: Column.symbolMin, ideal: Column.symbol)
      TableColumn(Self.header(L10n.Trades.exit)) { row in
        cell(row, step: steps[row.id]) {
          switch row {
          case .open(let position):
            // A position still open: the OPEN tag, which opens the Chart on it.
            Button { showOnChart(position.id) } label: {
              HStack(spacing: Tokens.Space.xs) {
                // One pulse per thing the bot did to the position (a fill, a stop placed or
                // verified), never a loop.
                PulseDot(Palette.accent, size: Tokens.Size.dotSmall, event: position.event)
                Badge(L10n.Trades.open, tone: Tone.openPosition)
                OpenLine(row: position)
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
      TableColumn(Self.header(L10n.Trades.result)) { row in
        cell(row, step: steps[row.id]) {
          switch row {
          case .open:
            // Still open: R now, greyed while it is as of an older bar (MacTrades v134).
            Text(verbatim: row.resultR.map(Risk.text) ?? Format.missing)
              .font(Tokens.Typography.calloutMono.bold())
              .foregroundStyle(row.resultRColor)
          case .closed(let trade):
            MoneyText(value: trade.resultUsd.value, font: Tokens.Typography.calloutMono.bold())
          }
        }
      }
      .width(min: Column.moneyMin, ideal: Column.money)
    }
    .withoutScrollIndicators()
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

/// A row of the day's trades table: a position still open on the live day (its live R), or a
/// closed trade.
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

  /// R now (open, at the newest captured bar) or at the exit; the table shows it for an open row.
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
}

/// An open position's size, entry and stop in the trades table: "10 @ 12.34 · stop 11.90 ✓",
/// the tick only once the broker confirmed the stop (MacTrades v134); its state in words when
/// it has no stop price.
private struct OpenLine: View {
  let row: PositionRow

  /// Symbol after a confirmed stop.
  static let confirmedSymbol = "checkmark"

  var body: some View {
    let state = row.position.stop.state
    HStack(spacing: Tokens.Space.xxs) {
      Text(L10n.Trades.openLine(Format.quantity(row.quantity), Format.price(row.entry),
        row.stop == nil ? state.title : Format.price(row.stop)))
      if state.isProtected {
        Image(systemName: Self.confirmedSymbol).accessibilityHidden(true)
      }
    }
    .font(Tokens.Typography.captionMono)
    .foregroundStyle(state.isProtected ? Palette.textSecondary : state.tone.text)
    .fixedSize()
    .help(Text(verbatim: state.title))
  }
}

/// The selected trade (MacTrades v134): its symbol and time, the result big with its R, one line
/// with its size, prices, stop and 1 R, and how it exited; its risk, stop timing, price excursion
/// and what came after are one click away under "Details". "Other versions" replays it.
private struct TradeDetailCard: View {
  let trade: DayTrade?
  @State private var anotherShown = false

  /// Accessibility id of the card, for the UI tests.
  static let id = "trades-detail"
  /// Symbol of the "Other versions" button.
  static let anotherSymbol = "arrow.triangle.branch"

  var body: some View {
    Group {
      if let trade {
        Card(L10n.Trades.selectedTrade, trailing: {
          Button {
            anotherShown.toggle()
          } label: {
            Label { Text(L10n.Trades.whatIfStrategy) } icon: { Image(systemName: Self.anotherSymbol) }
          }
          // The design's outlined button in the card's header.
          .buttonStyle(.chip(selected: true))
          // Full label in either language, never cut.
          .fixedSize()
          .help(Text(L10n.Trades.anotherHelp))
          .popover(isPresented: $anotherShown, arrowEdge: .bottom) {
            AnotherStrategyView(trade: trade)
          }
        }, content: {
          VStack(alignment: .leading, spacing: Tokens.Space.m) {
            headline(trade)
            // The tick only when the broker confirmed the stop.
            let parts = (Format.quantity(trade.quantity.value), Format.price(trade.entryPrice.value),
              Format.price(trade.exitPrice.value), Format.price(trade.stopPrice?.value), Money.usd(trade.plannedLossUsd.value))
            Text(trade.stopConfirmedAfterSeconds == nil ? L10n.Trades.fillLine(parts.0, parts.1, parts.2, parts.3, parts.4)
              : L10n.Trades.fillLineVerified(parts.0, parts.1, parts.2, parts.3, parts.4))
              .font(Tokens.Typography.captionMono)
              .foregroundStyle(Palette.textSecondary)
              .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Tokens.Space.s) {
              Text(L10n.Trades.exit).foregroundStyle(Palette.textSecondary)
              Spacer(minLength: Tokens.Space.s)
              Badge(verbatim: Board.exitReasonTitle(trade.exitReason), tone: Tone.exit(trade.exitReason))
            }
            .font(Tokens.Typography.callout)
            DisclosureLine(L10n.Trades.details) {
              details(trade)
            }
            Spacer(minLength: 0)
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

  /// The symbol and when it closed; the result big, with its R under it.
  private func headline(_ trade: DayTrade) -> some View {
    HStack(alignment: .top, spacing: Tokens.Space.m) {
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        SymbolText(trade.symbol).font(Tokens.Typography.metric)
        Text(verbatim: Format.marketMinute(trade.closedAt.date))
          .font(Tokens.Typography.captionMono)
          .foregroundStyle(Palette.textTertiary)
      }
      Spacer(minLength: Tokens.Space.s)
      VStack(alignment: .trailing, spacing: Tokens.Space.xxs) {
        MoneyText(value: trade.resultUsd.value, font: Tokens.Typography.metric)
        if let r = trade.resultR {
          Text(verbatim: Risk.text(r))
            .font(Tokens.Typography.captionMono)
            .foregroundStyle(Palette.result(r))
        }
      }
    }
  }

  /// Everything else about the trade, under "Details".
  @ViewBuilder private func details(_ trade: DayTrade) -> some View {
    Grid(alignment: .leading, horizontalSpacing: Tokens.Space.m, verticalSpacing: Tokens.Space.s) {
      GridRow {
        Text(L10n.Trades.stopConfirmedAfter).foregroundStyle(Palette.textSecondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .fixedSize(horizontal: false, vertical: true)
          .help(Text(L10n.Trades.stopConfirmedHelp))
        if let seconds = trade.stopConfirmedAfterSeconds {
          Text(verbatim: Format.seconds(seconds.value)).font(Tokens.Typography.calloutMono)
            // The values line up on the right, as in the design; the labels take the rest.
            .gridColumnAlignment(.trailing)
        } else {
          notRecorded.gridColumnAlignment(.trailing)
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
          // "Once · acknowledged" wraps under itself in a narrow card, never cut.
          .multilineTextAlignment(.trailing)
          .fixedSize(horizontal: false, vertical: true)
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
      Text(verbatim: after)
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(Palette.textTertiary)
        .fixedSize(horizontal: false, vertical: true)
        .help(Text(L10n.Trades.priceAfterExit))
    }
    Footnote(L10n.Trades.excursionLowerBound)
  }

  private func excursion(_ title: LocalizedStringResource, _ value: DecimalString?) -> some View {
    GridRow {
      Text(title).foregroundStyle(Palette.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
      if let value {
        MoneyText(value: value.value, font: Tokens.Typography.calloutMono)
      } else {
        Text(L10n.Trades.unknown).foregroundStyle(Palette.textQuaternary)
      }
    }
  }

  private var notRecorded: some View {
    Text(L10n.Trades.notRecorded).foregroundStyle(Palette.textQuaternary)
  }
}

/// "Another strategy" on one closed trade: a strategy version picked here, replayed by the API
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
          Skeleton(L10n.Common.loading) { SkeletonLines(Tokens.Loading.lines) }
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
          MoneyText(value: trade.resultGrossUsd.value, font: Tokens.Typography.calloutMono)
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
        Skeleton(L10n.Common.loading) { SkeletonBlock(.line) }
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
      if let cause = found.causeText {
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
            MoneyText(value: usd, font: Tokens.Typography.calloutMono)
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
/// by the platform (the rule in words, with its detail) or never evaluated, each with what it
/// would have made, and the day's total in the header (MacTrades v134). A click opens a row's
/// what-if levels and the price after. Repeats on one symbol for one reason are one row, as on iOS.
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
      if let signals = model.skipped?.signals, let summary = WhatIfSummary.make(SkippedGroup.make(signals)) {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.xs) {
          Text(L10n.Trades.whatIfSummary)
            .font(Tokens.Typography.caption)
            .foregroundStyle(Palette.textTertiary)
          Text(verbatim: Risk.text(summary.resultR))
            .font(Tokens.Typography.captionMono.bold())
            .foregroundStyle(Palette.result(summary.resultR))
          Text(verbatim: Money.signedUSD(summary.resultUsd))
            .font(Tokens.Typography.captionMono.bold())
            .foregroundStyle(Palette.result(summary.resultUsd))
        }
        // How the total was worked out, and how many it counts, on hover.
        .help(Text(L10n.Trades.whatIfHelp) + Text(verbatim: Format.itemSeparator)
          + Text(L10n.Trades.whatIfCounts(summary.wins, summary.losses, summary.notReplayed)))
      }
    }, content: {
      if let signals = model.skipped?.signals, !signals.isEmpty {
        let groups = SkippedGroup.make(signals)
        // The latest runs (newest first), then "Show all N ›": refusals add up all day.
        CappedList(groups, id: \.id, title: L10n.Trades.notTaken) { index, group in
          VStack(alignment: .leading, spacing: Tokens.Space.s) {
            if index > 0 { Divider() }
            SkippedRow(group: group, showOnChart: showOnChart)
              .arrivalFlash(arrived.contains(group.id), color: Palette.info, outset: Self.rowOutset)
          }
        }
        .onArrival(of: groups.map(\.id)) { arrived = $0 }
      } else if let error = model.skippedError {
        ReadFailureNote(L10n.Trades.notTakenUnavailable, detail: error)
      } else if model.skipped != nil {
        // The apps' empty state, centred in the card beside the trade's detail: a lone line at
        // the top left the card half empty.
        EmptyState(L10n.Trades.notTakenEmpty)
      } else {
        Skeleton(L10n.Common.loading) { SkeletonRows(Tokens.Loading.manyRows, badge: true) }
      }
    })
  }
}

/// One run of skipped signals: the symbol, the rule that refused it with its detail and time,
/// and what it would have made. A click opens the what-if levels and the price after; the context
/// menu opens the Chart on its symbol.
private struct SkippedRow: View {
  let group: SkippedGroup
  let showOnChart: (String) -> Void
  @State private var open = false

  /// Width of the symbol column, in points: a five-letter symbol in 13-point mono.
  static let symbolWidth: CGFloat = 56
  /// Symbols of the row's disclosure, closed and open.
  static let closedSymbol = "chevron.down"
  static let openSymbol = "chevron.up"

  /// "16:27" or, for repeats, "16:27–16:29 · ×3"; repeats within one minute (or on one bar)
  /// read "16:27 · ×3", never "16:27–16:27".
  private var when: String {
    let first = Format.marketMinute(group.first.at.date)
    guard group.count > 1 else { return first }
    let last = Format.marketMinute(group.latest.at.date)
    guard last != first else { return String(localized: L10n.Trades.repeatAt(first, group.count)) }
    return String(localized: L10n.Trades.repeatRange(first, last, group.count))
  }

  var body: some View {
    let signal = group.latest
    // The what-if is the setup's first signal: a repeat would not have been a second trade.
    let setup = group.first
    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      Button { withAnimation(Tokens.Motion.standard) { open.toggle() } } label: {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.m) {
          SymbolText(signal.symbol)
            .font(Tokens.Typography.calloutMono.weight(.semibold))
            .frame(width: Self.symbolWidth, alignment: .leading)
          VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
            HStack(spacing: Tokens.Space.s) {
              admission
              Text(verbatim: when)
                .font(Tokens.Typography.captionMono)
                .foregroundStyle(Palette.textTertiary)
            }
            if let cause = group.cause {
              CauseText(cause: cause)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          HStack(spacing: Tokens.Space.xs) {
            Text(verbatim: setup.whatIf.resultR.map { Risk.text($0.value) } ?? Format.missing)
              .font(Tokens.Typography.captionMono.bold())
              .foregroundStyle(setup.whatIf.resultR.map { Palette.result($0.value) } ?? Palette.textQuaternary)
            Image(systemName: open ? Self.openSymbol : Self.closedSymbol)
              .font(Tokens.Typography.annotation)
              .foregroundStyle(Palette.textQuaternary)
              .accessibilityHidden(true)
          }
          .fixedSize()
        }
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .contextMenu {
        Button { showOnChart(signal.symbol) } label: {
          Label { Text(L10n.Trades.showOnChart) } icon: { Image(systemName: "chart.xyaxis.line") }
        }
      }
      if open {
        VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
          if let entry = setup.entryPrice, let stop = setup.stopPrice {
            Text(L10n.Trades.whatIfLevels(Format.price(entry.value), Format.price(stop.value)))
          }
          let result = WhatIfText.result(setup.whatIf)
          Text(verbatim: result.text).foregroundStyle(result.color)
          Text(verbatim: WhatIfText.after(setup.pricesAfter)
            ?? ApiText.prose(setup.pricesAfterCauseCodes, text: setup.pricesAfterCause) ?? Format.missing)
        }
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(Palette.textTertiary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.leading, Self.symbolWidth + Tokens.Space.m)
        .transition(.opacity)
      }
    }
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
