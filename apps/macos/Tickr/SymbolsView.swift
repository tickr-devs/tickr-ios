import SwiftUI
import TickrDesign
import TickrKit

// The Symbols screen behind the Overview funnel (mockup v89, MacSymbols): every symbol of the
// shown day by the stage it got to, with why each one stopped, and the fast movers. A funnel
// stage or the fast movers' "Show all" opens it on that tab; "Overview" goes back. The rows are
// the full list, never capped; the list scrolls, the cards never cut a text.

struct SymbolsView: View {
  @Environment(AppModel.self) private var model
  @State private var filter = SymbolsFilter.all
  @State private var sort = SymbolsSort.furthest
  @State private var search = ""
  /// The symbol whose path the detail shows; nil shows the first row's.
  @State private var selected: String?

  /// Width of the detail beside the list, in points (the design's).
  static let detailWidth: CGFloat = 320
  /// Width of the search field, in points (the design's).
  static let searchWidth: CGFloat = 220
  /// Accessibility id of the screen, for the UI tests.
  static let id = "symbols"
  /// Width of the bar that marks the selected row, in points (the design's inset shadow).
  static let selectionBar: CGFloat = 3

  private var tab: SymbolsTab { model.symbolsTab ?? .stage(.screeners) }

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      header
      tabs
      controls
      HStack(alignment: .top, spacing: Tokens.Space.m) {
        list.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        detail.frame(width: Self.detailWidth)
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
    HStack(alignment: .bottom, spacing: Tokens.Space.m) {
      VStack(alignment: .leading, spacing: Tokens.Space.s) {
        Button(action: close) { BackCapsule(L10n.Symbols.back) }
          .buttonStyle(.backCapsule)
        ChipFlow(spacing: Tokens.Space.m) {
          Text(L10n.Symbols.title)
            .font(Tokens.Typography.heading)
            .foregroundStyle(Palette.textPrimary)
            .accessibilityAddTraits(.isHeader)
          Text(verbatim: context)
            .font(Tokens.Typography.captionMono)
            .foregroundStyle(Palette.textQuaternary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      TextField(text: $search, prompt: Text(L10n.Symbols.search)) { Text(L10n.Symbols.search) }
        .textFieldStyle(.roundedBorder)
        .frame(width: Self.searchWidth)
    }
  }

  /// "Mon Nov 16 · 10:48 ET · 412 screened": the day, the end of the latest discovery pass and how
  /// many symbols the screeners listed; the bot's cause when no pass is recorded.
  private var context: String {
    let day = Format.dayLabel(model.shownDay)
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

  // MARK: tabs and controls

  private var tabs: some View {
    ChipFlow(spacing: Tokens.Space.xs) {
      ForEach(SymbolsTab.all) { item in
        Button {
          withAnimation(Tokens.Motion.quick) { model.symbolsTab = item }
        } label: {
          HStack(spacing: Tokens.Space.xs) {
            Image(systemName: item.systemImage)
            Text(item.title)
            Text(verbatim: SymbolsBoard.count(item, symbols: model.symbols, movers: model.movers)
              .map(String.init) ?? Format.missing)
              .font(Tokens.Typography.annotationBold)
          }
        }
        .buttonStyle(.chip(selected: item == tab))
        .accessibilityAddTraits(item == tab ? .isSelected : [])
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(Text(L10n.Symbols.stages))
  }

  private var controls: some View {
    ChipFlow(spacing: Tokens.Space.m) {
      if case .stage = tab {
        SegmentSwitch(options: SymbolsFilter.allCases.map { ($0, Text($0.title)) }, selection: $filter)
          .fixedSize()
          .accessibilityLabel(Text(L10n.Symbols.show))
        HStack(spacing: Tokens.Space.s) {
          Text(L10n.Symbols.sort)
            .textCase(.uppercase)
            .font(Tokens.Typography.label)
            .tracking(Tokens.Typography.labelTracking)
            .foregroundStyle(Palette.textQuaternary)
          SegmentSwitch(options: SymbolsSort.allCases.map { ($0, Text($0.title)) }, selection: $sort)
            .fixedSize()
            .accessibilityLabel(Text(L10n.Symbols.sort))
        }
      } else {
        Text(verbatim: moverRules)
          .font(Tokens.Typography.captionMono)
          .foregroundStyle(Palette.textTertiary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  /// The active strategy's fast mover thresholds, or why there are none.
  private var moverRules: String {
    guard let movers = model.movers else {
      return model.moversError.map { String(localized: L10n.Symbols.unavailable($0)) } ?? Format.missing
    }
    return movers.rules.map(SymbolsBoard.rules) ?? movers.rulesCause ?? Format.missing
  }

  // MARK: list

  private var stageRows: [SymbolRowV1] {
    guard case .stage(let stage) = tab else { return [] }
    return SymbolsBoard.rows(model.symbols?.rows ?? [], stage: stage, filter: filter, sort: sort, search: search)
  }

  private var moverRows: [FastMoverV1] {
    SymbolsBoard.movers(model.movers?.movers ?? [], search: search)
  }

  private var rowsBySymbol: [String: SymbolRowV1] {
    Dictionary((model.symbols?.rows ?? []).map { ($0.symbol, $0) }, uniquingKeysWith: { first, _ in first })
  }

  private var list: some View {
    let isMovers = tab == .fastMovers
    let shown = isMovers ? moverRows.map(\.symbol) : stageRows.map(\.symbol)
    let byRow = rowsBySymbol
    return VStack(alignment: .leading, spacing: 0) {
      Group {
        if isMovers { MoverColumns.header } else { SymbolColumns.header }
      }
      .padding(.horizontal, Tokens.Space.m)
      .padding(.bottom, Tokens.Space.s)
      ScrollView(.vertical) {
        LazyVStack(alignment: .leading, spacing: 0) {
          if isMovers {
            ForEach(moverRows, id: \.symbol) { mover in
              rowButton(mover.symbol) { MoverColumns(mover: mover, row: byRow[mover.symbol]) }
            }
          } else {
            ForEach(stageRows, id: \.symbol) { row in
              rowButton(row.symbol) { SymbolColumns(row: row) }
            }
          }
          if shown.isEmpty {
            Footnote(verbatim: emptyText)
              .padding(Tokens.Space.m)
          }
        }
      }
      .scrollBounceBehavior(.basedOnSize)
      Rectangle().fill(Palette.separator).frame(height: Tokens.Stroke.thin)
      Text(L10n.Symbols.showingAll(shown.count))
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(Palette.textQuaternary)
        .padding(Tokens.Space.m)
    }
    .padding(.top, Tokens.Space.m)
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

  /// A row as a button that selects it for the detail, highlighted while selected.
  private func rowButton(_ symbol: String, @ViewBuilder content: () -> some View) -> some View {
    let isSelected = symbol == (selected ?? firstSymbol)
    return Button {
      selected = symbol
    } label: {
      content()
        .padding(.horizontal, Tokens.Space.m)
        .padding(.vertical, Tokens.Space.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Palette.selection : .clear)
        .overlay(alignment: .leading) {
          if isSelected { Rectangle().fill(Palette.info).frame(width: Self.selectionBar) }
        }
        .overlay(alignment: .top) { Rectangle().fill(Palette.separator).frame(height: Tokens.Stroke.thin) }
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private var firstSymbol: String? {
    tab == .fastMovers ? moverRows.first?.symbol : stageRows.first?.symbol
  }

  // MARK: detail

  private var detail: some View {
    let symbol = selected ?? firstSymbol
    let row = symbol.flatMap { rowsBySymbol[$0] }
    let mover = symbol.flatMap { name in model.movers?.movers.first { $0.symbol == name } }
    return SymbolDetail(symbol: symbol, row: row, mover: mover)
  }
}

// MARK: - rows

/// The columns of a stage row: the symbol, its screeners with rank and change, how far it got,
/// what happened and when it was first seen. Every text wraps; none is cut.
private struct SymbolColumns: View {
  let row: SymbolRowV1

  /// Widths of the fixed columns, in points (the design's grid).
  static let symbolWidth: CGFloat = 72
  static let trackWidth: CGFloat = 120
  static let seenWidth: CGFloat = 62

  static var header: some View {
    HStack(spacing: Tokens.Space.m) {
      ColumnTitle(L10n.Symbols.columnSymbol).frame(width: symbolWidth, alignment: .leading)
      ColumnTitle(L10n.Symbols.columnSources).frame(maxWidth: .infinity, alignment: .leading)
      ColumnTitle(L10n.Symbols.columnFurthest).frame(width: trackWidth, alignment: .leading)
      ColumnTitle(L10n.Symbols.columnOutcome).frame(maxWidth: .infinity, alignment: .leading)
      ColumnTitle(L10n.Symbols.columnSeen).frame(width: seenWidth, alignment: .trailing)
    }
  }

  var body: some View {
    let outcome = SymbolsBoard.outcome(row)
    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.m) {
      Text(verbatim: row.symbol)
        .font(Tokens.Typography.chip)
        .foregroundStyle(Palette.textPrimary)
        .frame(width: Self.symbolWidth, alignment: .leading)
      SourceChips(row.sourceChips).frame(maxWidth: .infinity, alignment: .leading)
      StageTrack(colors: row.trackColors, title: row.furthest.title)
        .frame(width: Self.trackWidth, alignment: .leading)
      HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.xs) {
        if row.verdict == .watch { VerdictTag(verdict: .watch) }
        Text(verbatim: outcome.text)
          .font(Tokens.Typography.captionMono)
          .foregroundStyle(outcome.tone.color)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      Text(verbatim: Format.marketTime(row.firstSeen?.date))
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(Palette.textQuaternary)
        .frame(width: Self.seenWidth, alignment: .trailing)
    }
    .accessibilityElement(children: .combine)
  }
}

/// The columns of a fast mover row: the symbol, its last bar against the bars before, its
/// screeners, how far it got and the bar's time.
private struct MoverColumns: View {
  let mover: FastMoverV1
  /// The symbol's row on the Symbols screen, when it has one.
  let row: SymbolRowV1?

  /// Widths of the fixed columns, in points (the design's grid).
  static let symbolWidth: CGFloat = 72
  static let volumeWidth: CGFloat = 84
  static let moveWidth: CGFloat = 84
  static let dollarsWidth: CGFloat = 104
  static let trackWidth: CGFloat = 120
  static let timeWidth: CGFloat = 62

  static var header: some View {
    HStack(spacing: Tokens.Space.m) {
      ColumnTitle(L10n.Symbols.columnSymbol).frame(width: symbolWidth, alignment: .leading)
      ColumnTitle(L10n.Symbols.columnVolume).frame(width: volumeWidth, alignment: .leading)
      ColumnTitle(L10n.Symbols.columnMove).frame(width: moveWidth, alignment: .leading)
      ColumnTitle(L10n.Symbols.columnDollars).frame(width: dollarsWidth, alignment: .leading)
      ColumnTitle(L10n.Symbols.columnScreeners).frame(maxWidth: .infinity, alignment: .leading)
      ColumnTitle(L10n.Symbols.columnFurthest).frame(width: trackWidth, alignment: .leading)
      ColumnTitle(L10n.Symbols.columnTime).frame(width: timeWidth, alignment: .trailing)
    }
  }

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.m) {
      Text(verbatim: mover.symbol)
        .font(Tokens.Typography.chip)
        .foregroundStyle(Palette.textPrimary)
        .frame(width: Self.symbolWidth, alignment: .leading)
      MoverFigure(text: SymbolsBoard.volume(mover), fired: mover.fired(.volume))
        .frame(width: Self.volumeWidth, alignment: .leading)
      MoverFigure(text: SymbolsBoard.move(mover), fired: mover.fired(.move),
        color: mover.moveAtr.isNegative ? Palette.lossText : Palette.profitText)
        .frame(width: Self.moveWidth, alignment: .leading)
      MoverFigure(text: SymbolsBoard.dollars(mover), fired: mover.fired(.dollars))
        .frame(width: Self.dollarsWidth, alignment: .leading)
      HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.xs) {
        if let row { SourceChips(row.sourceChips) }
        if mover.watching { VerdictTag(verdict: .watch) }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      Group {
        if let row {
          StageTrack(colors: row.trackColors, title: row.furthest.title)
        } else {
          Text(verbatim: Format.missing)
        }
      }
      .frame(width: Self.trackWidth, alignment: .leading)
      Text(verbatim: Format.marketTime(mover.at.date))
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(Palette.textQuaternary)
        .frame(width: Self.timeWidth, alignment: .trailing)
    }
    .accessibilityElement(children: .combine)
  }
}

/// The signals named in `FastMoverV1.fired` (protocol constants of the API).
enum FastMoverSignal: String {
  case volume = "volume_ratio"
  case move = "move_atr"
  case dollars = "dollar_volume_ratio"
}

extension FastMoverV1 {
  /// Whether `signal` reached its threshold on the mover's bar.
  func fired(_ signal: FastMoverSignal) -> Bool { fired.contains(signal.rawValue) }
}

/// A column's title above the rows.
private struct ColumnTitle: View {
  let title: LocalizedStringResource

  init(_ title: LocalizedStringResource) { self.title = title }

  var body: some View {
    Text(title)
      .textCase(.uppercase)
      .font(Tokens.Typography.label)
      .tracking(Tokens.Typography.labelTracking)
      .foregroundStyle(Palette.textQuaternary)
      .fixedSize(horizontal: false, vertical: true)
  }
}

// MARK: - detail

/// The selected symbol's whole path today: its outcome, screeners, the fast mover bar if any, then
/// each stage with passed, where it stands (and why) or not reached; links to its chart and days.
private struct SymbolDetail: View {
  @Environment(AppModel.self) private var model
  @AppStorage(ChartView.Keys.symbol) private var chartSymbol = ""
  let symbol: String?
  let row: SymbolRowV1?
  let mover: FastMoverV1?

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      if let symbol {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
          Text(verbatim: symbol)
            .font(Tokens.Typography.heading)
            .foregroundStyle(Palette.textPrimary)
          if row?.verdict == .watch || mover?.watching == true { VerdictTag(verdict: .watch) }
        }
        if let row {
          let outcome = SymbolsBoard.outcome(row)
          Text(verbatim: outcome.text)
            .font(Tokens.Typography.captionMono)
            .foregroundStyle(outcome.tone.color)
            .fixedSize(horizontal: false, vertical: true)
          SourceChips(row.sourceChips)
        }
        if let mover {
          Text(L10n.Symbols.moverLine(Format.marketTime(mover.at.date), SymbolsBoard.volume(mover),
            SymbolsBoard.move(mover), SymbolsBoard.dollars(mover)))
            .font(Tokens.Typography.captionMono)
            .foregroundStyle(Palette.warningText)
            .fixedSize(horizontal: false, vertical: true)
        }
        if let row { path(row) }
        ChipFlow(spacing: Tokens.Space.s) {
          HeaderLink(L10n.Symbols.openChart, systemImage: Self.chartSymbol) {
            chartSymbol = symbol
            model.section = .chart
          }
          HeaderLink(L10n.Symbols.tradesAndDays) { model.section = .trades }
        }
      } else {
        Footnote(L10n.Symbols.selectHint)
      }
      Spacer(minLength: 0)
    }
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .tickrCard(radius: Tokens.Radius.large)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(Text(L10n.Symbols.detailLabel))
  }

  /// SF Symbol of the chart link.
  static let chartSymbol = "chart.xyaxis.line"
  /// SF Symbols of a stage on the path: passed, where it stands, not reached.
  static let passedSymbol = "checkmark.circle.fill"
  static let droppedSymbol = "xmark.circle.fill"
  static let waitingSymbol = "clock"
  static let aheadSymbol = "circle"

  private func path(_ row: SymbolRowV1) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(L10n.Symbols.pathToday)
        .textCase(.uppercase)
        .font(Tokens.Typography.label)
        .tracking(Tokens.Typography.labelTracking)
        .foregroundStyle(Palette.textQuaternary)
        .padding(.bottom, Tokens.Space.s)
      ForEach(SymbolsBoard.path(row)) { step in
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
          Image(systemName: symbol(step.mark))
            .foregroundStyle(color(step.mark))
            .accessibilityHidden(true)
          VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
            Text(step.stage.title)
              .font(Tokens.Typography.caption)
              .foregroundStyle(step.mark == .ahead ? Palette.textQuaternary : Palette.textSecondary)
            if let detail = step.detail {
              Text(verbatim: detail)
                .font(Tokens.Typography.annotation)
                .foregroundStyle(Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
          Spacer(minLength: 0)
          if case .here = step.mark {
            Text(verbatim: Format.marketTime(row.at?.date))
              .font(Tokens.Typography.annotation)
              .foregroundStyle(Palette.textQuaternary)
          }
        }
        .padding(.vertical, Tokens.Space.xs)
        .overlay(alignment: .top) { Rectangle().fill(Palette.separator).frame(height: Tokens.Stroke.thin) }
        .accessibilityElement(children: .combine)
      }
    }
  }

  private func symbol(_ mark: SymbolsBoard.Step.Mark) -> String {
    switch mark {
    case .passed: Self.passedSymbol
    case .here(.passed): Self.passedSymbol
    case .here(.dropped): Self.droppedSymbol
    case .here(.waiting), .here(.notReached): Self.waitingSymbol
    case .ahead: Self.aheadSymbol
    }
  }

  private func color(_ mark: SymbolsBoard.Step.Mark) -> Color {
    switch mark {
    case .passed: Palette.profit
    case .here(let tone): tone.color
    case .ahead: Palette.textQuaternary
    }
  }
}

// MARK: - colours and glyphs

extension SymbolRowV1 {
  /// The symbol's screeners as chips; the change shows once, on the first.
  var sourceChips: [SourceChips.Item] {
    sources.enumerated().map { index, source in
      let change = index == 0 ? changePct : nil
      return SourceChips.Item(text: SymbolsBoard.source(source), change: change.map(SymbolsBoard.change),
        changeColor: change?.isNegative == true ? Palette.lossText : Palette.profitText)
    }
  }

  /// One colour per stage: the stage's own up to the furthest, red where it was dropped.
  var trackColors: [Color] {
    SymbolStage.allCases.map { stage in
      if stage == self.stage, state == .dropped { return Palette.loss }
      return stage.order <= furthest.order ? stage.color : Palette.separatorStrong
    }
  }
}

extension SymbolStage {
  /// The stage's colour, as the funnel draws it.
  var color: Color {
    switch self {
    case .screeners: Palette.accent
    case .universe: Palette.seriesUniverse
    case .quote: Palette.accentText
    case .bars: Palette.info
    case .strategy: Palette.highlight
    case .risk: Palette.warning
    case .order: Palette.infoText
    case .stop: Palette.profit
    }
  }
}

extension SymbolsTab {
  /// The tab chip's SF Symbol.
  var systemImage: String {
    switch self {
    case .stage(.screeners): Self.screenersSymbol
    case .stage(.universe): Self.universeSymbol
    case .stage(.quote): Self.quoteSymbol
    case .stage(.bars): Self.barsSymbol
    case .stage(.strategy): Self.strategySymbol
    case .stage(.risk): Self.riskSymbol
    case .stage(.order): Self.orderSymbol
    case .stage(.stop): Self.stopSymbol
    case .fastMovers: Self.fastMoversSymbol
    }
  }

  /// SF Symbols of the tabs, as the design's stage glyphs.
  static let screenersSymbol = "line.3.horizontal.decrease"
  /// The universe filter.
  static let universeSymbol = "building.columns"
  /// A fresh quote (a coin with arrows).
  static let quoteSymbol = "dollarsign.arrow.circlepath"
  /// Minute bars.
  static let barsSymbol = "chart.bar"
  /// The strategy's decision.
  static let strategySymbol = "arrow.triangle.branch"
  /// The risk gauge.
  static let riskSymbol = "gauge.with.dots.needle.33percent"
  /// The entry order.
  static let orderSymbol = "paperplane"
  /// The broker stop.
  static let stopSymbol = "checkmark.shield"
  /// A fast mover's jump.
  static let fastMoversSymbol = "bolt"
}

extension SymbolsBoard.Tone {
  /// The colour of an outcome: passed green, waiting blue, dropped red, not reached amber.
  var color: Color {
    switch self {
    case .passed: Palette.profitText
    case .waiting: Palette.infoText
    case .dropped: Palette.lossText
    case .notReached: Palette.warningText
    }
  }
}
