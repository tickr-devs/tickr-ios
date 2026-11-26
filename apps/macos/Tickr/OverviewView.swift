import Charts
import SwiftUI
import TickrDesign
import TickrKit

/// Overview: what the bot is doing now, its positions and protection, the day's result, and the
/// bot controls. For a recorded day it shows that day read-only.
struct OverviewView: View {
  @Environment(AppModel.self) private var model

  /// The order in which the cards rise in as the screen appears.
  private enum Order: Int { case header = 0, result, flow, watching, positions, middle, right }

  /// Positions of the cards in the screen's `CardGrid`.
  private enum Slot: Int {
    case header = 0, result, flow, watching, positions, safety, riskRoom, fastMovers, journal
  }

  /// Narrowest screen, in points, with the design's three columns of cards; below it the cards
  /// sit in two columns (MainNarrow v110).
  static let threeColumnsMinWidth: CGFloat = 1040
  /// The design's column widths (CSS fr units): Watching closely, Positions, Safety and the bot;
  /// then Risk room, Fast movers, the journal (Main v115).
  static let middleRowWeights: [CGFloat] = [1, 1.4, 1]
  static let bottomRowWeights: [CGFloat] = [1.15, 1.3, 0.95]
  /// Width of the day's result beside the header on the two-column board, in points
  /// (MainNarrow v110, 1024-point board: `width:250px`).
  static let dayResultNarrowWidth: CGFloat = 250
  /// Positions beside Safety · bot on the two-column board (MainNarrow v110, 1024-point board:
  /// `grid-template-columns:minmax(0,1.15fr) minmax(0,1fr)`), and two equal columns below them.
  static let positionsSafetyWeights: [CGFloat] = [1.15, 1]
  static let twoColumnWeights: [CGFloat] = [1, 1]
  /// Least height of the design's middle row (Watching closely, Positions, Safety and the bot),
  /// in points. The row grows to its tallest card, so every safety fact and watched row is in
  /// sight without a scroll inside a card.
  static let middleRowHeight: CGFloat = 298
  /// Least height of the bottom row (Risk room, Fast movers, the journal), in points. It takes
  /// the rest of the window's height as in the design, never less than this.
  static let bottomRowMinHeight: CGFloat = 150
  /// Padding around the cards on each side: the screen's widths above are the grid's plus twice this.
  static let padding = Tokens.Space.l
  /// Narrowest grid, in points, with the cards in two columns: two of the least grid column
  /// (`Tokens.Size.gridColumnMin`) and the gap between. Narrower (a window capped to a small
  /// display, `WindowFit`), the cards stack in one column, the Safety · bot card first after the
  /// header and the result, so its commands are reached without a sideways scroll.
  static let twoColumnsMinGridWidth: CGFloat = CardArrangement.columnsMinWidth(2)
  /// The same as a screen width: the grid and its padding.
  static let twoColumnsMinScreenWidth: CGFloat = twoColumnsMinGridWidth + padding * CardArrangement.paddedEdges
  /// Least size of the screen, in points: one column of cards and the padding; any height, the
  /// cards scroll. The window never scrolls the Overview sideways (`ScreenRoomFrame`).
  static let leastSize = CGSize(
    width: CardArrangement.columnsMinWidth(1) + padding * CardArrangement.paddedEdges, height: 0)

  /// The board for a grid `width` points wide: the arrangement `arrangements` picks for it.
  static func layout(gridWidth width: CGFloat) -> OverviewLayout {
    if width >= threeColumnsMinWidth - padding * CardArrangement.paddedEdges { return .board }
    if width >= headerBesideNarrowResultMinGridWidth { return .twoColumns }
    return width >= twoColumnsMinGridWidth ? .twoColumnsResultBelow : .oneColumn
  }

  /// Narrowest two-column grid, in points, with the day's result beside the header: the result's
  /// narrow column and its gap, beside the brand mark and the day controls (`DayControls`), the
  /// widest part of the header that never wraps. Narrower, the result is one line under it.
  static let headerBesideNarrowResultMinGridWidth: CGFloat = OverviewView.dayResultNarrowWidth + Tokens.Space.xl
    + Tokens.Size.logo + Tokens.Space.l
    + DayControls.stepperWidth(today: String(localized: L10n.Common.today))

  /// The design's grid at the widest (Main); two columns with the result beside the header, then
  /// one column with the Safety · bot card first after the header and the result (MainNarrow
  /// v110). The same cards in each: a resize moves them and never makes them anew. Below the
  /// design's grid every card is as tall as its content and the screen scrolls.
  static let arrangements: [CardArrangement] = [
    CardArrangement(minWidth: threeColumnsMinWidth - padding * CardArrangement.paddedEdges, rows: [
      headerBesideResult(Tokens.Size.dayResultWidth),
      single(.flow),
      weighted(middleRowWeights, [.watching, .positions, .safety], height: .atLeast(middleRowHeight)),
      weighted(bottomRowWeights, [.riskRoom, .fastMovers, .journal], height: .fillsRest(atLeast: bottomRowMinHeight)),
    ]),
    CardArrangement(minWidth: headerBesideNarrowResultMinGridWidth,
      rows: [headerBesideResult(OverviewView.dayResultNarrowWidth)] + twoColumnRows),
    CardArrangement(minWidth: twoColumnsMinGridWidth, rows: [single(.header), single(.result)] + twoColumnRows),
    CardArrangement(minWidth: 0, rows: [
      single(.header), single(.result), single(.safety), single(.flow), single(.positions), single(.watching),
      single(.riskRoom), single(.fastMovers), single(.journal),
    ]),
  ]

  /// Below the header and the result on the two-column board (MainNarrow v110, 1024 points).
  private static let twoColumnRows: [CardRow] = [
    single(.flow),
    sized(positionsSafetyWeights, [.positions, .safety]),
    single(.watching),
    sized(twoColumnWeights, [.riskRoom, .fastMovers]),
    single(.journal),
  ]

  /// The day's result in its own column `width` points wide beside the header, each at its own
  /// height.
  private static func headerBesideResult(_ width: CGFloat) -> CardRow {
    CardRow(
      columns: [
        CardColumn(width: .share(1), cards: [Slot.header.rawValue]),
        CardColumn(width: .fixed(width), cards: [Slot.result.rawValue]),
      ],
      linesUp: false, columnGap: Tokens.Space.xl)
  }

  /// Cards side by side, each as tall as its own content (the two-column board's
  /// `align-items:start`).
  private static func sized(_ weights: [CGFloat], _ slots: [Slot]) -> CardRow {
    CardRow(columns: zip(weights, slots).map { CardColumn(width: .share($0), cards: [$1.rawValue]) }, linesUp: false)
  }

  private static func single(_ slot: Slot) -> CardRow {
    CardRow(columns: [CardColumn(width: .share(1), cards: [slot.rawValue])])
  }

  private static func weighted(_ weights: [CGFloat], _ slots: [Slot], height: CardRow.Height = .natural) -> CardRow {
    CardRow(columns: zip(weights, slots).map { CardColumn(width: .share($0), cards: [$1.rawValue]) }, height: height)
  }

