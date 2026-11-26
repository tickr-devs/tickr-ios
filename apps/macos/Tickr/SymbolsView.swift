import SwiftUI
import TickrDesign
import TickrKit

// The Symbols screen behind the Overview funnel (mockup MacSymbols, 2026-11-25): every symbol of
// the shown day in one column grid, by the funnel stage it got to, with why each one stopped in
// short, and the fast movers (their three figures only on that tab). A funnel stage or the fast
// movers' "Show all" opens it on that tab; "Overview" or Esc goes back. A click on a column's title
// sorts by it. The rows are the full list, never capped; the list scrolls, and no text is cut.

struct SymbolsView: View {
  @Environment(AppModel.self) private var model
  @State private var filter = SymbolsFilter.all
  @State private var search = ""
  /// The sort chosen by a click on a column title; nil keeps the tab's own.
  @State private var order: SymbolsOrder?
  /// The symbol the detail shows; nil shows the first line's.
  @State private var selected: String?

  /// Width of the detail beside the table, in points (the design's).
  static let detailWidth: CGFloat = 300
  /// Width of the search field, in points (the design's).
  static let searchWidth: CGFloat = 220
  /// Accessibility id of the screen, for the UI tests.
  static let id = "symbols"

  private var tab: SymbolsTab { model.symbolsTab ?? .stage(.screeners) }
  private var shownOrder: SymbolsOrder { order ?? SymbolsOrder.standard(tab) }

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      header
      tabs
      HStack(alignment: .top, spacing: Tokens.Space.m) {
        table.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        ScrollView(.vertical) { detail }
          .scrollEdgeHints()
          .scrollBounceBehavior(.basedOnSize)
          .frame(width: Self.detailWidth)
      }
      .frame(maxHeight: .infinity, alignment: .top)
    }
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .accessibilityIdentifier(Self.id)
    // Esc goes back to the Overview, as the back capsule does.
    #if os(macOS)
    .onExitCommand { close() }
    #endif
  }

  private func close() {
    withAnimation(Tokens.Motion.standard) { model.symbolsTab = nil }
  }

  // MARK: header

  private var header: some View {
    HStack(alignment: .center, spacing: Tokens.Space.m) {
      Button(action: close) { BackCapsule(L10n.Symbols.back) }
        .buttonStyle(.backCapsule)
      Text(L10n.Symbols.title)
        .font(Tokens.Typography.heading)
        .foregroundStyle(Palette.textPrimary)
        .accessibilityAddTraits(.isHeader)
      Text(verbatim: context)
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(Palette.textQuaternary)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
      if case .stage = tab {
        SegmentSwitch(options: SymbolsFilter.allCases.map { ($0, Text(SymbolsText.filterCount($0, filterCount($0)))) },
          selection: $filter)
          .fixedSize()
          .accessibilityLabel(Text(L10n.Symbols.show))
      } else if let rule = fastRule {
        FastRuleButton(rule: rule)
      }
      TextField(text: $search, prompt: Text(L10n.Symbols.search)) { Text(L10n.Symbols.search) }
        .textFieldStyle(.roundedBorder)
        .frame(width: Self.searchWidth)
    }
  }

  /// "Mon Nov 16 · 10:48 ET · From the screeners": the day, the end of the latest discovery pass
  /// and the tab's caption; the bot's cause when no pass is recorded.
  private var context: String {
    let day = DayText.day(model.shownDay)
    guard let symbols = model.symbols else {
      return [day, model.symbolsError.map { String(localized: L10n.Symbols.unavailable($0)) }]
        .compactMap { $0 }.joined(separator: Format.itemSeparator)
    }
    guard let asOf = symbols.asOf?.date else {
      return [day, symbols.asOfCause].compactMap { $0 }.joined(separator: Format.itemSeparator)
    }
    return String(localized: L10n.Symbols.context(day, Format.marketTime(asOf),
      SymbolsBoard.caption(tab, symbols: symbols)))
  }

  /// The fast mover rule in one sentence, or why there is none; nil before the movers are read.
  private var fastRule: String? {
    guard let movers = model.movers else {
      return model.moversError.map { String(localized: L10n.Symbols.unavailable($0)) }
    }
    return movers.rules.map(SymbolsBoard.fastRule) ?? movers.rulesCauseText
  }

  private func filterCount(_ filter: SymbolsFilter) -> Int {
    guard case .stage(let stage) = tab else { return 0 }
    return SymbolsBoard.rows(model.symbols?.rows ?? [], stage: stage, filter: filter, sort: .symbol, search: search).count
  }

  // MARK: tabs

  private var tabs: some View {
    HStack(spacing: 0) {
      ForEach(SymbolsTab.all) { item in
        if item == .fastMovers {
          Spacer(minLength: Tokens.Space.m)
          Rectangle().fill(Palette.separatorStrong).frame(width: Tokens.Stroke.thin, height: Tokens.Space.l)
            .padding(.trailing, Tokens.Space.s)
        }
        Button {
          withAnimation(Tokens.Motion.quick) {
            model.symbolsTab = item
            order = nil
            filter = .all
            selected = nil
          }
        } label: {
          UnderlineTab(item.title, count: count(item), selected: item == tab,
            systemImage: item == .fastMovers ? SymbolsTab.fastMoversSymbol : nil)
        }
        .buttonStyle(.plain)
        if case .stage(let stage) = item, stage != SymbolStage.allCases.last {
          Image(systemName: Symbols.next)
            .font(Tokens.Typography.chevron)
            .foregroundStyle(Palette.separatorStrong)
            .accessibilityHidden(true)
        }
      }
    }
    .frame(height: UnderlineTab.macHeight)
    .overlay(alignment: .bottom) { Rectangle().fill(Palette.separator).frame(height: Tokens.Stroke.thin) }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(Text(L10n.Symbols.stages))
  }

  private func count(_ item: SymbolsTab) -> String {
    SymbolsBoard.count(item, symbols: model.symbols, movers: model.movers).map(String.init) ?? Format.missing
  }

  // MARK: table

  private var lines: [SymbolsLine] {
    SymbolsBoard.lines(tab, symbols: model.symbols, movers: model.movers, positions: Set(model.positions.map(\.id)),
      query: SymbolsQuery(filter: filter, search: search, order: shownOrder))
  }

  private var table: some View {
    let shown = lines
    let fastMovers = tab == .fastMovers
    let current = selected ?? shown.first?.symbol
    return VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 0) {
        ForEach(SymbolsColumn.table(fastMovers: fastMovers)) { column in
          Button {
            order = shownOrder.clicked(column)
          } label: {
            SymbolsColumnTitle(column: column, fastMovers: fastMovers, order: shownOrder)
          }
          .buttonStyle(.plain)
          .modifier(SymbolsGrid.Cell(column: column))
        }
      }
      .frame(minHeight: SymbolsGrid.headerHeight)
      .padding(.horizontal, Tokens.Space.xs)
      .overlay(alignment: .bottom) { Rectangle().fill(Palette.separator).frame(height: Tokens.Stroke.thin) }
      ScrollViewReader { proxy in
        ScrollView(.vertical) {
          LazyVStack(alignment: .leading, spacing: 0) {
            if loading {
              // Rows in the table's own column grid (mockup v102).
              Skeleton(L10n.Common.loading) {
                VStack(alignment: .leading, spacing: 0) {
                  ForEach(0..<SymbolsSkeleton.rows, id: \.self) { index in
                    SymbolsSkeleton.row(index, fastMovers: fastMovers)
                  }
                }
              }
            }
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, line in
              Button {
                selected = line.symbol
              } label: {
                SymbolsGrid(line: line, fastMovers: fastMovers, zebra: !index.isMultiple(of: SymbolsGrid.stripeEvery),
                  selected: line.symbol == current)
              }
              .buttonStyle(.plain)
              .id(line.symbol)
            }
            if shown.isEmpty && !loading {
              Footnote(verbatim: emptyText)
                .padding(Tokens.Space.m)
            }
          }
          // One list per tab: rows of one tab never stay on screen under another tab's columns.
          .id(tab)
        }
        .scrollEdgeHints()
        .scrollBounceBehavior(.basedOnSize)
        .focusable()
        .focusEffectDisabled()
        #if os(macOS)
        .onMoveCommand { direction in
          guard let moved = SymbolsGrid.step(shown, from: current, direction) else { return }
          selected = moved
          withAnimation(Tokens.Motion.quick) { proxy.scrollTo(moved) }
        }
        #endif
      }
      Rectangle().fill(Palette.separator).frame(height: Tokens.Stroke.thin)
      HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.m) {
        // Fast movers: the flagged symbols, and apart from them the open positions and waiting
        // symbols pinned on top, so the tab's count and this line agree (owner test 2026-11-18:
        // 74 vs 79).
        let pinned = tab == .fastMovers ? shown.filter { $0.mover == nil }.count : 0
        Text(pinned > 0 ? L10n.Symbols.showingMovers(shown.count - pinned, pinned) : L10n.Symbols.showingAll(shown.count))
        Spacer(minLength: 0)
        Text(SymbolsText.sortHint)
      }
      .font(Tokens.Typography.annotation)
      .foregroundStyle(Palette.textQuaternary)
      .padding(.horizontal, Tokens.Space.m)
      .padding(.vertical, Tokens.Space.s)
    }
    .tickrCard(radius: Tokens.Radius.large)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(Text(L10n.Symbols.listLabel))
  }

  /// Whether the shown tab's rows are being read: none yet and no failure.
  private var loading: Bool {
    tab == .fastMovers ? model.movers == nil && model.moversError == nil
      : model.symbols == nil && model.symbolsError == nil
  }

  private var emptyText: String {
    if !search.trimmingCharacters(in: .whitespaces).isEmpty {
      return String(localized: L10n.Symbols.noMatch(search))
    }
    if tab == .fastMovers {
      return model.moversError.map { String(localized: L10n.Symbols.unavailable($0)) }
        ?? String(localized: L10n.Symbols.noMovers)
    }
    return model.symbolsError.map { String(localized: L10n.Symbols.unavailable($0)) }
      ?? model.symbols?.asOfCause ?? String(localized: L10n.Symbols.noneHere)
  }

  // MARK: detail

  @ViewBuilder private var detail: some View {
    let shown = lines
    let symbol = selected ?? shown.first?.symbol
    if loading {
      SymbolsSkeleton.detail
    } else if let symbol {
      let line = shown.first { $0.symbol == symbol }
        ?? SymbolsLine(symbol: symbol, row: model.symbols?.rows.first { $0.symbol == symbol },
          mover: model.movers?.movers.first { $0.symbol == symbol },
          position: model.positions.contains { $0.id == symbol })
      SymbolsDetailPanel(line: line)
    } else {
      Footnote(L10n.Symbols.selectHint)
        .padding(Tokens.Space.l)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .tickrCard(radius: Tokens.Radius.large)
    }
  }
}

