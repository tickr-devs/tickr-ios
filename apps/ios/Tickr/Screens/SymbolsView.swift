import SwiftUI
import TickrDesign
import TickrKit

// The Symbols screen behind Home's funnel (mockup v89, iOS): every symbol of today by the stage
// it got to, with why each one stopped, and the fast movers. A funnel stage or the Fast movers
// card's "Show all" pushes it on that tab; "‹ Home" goes back. The rows are the full list, never
// capped; a tap on one shows its path today in a sheet. Texts wrap, never cut.

struct SymbolsView: View {
  @Environment(AppModel.self) private var model
  @State private var tab: SymbolsTab
  @State private var filter = SymbolsFilter.all
  @State private var sort = SymbolsSort.furthest
  @State private var search = ""
  /// The symbol whose path the sheet shows.
  @State private var selected: SelectedSymbol?

  init(tab: SymbolsTab) {
    _tab = State(initialValue: tab)
  }

  /// Accessibility id of the screen, for the UI tests.
  static let id = "symbols"
  /// SF Symbol of the search field.
  static let searchSymbol = "magnifyingglass"

  var body: some View {
    Screen(L10n.Symbols.title, back: L10n.App.home) {
      Text(verbatim: context)
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(Palette.textQuaternary)
        .fixedSize(horizontal: false, vertical: true)
      searchField
      tabs
      controls
      list
    }
    .accessibilityIdentifier(Self.id)
    .refreshable { await model.refreshFlow() }
    .task(id: model.connection.url) { await model.followFlow() }
    .sheet(item: $selected) { item in
      SymbolDetailSheet(symbol: item.id, row: rowsBySymbol[item.id],
        mover: model.movers?.movers.first { $0.symbol == item.id })
    }
  }

  /// "Mon Nov 16 · 10:48 ET · 412 screened": the day, the end of the latest discovery pass and how
  /// many symbols the screeners listed; the bot's cause when no pass is recorded.
  private var context: String {
    let day = DayText.day(model.today.noonInNewYork)
    guard let symbols = model.symbols else {
      return [day, model.symbolsError.map { String(localized: L10n.Symbols.unavailable($0)) }]
        .compactMap { $0 }.joined(separator: Format.separator)
    }
    guard let asOf = symbols.asOf?.date else {
      return [day, symbols.asOfCause].compactMap { $0 }.joined(separator: Format.separator)
    }
    let screened = SymbolsBoard.count(.stage(.screeners), symbols: symbols, movers: model.movers) ?? 0
    return String(localized: L10n.Symbols.context(day, Format.time(asOf), screened))
  }

  private var searchField: some View {
    HStack(spacing: Tokens.Space.s) {
      Image(systemName: Self.searchSymbol)
        .foregroundStyle(Palette.textQuaternary)
        .accessibilityHidden(true)
      TextField(text: $search, prompt: Text(L10n.Symbols.search)) { Text(L10n.Symbols.search) }
        .textInputAutocapitalization(.characters)
        .autocorrectionDisabled()
        .font(Tokens.Typography.calloutMono)
    }
    .padding(.horizontal, Tokens.Space.m)
    .frame(minHeight: Tokens.Size.touchTarget)
    .background(Palette.chipFill, in: Capsule())
    .overlay { Capsule().strokeBorder(Palette.separatorStrong, lineWidth: Tokens.Stroke.thin) }
  }

  // MARK: tabs and controls