  var body: some View {
    // The visible height is read in the same layout pass that places the cards (no view state),
    // so the bottom row follows the window's edge during a resize instead of a pass behind it.
    GeometryReader { viewport in
      ScrollViewReader { proxy in
        ScrollView {
          CardGrid(arrangements: Self.arrangements, spacing: Tokens.Space.l,
            minHeight: max(viewport.size.height - Self.padding * CardArrangement.paddedEdges, 0)) {
            Header().rise(step: Order.header.rawValue)
            DayResult().rise(step: Order.result.rawValue)
            LiveFlowCard().rise(step: Order.flow.rawValue)
            WatchingCard().filling().rise(step: Order.watching.rawValue)
            PositionsCard().filling().rise(step: Order.positions.rawValue).id(PositionsCard.id)
            SafetyCard().filling().rise(step: Order.middle.rawValue).id(SafetyCard.id)
              // Also when a card above it changes height while the page's height stays the same
              // (the bottom row fills the rest), which moves it without a content-size change.
              .onGeometryChange(for: CGFloat.self) { $0.frame(in: .scrollView).minY } action: { _ in
                showSafetyFirstIfAsked(proxy)
              }
            Group {
              RiskRoomCard().filling()
              FastMoversCard().filling()
              JournalCard().filling()
            }
            .rise(step: Order.right.rawValue)
          }
          .padding(Self.padding)
          // The cards that change with the board (the day's result, Watching closely) read it
          // from the same width the grid picks its arrangement from.
          .environment(\.overviewLayout,
            Self.layout(gridWidth: viewport.size.width - Self.padding * CardArrangement.paddedEdges))
        }
        .scrollEdgeHints()
        // Also when the cards below grow: until they load, the page can be too short to bring the
        // card to the top.
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentSize.height } action: { _, _ in
          showSafetyFirstIfAsked(proxy)
        }
      }
    }
    // The cards wait under the launch's opening and rise as its mark flies to the header.
    .environment(\.risesHeld, !model.openingPlayed && !model.openingFlying)
    // "Show all" of Watching closely opens its full list over the cards.
    .watchingAllPanel()
    // Another day lands at once: no crossfade of one day's figures over the other's.
    .jumps(on: model.shownDay)
  }

  /// UI tests (`LayoutSweep.safetyFirst`, `LayoutSweep.positionsFirst`): the Safety · bot card
  /// or the Positions card at the top of the screen, kept there while the cards above it load, so
  /// a test clicks its commands without a scroll.
  private func showSafetyFirstIfAsked(_ proxy: ScrollViewProxy) {
    #if DEBUG
    if LayoutSweep.positionsFirst {
      proxy.scrollTo(PositionsCard.id, anchor: .top)
    } else if LayoutSweep.safetyFirst {
      proxy.scrollTo(SafetyCard.id, anchor: .top)
    }
    #endif
  }
}

/// Which of Overview's boards is shown (`OverviewView.arrangements`): the design's grid, two
/// columns, or one column (MainNarrow v110).
enum OverviewLayout {
  /// The design's three columns.
  case board
  /// Two columns, the day's result beside the header.
  case twoColumns
  /// Two columns, the header too narrow for the result beside it: the result under it on one line.
  case twoColumnsResultBelow
  /// One column.
  case oneColumn

  /// The day's result is one line under the header.
  var resultInline: Bool { self == .twoColumnsResultBelow || self == .oneColumn }
  /// Below the design's grid: cards are as tall as their content.
  var sized: Bool { self != .board }
}

extension EnvironmentValues {
  /// Overview's board for the cards that change with it (`OverviewView.layout(gridWidth:)`).
  @Entry var overviewLayout = OverviewLayout.board
}

// MARK: header

private struct Header: View {
  @Environment(AppModel.self) private var model
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.windowFit) private var fit

  var body: some View {
    HStack(alignment: .center, spacing: Tokens.Space.l) {
      // Drawn at once while the opening flies the mark here; it draws itself on later visits.
      // Muted while the link is down: nothing about the bot can be known, so no green mark.
      BrandMark(live: model.ornamentsMove(reduceMotion: reduceMotion) && !linkDown,
        tone: linkDown ? .muted : .brand, drawsIn: model.openingPlayed)
        // Hidden while the launch's opening flies its own mark here; shown as that one lands.
        .opacity(model.openingPlayed ? 1 : 0)
        .onGeometryChange(for: CGPoint.self) { proxy in
          let frame = proxy.frame(in: .global)
          return CGPoint(x: frame.midX, y: frame.midY)
        } action: { centre in
          // Only while the opening can still land here: afterwards a scroll would write the
          // model on every frame for nobody.
          if !model.openingPlayed { model.overviewMarkCentre = centre }
        }
      VStack(alignment: .leading, spacing: Tokens.Space.m) {
        if fit.titleBar.stepper {
          titleRow
        } else {
          // The day controls left the title bar (a window narrower than its comfortable width):
          // beside the name and its badges when they fit, else on their own line, right-aligned
          // (MainNarrow v110).
          ViewThatFits(in: .horizontal) {
            HStack(spacing: Tokens.Space.m) {
              titleRow
              Spacer(minLength: Tokens.Space.m)
              DayControls()
            }
            VStack(alignment: .trailing, spacing: Tokens.Space.s) {
              titleRow.frame(maxWidth: .infinity, alignment: .leading)
              DayControls()
            }
          }
        }
        // While the link is down the one connection banner above the screen says so; the
        // headline would only repeat it in red (owner, 2026-11-18).
        if !linkDown { banner }
      }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// The last read of the bot failed: the connection banner speaks for the whole screen.
  private var linkDown: Bool { model.connectionState.failure != nil }

  /// "Tickr Operator", the environment badge and, when the shown day needs a look, its verdict.
  private var titleRow: some View {
    // The badges go onto a second line rather than run past a narrow header (MainNarrow v110).
    WrapRow(spacing: Tokens.Space.m, lineSpacing: Tokens.Space.s) {
      HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
        Text(L10n.App.name).font(Tokens.Typography.title).foregroundStyle(Palette.infoText)
        Text(L10n.Common.operatorTitle).font(Tokens.Typography.subtitle).foregroundStyle(Palette.textPrimary)
      }
      // The product name never wraps ("Tickr Operat / or" in a narrow window): badges move first.
      .fixedSize()
      if let status = model.status {
        EnvironmentBadge(ApiText.environment(status.environment), raw: status.environment,
          accessibilityLabel: ApiText.environmentLabel(status.environment))
      }
      // The shown day's clean-day verdict from the bot's journal, only when it needs a look
      // (mockup Main: a clean day says nothing new here).
      if let clean = model.days.first(where: { $0.day == model.shownDay })?.clean, clean.verdict == .notClean {
        CleanBadge(clean: clean)
      }
    }
  }

  private var banner: some View {
    let content = content
    // The gate badge sits with the countdown beside the headline (mockup v108), live only.
    return HeadlineBanner(content.title, detail: content.detail, tone: content.tone, alarm: content.alarm,
      pulse: model.isLive ? AnyHashable(content.pulse) : nil, facts: model.isLive ? model.headlineFacts : nil)
      .modifier(AlarmPulse(active: content.alarm))
      .textSelection(.enabled)
  }

  private struct Content {
    let title: String
    let detail: String?
    let tone: Tone
    let alarm: Bool
    /// What the dot pulses on: the title, but a stale status's age is no new event.
    let pulse: Headline.Pulse
  }

  private var content: Content {
    if !model.isLive {
      let title = String(localized: L10n.Common.recordedDay(DayText.day(model.shownDay)))
      return Content(
        title: title, detail: String(localized: L10n.Overview.recordedDetail),
        tone: .highlight, alarm: false, pulse: .text(title))
    }
    let headline = model.headline
    return Content(title: headline.text, detail: headline.detail, tone: headline.tone,
      alarm: headline.severity == .alarm, pulse: headline.pulse)
  }
}

