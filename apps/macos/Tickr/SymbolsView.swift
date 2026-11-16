import SwiftUI
import TickrDesign
import TickrKit

// The Symbols screen behind the Overview funnel (mockup v101, MacSymbols): every symbol of the
// shown day in one column grid, by the funnel stage it got to, with why each one stopped, and the
// fast movers. A funnel stage or the fast movers' "Show all" opens it on that tab; "Overview" or
// Esc goes back. A click on a column's title sorts by it. The rows are the full list, never
// capped; the list scrolls, and no text is cut.

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
          .scrollBounceBehavior(.basedOnSize)
          .frame(width: Self.detailWidth)
      }
      .frame(maxHeight: .infinity, alignment: .top)
    }
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .accessibilityIdentifier(Self.id)
    // Esc goes back to the Overview, as the back capsule does.
    .onExitCommand { close() }
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
      } else {
        Text(verbatim: moverRules)
          .font(Tokens.Typography.captionMono)
          .foregroundStyle(Palette.textQuaternary)
          .fixedSize(horizontal: false, vertical: true)
      }
      TextField(text: $search, prompt: Text(L10n.Symbols.search)) { Text(L10n.Symbols.search) }
        .textFieldStyle(.roundedBorder)
        .frame(width: Self.searchWidth)
    }
  }

  /// "Mon Nov 16 · 10:48 ET · 412 screened": the day, the end of the latest discovery pass and how
  /// many symbols the screeners listed; the bot's cause when no pass is recorded.
  private var context: String {
    let day = DayText.day(model.shownDay)
    guard let symbols = model.symbols else {
      return [day, model.symbolsError.map { String(localized: L10n.Symbols.unavailable($0)) }]
        .compactMap { $0 }.joined(separator: Format.itemSeparator)
    }
    guard let asOf = symbols.asOf?.date else {
      return [day, symbols.asOfCause].compactMap { $0 }.joined(separator: Format.itemSeparator)
    }
    let screened = SymbolsBoard.count(.stage(.screeners), symbols: symbols, movers: model.movers) ?? 0
    return String(localized: L10n.Symbols.context(day, Format.marketTime(asOf), screened))
  }

  /// The active strategy's fast mover thresholds, or why there are none.
  private var moverRules: String {
    guard let movers = model.movers else {
      return model.moversError.map { String(localized: L10n.Symbols.unavailable($0)) } ?? Format.missing
    }
    return movers.rules.map(SymbolsBoard.rules) ?? movers.rulesCause ?? Format.missing
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
        ForEach(SymbolsColumn.allCases) { column in
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
            if shown.isEmpty {
              Footnote(verbatim: emptyText)
                .padding(Tokens.Space.m)
            }
          }
          // One list per tab: rows of one tab never stay on screen under another tab's columns.
          .id(tab)
        }
        .scrollBounceBehavior(.basedOnSize)
        .focusable()
        .focusEffectDisabled()
        .onMoveCommand { direction in
          guard let moved = SymbolsGrid.step(shown, from: current, direction) else { return }
          selected = moved
          withAnimation(Tokens.Motion.quick) { proxy.scrollTo(moved) }
        }
      }
      Rectangle().fill(Palette.separator).frame(height: Tokens.Stroke.thin)
      HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.m) {
        Text(L10n.Symbols.showingAll(shown.count))
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
    if let symbol {
      let line = shown.first { $0.symbol == symbol }
        ?? SymbolsLine(symbol: symbol, row: model.symbols?.rows.first { $0.symbol == symbol },
          mover: model.movers?.movers.first { $0.symbol == symbol },
          position: model.positions.contains { $0.id == symbol })
      SymbolsDetailPanel(line: line, rules: model.movers?.rules)
    } else {
      Footnote(L10n.Symbols.selectHint)
        .padding(Tokens.Space.l)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .tickrCard(radius: Tokens.Radius.large)
    }
  }
}

// MARK: - table row

/// One line of the table in the design's column grid (mockup v101): every tab and every kind of
/// line uses the same columns, an empty cell reads "—" and nothing moves into another column.
/// Zebra rows, a blue bar on the selected one; a long reason makes the row taller, never cut.
private struct SymbolsGrid: View {
  let line: SymbolsLine
  let fastMovers: Bool
  let zebra: Bool
  let selected: Bool