  private var tabs: some View {
    ChipFlow(spacing: Tokens.Space.xs) {
      ForEach(SymbolsTab.all) { item in
        Button {
          withAnimation(Tokens.Motion.quick) { tab = item }
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

  @ViewBuilder
  private var controls: some View {
    if case .stage = tab {
      VStack(alignment: .leading, spacing: Tokens.Space.s) {
        SegmentSwitch(options: SymbolsFilter.allCases.map { ($0, Text($0.title)) }, selection: $filter)
          .accessibilityLabel(Text(L10n.Symbols.show))
        SegmentSwitch(options: SymbolsSort.allCases.map { ($0, Text($0.title)) }, selection: $sort)
          .accessibilityLabel(Text(L10n.Symbols.sort))
      }
    } else {
      Text(verbatim: moverRules)
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(Palette.textTertiary)
        .fixedSize(horizontal: false, vertical: true)
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
    let count = isMovers ? moverRows.count : stageRows.count
    let byRow = rowsBySymbol
    return VStack(alignment: .leading, spacing: 0) {
      LazyVStack(alignment: .leading, spacing: 0) {
        if isMovers {
          ForEach(moverRows, id: \.symbol) { mover in
            rowButton(mover.symbol) { MoverRow(mover: mover, row: byRow[mover.symbol]) }
          }
        } else {
          ForEach(stageRows, id: \.symbol) { row in
            rowButton(row.symbol) { SymbolRow(row: row) }
          }
        }
        if count == 0 {
          Text(verbatim: emptyText)
            .font(Tokens.Typography.callout)
            .foregroundStyle(Palette.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(Tokens.Space.l)
        }
      }
      // One list per tab: rows of one tab never stay on screen under another tab's layout.
      .id(tab)
      Text(L10n.Symbols.showingAll(count))
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(Palette.textQuaternary)
        .padding(Tokens.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { Rectangle().fill(Palette.separator).frame(height: Tokens.Stroke.thin) }
    }
    .tickrCard()
    .accessibilityElement(children: .contain)
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

  /// A row as a button that shows the symbol's path in a sheet.
  private func rowButton(_ symbol: String, @ViewBuilder content: () -> some View) -> some View {
    Button {
      selected = SelectedSymbol(id: symbol)
    } label: {
      HStack(spacing: Tokens.Space.s) {
        content()
        Chevron()
      }
      .padding(.horizontal, Tokens.Space.l)
      .padding(.vertical, Tokens.Space.m)
      .frame(maxWidth: .infinity, alignment: .leading)
      .overlay(alignment: .top) { Rectangle().fill(Palette.separator).frame(height: Tokens.Stroke.thin) }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityHint(Text(L10n.Symbols.rowHint))
  }
}

/// The symbol a sheet shows, as `sheet(item:)` needs it.
private struct SelectedSymbol: Identifiable {
  let id: String
}

// MARK: - rows

/// A stage row: the symbol and when it was first seen, its screeners, how far it got and what
/// happened. Every text wraps; none is cut.
private struct SymbolRow: View {
  let row: SymbolRowV1

  var body: some View {
    let outcome = SymbolsBoard.outcome(row)
    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
        Text(verbatim: row.symbol)
          .font(Tokens.Typography.chip)
          .foregroundStyle(Palette.textPrimary)
        if row.verdict == .watch { Badge(Verdict.watch.title, color: Palette.infoText) }
        Spacer(minLength: 0)
        Text(verbatim: row.firstSeen.map { Format.time($0.date) } ?? Format.missing)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      }
      SourceChips(row.sourceChips)
      StageTrack(colors: row.trackColors, title: row.furthest.title)
      Text(verbatim: outcome.text)
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(outcome.tone.color)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

/// A fast mover row: the symbol and the bar's time, its three figures (bright when the signal
/// fired), its screeners and how far it got.
private struct MoverRow: View {
  let mover: FastMoverV1
  /// The symbol's row on the Symbols screen, when it has one.
  let row: SymbolRowV1?

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      FastMoverLine(mover: mover)
      if let row {
        SourceChips(row.sourceChips)
        StageTrack(colors: row.trackColors, title: row.furthest.title)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

/// A fast mover's symbol, WATCH pill and time, then its volume against average, ATR move and
/// dollar volume, each bright when its signal fired. Shared by the card and the screen.
struct FastMoverLine: View {
  let mover: FastMoverV1

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
      HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
        Text(verbatim: mover.symbol)
          .font(Tokens.Typography.chip)
          .foregroundStyle(Palette.textPrimary)
        if mover.watching { Badge(Verdict.watch.title, color: Palette.infoText) }
        Spacer(minLength: 0)
        Text(verbatim: Format.time(mover.at.date))
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      }
      ChipFlow(spacing: Tokens.Space.s) {
        MoverFigure(text: SymbolsBoard.volume(mover), fired: mover.fired(.volume))
        MoverFigure(text: SymbolsBoard.move(mover), fired: mover.fired(.move))
        MoverFigure(text: SymbolsBoard.dollars(mover), fired: mover.fired(.dollars))
      }
    }
  }
}

// MARK: - detail

/// A symbol's whole path today in a sheet: its outcome, screeners, the fast mover bar if any,
/// then each stage with passed, where it stands (and why) or not reached; a link to its chart.
private struct SymbolDetailSheet: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  let symbol: String
  let row: SymbolRowV1?
  let mover: FastMoverV1?

  /// SF Symbol of the chart link.
  static let chartSymbol = "chart.xyaxis.line"
  /// SF Symbols of a stage on the path: passed, dropped, waiting there, not reached.
  static let passedSymbol = "checkmark.circle.fill"
  static let droppedSymbol = "xmark.circle.fill"
  static let waitingSymbol = "clock"
  static let aheadSymbol = "circle"

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Tokens.Space.m) {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
          Text(verbatim: symbol)
            .font(Tokens.Typography.heading)
            .foregroundStyle(Palette.textPrimary)
          if row?.verdict == .watch || mover?.watching == true { Badge(Verdict.watch.title, color: Palette.infoText) }
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
          Text(L10n.Symbols.moverLine(Format.time(mover.at.date), SymbolsBoard.volume(mover),
            SymbolsBoard.move(mover), SymbolsBoard.dollars(mover)))
            .font(Tokens.Typography.captionMono)
            .foregroundStyle(Palette.warningText)
            .fixedSize(horizontal: false, vertical: true)
        }
        if let row { path(row) }
        HeaderLink(L10n.Symbols.openChart, systemImage: Self.chartSymbol) {
          model.selectedSymbol = symbol
          model.selectedTab = .chart
          dismiss()
        }
      }
      .padding(Tokens.Space.l)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    .presentationBackground(Palette.surface)
  }

  private func path(_ row: SymbolRowV1) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      CardLabel(L10n.Symbols.pathToday)
        .padding(.bottom, Tokens.Space.s)
      ForEach(SymbolsBoard.path(row)) { step in
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
          Image(systemName: glyph(step.mark))
            .foregroundStyle(color(step.mark))
            .accessibilityHidden(true)
          VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
            Text(step.stage.title)
              .font(Tokens.Typography.callout)
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
            Text(verbatim: row.at.map { Format.time($0.date) } ?? Format.missing)
              .font(Tokens.Typography.annotation)
              .foregroundStyle(Palette.textQuaternary)
          }
        }
        .padding(.vertical, Tokens.Space.s)
        .overlay(alignment: .top) { Rectangle().fill(Palette.separator).frame(height: Tokens.Stroke.thin) }
        .accessibilityElement(children: .combine)
      }
    }
  }

  private func glyph(_ mark: SymbolsBoard.Step.Mark) -> String {
    switch mark {
    case .passed, .here(.passed): Self.passedSymbol
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

// MARK: - the Fast movers card on Home

/// The day's fast movers on Home: the newest few rows, then "Show all N ›" pushing the Symbols
/// screen on its Fast movers tab, and the thresholds in a mono caption. A new mover rises in as
/// it arrives, a real event of the bot.
struct FastMoversCard: View {
  let movers: MoversV1?
  let failure: String?
  /// The Symbols screen on its Fast movers tab is pushed.
  @State private var showsAll = false

  /// Rows the card shows; the rest are on the Symbols screen.
  static let rowCap = 3

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      CardLabel(L10n.FastMovers.title)
      if let movers {
        if movers.movers.isEmpty {
          Text(verbatim: movers.rulesCause ?? String(localized: L10n.FastMovers.none))
            .font(Tokens.Typography.callout)
            .foregroundStyle(Palette.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
        }
        let shown = Array(movers.movers.prefix(Self.rowCap))
        ForEach(Array(shown.enumerated()), id: \.element.symbol) { index, mover in
          FastMoverLine(mover: mover).rise(step: index)
        }
        .animation(Tokens.Motion.standard, value: shown.map(\.symbol))
        if let rules = movers.rules {
          Text(verbatim: SymbolsBoard.rules(rules))
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textQuaternary)
            .fixedSize(horizontal: false, vertical: true)
        }
      } else if let failure {
        Text(L10n.FastMovers.unavailable(failure))
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.warningText)
          .fixedSize(horizontal: false, vertical: true)
      } else {
        TickrLoader(L10n.Common.loading).frame(maxWidth: .infinity)
      }
      if let movers, !movers.movers.isEmpty {
        CardFooterLink(L10n.FastMovers.showAll, count: movers.movers.count) { showsAll = true }
      }
    }
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, alignment: .leading)
    .tickrCard()
    .navigationDestination(isPresented: $showsAll) { SymbolsView(tab: .fastMovers) }
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
  static let stopSymbol = StopState.levelSymbol
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