/// A steady red glow around something that needs attention now. It fades in when the alarm
/// starts and out when it ends, and stays still in between: motion only on a real change.
struct AlarmPulse: ViewModifier {
  let active: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Blur radius of the glow, in points.
  static let glow: CGFloat = 10

  func body(content: Content) -> some View {
    content
      .shadow(color: active ? Palette.loss.opacity(Tokens.Opacity.medium) : .clear, radius: Self.glow)
      .animation(reduceMotion ? nil : Tokens.Motion.standard, value: active)
  }
}

/// The day's result beside the header, right-aligned and large, as the design sets it apart
/// from the cards; on the one-column board one line under the header that wraps rather than cuts
/// (MainNarrow v110, 640-point board).
private struct DayResult: View {
  @Environment(AppModel.self) private var model
  @Environment(\.overviewLayout) private var layout
  @State private var counted: Decimal = 0
  /// The day `counted` is of: another day's result lands at once, never counting through values
  /// no day had.
  @State private var countedDay: WireDate?

  /// Size of the result's sparkline, in points, as the design draws it.
  static let sparklineWidth: CGFloat = 200
  static let sparklineHeight: CGFloat = 26

  var body: some View {
    Group {
      if model.connectionState.isNeverConnected || (model.isLive && model.status == nil) {
        // Nothing was ever read, or the bot has written no status: the result is unknown, never
        // "$0.00" (mockup "no connection" v2), on screen and to VoiceOver.
        VStack(alignment: layout.resultInline ? .leading : .trailing, spacing: Tokens.Space.xxs) {
          CardLabel(L10n.Overview.dayResult)
          Text(verbatim: ApiText.missing)
            .font(Tokens.Typography.display)
            .foregroundStyle(Palette.textQuaternary)
        }
        .frame(maxWidth: .infinity, alignment: layout.resultInline ? .leading : .trailing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(L10n.Overview.dayResultUnavailable))
      } else if model.dayPending {
        // The picked day's result is still being read: a skeleton, never "$0.00".
        VStack(alignment: layout.resultInline ? .leading : .trailing, spacing: Tokens.Space.xxs) {
          CardLabel(L10n.Overview.dayResult)
          Skeleton(L10n.Common.loading) { SkeletonLines(Tokens.Loading.fewLines, leadingValue: true) }
            .frame(width: Self.sparklineWidth)
        }
        .frame(maxWidth: .infinity, alignment: layout.resultInline ? .leading : .trailing)
      } else if layout.resultInline {
        WrapRow(spacing: Tokens.Space.m) {
          CardLabel(L10n.Overview.dayResult)
          MoneyText(value: counted, font: Tokens.Typography.display)
          Text(verbatim: subtitle).font(Tokens.Typography.annotation).foregroundStyle(Palette.textQuaternary)
          if model.shownResultBeforeFees { beforeFees }
          sparkline
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        VStack(alignment: .trailing, spacing: Tokens.Space.xxs) {
          CardLabel(L10n.Overview.dayResult)
          MoneyText(value: counted, font: Tokens.Typography.display)
          Text(verbatim: subtitle).font(Tokens.Typography.annotation).foregroundStyle(Palette.textQuaternary)
            .multilineTextAlignment(.trailing)
          if model.shownResultBeforeFees {
            // Wraps rather than cuts, in either language.
            beforeFees
              .multilineTextAlignment(.trailing)
              .fixedSize(horizontal: false, vertical: true)
          }
          sparkline
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
      }
    }
    .onAppear { countUp() }
    .onChange(of: model.shownResult) { countUp() }
    .onChange(of: model.shownDay) { countUp() }
  }

  private var beforeFees: some View {
    Text(L10n.Overview.beforeFees)
      .font(Tokens.Typography.annotation)
      .foregroundStyle(Palette.warningText)
  }

  private var sparkline: some View {
    DrawnSparkline(values: model.cumulativeResults, color: Palette.result(model.shownResult))
      .frame(width: Self.sparklineWidth, height: Self.sparklineHeight)
  }

  private var subtitle: String {
    var text = String(localized: L10n.Overview.dayCounts(model.shownTradeCount, model.shownWins, model.shownLosses))
    let unrealized = model.positions.compactMap(\.unrealized)
    // Only when every open position has a fresh price; a partial sum would mislead.
    if model.isLive && !model.positions.isEmpty && unrealized.count == model.positions.count {
      text += String(localized: L10n.Overview.openResult(Money.signedUSD(unrealized.reduce(0, +))))
    }
    return text
  }

  private func countUp() {
    // Only today's live result counts on; a recorded day's lands at once when read.
    let sameDay = countedDay == nil || countedDay == model.shownDay
    countedDay = model.shownDay
    withAnimation(sameDay && model.isLive ? Tokens.Motion.fill : nil) { counted = model.shownResult }
  }
}

// MARK: live flow

private struct LiveFlowCard: View {
  @Environment(AppModel.self) private var model
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Accessibility id of the card, for the UI tests.
  static let id = "overview-live-flow"

  var body: some View {
    Card(model.isLive ? L10n.Flow.title : L10n.Flow.titleRecorded) {
      // Live: a green dot and the New York time of the bot's last status write, as in the design.
      if model.isLive, let written = model.status?.writtenAt.date {
        HStack(spacing: Tokens.Space.xs) {
          PulseDot(Palette.profit, size: Tokens.Size.dotSmall, event: model.status?.botState)
          Text(L10n.Risk.clock(Format.marketTime(written)))
        }
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(Palette.textQuaternary)
      } else {
        Text(L10n.Flow.recorded)
          .font(Tokens.Typography.captionMono)
          .foregroundStyle(Palette.textQuaternary)
      }
    } content: {
      // The screeners' chips scrolling across the top, then the stages (mockup Main: no separate
      // latest-event line, the journal has every event). A picked day still being read shows a
      // skeleton in their place, never "nothing recorded yet".
      if model.dayPending || model.flowPending {
        Skeleton(L10n.Common.loading) { SkeletonLines(Tokens.Loading.fewLines) }
      } else if let chips = model.flow?.chips, !chips.isEmpty {
        FlowChips(chips: chips, moving: model.ornamentsMove(reduceMotion: reduceMotion))
      }
      // A failed /flow read: the stages and dots below then lack the day's flow.
      if let error = model.flowError {
        ReadFailureNote(L10n.Screener.unavailable(error), detail: nil)
      }
      let marks = self.marks
      Pipeline(stages: stages(marks), marks: marks, moving: model.isLive,
        sources: StageSources(flow: model.flow, skipped: model.skipped, watching: model.watching,
          status: model.isLive ? model.status : nil, settings: model.settings))
    }
    .accessibilityIdentifier(Self.id)
  }

  /// Today's symbols, each at its furthest stage.
  private var marks: [FlowMark] {
    FlowBoard.marks(flow: model.flow, skipped: model.skipped,
      positions: model.isLive ? model.status?.positions ?? [] : [])
  }

  private func stages(_ marks: [FlowMark]) -> [Pipeline.Stage] {
    let status = model.isLive ? model.status : nil
    // How many each early stage dropped of the one before it (mockup Main: "−144"), and how many
    // entries the risk limits refused.
    let funnel = FlowStages.dropped([flowCount(.screeners), flowCount(.universe), symbolCount(.quote),
      symbolCount(.bars)]).map { $0.map { String(localized: L10n.Flow.dropped($0)) } }
    let refused = marks.filter { $0.stage == .risk && $0.refused }.count
    let positions = status.map(Board.positions) ?? []
    // An open position whose stop is not verified outranks the day's count of verified stops.
    let unprotected = positions.first { !$0.stop.state.isProtected }
    // The one stage rule of both apps (`StopState.stageTone`): neutral with no position, else the
    // worst of the open and the day's stops.
    let stopTone = StopState.stageTone(open: positions.map(\.stop.state), day: (model.flow?.stops ?? []).map(\.state))
    return [
      .init(id: .screeners, name: L10n.Flow.screeners, value: count(.screeners),
        glyph: .screeners, color: Palette.accent, text: Palette.accentText),
      .init(id: .universe, name: L10n.Flow.universe, value: count(.universe), drop: funnel[1],
        glyph: .universe, color: Palette.seriesUniverse, text: Palette.seriesATRText),
      // Quote and bars come from GET /symbols only (the flow keeps its six stages for older apps).
      .init(id: .quote, name: L10n.Flow.quote, value: reached(.quote), note: model.symbolsError, drop: funnel[2],
        glyph: .quote, color: Palette.accent, text: Palette.accentText),
      .init(id: .bars, name: L10n.Flow.bars, value: reached(.bars), note: model.symbolsError, drop: funnel[3],
        glyph: .bars, color: Palette.info, text: Palette.infoText),
      .init(id: .strategy, name: L10n.Common.strategy,
        value: count(.strategy) ?? status.map { Format.strategy($0.strategy) },
        glyph: .strategy, color: Palette.highlight, text: Palette.highlightText),
      // The day's count, as in the design; only an entry block that needs the operator outranks
      // it. A calm pause ("not now") shows only when there is no count yet.
      .init(id: .risk, name: L10n.Common.risk,
        value: (status?.entryBlock?.attention == true ? String(localized: L10n.Flow.blocked) : nil)
          ?? count(.risk)
          ?? status?.entryBlock.map { _ in String(localized: L10n.Flow.waiting) }
          ?? status.map { _ in String(localized: L10n.Flow.entriesAllowed) },
        drop: refused > 0 ? String(localized: L10n.Flow.refusedCount(refused)) : nil,
        glyph: .risk, color: Palette.warning, text: Palette.warningText),
      .init(id: .order, name: L10n.Flow.order,
        value: count(.order) ?? status.map { String(localized: L10n.Flow.closedCount($0.tradesToday.count)) },
        glyph: .order, color: Palette.info, text: Palette.infoText),
      .init(id: .stop, name: L10n.Flow.brokerStop,
        value: unprotected.map { $0.stop.state.title } ?? count(.stop)
          ?? positions.first.map { $0.stop.state.title }
          ?? status.map { _ in String(localized: L10n.Common.noPosition) },
        glyph: .brokerStop, color: stopTone.fill, text: stopTone.text),
      .init(id: .reconcile, name: L10n.Flow.reconcile, value: reconcile.value, note: reconcile.note,
        glyph: .reconcile, color: Palette.infoText, text: Palette.infoText),
    ]
  }
}

extension LiveFlowCard {
  /// "412": how many symbols reached `stage` on the shown day; nil without a flow.
  fileprivate func count(_ stage: FlowStage) -> String? {
    flowCount(stage).map(Self.number)
  }

  /// "141": how many symbols got to `stage` (GET /symbols); nil before the symbols are read.
  fileprivate func reached(_ stage: SymbolStage) -> String? {
    symbolCount(stage).map(Self.number)
  }

  fileprivate func flowCount(_ stage: FlowStage) -> Int? {
    model.flow?.stages.first { $0.stage == stage }?.count
  }

  fileprivate func symbolCount(_ stage: SymbolStage) -> Int? {
    model.symbols?.stages.first { $0.stage == stage }?.count
  }

  /// A count of symbols, grouped as every number of the apps.
  fileprivate static func number(_ count: Int) -> String {
    Money.number(Decimal(count), fractionDigits: 0)
  }

  fileprivate var reconcile: FlowStages.Reconcile { model.shownReconcile }
}

extension Board.Event.Tone {
  var tickerTone: TickerItem.Tone {
    switch self {
    case .teal: return .teal
    case .green: return .green
    case .blue: return .blue
    case .amber: return .amber
    case .violet: return .violet
    case .red: return .red
    case .muted: return .muted
    }
  }

  /// The tone as a text colour, from the shared map (`Tone(_:)` in TickrDesign).
  var color: Color { TickrDesign.Tone(self).text }
}

/// The stages a setup passes through, on one line, with today's symbols as dots under the stage
/// each reached. Nothing moves on a timer: a dot flies to its new stage only when a read of the
/// bot's flow moves it there, a refused symbol drops into its stage's tray, and a stage pulses
/// once when its value changes. Hovering a stage highlights it; a click on a symbol stage opens
/// the Symbols screen on that stage's tab (every symbol, no caps); reconcile, which holds no
/// symbols, opens its detail (`StageDetailView`) in a popover anchored to it.
private struct Pipeline: View {
  /// The stages, in the order a setup passes them.
  enum StageID: Hashable {
    case screeners, universe, quote, bars, strategy, risk, order, stop, reconcile

    /// The flow stage whose symbols sit under this one; nil for quote, bars (GET /flow has no
    /// such stage) and reconcile.
    var flowStage: FlowStage? {
      switch self {
      case .screeners: .screeners
      case .universe: .universe
      case .strategy: .strategy
      case .risk: .risk
      case .order: .order
      case .stop: .stop
      case .quote, .bars, .reconcile: nil
      }
    }

    /// The stage of the detail a click opens.
    var pipeline: PipelineStage {
      switch self {
      case .screeners: .screeners
      case .universe: .universe
      case .quote: .quote
      case .bars: .bars
      case .strategy: .strategy
      case .risk: .risk
      case .order: .order
      case .stop: .stop
      case .reconcile: .reconcile
      }
    }
  }

  struct Stage: Identifiable {
    let id: StageID
    let name: LocalizedStringResource
    /// nil = the API does not report this stage yet.
    let value: String?
    /// Why the value is missing, shown as its tooltip; nil = the API does not report it.
    var note: String?
    /// The small line under the value: how many the stage dropped ("−144") or refused.
    var drop: String?
    /// The stage's line glyph, as on the board.
    let glyph: DesignGlyph
    /// Fill colour of the stage (ring, glow) and the colour of its name.
    let color: Color
    let text: Color
  }

  let stages: [Stage]
  /// Today's symbols, each at its furthest stage (FlowBoard).
  let marks: [FlowMark]
  /// The shown day is today: a stage whose value changes pulses once. On a past day nothing moves.
  let moving: Bool
  /// What the stages' details are built from (`StageDetail`).
  let sources: StageSources
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Namespace private var board
  /// The stage under the pointer, highlighted.
  @State private var hovered: StageID?
  /// The stage whose detail popover is open (reconcile only).
  @State private var open: StageID?
  @Environment(AppModel.self) private var model

  /// Most dots a stage shows, as in the design; the rest are counted ("+404").
  static let poolCap = 8
  /// Widest a stage's dots run before they wrap, in points (the design's).
  static let poolWidth: CGFloat = 104
  /// Blur of the soft glow around a reporting stage, in points.
  static let stageGlow: CGFloat = 9
  /// Blur of the glow around a stage under the pointer or with its detail open, in points.
  static let stageGlowHovered: CGFloat = 16

  var body: some View {
    // One row of stages while each keeps its ring and its longest word whole; else rows of five
    // and four (MainNarrow v110), so a name breaks only between its words. The track runs from
    // the centre of the first row's first ring to its last one's.
    StageRows(leastCellWidth: StageRows.leastCellWidth(names: stages.map { String(localized: $0.name) },
      values: stages.compactMap(\.value)),
      trackHeight: Tokens.Stroke.bold, trackY: Tokens.Size.stage / 2 + Tokens.Space.xs) {
      Capsule().fill(Palette.separatorStrong)
      ForEach(stages) { stage in
        column(stage)
      }
    }
    // A dot's flight is the change of its mark between two reads, never a loop.
    .animation(reduceMotion ? nil : Tokens.Motion.standard, value: marks)
  }

  /// A stage as a button: hovering highlights it, a click opens its symbols (or reconcile's detail).
  private func column(_ stage: Stage) -> some View {
    let lit = hovered == stage.id || open == stage.id
    return Button {
      if let tab = SymbolsTab(stage.id.pipeline) {
        withAnimation(reduceMotion ? nil : Tokens.Motion.standard) { model.symbolsTab = tab }
      } else {
        open = stage.id
      }
    } label: {
      columnBody(stage, lit: lit)
        .padding(.vertical, Tokens.Space.xs)
        .background {
          RoundedRectangle(cornerRadius: Tokens.Radius.medium)
            .fill(stage.color.opacity(lit ? Tokens.Opacity.wash : 0))
        }
        .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.medium))
    }
    .buttonStyle(.plain)
    .pointerStyle(.link)
    .onHover { inside in
      if inside {
        hovered = stage.id
      } else if hovered == stage.id {
        hovered = nil
      }
    }
    .animation(reduceMotion ? nil : Tokens.Motion.quick, value: lit)
    .popover(isPresented: Binding(get: { open == stage.id }, set: { if !$0 { open = nil } }), arrowEdge: .bottom) {
      StageDetailView(name: stage.name, color: stage.color, detail: StageDetail.make(stage.id.pipeline, from: sources))
    }
    .frame(maxWidth: .infinity)
    .accessibilityLabel(Text(stage.name))
    .accessibilityValue(Text(verbatim: stage.value ?? Format.missing))
    .accessibilityHint(Text(L10n.Flow.stageDetailsHint))
  }