// MARK: - loading

/// The Symbols screen while its rows load (mockup v102): skeleton rows in the table's own column
/// grid (`SymbolsGrid`), and a skeleton of the detail panel.
@MainActor
private enum SymbolsSkeleton {
  /// Skeleton rows in the table, as the board's.
  static let rows = 18
  /// Widths of the blocks that differ row to row, in points, repeating: the symbol and the
  /// outcome's words.
  static let symbols: [CGFloat] = [44, 38, 50, 42, 36, 48]
  static let outcomes: [CGFloat] = [120, 90, 140, 104, 80, 128]
  /// Fixed blocks of a row, in points: a figure, the stage track (and its height) with the
  /// stage's name, the outcome's pill.
  static let figure: CGFloat = 28
  static let track: CGFloat = 57
  static let trackHeight: CGFloat = 10
  static let stage: CGFloat = 52
  static let outcomePill: CGFloat = 64
  /// The detail panel's blocks, in points: the symbol and its badge, the price, the screeners'
  /// line, the sparkline, the headline's word and caption, and the steps' title.
  static let detailSymbol: CGFloat = 72
  static let detailSymbolHeight: CGFloat = 20
  static let detailBadge: CGFloat = 62
  static let detailPrice: CGFloat = 120
  static let detailPriceHeight: CGFloat = 22
  static let sparklineHeight: CGFloat = 40
  static let foundBy: CGFloat = 220
  static let headlineWord: CGFloat = 90
  static let headlineWordHeight: CGFloat = 18
  static let detailOutcome: CGFloat = 170
  static let stepsTitle: CGFloat = 120

