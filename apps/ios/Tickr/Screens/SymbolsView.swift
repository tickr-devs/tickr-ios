import SwiftUI
import TickrDesign
import TickrKit

// The Symbols screen behind Home's funnel (mockup v101, IOSSymbols): every symbol of today by the
// funnel stage it got to, with why each one stopped, and the fast movers. A funnel stage or the
// Fast movers card's "Show all" pushes it on that tab; "‹ Home" goes back. The funnel tabs scroll
// sideways; a menu sorts the rows. A tap on a row pushes the symbol's detail. The rows are the
// full list, never capped; texts wrap, never cut.

struct SymbolsView: View {
  @Environment(AppModel.self) private var model
  @State private var tab: SymbolsTab
  @State private var filter = SymbolsFilter.all
  @State private var search = ""
  /// The sort chosen in the menu; nil keeps the tab's own.
  @State private var order: SymbolsOrder?
  /// The symbol whose detail is pushed.
  @State private var selected: SelectedSymbol?

  init(tab: SymbolsTab) {
    _tab = State(initialValue: tab)
  }

  /// Accessibility id of the screen, for the UI tests.
  static let id = "symbols"
  /// SF Symbols of the search field and the sort menu.
  static let searchSymbol = "magnifyingglass"
  static let sortSymbol = "arrow.up.arrow.down"
  /// The columns the sort menu offers, as the table's titles name them.
  static let sortColumns: [SymbolsColumn] = [.stage, .change, .last, .symbol, .screener, .atr, .volume, .dollars, .time]