  private func columnBody(_ stage: Stage, lit: Bool) -> some View {
    let reported = stage.value != nil
    let strength = reported ? 1 : Tokens.Opacity.faint
    return VStack(spacing: Tokens.Space.xs) {
      ZStack {
        Circle().fill(Palette.surface)
        // The design's tint: the stage colour over the card, stronger under the pointer.
        Circle().fill(stage.color.opacity((lit ? Tokens.Opacity.faint : Tokens.Opacity.glow) * strength))
        Circle().strokeBorder(stage.color.opacity(lit ? 1 : strength), lineWidth: Tokens.Stroke.bold)
        DesignGlyphView(stage.glyph, side: Tokens.Size.stageGlyph)
          .foregroundStyle(stage.color.opacity(reported || lit ? 1 : Tokens.Opacity.border))
      }
      .frame(width: Tokens.Size.stage, height: Tokens.Size.stage)
      .shadow(color: reported || lit ? stage.color.opacity(lit ? Tokens.Opacity.medium : Tokens.Opacity.faint) : .clear,
        radius: lit ? Self.stageGlowHovered : Self.stageGlow)
      // One pulse when the stage's value changes (a new count, a verified stop): a real event.
      .eventPulse(Circle(), color: stage.color, scale: Tokens.Motion.pulseScale,
        event: reported && moving ? stage.value : nil)
      Text(stage.name)
        .textCase(.uppercase)
        .font(Tokens.Typography.annotationBold)
        .tracking(Tokens.Typography.labelTracking)
        .foregroundStyle(reported ? stage.text : Palette.textQuaternary)
      if let value = stage.value {
        Text(verbatim: value)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textTertiary)
          .contentTransition(.numericText())
      } else {
        Text(verbatim: Format.missing)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
          .help(stage.note.map { Text(verbatim: $0) } ?? Text(L10n.Flow.notReported))
      }
      // How many the stage dropped or refused, small; the symbols left out and why on hover.
      if let drop = stage.drop {
        let out = stage.id.flowStage.map { flowStage in marks.filter { $0.stage == flowStage && $0.refused } } ?? []
        let line = Text(verbatim: drop)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(stage.id == .risk ? Palette.seriesATRText : Palette.textQuaternary)
          .contentTransition(.numericText())
        if out.isEmpty {
          line
        } else {
          line.hint(verbatim: out.map { [$0.id, $0.note].compactMap { $0 }.joined(separator: Format.itemSeparator) }
            .joined(separator: Format.lineSeparator))
        }
      }
      if let flowStage = stage.id.flowStage {
        // Only a stage that holds symbols shows its pool: empty boxes read as broken placeholders.
        // A stop dot is green unless its own stop is waiting or unconfirmed: one unprotected
        // position reddens the stage, never the day's other stops.
        let here = marks.filter { $0.stage == flowStage && !$0.refused }
        if !here.isEmpty {
          pool(here, color: flowStage == .stop ? Palette.profit : stage.color)
        }
      }
    }
    .frame(maxWidth: .infinity)
  }

  /// The symbols whose furthest stage this is, as dots under the stage's value, as the design
  /// draws them; past `poolCap` the rest are counted ("+404").
  private func pool(_ here: [FlowMark], color: Color) -> some View {
    CentredFlow(spacing: Tokens.Space.xs) {
      ForEach(here.prefix(Self.poolCap)) { mark in
        MarkDot(mark: mark, color: color)
          .matchedGeometryEffect(id: mark.id, in: board)
          .transition(.scale.combined(with: .opacity))
      }
      if here.count > Self.poolCap {
        Text(L10n.Flow.more(here.count - Self.poolCap))
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      }
    }
    .frame(maxWidth: Self.poolWidth)
  }
}