  /// One skeleton row: a block in every column of the grid, as tall as a line.
  static func row(_ index: Int, fastMovers: Bool) -> some View {
    HStack(spacing: 0) {
      ForEach(SymbolsColumn.table(fastMovers: fastMovers)) { column in
        cell(column, index).modifier(SymbolsGrid.Cell(column: column))
      }
    }
    .padding(.horizontal, Tokens.Space.xs)
    .padding(.vertical, Tokens.Space.xs)
    .frame(maxWidth: .infinity, minHeight: SymbolsGrid.rowHeight, alignment: .leading)
    .overlay(alignment: .bottom) { SkeletonGridLine() }
  }

  @ViewBuilder private static func cell(_ column: SymbolsColumn, _ index: Int) -> some View {
    let pick = { (widths: [CGFloat]) in widths[index % widths.count] }
    switch column {
    case .symbol: SkeletonBlock(.line, width: pick(symbols))
    case .stage:
      HStack(spacing: Tokens.Space.xs) {
        SkeletonBlock(.block(height: trackHeight), width: track)
        SkeletonBlock(.line, width: stage)
      }
    case .outcome:
      HStack(spacing: Tokens.Space.xs) {
        SkeletonBlock(.pill, width: outcomePill)
        SkeletonBlock(.line, width: pick(outcomes))
      }
    case .last, .change, .volume, .atr, .dollars, .screener, .time: SkeletonBlock(.line, width: figure)
    }
  }