  /// The design's column widths, in points; the outcome takes the rest.
  static let symbolWidth: CGFloat = 130
  static let lastWidth: CGFloat = 66
  static let changeWidth: CGFloat = 80
  static let volumeWidth: CGFloat = 48
  static let atrWidth: CGFloat = 50
  static let dollarsWidth: CGFloat = 56
  static let screenerWidth: CGFloat = 120
  static let stageWidth: CGFloat = 142
  static let timeWidth: CGFloat = 50
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
    case .screener: screenerWidth
    case .stage: stageWidth
    case .outcome: nil
    case .time: timeWidth
    }
  }

  /// Heights of the title row and the least height of a line, in points (the design's).
  static let headerHeight: CGFloat = 30
  static let rowHeight: CGFloat = 32
  /// Width of the outcome badge's slot, in points (the design's).
  static let badgeSlot: CGFloat = 72
  /// Opacity of the zebra stripe (the design's 2.2 %).
  static let zebraOpacity = 0.022

  /// A column's frame: its width, or the rest for the outcome, figures to the right.
  struct Cell: ViewModifier {
    let column: SymbolsColumn

    func body(content: Content) -> some View {
      let alignment: Alignment = column.isFigure ? .trailing : .leading
      if let width = SymbolsGrid.width(column) {
        content.padding(.horizontal, Tokens.Space.s).frame(width: width, alignment: alignment)
      } else {
        content.padding(.horizontal, Tokens.Space.s).frame(maxWidth: .infinity, alignment: alignment)
      }
    }
  }

  /// The symbol after or before `current` for an arrow key; nil at an end.
  static func step(_ lines: [SymbolsLine], from current: String?, _ direction: MoveCommandDirection) -> String? {
    guard let index = lines.firstIndex(where: { $0.symbol == current }) else { return lines.first?.symbol }
    switch direction {
    case .down: return lines.indices.contains(index + 1) ? lines[index + 1].symbol : nil
    case .up: return index > 0 ? lines[index - 1].symbol : nil
    default: return nil
    }
  }

  var body: some View {
    HStack(spacing: 0) {
      ForEach(SymbolsColumn.allCases) { column in
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

  @ViewBuilder private func cell(_ column: SymbolsColumn) -> some View {
    let row = line.row
    let mover = line.mover
    switch column {
    case .symbol:
      HStack(spacing: Tokens.Space.s) {
        Text(verbatim: line.symbol)
          .font(Tokens.Typography.symbolCompact.monospaced())
          .fontWeight(.bold)
          .foregroundStyle(Palette.textPrimary)
        SymbolsLineBadge(line: line)
      }
    case .last:
      figure(SymbolsBoard.price(line).map { Money.price($0.value) })
    case .change:
      figure(SymbolsBoard.tableChange(row?.changePct), color: row?.changePct?.isNegative == true
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
      if let screener = SymbolsBoard.screenerCell(row) {
        HStack(spacing: Tokens.Space.xs) {
          SourceChips([SourceChips.Item(text: screener.chip, change: nil, changeColor: Palette.textSecondary)])
          if let more = screener.more {
            Text(verbatim: more).font(Tokens.Typography.annotationBold).foregroundStyle(Palette.textQuaternary)
          }
        }
      } else {
        dash
      }
    case .stage:
      if let row {
        StageTrack(colors: row.trackColors, title: row.furthest.title)
      } else {
        dash
      }
    case .outcome:
      if let row {
        HStack(alignment: .center, spacing: Tokens.Space.s) {
          SymbolsOutcomeBadge(outcome: SymbolsOutcome(row.state))
            .frame(width: Self.badgeSlot, alignment: .leading)
          if let why = SymbolsBoard.why(row) {
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

/// The POSITION (teal) or WATCH (blue) badge beside a symbol.
private struct SymbolsLineBadge: View {
  let line: SymbolsLine

  var body: some View {
    if line.position {
      Badge(SymbolsText.position, color: Palette.accentText)
    } else if line.watching {
      Badge(Verdict.watch.title, color: Palette.infoText)
    }
  }
}

/// PASSED green, WAITING blue, DROPPED pink, NOT REACHED grey.
private struct SymbolsOutcomeBadge: View {
  let outcome: SymbolsOutcome

  var body: some View { Badge(outcome.title, color: outcome.color) }
}

// MARK: - detail

/// The selected symbol (mockup v101's detail, 300 pt, as tall as its content): the symbol, its
/// price and change, the outcome and why, its fast bar against the thresholds, every stage of its
/// path today with the time it got there, its screeners, the strategy's last decision with its
/// checks, and links to its chart and days.
private struct SymbolsDetailPanel: View {
  @Environment(AppModel.self) private var model
  @AppStorage(ChartView.Keys.symbol) private var chartSymbol = ""
  let line: SymbolsLine
  let rules: FastMoverRulesV1?

  /// SF Symbols of the chart link and the path steps.
  static let chartSymbol = "chart.xyaxis.line"
  static let passedSymbol = "checkmark"
  static let droppedSymbol = "xmark"
  static let waitingSymbol = "clock"
  static let aheadSymbol = "minus"

  var body: some View {
    let row = line.row
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
        Text(verbatim: line.symbol)
          .font(Tokens.Typography.quote)
          .fontWeight(.bold)
          .foregroundStyle(Palette.textPrimary)
        SymbolsLineBadge(line: line)
        Spacer(minLength: Tokens.Space.s)
        if let seen = row?.firstSeen?.date {
          Text(SymbolsText.seen(Format.marketTime(seen)))
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textQuaternary)
        }
      }
      HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
        Text(verbatim: SymbolsBoard.price(line).map { Money.price($0.value) } ?? Format.missing)
          .font(Tokens.Typography.metric)
          .foregroundStyle(Palette.textPrimary)
        if let change = SymbolsBoard.tableChange(row?.changePct) {
          Text(verbatim: change)
            .font(Tokens.Typography.captionMono)
            .fontWeight(.semibold)
            .foregroundStyle(row?.changePct?.isNegative == true ? Palette.droppedText : Palette.profitText)
        }
        Spacer(minLength: Tokens.Space.s)
        Text(SymbolsText.today)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      }
      if let row { outcome(row) }
      section(SymbolsText.fastMover,
        note: line.mover.map { String(localized: SymbolsText.flagged(Format.marketTime($0.at.date))) }
          ?? String(localized: SymbolsText.notFlagged))
      if let mover = line.mover { stats(mover) }
      if let row {
        section(L10n.Symbols.pathToday, note: nil)
        VStack(alignment: .leading, spacing: 0) {
          ForEach(SymbolsBoard.path(row)) { step in pathStep(step, row: row) }
        }
        if !row.sources.isEmpty {
          section(SymbolsText.screeners, note: nil)
          VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
            ForEach(row.sources, id: \.kind) { source in
              HStack {
                Text(verbatim: SymbolsBoard.screenerName(source)).foregroundStyle(Palette.textSecondary)
                Spacer(minLength: Tokens.Space.s)
                Text(SymbolsText.rank(source.rank)).foregroundStyle(Palette.textTertiary)
              }
              .font(Tokens.Typography.captionMono)
            }
          }
        }
        section(SymbolsText.lastDecision, note: nil)
        decision(row)
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

  /// The outcome badge, then "at Strategy · Close above VWAP 5.12 >= 5.20" or "reached Stop".
  private func outcome(_ row: SymbolRowV1) -> some View {
    let stage = String(localized: row.stage.title)
    let place = String(localized: row.state == .passed ? SymbolsText.reachedStage(stage) : SymbolsText.atStage(stage))
    let text = [place, SymbolsBoard.why(row)].compactMap { $0 }.joined(separator: Format.itemSeparator)
    return HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
      SymbolsOutcomeBadge(outcome: SymbolsOutcome(row.state))
      Text(verbatim: text)
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(Palette.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  /// A section's label with an optional note on the right, under a line.
  private func section(_ title: LocalizedStringResource, note: String?) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text(title)
        .textCase(.uppercase)
        .font(Tokens.Typography.label)
        .tracking(Tokens.Typography.labelTracking)
        .foregroundStyle(Palette.textQuaternary)
      Spacer(minLength: Tokens.Space.s)
      if let note {
        Text(verbatim: note)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      }
    }
    .padding(.top, Tokens.Space.s)
    .overlay(alignment: .top) { Rectangle().fill(Palette.separator).frame(height: Tokens.Stroke.thin) }
  }

  /// The three fast mover figures, each against its threshold.
  private func stats(_ mover: FastMoverV1) -> some View {
    HStack(alignment: .top, spacing: Tokens.Space.s) {
      MoverStat(SymbolsText.statVolume, value: SymbolsBoard.ratio(mover.volumeRatio),
        note: note(mover.fired(.volume), rules?.minVolumeRatio, ratio: true), met: mover.fired(.volume))
      MoverStat(SymbolsText.statMove, value: SymbolsBoard.atr(mover.moveAtr),
        note: note(mover.fired(.move), rules?.minMoveAtr, ratio: false), met: mover.fired(.move))
      MoverStat(SymbolsText.statDollars, value: SymbolsBoard.ratio(mover.dollarVolumeRatio),
        note: note(mover.fired(.dollars), rules?.minDollarVolumeRatio, ratio: true), met: mover.fired(.dollars))
    }
  }

  private func note(_ fired: Bool, _ threshold: DecimalString?, ratio: Bool) -> String {
    threshold.map { SymbolsBoard.moverNote(fired: fired, threshold: $0, ratio: ratio) } ?? Format.missing
  }

  private func pathStep(_ step: SymbolsBoard.Step, row: SymbolRowV1) -> some View {
    let reachedAt = row.reached.first { $0.stage == step.stage }?.at?.date
    let (glyph, color): (String, Color) = switch step.mark {
    case .passed, .here(.passed): (Self.passedSymbol, Palette.profitText)
    case .here(.dropped): (Self.droppedSymbol, Palette.droppedText)
    case .here(.waiting): (Self.waitingSymbol, Palette.infoText)
    case .here(.notReached): (Self.waitingSymbol, Palette.warningText)
    case .ahead: (Self.aheadSymbol, Palette.textQuaternary)
    }
    let detail: String? = switch step.mark {
    case .here(.dropped), .here(.waiting), .here(.notReached): SymbolsBoard.why(row)
    case .ahead: String(localized: SymbolsText.stepNotReached)
    case .passed, .here(.passed): nil
    }
    return SymbolPathStep(systemImage: glyph, color: color, title: step.stage.title,
      time: step.mark == .ahead ? Format.missing : Format.marketTime(reachedAt), detail: detail,
      detailColor: step.mark == .ahead ? Palette.textQuaternary : color, reached: step.mark != .ahead)
  }

  /// The strategy's latest decision: its verdict, when and which strategy, then every check.
  @ViewBuilder private func decision(_ row: SymbolRowV1) -> some View {
    if let verdict = row.verdict {
      VStack(alignment: .leading, spacing: Tokens.Space.xs) {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
          Badge(verdict.title, color: verdict.color)
          Text(SymbolsText.decided(Format.marketTime(row.decidedAt?.date), row.strategy ?? Format.missing))
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textQuaternary)
            .fixedSize(horizontal: false, vertical: true)
        }
        ForEach(Array(row.checks.enumerated()), id: \.offset) { _, check in
          HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
            Image(systemName: check.passed ? Self.passedSymbol : Self.droppedSymbol)
              .font(Tokens.Typography.chevron)
              .foregroundStyle(check.passed ? Palette.profitText : Palette.droppedText)
            Text(verbatim: SymbolsBoard.checkText(check))
              .font(Tokens.Typography.captionMono)
              .foregroundStyle(Palette.textSecondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          .accessibilityElement(children: .combine)
        }
      }
    } else {
      Text(SymbolsText.noDecision)
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(Palette.textTertiary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

// MARK: - colours and glyphs

extension SymbolRowV1 {
  /// One segment per stage (mockup v101): passed teal, where it stands blue when waiting and pink
  /// when dropped, a hairline where it never got.
  var trackColors: [Color] {
    SymbolStage.allCases.map { stage in
      if stage == self.stage {
        switch state {
        case .passed: return Palette.accent
        case .waiting: return Palette.info
        case .dropped: return Palette.dropped
        case .notReached: return Palette.warning
        }
      }
      return stage.order < self.stage.order || stage.order <= furthest.order ? Palette.accent : Palette.separatorStrong
    }
  }
}

extension SymbolsOutcome {
  /// PASSED green, WAITING blue, DROPPED pink, NOT REACHED grey.
  var color: Color {
    switch self {
    case .passed: Palette.profitText
    case .waiting: Palette.infoText
    case .dropped: Palette.droppedText
    case .notReached: Palette.textTertiary
    }
  }
}

extension SymbolsTab {
  /// The Fast movers tab's bolt.
  static let fastMoversSymbol = "bolt.fill"
}