/// Dots in rows, each row centred, wrapping at the offered width: the design's pool. Not lazy, so
/// every dot exists and a moved one always flies.
private struct CentredFlow: Layout {
  let spacing: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let rows = rows(width: proposal.width ?? .infinity, subviews: subviews)
    let width = rows.map(\.width).max() ?? 0
    let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
    return CGSize(width: proposal.width ?? width, height: height)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    var y = bounds.minY
    for row in rows(width: bounds.width, subviews: subviews) {
      var x = bounds.minX + (bounds.width - row.width) / 2
      for index in row.indices {
        let size = subviews[index].sizeThatFits(.unspecified)
        subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
        x += size.width + spacing
      }
      y += row.height + spacing
    }
  }

  private struct Row {
    var indices: [Int] = []
    var width: CGFloat = 0
    var height: CGFloat = 0
  }

  private func rows(width: CGFloat, subviews: Subviews) -> [Row] {
    var rows: [Row] = []
    var row = Row()
    for index in subviews.indices {
      let size = subviews[index].sizeThatFits(.unspecified)
      let needed = row.indices.isEmpty ? size.width : row.width + spacing + size.width
      if needed > width, !row.indices.isEmpty {
        rows.append(row)
        row = Row()
      }
      row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
      row.height = max(row.height, size.height)
      row.indices.append(index)
    }
    if !row.indices.isEmpty { rows.append(row) }
    return rows
  }
}