  /// The detail panel's skeleton, in the panel's own frame.
  static var detail: some View {
    Skeleton(nil) {
      VStack(alignment: .leading, spacing: Tokens.Space.m) {
        HStack(spacing: Tokens.Space.s) {
          SkeletonBlock(.block(height: detailSymbolHeight), width: detailSymbol)
          SkeletonBlock(.pill, width: detailBadge)
        }
        SkeletonBlock(.block(height: detailPriceHeight), width: detailPrice)
        SkeletonBlock(.line, width: foundBy)
        SkeletonBlock(.block(height: sparklineHeight))
        SkeletonBlock(.block(height: headlineWordHeight), width: headlineWord)
        SkeletonBlock(.line, width: detailOutcome)
        SkeletonBlock(.line, width: stepsTitle)
        Spacer(minLength: 0)
      }
    }
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .tickrCard(radius: Tokens.Radius.large)
  }
}

// MARK: - table row

/// One line of the table in the design's column grid (mockup v101): every tab and every kind of
/// line uses the same columns, an empty cell reads "—" and nothing moves into another column.
/// Zebra rows, a blue bar on the selected one; a long reason makes the row taller, never cut.
private struct SymbolsGrid: View {
  @Environment(AppModel.self) private var model
  let line: SymbolsLine
  let fastMovers: Bool
  let zebra: Bool
  let selected: Bool

  /// The design's column widths, in points; the outcome takes the rest.
  static let symbolWidth: CGFloat = 130
  static let lastWidth: CGFloat = 66
  static let changeWidth: CGFloat = 80
  /// Wide enough for the widest figure on its bold capsule ("40.1×", "-21.2", "51.8×").
  static let volumeWidth: CGFloat = 60
  static let atrWidth: CGFloat = 60
  static let dollarsWidth: CGFloat = 64
  static let stageWidth: CGFloat = 142
  /// The time column is as wide as its clock ("09:32:01") in the lines' font, never a set width:
  /// a time on two lines read "09:32" over ":01" (owner, 2026-11-23).
  static let timeShapes = FigureShapes.shapes([ClockText.seconds(.distantPast)])
  /// Every second line is striped.
  static let stripeEvery = 2

  static func width(_ column: SymbolsColumn) -> CGFloat? {
    switch column {
    case .symbol: symbolWidth
    case .last: lastWidth
    case .change: changeWidth
    case .volume: volumeWidth
    case .atr: atrWidth
    case .dollars: dollarsWidth
    case .stage: stageWidth
    case .screener, .outcome, .time: nil
    }
  }

