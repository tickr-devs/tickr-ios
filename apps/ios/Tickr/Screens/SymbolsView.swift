import SwiftUI
import TickrDesign
import TickrKit

// The Symbols screen behind Home's funnel (mockup IOSSymbols, 2026-11-25): every symbol of today by
// the funnel stage it got to, with why each one stopped in short, and the fast movers. A funnel
// stage or the Fast movers card's "Show all" pushes it on that tab; "‹ Home" goes back. The funnel
// tabs scroll sideways; a menu sorts the rows. A tap on a row pushes the symbol's detail. The rows
// are the full list, never capped; texts wrap, never cut.

struct SymbolsView: View {
  @Environment(AppModel.self) private var model
  @State private var tab: SymbolsTab
  @State private var filter = SymbolsFilter.all
  @State private var search = ""
  /// The sort chosen in the menu; nil keeps the tab's own.
  @State private var order: SymbolsOrder?
  /// The symbol whose detail is pushed.
  @State private var selected: SelectedSymbol?
  /// The fast mover rule shows under its caption.
  @State private var showsRule = false

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
      SymbolDetailScreen(line: line(item.id))
    }
  }

  /// "Mon Nov 16 · 10:48 ET": the day and the end of the latest discovery pass; the bot's cause
  /// when no pass is recorded.
  private var context: String {
    let day = DayText.day(model.shownDay)
    guard let symbols = model.symbols else {
      return [day, model.symbolsError.map { String(localized: L10n.Symbols.unavailable($0)) }]
        .compactMap { $0 }.joined(separator: Format.separator)
    }
    guard let asOf = symbols.asOf?.date else {
      return [day, symbols.asOfCause].compactMap { $0 }.joined(separator: Format.separator)
    }
    return String(localized: L10n.Symbols.context(day, Format.time(asOf)))
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
      .withoutScrollIndicators()
      .overlay(alignment: .bottom) { Rectangle().fill(Palette.separator).frame(height: Tokens.Stroke.thin) }
      .onAppear { proxy.scrollTo(tab.id, anchor: .center) }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(Text(L10n.Symbols.stages))
  }

  private func count(_ item: SymbolsTab) -> String {
    SymbolsBoard.count(item, symbols: model.symbols, movers: model.movers).map(String.init) ?? Format.missing
  }

  /// The All / Passed / Dropped here switch with counts and the stage's caption under it, or the
  /// fast movers' caption with an "i" that opens their rule under it (mockup IOSSymbols); then
  /// the sort menu.
  private var controls: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      HStack(alignment: .center, spacing: Tokens.Space.s) {
        if case .stage = tab {
          SegmentSwitch(options: SymbolsFilter.allCases.map { ($0, Text(SymbolsText.filterCount($0, filterCount($0)))) },
            selection: $filter)
            .accessibilityLabel(Text(L10n.Symbols.show))
        } else {
          Text(verbatim: SymbolsBoard.caption(tab, symbols: model.symbols))
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
          if fastRule != nil { ruleButton }
          Spacer(minLength: 0)
        }
        sortMenu
      }
      if case .stage = tab {
        Text(verbatim: SymbolsBoard.caption(tab, symbols: model.symbols))
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textTertiary)
          .fixedSize(horizontal: false, vertical: true)
      } else if showsRule, let fastRule {
        Text(verbatim: fastRule)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
          .transition(.opacity)
      }
    }
  }

  /// The "i" beside the fast movers' caption: shows or hides their rule.
  private var ruleButton: some View {
    Button {
      withAnimation(Tokens.Motion.quick) { showsRule.toggle() }
    } label: {
      Image(systemName: InfoCaption.infoSymbol)
        .font(Tokens.Typography.callout)
        .foregroundStyle(showsRule ? Palette.infoText : Palette.textTertiary)
        .frame(width: Tokens.Size.touchTarget, height: Tokens.Size.touchTarget)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(Text(SymbolsText.fastRuleLabel))
    .accessibilityAddTraits(showsRule ? .isSelected : [])
  }

  private var sortMenu: some View {
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

  private func filterCount(_ filter: SymbolsFilter) -> Int {
    guard case .stage(let stage) = tab else { return 0 }
    return SymbolsBoard.rows(model.symbols?.rows ?? [], stage: stage, filter: filter, sort: .symbol, search: search).count
  }

  /// The fast mover rule in one sentence, or why there is none; nil before the movers are read.
  private var fastRule: String? {
    guard let movers = model.movers else {
      return model.moversError.map { String(localized: L10n.Symbols.unavailable($0)) }
    }
    return movers.rules.map(SymbolsBoard.fastRule) ?? movers.rulesCauseText
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
          // Two-line rows in the rows' own columns and padding (mockup v102); the rows take
          // their place at once (`loadsInPlace` below).
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
    .loadsInPlace(!loading)
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

/// One row (mockup IOSSymbols): the symbol, its badge, then the price, change and time on the
/// right; the stage track with the stage name in the outcome's colour and why in short; on the
/// Fast movers tab the bar's signals that fired. A chevron, as the row pushes the detail. Every text wraps; none is cut.
private struct SymbolListRow: View {
  @Environment(AppModel.self) private var model
  let line: SymbolsLine
  let fastMovers: Bool

  /// The line's price and change: live where the bot's quotes hold the symbol.
  private var shown: SymbolsPrice { SymbolsBoard.shown(line, live: model.livePrice(line.symbol)) }

  /// Width of the change on the first line, in points (the design's).
  static let changeWidth: CGFloat = 66
  /// The time is as wide as its clock ("09:32") in its font, on one line, never a set width.
  static let timeShapes = FigureShapes.shapes([ClockText.minutes(.distantPast)])

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
          SteadyFigure(time.map(Format.time) ?? Format.missing, shapes: Self.timeShapes, alignment: .trailing)
            .font(Tokens.Typography.annotation)
            .monospacedDigit()
            .foregroundStyle(Palette.textQuaternary)
        }
        if let row {
          HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
            StageTrack(colors: row.trackColors, title: row.furthest.title,
              titleColor: SymbolsOutcome(row).color)
              .fixedSize()
            if let why = SymbolsBoard.shortWhy(row) {
              Text(verbatim: why)
                .font(Tokens.Typography.annotation)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
        }
        // On the Fast movers tab only the signals that fired (mockup IOSSymbols).
        if fastMovers, let mover = line.mover {
          ChipFlow(spacing: Tokens.Space.s) {
            ForEach(SymbolsBoard.firedSignals(mover), id: \.self) { signal in
              MoverFigure(text: signal, fired: true)
            }
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
          SteadyFigure("", shapes: SymbolListRow.timeShapes)
            .font(Tokens.Typography.annotation)
            .monospacedDigit()
            .hidden()
            .overlay { SkeletonBlock(.line) }
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

/// The OPEN badge (teal) beside a symbol with an open position.
private struct SymbolTagBadge: View {
  let line: SymbolsLine

  var body: some View {
    if line.position {
      Badge(SymbolsText.position, color: Palette.accentText)
    }
  }
}

/// One fast mover on Home, as on the Mac Overview (mockup Main, IOSHome): the symbol, its one main
/// signal (`SymbolsBoard.mainReason`, the one furthest past its rule) and the bar's time. Texts
/// wrap, never cut; the three figures are on the Symbols screen's Fast movers tab. No badge: the
/// row says why it moved, nothing more.
struct FastMoverLine: View {
  let mover: FastMoverV1
  let rules: FastMoverRulesV1?

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
      SymbolText(mover.symbol)
        .font(Tokens.Typography.chip)
        .foregroundStyle(Palette.textPrimary)
      Text(verbatim: SymbolsBoard.mainReason(mover, rules: rules))
        .font(Tokens.Typography.subheadline)
        .foregroundStyle(Palette.warningText)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
      Text(verbatim: Format.time(mover.at.date))
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
    }
    .accessibilityElement(children: .combine)
  }
}

// MARK: - the Fast movers card on Home

/// The day's fast movers on Home (mockup IOSHome): the newest few rows, one main reason each,
/// then "Show all N ›" pushing the Symbols screen on its Fast movers tab. The rule that flags a
/// fast mover is behind the "i" beside the title, shown in place. A new mover rises in as it
/// arrives, a real event of the bot.
struct FastMoversCard: View {
  let movers: MoversV1?
  let failure: String?
  /// The Symbols screen on its Fast movers tab is pushed.
  @State private var showsAll = false
  /// The rule is shown under the title.
  @State private var showsRule = false

  /// Rows the card shows; the rest are on the Symbols screen.
  static let rowCap = 3

  /// The fast mover rule in one sentence, or why the bot sent none; nil before the movers are read.
  private var rule: String? {
    guard let movers else { return nil }
    return movers.rules.map(SymbolsBoard.fastRule) ?? movers.rulesCauseText
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      HStack(alignment: .center, spacing: Tokens.Space.s) {
        CardLabel(L10n.FastMovers.title)
        Spacer(minLength: 0)
        // Always there, so the header keeps its height while the movers load; dimmed until then.
        ruleButton
      }
      if showsRule, let rule {
        Text(verbatim: rule)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
          .transition(.opacity)
      }
      if let movers {
        if movers.movers.isEmpty {
          Text(verbatim: movers.rulesCauseText ?? String(localized: L10n.FastMovers.none))
            .font(Tokens.Typography.callout)
            .foregroundStyle(Palette.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
        }
        let shown = Array(movers.movers.prefix(Self.rowCap))
        ForEach(Array(shown.enumerated()), id: \.element.symbol) { index, mover in
          FastMoverLine(mover: mover, rules: movers.rules).rise(step: index)
        }
        .animation(Tokens.Motion.standard, value: shown.map(\.symbol))
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
    .loadsInPlace(movers != nil || failure != nil)
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, alignment: .leading)
    .tickrCard()
    .navigationDestination(isPresented: $showsAll) { SymbolsView(tab: .fastMovers) }
  }

  /// The "i" beside the title: shows or hides the rule, as on the Symbols screen.
  private var ruleButton: some View {
    Button {
      withAnimation(Tokens.Motion.quick) { showsRule.toggle() }
    } label: {
      Image(systemName: InfoCaption.infoSymbol)
        .font(Tokens.Typography.callout)
        .foregroundStyle(showsRule ? Palette.infoText : Palette.textTertiary)
        .frame(width: Tokens.Size.touchTarget, height: Tokens.Size.touchTarget)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(rule == nil)
    .accessibilityLabel(Text(SymbolsText.fastRuleLabel))
    .accessibilityAddTraits(showsRule ? .isSelected : [])
  }
}

// MARK: - detail

/// A symbol's detail, pushed from the list (mockup IOSSymbols): the symbol, when it was first seen,
/// its price and change and today's line, then what happened in one word and one caption with
/// its fast bar's signals, its steps today behind its footer link, and the chart link.
private struct SymbolDetailScreen: View {
  @Environment(AppModel.self) private var model
  /// Today's price line, kept while the same symbol's line is read again.
  @State private var dayLine: SymbolDayLine?
  @State private var shownLineSymbol: String?
  let line: SymbolsLine

  /// The line's price and change: live where the bot's quotes hold the symbol.
  private var shown: SymbolsPrice { SymbolsBoard.shown(line, live: model.livePrice(line.symbol)) }

  /// SF Symbols of the chart link, the fast mover's bolt and the path steps.
  static let chartSymbol = "chart.xyaxis.line"
  static let fastSymbol = "bolt.fill"
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
          // The shown day: "today", or the recorded day the line is of.
          Group {
            if model.isLive { Text(SymbolsText.today) } else { Text(verbatim: DayText.day(model.shownDay)) }
          }
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textQuaternary)
        }
        .task(id: line) { await readDayLine() }
        if let dayLine {
          let plotted = dayLine.plotted
          DayLine(closes: plotted.closes, previousClose: plotted.previousClose)
        }
      }
      if row != nil || line.mover != nil {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
          if let row {
            let headline = SymbolsBoard.headline(row)
            SymbolHeadline(headline.title, caption: headline.caption, color: SymbolsOutcome(row).headlineColor)
          }
          if let mover = line.mover {
            Label {
              Text(verbatim: SymbolsBoard.fastNote(mover, time: Format.time(mover.at.date)))
                .fixedSize(horizontal: false, vertical: true)
            } icon: {
              Image(systemName: Self.fastSymbol)
            }
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.warningText)
          }
          if let row {
            FooterDetail(SymbolsText.stepsToday,
              summary: String(localized: SymbolsText.stepsPassed(SymbolsBoard.stepsPassed(row), SymbolStage.allCases.count)),
              endsCard: false) {
              VStack(alignment: .leading, spacing: 0) {
                ForEach(SymbolsBoard.path(row)) { step in pathStep(step, row: row) }
              }
            }
          }
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
      time: step.mark == .ahead ? Format.missing : reachedAt.map(Format.time) ?? Format.missing, detail: detail,
      detailColor: detailColor, reached: step.mark != .ahead)
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
  /// One segment per stage (mockup IOSSymbols): passed teal, where it stands blue when waiting,
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
  /// ENTERED green, WAITING blue; SKIPPED, DROPPED and NOT REACHED neutral (mockup IOSSymbols).
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