/// One symbol on the live flow: filled in its stage's colour, amber while its broker stop waits,
/// red when it was never confirmed. Hover names it and why.
private struct MarkDot: View {
  let mark: FlowMark
  let color: Color

  var body: some View {
    let fill: Color = switch mark.tone {
    case .normal: color
    case .pending: Palette.warning
    case .alarm: Palette.loss
    }
    Circle().fill(fill)
      .frame(width: Tokens.Size.flowMark, height: Tokens.Size.flowMark)
      .hint(verbatim: [mark.id, mark.note].compactMap { $0 }.joined(separator: Format.lineSeparator))
      .accessibilityLabel(Text(verbatim: mark.id))
  }
}

// MARK: positions

private struct PositionsCard: View {
  @Environment(AppModel.self) private var model
  @AppStorage(ChartView.Keys.symbol) private var chartSymbol = ""
  @State private var selected: String?

  var body: some View {
    let rows = model.positions
    let shown = rows.first(where: { $0.id == selected }) ?? rows.first
    Card(title) {
      HStack(spacing: Tokens.Space.s) {
        // One tab per open position with its result, as in the design; a single position needs none.
        // A tab never wraps or cuts its words (owner report 2026-11-18: five positions stacked
        // "+$17.42" one character per line): when the results do not fit, the tabs show the
        // symbols alone, tinted by their result; when even those do not, they scroll sideways.
        if rows.count > 1 && model.stoppedPositions == nil {
          ViewThatFits(in: .horizontal) {
            tabs(rows, shown: shown, results: true)
            tabs(rows, shown: shown, results: false)
            ScrollView(.horizontal) { tabs(rows, shown: shown, results: false) }
              .withoutScrollIndicators()
          }
        }
        // Close all beside the tabs (mockup Main): it pauses entries, cancels the working entry
        // orders and closes every position; shown only while one is open.
        CloseAllButton()
        HeaderLink(L10n.Position.openChart, systemImage: AppSection.chartSymbol) {
          if let shown { chartSymbol = shown.position.symbol }
          model.section = .chart
        }
        .fixedSize()
        .disabled(rows.isEmpty)
      }
    } content: {
      if model.isLive, let stopped = model.stoppedPositions {
        // Bot stopped with positions open (boards Main, MainNarrow): the stopped bot's last
        // knowledge of them, in place of the live position view, with Start bot.
        StoppedPositionsPanel(stopped) { OverviewStartButton() }
      } else if let row = rows.first(where: { $0.id == selected }) ?? rows.first {
        PositionDetail(row: row)
          .id(row.id)
          .transition(.opacity.combined(with: .scale(scale: PositionsCard.switchScale)))
      } else {
        EmptyPositions()
      }
    }
    .animation(Tokens.Motion.standard, value: selected)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(Self.id)
  }

  /// Accessibility id of the card, for the UI tests.
  static let id = "overview-positions"

  /// Scale a position's detail starts from when the selection changes.
  static let switchScale = 0.98

  /// The positions' tabs in one row at their own width, with or without their results.
  private func tabs(_ rows: [PositionRow], shown: PositionRow?, results: Bool) -> some View {
    HStack(spacing: Tokens.Space.s) {
      ForEach(rows) { row in
        PositionTab(row: row, selected: row.id == shown?.id, showsResult: results) { selected = row.id }
      }
    }
    .fixedSize()
  }

  private var title: LocalizedStringResource {
    if model.connectionState.isNeverConnected { return L10n.Position.titleUnknown }
    let count = model.positions.count
    if let limit = model.settings?.risk.maxOpenPositions {
      return L10n.Position.titleOfLimit(count, limit)
    }
    return L10n.Position.title(count)
  }
}

/// A position's tab on the Positions card: its symbol and open result, outlined when shown.
private struct PositionTab: View {
  let row: PositionRow
  let selected: Bool
  /// Whether the open result is written beside the symbol; without it the symbol takes its colour.
  let showsResult: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: Tokens.Space.xs) {
        StopDot(row.position.stop.state)
        if showsResult || row.unrealized == nil {
          SymbolText(row.position.symbol).foregroundStyle(Palette.textPrimary)
        } else if let value = row.unrealized {
          SymbolText(row.position.symbol).foregroundStyle(Palette.result(value))
        }
        if showsResult, let value = row.unrealized {
          Text(verbatim: Money.signedUSD(value)).foregroundStyle(Palette.result(value))
        }
      }
      .fixedSize()
    }
    .buttonStyle(.chip(selected: selected))
    // The dot's state in words, as the iPhone's position tab says it; the result too, which the
    // narrow tab may not write.
    .accessibilityValue(Text(verbatim: [Board.stopStateTitle(row.position.stop.state),
      row.unrealized.map(Money.signedUSD)].compactMap { $0 }.joined(separator: Format.itemSeparator)))
    .help(Text(verbatim: row.unrealized.map(Money.signedUSD) ?? row.position.symbol))
  }
}

/// The selected position (mockup Main): its price line beside the symbol, the open result in
/// large, the stop with the broker's confirmation, the size, the price now with its R, the most
/// it can lose, and "Close ABCD", the close command for this position, which asks first.
private struct PositionDetail: View {
  let row: PositionRow

  /// Smallest size of the price chart, and width of the figures column, in points.
  static let chartMinWidth: CGFloat = 160
  static let chartMinHeight: CGFloat = 210
  static let figuresWidth: CGFloat = 200
  /// Accessibility id prefix of the position's close button.
  static let closePrefix = "position-close-"