  /// Heights of the title row and the least height of a line, in points (the design's).
  static let headerHeight: CGFloat = 30
  static let rowHeight: CGFloat = 32
  /// Opacity of the zebra stripe (the design's 2.2 %).
  static let zebraOpacity = 0.022

  /// A column's frame: its width, the clock's for the time, or the rest for the outcome, figures
  /// to the right.
  struct Cell: ViewModifier {
    let column: SymbolsColumn

    func body(content: Content) -> some View {
      let alignment: Alignment = column.isFigure ? .trailing : .leading
      if column == .time {
        // The clock's room in the lines' font under the title and every line alike.
        ZStack(alignment: alignment) {
          SteadyFigure("", shapes: SymbolsGrid.timeShapes)
            .font(Tokens.Typography.captionMono)
            .hidden()
          content
        }
        .fixedSize()
        .padding(.horizontal, Tokens.Space.s)
      } else if let width = SymbolsGrid.width(column) {
        content.padding(.horizontal, Tokens.Space.s).frame(width: width, alignment: alignment)
      } else {
        content.padding(.horizontal, Tokens.Space.s).frame(maxWidth: .infinity, alignment: alignment)
      }
    }
  }

  #if os(macOS)
  /// The symbol after or before `current` for an arrow key; nil at an end.
  static func step(_ lines: [SymbolsLine], from current: String?, _ direction: MoveCommandDirection) -> String? {
    guard let index = lines.firstIndex(where: { $0.symbol == current }) else { return lines.first?.symbol }
    switch direction {
    case .down: return lines.indices.contains(index + 1) ? lines[index + 1].symbol : nil
    case .up: return index > 0 ? lines[index - 1].symbol : nil
    default: return nil
    }
  }
  #endif