  private var shownOrder: SymbolsOrder { order ?? SymbolsOrder.standard(tab) }

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
    .navigationDestination(item: $selected) { item in
      SymbolDetailScreen(line: line(item.id), rules: model.movers?.rules)
    }
  }

  /// "Mon Nov 16 · 10:48 ET · 412 screened": the day, the end of the latest discovery pass and how
  /// many symbols the screeners listed; the bot's cause when no pass is recorded.
  private var context: String {
    let day = DayText.day(model.today)
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

  /// The funnel's stages as an underlined strip that scrolls sideways, chevrons between them, and
  /// the Fast movers apart after a divider.
  private var tabs: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal) {
        HStack(spacing: 0) {
          ForEach(SymbolsTab.all) { item in
            if item == .fastMovers {
              Rectangle().fill(Palette.separatorStrong).frame(width: Tokens.Stroke.thin, height: Tokens.Space.l)
                .padding(.horizontal, Tokens.Space.s)
            }
            Button {
              withAnimation(Tokens.Motion.quick) {
                tab = item
                order = nil
                filter = .all
                proxy.scrollTo(item.id, anchor: .center)
              }
            } label: {
              UnderlineTab(item.title, count: count(item), selected: item == tab,
                systemImage: item == .fastMovers ? SymbolsTab.fastMoversSymbol : nil)
                .font(Tokens.Typography.body)
            }
            .buttonStyle(.plain)
            .id(item.id)
            if case .stage(let stage) = item, stage != SymbolStage.allCases.last {
              Image(systemName: Symbols.next)
                .font(Tokens.Typography.chevron)
                .foregroundStyle(Palette.separatorStrong)
                .accessibilityHidden(true)
            }
          }
        }
        .frame(height: UnderlineTab.phoneHeight)
      }
      .scrollIndicators(.hidden)
      .overlay(alignment: .bottom) { Rectangle().fill(Palette.separator).frame(height: Tokens.Stroke.thin) }
      .onAppear { proxy.scrollTo(tab.id, anchor: .center) }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(Text(L10n.Symbols.stages))
  }

  private func count(_ item: SymbolsTab) -> String {
    SymbolsBoard.count(item, symbols: model.symbols, movers: model.movers).map(String.init) ?? Format.missing
  }

  /// The All / Passed / Dropped here switch with counts, or the fast mover rule; then the sort menu.
  private var controls: some View {
    HStack(alignment: .center, spacing: Tokens.Space.s) {
      if case .stage = tab {
        SegmentSwitch(options: SymbolsFilter.allCases.map { ($0, Text(SymbolsText.filterCount($0, filterCount($0)))) },
          selection: $filter)
          .accessibilityLabel(Text(L10n.Symbols.show))
      } else {
        Text(verbatim: moverRules)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      Menu {
        Picker(selection: Binding(get: { shownOrder.column }, set: { order = shownOrder.clicked($0) })) {
          ForEach(Self.sortColumns) { column in
            Text(column.title(fastMovers: tab == .fastMovers)).tag(column)
          }
        } label: {
          Text(L10n.Symbols.sort)
        }
      } label: {
        Image(systemName: Self.sortSymbol)
          .font(Tokens.Typography.headerSymbol)
          .foregroundStyle(Palette.infoText)
          .frame(width: Tokens.Size.touchTarget, height: Tokens.Size.touchTarget)
          .contentShape(Rectangle())
      }
      .accessibilityLabel(Text(L10n.Symbols.sort))
    }
  }

  private func filterCount(_ filter: SymbolsFilter) -> Int {
    guard case .stage(let stage) = tab else { return 0 }
    return SymbolsBoard.rows(model.symbols?.rows ?? [], stage: stage, filter: filter, sort: .symbol, search: search).count
  }

  /// The active strategy's fast mover thresholds, or why there are none.
  private var moverRules: String {
    guard let movers = model.movers else {
      return model.moversError.map { String(localized: L10n.Symbols.unavailable($0)) } ?? Format.missing
    }
    return movers.rules.map(SymbolsBoard.rules) ?? movers.rulesCauseText ?? Format.missing
  }

  // MARK: list

  private var positions: Set<String> { Set(model.status?.positions.map(\.symbol) ?? []) }

  private var lines: [SymbolsLine] {
    SymbolsBoard.lines(tab, symbols: model.symbols, movers: model.movers, positions: positions,
      query: SymbolsQuery(filter: filter, search: search, order: shownOrder))
  }

  /// The line of `symbol`, also when the search or the tab no longer lists it.
  private func line(_ symbol: String) -> SymbolsLine {
    lines.first { $0.symbol == symbol }
      ?? SymbolsLine(symbol: symbol, row: model.symbols?.rows.first { $0.symbol == symbol },
        mover: model.movers?.movers.first { $0.symbol == symbol }, position: positions.contains(symbol))
  }

  private var list: some View {
    let shown = lines
    let fastMovers = tab == .fastMovers
    return VStack(alignment: .leading, spacing: 0) {
      LazyVStack(alignment: .leading, spacing: 0) {
        if loading {
          // Two-line rows in the rows' own columns and padding (mockup v102).
          Skeleton(L10n.Common.loading) {
            VStack(alignment: .leading, spacing: 0) {
              ForEach(0..<SymbolsSkeleton.rows, id: \.self) { index in
                SymbolsSkeleton.row(index)
              }
            }
          }
        }
        ForEach(shown) { line in
          Button {
            selected = SelectedSymbol(id: line.symbol)
          } label: {
            SymbolListRow(line: line, fastMovers: fastMovers)
          }
          .buttonStyle(.plain)
          .accessibilityHint(Text(L10n.Symbols.rowHint))
        }
        if shown.isEmpty && !loading {
          Text(verbatim: emptyText)
            .font(Tokens.Typography.callout)
            .foregroundStyle(Palette.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(Tokens.Space.l)
        }
      }
      // One list per tab: rows of one tab never stay on screen under another tab's layout.
      .id(tab)
      Text(L10n.Symbols.showingAll(shown.count))
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(Palette.textQuaternary)
        .padding(Tokens.Space.l)
        .frame(maxWidth: .infinity, alignment: .center)
        .overlay(alignment: .top) { Rectangle().fill(Palette.separator).frame(height: Tokens.Stroke.thin) }
    }
    .tickrCard()
    .accessibilityElement(children: .contain)
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
}

/// The symbol a pushed detail shows, as `navigationDestination(item:)` needs it.
private struct SelectedSymbol: Identifiable, Hashable {
  let id: String
}

// MARK: - rows

/// One row (mockup v101): the symbol, its badge, then the price, change and time on the right; the
/// stage track with the stage name in the outcome's colour and why; on the Fast movers tab the
/// bar's three figures. A chevron, as the row pushes the detail. Every text wraps; none is cut.
private struct SymbolListRow: View {
  @Environment(AppModel.self) private var model
  let line: SymbolsLine
  let fastMovers: Bool

  /// The line's price and change: live where the bot's quotes hold the symbol.
  private var shown: SymbolsPrice { SymbolsBoard.shown(line, live: model.livePrice(line.symbol)) }

  /// Widths of the change and the time on the first line, in points (the design's).
  static let changeWidth: CGFloat = 66
  static let timeWidth: CGFloat = 34

  var body: some View {
    let row = line.row
    HStack(spacing: Tokens.Space.s) {
      VStack(alignment: .leading, spacing: Tokens.Space.xs) {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
          SymbolText(line.symbol)
            .font(Tokens.Typography.chip)
            .foregroundStyle(Palette.textPrimary)
          SymbolTagBadge(line: line)
          Spacer(minLength: 0)
          Text(verbatim: shown.price.map { Money.price($0) } ?? Format.missing)
            .font(Tokens.Typography.calloutMono)
            .foregroundStyle(Palette.textPrimary)
          Text(verbatim: SymbolsBoard.tableChange(shown.changePct) ?? Format.missing)
            .font(Tokens.Typography.annotation)
            .foregroundStyle((shown.changePct ?? 0) < 0 ? Palette.droppedText : Palette.profitText)
            .frame(width: Self.changeWidth, alignment: .trailing)
          Text(verbatim: time.map(Format.time) ?? Format.missing)
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textQuaternary)
            .frame(width: Self.timeWidth, alignment: .trailing)
        }
        if let row {
          HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
            StageTrack(colors: row.trackColors, title: row.furthest.title,
              titleColor: SymbolsOutcome(row.state).color)
              .fixedSize()
            if let why = SymbolsBoard.why(row) {
              Text(verbatim: why)
                .font(Tokens.Typography.annotation)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
        }
        if fastMovers, let mover = line.mover {
          ChipFlow(spacing: Tokens.Space.s) {
            MoverFigure(text: SymbolsBoard.volume(mover), fired: mover.fired(.volume))
            MoverFigure(text: SymbolsBoard.move(mover), fired: mover.fired(.move))
            MoverFigure(text: SymbolsBoard.dollars(mover), fired: mover.fired(.dollars))
          }
        }
      }
      Chevron()
    }
    .padding(.horizontal, Tokens.Space.l)
    .padding(.vertical, Tokens.Space.m)
    .frame(maxWidth: .infinity, alignment: .leading)
    .overlay(alignment: .top) { Rectangle().fill(Palette.separator).frame(height: Tokens.Stroke.thin) }
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
  }

  /// The bar's time on the Fast movers tab, else when a screener first listed it.
  private var time: Date? { fastMovers ? line.mover?.at.date : line.row?.firstSeen?.date }
}

/// The Symbols list while its rows load (mockup v102): two-line skeleton rows in `SymbolListRow`'s
/// shape — the symbol and its badge, the price, the change and the time in the row's own column
/// widths; the stage track, the stage and why under them; the chevron's room.
@MainActor
private enum SymbolsSkeleton {
  /// Skeleton rows in the list, as the board's.
  static let rows = 9
  /// Widths that differ row to row, in points, repeating: the symbol, its badge, the price and
  /// why.
  static let symbols: [CGFloat] = [44, 38, 50, 42, 36]
  static let badges: [CGFloat] = [48, 56, 40, 60, 52]
  static let prices: [CGFloat] = [46, 40, 52, 44, 38]
  static let whys: [CGFloat] = [110, 84, 130, 96, 72]
  /// Fixed blocks of a row, in points: the symbol's and the price's heights, the change, the
  /// stage track (and its height) and the stage's name.
  static let symbolHeight: CGFloat = 14
  static let priceHeight: CGFloat = 12
  static let change: CGFloat = 38
  static let track: CGFloat = 57
  static let trackHeight: CGFloat = 10
  static let stage: CGFloat = 58

  static func row(_ index: Int) -> some View {
    let pick = { (widths: [CGFloat]) in widths[index % widths.count] }
    return HStack(spacing: Tokens.Space.s) {
      VStack(alignment: .leading, spacing: Tokens.Space.s) {
        HStack(spacing: Tokens.Space.s) {
          SkeletonBlock(.block(height: symbolHeight), width: pick(symbols))
          SkeletonBlock(.pill, width: pick(badges))
          Spacer(minLength: 0)
          SkeletonBlock(.block(height: priceHeight), width: pick(prices))
          SkeletonBlock(.line, width: change).frame(width: SymbolListRow.changeWidth, alignment: .trailing)
          SkeletonBlock(.line, width: SymbolListRow.timeWidth)
        }
        HStack(spacing: Tokens.Space.s) {
          SkeletonBlock(.block(height: trackHeight), width: track)
          SkeletonBlock(.line, width: stage)
          SkeletonBlock(.line, width: pick(whys))
        }
      }
      Chevron().hidden()
    }
    .padding(.horizontal, Tokens.Space.l)
    .padding(.vertical, Tokens.Space.m)
    .frame(maxWidth: .infinity, alignment: .leading)
    .overlay(alignment: .top) { SkeletonGridLine() }
  }
}

/// The POSITION (teal) or WATCH (blue) badge beside a symbol.
private struct SymbolTagBadge: View {
  let line: SymbolsLine

  var body: some View {
    if line.position {
      Badge(SymbolsText.position, color: Palette.accentText)
    } else if line.watching {
      Badge(Verdict.watch.title, color: Palette.infoText)
    }
  }
}

/// A fast mover's symbol, WATCH pill and time, then its volume against average, ATR move and
/// dollar volume, each bright when its signal fired. Shared by the card and the screen.
struct FastMoverLine: View {
  let mover: FastMoverV1

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
      HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
        SymbolText(mover.symbol)
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
          Text(verbatim: movers.rulesCauseText ?? String(localized: L10n.FastMovers.none))
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
        Skeleton(L10n.Common.loading) { SkeletonRows(Tokens.Loading.fewRows) }
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

// MARK: - detail

/// A symbol's detail, pushed from the list (mockup v101): the symbol, its price and change, then
/// cards for the outcome and the fast bar, the path today with the time of each stage, the
/// screeners and the strategy's last decision with its checks, and the links.
private struct SymbolDetailScreen: View {
  @Environment(AppModel.self) private var model
  /// Today's price line, kept while the same symbol's line is read again.
  @State private var dayLine: SymbolDayLine?
  @State private var shownLineSymbol: String?
  let line: SymbolsLine
  let rules: FastMoverRulesV1?

  /// The line's price and change: live where the bot's quotes hold the symbol.
  private var shown: SymbolsPrice { SymbolsBoard.shown(line, live: model.livePrice(line.symbol)) }

  /// SF Symbols of the chart link and the path steps.
  static let chartSymbol = "chart.xyaxis.line"
  static let passedSymbol = "checkmark"
  static let droppedSymbol = "xmark"
  static let waitingSymbol = "clock"
  static let aheadSymbol = "minus"

  var body: some View {
    let row = line.row
    // The title is the ticker itself, data that no catalog translates.
    Screen(LocalizedStringResource(stringLiteral: line.symbol), back: L10n.Symbols.title) {
      VStack(alignment: .leading, spacing: Tokens.Space.xs) {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
          SymbolTagBadge(line: line)
          Spacer(minLength: Tokens.Space.s)
          if let seen = row?.firstSeen?.date {
            Text(SymbolsText.seen(Format.time(seen)))
              .font(Tokens.Typography.annotation)
              .foregroundStyle(Palette.textQuaternary)
          }
        }
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
          Text(verbatim: shown.price.map { Money.price($0) } ?? Format.missing)
            .font(Tokens.Typography.metric)
            .foregroundStyle(Palette.textPrimary)
          if let change = SymbolsBoard.tableChange(shown.changePct) {
            Text(verbatim: change)
              .font(Tokens.Typography.calloutMono)
              .fontWeight(.semibold)
              .foregroundStyle((shown.changePct ?? 0) < 0 ? Palette.droppedText : Palette.profitText)
          }
          Spacer(minLength: Tokens.Space.s)
          Text(SymbolsText.today)
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textQuaternary)
        }
        .task(id: line) { await readDayLine() }
        if let dayLine {
          let plotted = dayLine.plotted
          DayLine(closes: plotted.closes, previousClose: plotted.previousClose)
        }
      }
      VStack(alignment: .leading, spacing: Tokens.Space.m) {
        if let row { outcome(row) }
        sectionLabel(SymbolsText.fastMover,
          note: line.mover.map { String(localized: SymbolsText.flagged(Format.time($0.at.date))) }
            ?? String(localized: SymbolsText.notFlagged))
        if let mover = line.mover { stats(mover) }
      }
      .detailCard()
      if let row {
        VStack(alignment: .leading, spacing: 0) {
          sectionLabel(L10n.Symbols.pathToday, note: nil).padding(.bottom, Tokens.Space.xs)
          ForEach(SymbolsBoard.path(row)) { step in pathStep(step, row: row) }
        }
        .detailCard()
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
          if !row.sources.isEmpty {
            sectionLabel(SymbolsText.screeners, note: nil)
            ForEach(row.sources, id: \.kind) { source in
              HStack {
                Text(verbatim: SymbolsBoard.screenerName(source)).foregroundStyle(Palette.textSecondary)
                Spacer(minLength: Tokens.Space.s)
                Text(SymbolsText.rank(source.rank)).foregroundStyle(Palette.textTertiary)
              }
              .font(Tokens.Typography.calloutMono)
            }
          }
          sectionLabel(SymbolsText.lastDecision, note: nil)
          decision(row)
        }
        .detailCard()
      }
      ChipFlow(spacing: Tokens.Space.s) {
        HeaderLink(L10n.Symbols.openChart, systemImage: Self.chartSymbol) {
          model.selectedSymbol = line.symbol
          model.selectedTab = .chart
        }
      }
    }
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

  /// The outcome badge, then "at Strategy · Close above VWAP 5.12 >= 5.20" or "reached Stop".
  private func outcome(_ row: SymbolRowV1) -> some View {
    let stage = String(localized: row.stage.title)
    let place = String(localized: row.state == .passed ? SymbolsText.reachedStage(stage) : SymbolsText.atStage(stage))
    let text = [place, SymbolsBoard.why(row)].compactMap { $0 }.joined(separator: Format.separator)
    return HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
      Badge(SymbolsOutcome(row.state).title, color: SymbolsOutcome(row.state).color)
      Text(verbatim: text)
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(Palette.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func sectionLabel(_ title: LocalizedStringResource, note: String?) -> some View {
    HStack(alignment: .firstTextBaseline) {
      CardLabel(title)
      Spacer(minLength: Tokens.Space.s)
      if let note {
        Text(verbatim: note)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      }
    }
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
      time: step.mark == .ahead ? Format.missing : reachedAt.map(Format.time) ?? Format.missing, detail: detail,
      detailColor: step.mark == .ahead ? Palette.textQuaternary : color, reached: step.mark != .ahead)
  }

  /// The strategy's latest decision: its verdict, when and which strategy, then every check.
  @ViewBuilder private func decision(_ row: SymbolRowV1) -> some View {
    if let verdict = row.verdict {
      HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
        Badge(verdict.title, color: verdict.color)
        Text(SymbolsText.decided(row.decidedAt.map { Format.time($0.date) } ?? Format.missing,
          row.strategy ?? Format.missing))
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
    } else {
      Text(SymbolsText.noDecision)
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(Palette.textTertiary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

private extension View {
  /// A section of the detail in a card.
  func detailCard() -> some View {
    padding(Tokens.Space.l).frame(maxWidth: .infinity, alignment: .leading).tickrCard()
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