  var body: some View {
    // The chart beside the figures; above them in a card too narrow for both (the two-column
    // Overview, MainNarrow v110), so no figure runs under the next card.
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .top, spacing: Tokens.Space.l) {
        chart
        // A long figure wraps inside the column the design gives it.
        facts.frame(width: Self.figuresWidth)
      }
      VStack(alignment: .leading, spacing: Tokens.Space.l) {
        chart
        facts
      }
    }
  }

  /// The price line; it opens the Chart on the position, as its "Open chart" does.
  private var chart: some View {
    ChartLink(row.position.symbol) {
      MiniChart(closes: row.line, entry: row.entry, stop: row.stop, live: row.price != nil)
        .frame(minWidth: Self.chartMinWidth, minHeight: Self.chartMinHeight)
    }
  }

  private var facts: some View {
    let symbol = row.position.symbol
    return VStack(alignment: .leading, spacing: Tokens.Space.s) {
      SymbolText(symbol).font(Tokens.Typography.figure).foregroundStyle(Palette.textPrimary)
      Group {
        if let value = row.unrealized {
          Text(verbatim: Money.signedUSD(value)).foregroundStyle(Palette.result(value))
        } else {
          Text(verbatim: Format.missing).foregroundStyle(Palette.textQuaternary)
        }
      }
      .font(Tokens.Typography.hero)
      .contentTransition(.numericText())
      .hint(L10n.Position.unrealized)
      stop
      Text(L10n.Position.sharesAt(Format.quantity(row.quantity), Money.price(row.entry)))
        .font(Tokens.Typography.caption)
        .foregroundStyle(Palette.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
      now
      line(Text(L10n.Position.maxLoss), value: Risk.plannedLoss(entry: row.entry, stop: row.stop,
        quantity: row.quantity).map(Money.usd) ?? Format.missing)
        .help(Text(L10n.Position.maxLossHelp))
      Spacer(minLength: Tokens.Space.s)
      BotCommandButton(action: .flatten(symbol: symbol), place: .window, size: .regular,
        title: L10n.Bot.closeSymbol(symbol), identifier: Self.closePrefix + symbol)
    }
  }

  /// The stop's glyph, "Protected" once the broker confirmed it (else the stop's state) and its price.
  private var stop: some View {
    let state = row.position.stop.state
    return HStack(spacing: Tokens.Space.s) {
      StopGlyph(state: state, symbol: row.position.symbol, price: row.position.stop.price, style: .compact)
      VStack(alignment: .leading, spacing: 0) {
        Group {
          if state == .verified { Text(L10n.Position.protected) } else { Text(verbatim: state.title) }
        }
        .font(Tokens.Typography.caption.weight(.semibold))
        .foregroundStyle(state.tone.text)
        Text(L10n.Position.stopLevel(Format.price(row.stop)))
          .font(Tokens.Typography.captionMono)
          .foregroundStyle(Palette.textTertiary)
      }
      .fixedSize(horizontal: false, vertical: true)
    }
    .accessibilityElement(children: .combine)
  }

  /// "Now 12.53 · 0.43 R"; with no current price, the newest bar's close and R, greyed, as of its time.
  private var now: some View {
    let stale = row.isStale
    let price = (row.price ?? row.latestClose).map { Format.price($0) } ?? Format.missing
    let result = (stale ? row.latestResultR : row.resultR).map(Risk.text) ?? Format.missing
    let label = stale ? row.lastBarAt.map { Text(L10n.Position.lastBarCloseAt(Format.marketMinute($0))) }
      ?? Text(L10n.Position.lastBarClose) : Text(L10n.Position.now)
    return line(label, value: [price, result].joined(separator: Format.itemSeparator), muted: stale)
      .help(stale ? row.lastBarAt.map { Text(L10n.Position.staleHelp(Format.marketMinute($0))) }
        ?? Text(L10n.Position.lastBarClose) : Text(L10n.Position.now))
  }

  /// A label and its figure on one line, wrapping rather than cut.
  private func line(_ label: Text, value: String, muted: Bool = false) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
      label.font(Tokens.Typography.caption).foregroundStyle(Palette.textTertiary)
      Text(verbatim: value)
        .font(Tokens.Typography.calloutMono)
        .foregroundStyle(muted ? Palette.textQuaternary : Palette.textPrimary)
        .contentTransition(.numericText())
    }
    .fixedSize(horizontal: false, vertical: true)
    .accessibilityElement(children: .combine)
  }
}

extension StopState {
  /// "Stop ✓", "No stop": the protection of a position, in the person's language.
  var title: String {
    switch self {
    case .verified: return String(localized: L10n.Stop.verified)
    case .pending: return String(localized: L10n.Stop.pending)
    case .missing: return String(localized: L10n.Stop.missing)
    case .unknown: return String(localized: L10n.Stop.unknown)
    }
  }
}

/// Closes since the entry (Swift Charts), with the entry and stop as dashed levels and a pulsing
/// last point. The line draws itself in; the levels stand from the start.
private struct MiniChart: View {
  /// Room above and below the values, as a share of their range.
  static let padShare = 0.12
  /// Least room, in dollars, so a flat line still has a visible scale.
  static let padMinimum = 0.01
  /// Plot keys of the two axes (the chart has its own accessibility label, so they are not read).
  static let barKey = "bar"
  static let priceKey = "price"

  let closes: [Decimal]
  let entry: Decimal
  let stop: Decimal?
  /// The price is current (the live bid or a fresh bar): the dot rings; else the line is dim.
  let live: Bool

  var body: some View {
    let values = closes.map(Self.double)
    Group {
      if values.count > 1 {
        let domain = priceDomain(LiveSparkline.window(values, .large))
        let bars = 0...(values.count - 1)
        ZStack {
          Chart {
            level(entry, color: Palette.info, label: Text(L10n.Position.entryLevel(Money.price(entry))))
            if let stop {
              level(stop, color: Palette.loss, label: Text(L10n.Position.stopLevel(Money.price(stop))))
            }
          }
          .plain(bars: bars, prices: domain)
          // Drawn in once; each new price glides the line's end and its dot, which rings while the
          // price is current. The same line as on the iPhone's position cards (mockup v116).
          LiveSparkline(values: values, live: live, scale: .large, domain: domain)
        }
      } else {
        Text(L10n.Position.waitingForBars)
          .font(Tokens.Typography.caption)
          .foregroundStyle(Palette.textQuaternary)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .padding(Tokens.Space.s)
    .background(Palette.surfaceSunken, in: RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(L10n.Position.chartLabel))
  }

  /// The price range shown: every close the line shows and each level, with some room above and
  /// below.
  private func priceDomain(_ values: [Double]) -> ClosedRange<Double> {
    let all = values + [Self.double(entry)] + (stop.map { [Self.double($0)] } ?? [])
    let lowest = all.min() ?? 0
    let highest = all.max() ?? 1
    let pad = max((highest - lowest) * Self.padShare, Self.padMinimum)
    return (lowest - pad)...(highest + pad)
  }

  private func level(_ price: Decimal, color: Color, label: Text) -> some ChartContent {
    RuleMark(y: .value(Self.priceKey, Self.double(price)))
      .foregroundStyle(color.opacity(Tokens.Opacity.overlay))
      .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.thin, dash: Tokens.Stroke.dash))
      .annotation(position: .top, alignment: .trailing, spacing: Tokens.Space.xxs) {
        label
          .font(Tokens.Typography.annotation)
          .foregroundStyle(color)
      }
  }

  static func double(_ value: Decimal) -> Double { NSDecimalNumber(decimal: value).doubleValue }
}

private extension View {
  /// A chart with no axes or legend over fixed bar and price ranges, so stacked charts line up.
  func plain(bars: ClosedRange<Int>, prices: ClosedRange<Double>) -> some View {
    chartXAxis(.hidden)
      .chartYAxis(.hidden)
      .chartLegend(.hidden)
      .chartXScale(domain: bars)
      .chartYScale(domain: prices)
  }
}

private struct EmptyPositions: View {
  @Environment(AppModel.self) private var model

  /// Size of the radar, and the least height of the empty state, in points.
  static let radar: CGFloat = 120
  static let minHeight: CGFloat = 200

  var body: some View {
    HStack(spacing: Tokens.Space.xl) {
      Radar().frame(width: Self.radar, height: Self.radar)
      VStack(alignment: .leading, spacing: Tokens.Space.s) {
        Group {
          if model.isLive { Text(L10n.Position.noPosition) } else { Text(L10n.Position.recordedDay) }
        }
        .font(.title3.weight(.semibold))
        Group {
          if model.isLive {
            Text(L10n.Position.waitingForSetup)
          } else {
            Text(L10n.Position.closedThisDay(model.shownTradeCount))
          }
        }
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textTertiary)
        if !model.isLive {
          HeaderLink(L10n.Position.openTrades, systemImage: AppSection.tradesSymbol) { model.section = .trades }
        }
      }
      Spacer()
    }
    // Fills the card the row stretches, centred in it, never a band of blank under the words.
    .frame(maxWidth: .infinity, minHeight: Self.minHeight, maxHeight: .infinity)
  }
}

/// A radar sweep with two blips while the bot scans for setups (ornament, as on the design).
private struct Radar: View {
  @Environment(AppModel.self) private var model
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase

  /// Rings, as a share of the radar's radius.
  static let rings = [1.0, 2.0 / 3, 1.0 / 3]
  /// Width of the sweep's tail.
  static let sweep = Angle.degrees(90)

  var body: some View {
    ZStack {
      ForEach(Self.rings, id: \.self) { scale in
        Circle().stroke(Palette.separatorStrong, lineWidth: Tokens.Stroke.thin).scaleEffect(scale)
      }
      // Core Animation turns the sweep (see RadarSweep).
      RadarSweep(
        color: Palette.accent.opacity(Tokens.Opacity.border), width: Self.sweep,
        blips: [Palette.highlight, Palette.accent],
        turning: model.ornamentsMove(reduceMotion: reduceMotion),
        active: scenePhase == .active)
        .allowsHitTesting(false)
    }
    .accessibilityHidden(true)
  }
}

// MARK: safety and bot

private struct SafetyCard: View {
  @Environment(AppModel.self) private var model
  /// Grows to its row's height (`filling()`), as a `Card` does.
  @Environment(\.cardFills) private var fills

  /// Accessibility id of the card, for the UI tests.
  static let id = "overview-safety"

  var body: some View {
    // One card as in the design (mockup Main): "Bot" with the bot's state, one status line that
    // opens every safety check, then Pause entries and Stop bot, always in reach.
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      // The state is a few words, always on one line.
      SectionHeader(L10n.Common.bot) { BotPill().fixedSize() }
      BotStatusLine()
      Spacer(minLength: 0)
      BotSection()
    }
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, maxHeight: fills ? .infinity : nil, alignment: .topLeading)
    .tickrCard(radius: Tokens.Radius.large)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(Self.id)
  }
}

/// The bot's commands at the foot of the Safety card, as the design draws them.
private struct BotSection: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      // While the link is down the controls are off and quiet grey, and the connection banner
      // says "commands off": no red line repeats it here (owner, 2026-11-18).
      // A close-and-stop shows its steps in place of the buttons (boards Main, MainNarrow),
      // driven only by the bot's status; a refusal brings the buttons back with its cause.
      if model.isLive, let rows = model.stopSteps {
        StopStepsSection(rows: rows)
      } else {
        BotControls()
          .grayscale(linkDown ? 1 : 0)
      }
      if model.isLive, let refusal = model.stopRefusal {
        Footnote(verbatim: refusal, color: Palette.lossText)
      }
      if !model.isLive {
        Footnote(L10n.Safety.offWhileRecorded)
      } else if model.response?.stale == true && !linkDown {
        Footnote(L10n.Safety.offWhileUntrusted, color: Palette.lossText)
      }
    }
  }

  private var linkDown: Bool { model.fetchError != nil }
}

// MARK: right column

private struct RiskRoomCard: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    Card(model.isLive ? L10n.RiskRoom.title : L10n.RiskRoom.recordedTitle) {
      HeaderLink(L10n.RiskRoom.details) { model.section = .risk }
    } content: {
      if !model.isLive {
        recorded
      } else if let risk = model.settings?.risk {
        // The shared card (mockup Main): the bot's own room, three facts, then the last entry in
        // one line with "Limits ›" opening every sizing limit. The app never computes a room the
        // bot did not report; whether the records agree is the Bot card's first check.
        let reservations = model.status?.openReservationsUsd?.value
        RiskRoomPanel(room: model.dailyRoom, limit: risk.maxDailyLossUsd.value, reserved: reservations, facts: [
          RiskFact(.netResult, RiskRoomText.netResult, value: Money.signedUSD(model.shownResult),
            color: Palette.result(model.shownResult)),
          RiskFact(.reservations, RiskRoomText.reservations, value: reservations.map(Money.usd) ?? Format.missing,
            color: reservations.map { Tone.amount($0, .warning).text } ?? Palette.textQuaternary),
          RiskFact(.positions, RiskRoomText.positions,
            value: String(localized: L10n.Common.countOf(model.positions.count, risk.maxOpenPositions))),
        ], sizing: model.watching.map { watching in
          EntrySizing(size: watching.latestSize, configured: SizingLimits(
            plannedLossUsd: risk.plannedLossUsd.value, notionalCapUsd: risk.positionNotionalCapUsd.value,
            dailyRoomUsd: model.dailyRoom), text: .money)
        }, summary: true)
        Spacer(minLength: 0)
      } else if let error = model.settingsError {
        ReadFailureNote(L10n.ReadFailed.settings, detail: error)
      } else {
        Footnote(L10n.RiskRoom.reading)
      }
    }
  }

  /// A recorded day: its own net result against the limit and whether its records agreed, then
  /// how its last entry was sized. The room left, the reservations and the positions are today's
  /// (Details), never mixed in here.
  @ViewBuilder private var recorded: some View {
    if model.dayPending {
      Skeleton(L10n.Common.loading) { SkeletonLines(Tokens.Loading.fewLines, leadingValue: true) }
    } else {
      VStack(spacing: Tokens.Space.s) {
        StatLine(L10n.RiskRoom.netResult, value: Money.signedUSD(model.shownResult), color: Palette.result(model.shownResult))
        StatLine(L10n.RiskRoom.limit, value: model.settings.map { Money.usd($0.risk.maxDailyLossUsd.value) } ?? Format.missing)
        let records = model.shownReconcile
        StatLine(L10n.RiskRoom.recordsAgree, value: records.value ?? Format.missing,
          color: records.agrees.map { $0 ? Palette.profitText : Palette.warningText } ?? Palette.textQuaternary)
          .help(records.note.map { Text(verbatim: $0) } ?? Text(L10n.RiskRoom.recordsAgree))
      }
      if let size = model.watching?.latestSize {
        EntrySizingSummary(sizing: EntrySizing(size: size, configured: nil, text: .money))
      }
      Spacer(minLength: 0)
      Footnote(L10n.RiskRoom.recordedNote)
    }
  }
}

private struct JournalCard: View {
  @Environment(AppModel.self) private var model

  /// Events the bot added while the card was on screen: each line washes once.
  @State private var arrived: Set<String> = []

  var body: some View {
    // A console on the sunken surface, as in the design; the lines are the shared journal's.
    Card(L10n.Journal.title, fill: Palette.surfaceSunken) {
      Text(L10n.Journal.latestFirst).font(Tokens.Typography.captionMono).foregroundStyle(Palette.textQuaternary)
    } content: {
      // The latest lines (at least `journalRows`, more in a tall window), then "Show all N ›".
      let events = lines
      if events.isEmpty {
        Group {
          if model.isLive || model.events != nil { Text(L10n.Journal.nothingYet) } else { Text(L10n.Journal.seeTrades) }
        }
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textTertiary)
      } else {
        CappedList(events, id: \.id, title: L10n.Journal.title, limit: Tokens.Lists.journalRows,
          spacing: 0) { _, event in JournalLine(event, arrived: arrived.contains(event.id)) }
        .textSelection(.enabled)
        .animation(Tokens.Motion.standard, value: events.map(\.id))
        .onArrival(of: events.map(\.id)) { arrived = $0 }
      }
    }
  }

  /// The shown day's journal; without it (an older bot), today's events from the status.
  private var lines: [Board.Event] {
    if let read = model.events { return Board.journal(read, price: Money.price) }
    return model.isLive ? (model.status.map(Board.events) ?? []) : []
  }
}

#if DEBUG
#Preview {
  OverviewView()
    .environment(PreviewAPI.model())
    .frame(width: PreviewAPI.windowWidth, height: PreviewAPI.windowHeight)
}
#endif