  var body: some View {
    HStack(spacing: 0) {
      ForEach(SymbolsColumn.table(fastMovers: fastMovers)) { column in
        cell(column).modifier(Cell(column: column))
      }
    }
    .font(Tokens.Typography.captionMono)
    .foregroundStyle(Palette.textSecondary)
    .padding(.horizontal, Tokens.Space.xs)
    .padding(.vertical, Tokens.Space.xs)
    .frame(maxWidth: .infinity, minHeight: Self.rowHeight, alignment: .leading)
    .background(selected ? Palette.selection : zebra ? Palette.textPrimary.opacity(Self.zebraOpacity) : .clear)
    .overlay(alignment: .leading) {
      if selected { Rectangle().fill(Palette.info).frame(width: Tokens.Stroke.bold) }
    }
    .overlay(alignment: .bottom) { Rectangle().fill(Palette.separator).frame(height: Tokens.Stroke.hairline) }
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  /// The line's price and change: live where the bot's quotes hold the symbol.
  private var shown: SymbolsPrice { SymbolsBoard.shown(line, live: model.livePrice(line.symbol)) }

  @ViewBuilder private func cell(_ column: SymbolsColumn) -> some View {
    let row = line.row
    let mover = line.mover
    switch column {
    case .symbol:
      HStack(spacing: Tokens.Space.s) {
        SymbolText(line.symbol)
          .font(Tokens.Typography.symbolCompact.monospaced())
          .fontWeight(.bold)
          .foregroundStyle(Palette.textPrimary)
        SymbolsLineBadge(line: line)
      }
    case .last:
      figure(shown.price.map { Money.price($0) })
    case .change:
      figure(SymbolsBoard.tableChange(shown.changePct), color: (shown.changePct ?? 0) < 0
        ? Palette.droppedText : Palette.profitText)
    case .volume:
      mover.map { MoverFigure(text: SymbolsBoard.ratio($0.volumeRatio), fired: $0.fired(.volume)) }
        ?? MoverFigure(text: Format.missing, fired: false)
    case .atr:
      mover.map { MoverFigure(text: SymbolsBoard.atr($0.moveAtr), fired: $0.fired(.move)) }
        ?? MoverFigure(text: Format.missing, fired: false)
    case .dollars:
      mover.map { MoverFigure(text: SymbolsBoard.ratio($0.dollarVolumeRatio), fired: $0.fired(.dollars)) }
        ?? MoverFigure(text: Format.missing, fired: false)
    case .screener:
      // Not a column of the table: the screeners are in the selected symbol's detail.
      dash
    case .stage:
      if let row {
        StageTrack(colors: row.trackColors, title: row.furthest.title)
      } else {
        dash
      }
    case .outcome:
      if let row {
        HStack(alignment: .center, spacing: Tokens.Space.s) {
          SymbolsOutcomeBadge.slot(SymbolsOutcome(row))
          if let why = SymbolsBoard.shortWhy(row) {
            Text(verbatim: why)
              .foregroundStyle(Palette.textSecondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      } else {
        dash
      }
    case .time:
      figure(Format.marketTime(fastMovers ? mover?.at.date : row?.firstSeen?.date), color: Palette.textQuaternary)
    }
  }

  private func figure(_ text: String?, color: Color = Palette.textSecondary) -> some View {
    Text(verbatim: text ?? Format.missing)
      .monospacedDigit()
      .foregroundStyle(text == nil ? Palette.textQuaternary : color)
  }

  private var dash: some View {
    Text(verbatim: Format.missing).foregroundStyle(Palette.textQuaternary)
  }
}

/// A column's title: a button that sorts by it; the sorted one shows ▲ or ▼ in blue.
private struct SymbolsColumnTitle: View {
  let column: SymbolsColumn
  let fastMovers: Bool
  let order: SymbolsOrder

  var body: some View {
    let sorted = order.column == column
    HStack(spacing: Tokens.Space.xxs) {
      Text(column.title(fastMovers: fastMovers))
        .textCase(.uppercase)
        .font(Tokens.Typography.label)
        .tracking(Tokens.Typography.labelTracking)
        .foregroundStyle(sorted ? Palette.textPrimary : Palette.textQuaternary)
        .fixedSize(horizontal: false, vertical: true)
      if sorted {
        Image(systemName: order.ascending ? Self.ascending : Self.descending)
          .font(Tokens.Typography.chevron)
          .foregroundStyle(Palette.infoText)
      }
    }
    .contentShape(Rectangle())
    .accessibilityAddTraits(sorted ? [.isSelected, .isButton] : .isButton)
  }

  /// SF Symbols of the sort direction.
  static let ascending = "arrowtriangle.up.fill"
  static let descending = "arrowtriangle.down.fill"
}

/// The OPEN badge (teal) beside a symbol with an open position.
private struct SymbolsLineBadge: View {
  let line: SymbolsLine

  var body: some View {
    if line.position {
      Badge(SymbolsText.position, color: Palette.accentText)
    }
  }
}

/// The fast mover rule behind an "i" button beside the Fast movers caption (mockup MacSymbols):
/// a real popover with the rule in one sentence.
private struct FastRuleButton: View {
  let rule: String
  @State private var open = false

  var body: some View {
    Button { open = true } label: {
      Image(systemName: InfoCaption.infoSymbol)
        .font(Tokens.Typography.caption)
        .foregroundStyle(Palette.textTertiary)
        .frame(minWidth: Tokens.Size.headerLink, minHeight: Tokens.Size.headerLink)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .pointerStyle(.link)
    .help(Text(SymbolsText.fastRuleLabel))
    .accessibilityLabel(Text(SymbolsText.fastRuleLabel))
    .popover(isPresented: $open, arrowEdge: .bottom) {
      VStack(alignment: .leading, spacing: Tokens.Space.s) {
        CardLabel(SymbolsText.fastRuleLabel)
        Text(verbatim: rule)
          .font(Tokens.Typography.callout)
          .foregroundStyle(Palette.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(Tokens.Space.l)
      .frame(idealWidth: Tokens.Size.popover, maxWidth: Tokens.Size.popover, alignment: .leading)
      .background(Palette.surface)
    }
  }
}

/// ENTERED green, WAITING blue; SKIPPED, DROPPED and NOT REACHED neutral (mockup MacSymbols).
private struct SymbolsOutcomeBadge: View {
  let outcome: SymbolsOutcome

  var body: some View { Badge(outcome.title, color: outcome.color) }

  /// The badge in a slot as wide as the widest outcome badge in the shown language, so the words
  /// after it line up on every line and never run under a long badge ("NOT REACHED", "NO ALCANZADO").
  static func slot(_ outcome: SymbolsOutcome) -> some View {
    ZStack(alignment: .leading) {
      ForEach(SymbolsOutcome.allCases, id: \.self) { SymbolsOutcomeBadge(outcome: $0).hidden() }
      SymbolsOutcomeBadge(outcome: outcome)
    }
    .fixedSize()
  }
}

// MARK: - detail

/// The selected symbol (mockup MacSymbols, 300 pt, as tall as its content): the symbol, its price
/// and change, the screeners that found it and when, today's line, what happened in one word and
/// one caption, its fast bar's signals, every stage of its steps today with the time and the
/// measured value behind a disclosure, and links to its chart and days.
private struct SymbolsDetailPanel: View {
  @Environment(AppModel.self) private var model
  @AppStorage(ChartView.Keys.symbol) private var chartSymbol = ""
  /// Today's price line, kept while the same symbol's line is read again.
  @State private var dayLine: SymbolDayLine?
  @State private var shownLineSymbol: String?
  /// The steps today are open.
  @State private var showsSteps = false
  let line: SymbolsLine

  /// SF Symbols of the chart link, the fast mover's bolt and the path steps.
  static let chartSymbol = "chart.xyaxis.line"
  static let fastSymbol = "bolt.fill"
  static let passedSymbol = "checkmark"
  static let droppedSymbol = "xmark"
  static let waitingSymbol = "clock"
  static let aheadSymbol = "minus"

  /// The line's price and change: live where the bot's quotes hold the symbol.
  private var shown: SymbolsPrice { SymbolsBoard.shown(line, live: model.livePrice(line.symbol)) }

  var body: some View {
    let row = line.row
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      VStack(alignment: .leading, spacing: Tokens.Space.xs) {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
          SymbolText(line.symbol)
            .font(Tokens.Typography.quote)
            .fontWeight(.bold)
            .foregroundStyle(Palette.textPrimary)
          SymbolsLineBadge(line: line)
          Spacer(minLength: Tokens.Space.s)
          Text(verbatim: shown.price.map { Money.price($0) } ?? Format.missing)
            .font(Tokens.Typography.figure)
            .foregroundStyle(Palette.textPrimary)
          if let change = SymbolsBoard.tableChange(shown.changePct) {
            Text(verbatim: change)
              .font(Tokens.Typography.captionMono)
              .fontWeight(.semibold)
              .foregroundStyle((shown.changePct ?? 0) < 0 ? Palette.droppedText : Palette.profitText)
          }
        }
        if let found = foundBy(row) {
          Text(verbatim: found)
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textQuaternary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .task(id: line) { await readDayLine() }
      if let dayLine {
        let plotted = dayLine.plotted
        DayLine(closes: plotted.closes, previousClose: plotted.previousClose)
      }
      if let row {
        let headline = SymbolsBoard.headline(row)
        SymbolHeadline(headline.title, caption: headline.caption, color: SymbolsOutcome(row).headlineColor)
      }
      if let mover = line.mover {
        Label {
          Text(verbatim: SymbolsBoard.fastNote(mover, time: Format.marketTime(mover.at.date)))
            .fixedSize(horizontal: false, vertical: true)
        } icon: {
          Image(systemName: Self.fastSymbol)
        }
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.warningText)
      }
      if let row {
        DetailDisclosure(SymbolsText.stepsToday,
          summary: String(localized: SymbolsText.stepsPassed(SymbolsBoard.stepsPassed(row), SymbolStage.allCases.count)),
          isOpen: $showsSteps) {
          VStack(alignment: .leading, spacing: 0) {
            ForEach(SymbolsBoard.path(row)) { step in pathStep(step, row: row) }
          }
        }
        .padding(.top, Tokens.Space.s)
        .overlay(alignment: .top) { Rectangle().fill(Palette.separator).frame(height: Tokens.Stroke.thin) }
      }
      ChipFlow(spacing: Tokens.Space.s) {
        HeaderLink(L10n.Symbols.openChart, systemImage: Self.chartSymbol) {
          chartSymbol = line.symbol
          model.section = .chart
        }
        HeaderLink(L10n.Symbols.tradesAndDays) { model.section = .trades }
      }
      .padding(.top, Tokens.Space.s)
      .overlay(alignment: .top) { Rectangle().fill(Palette.separator).frame(height: Tokens.Stroke.thin) }
    }
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .tickrCard(radius: Tokens.Radius.large)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(Text(L10n.Symbols.detailLabel))
  }

  /// "Found by Top gainers #3, Most active #7 · first seen 09:41"; only the time without a
  /// screener; nil without either.
  private func foundBy(_ row: SymbolRowV1?) -> String? {
    guard let row, let seen = row.firstSeen?.date else { return nil }
    let time = Format.marketTime(seen)
    guard let screeners = SymbolsBoard.foundBy(row) else { return String(localized: SymbolsText.seen(time)) }
    return String(localized: SymbolsText.foundBy(screeners, time))
  }

  /// Reads the line again whenever the row changes; another symbol's line never stays shown.
  private func readDayLine() async {
    let symbol = line.symbol
    let previous = SymbolDayLine.previousClose(price: SymbolsBoard.price(line), changePct: line.row?.changePct)
    if shownLineSymbol != symbol { dayLine = nil }
    let read = await model.symbolDayLine(symbol, previousClose: previous)
    guard !Task.isCancelled, line.symbol == symbol else { return }
    dayLine = read
    shownLineSymbol = symbol
  }

  private func pathStep(_ step: SymbolsBoard.Step, row: SymbolRowV1) -> some View {
    let reachedAt = SymbolsBoard.time(step, row: row)
    let (glyph, color): (String, Color) = switch step.mark {
    case .passed, .here(.passed): (Self.passedSymbol, Palette.profitText)
    case .here(.dropped): (Self.droppedSymbol, Palette.textTertiary)
    case .here(.waiting): (Self.waitingSymbol, Palette.infoText)
    case .here(.notReached): (Self.waitingSymbol, Palette.warningText)
    case .ahead: (Self.aheadSymbol, Palette.textQuaternary)
    }
    let detail = step.mark == .ahead ? String(localized: SymbolsText.stepNotReached) : step.detail
    let detailColor = switch step.mark {
    case .passed, .here(.passed): Palette.textTertiary
    case .ahead: Palette.textQuaternary
    case .here: color
    }
    return SymbolPathStep(systemImage: glyph, color: color, title: step.stage.title,
      time: step.mark == .ahead ? Format.missing : Format.marketTime(reachedAt), detail: detail,
      detailColor: detailColor, reached: step.mark != .ahead)
  }
}

// MARK: - colours and glyphs

extension SymbolRowV1 {
  /// One segment per stage (mockup MacSymbols): passed teal, where it stands blue when waiting,
  /// neutral when dropped and amber when not reached, a hairline where it never got.
  var trackColors: [Color] {
    SymbolStage.allCases.map { stage in
      if stage == self.stage {
        switch state {
        case .passed: return Palette.accent
        case .waiting: return Palette.info
        case .dropped: return Palette.textTertiary
        case .notReached: return Palette.warning
        }
      }
      return stage.order < self.stage.order || stage.order <= furthest.order ? Palette.accent : Palette.separatorStrong
    }
  }
}

extension SymbolsOutcome {
  /// ENTERED green, WAITING blue; SKIPPED, DROPPED and NOT REACHED neutral (mockup MacSymbols).
  var color: Color {
    switch self {
    case .passed: Palette.profitText
    case .waiting: Palette.infoText
    case .skipped, .dropped, .notReached: Palette.textTertiary
    }
  }

  /// The detail headline's colour: green or blue as the badge, the text's own colour otherwise.
  var headlineColor: Color {
    switch self {
    case .passed, .waiting: color
    case .skipped, .dropped, .notReached: Palette.textPrimary
    }
  }
}

extension SymbolsTab {
  /// The Fast movers tab's bolt.
  static let fastMoversSymbol = "bolt.fill"
}
