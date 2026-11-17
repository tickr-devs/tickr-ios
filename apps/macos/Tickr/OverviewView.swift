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
    case header = 0, result, flow, watching, positions, safety, riskRoom, observers, fastMovers, journal
  }

  /// Narrowest screen, in points, with the design's three columns of cards; below it the cards
  /// sit in two columns (MainNarrow v110).
  static let threeColumnsMinWidth: CGFloat = 1040
  /// The design's column widths (CSS fr units): Watching closely, Positions, Safety and the bot;
  /// then Risk room, Observers, Fast movers, the journal.
  static let middleRowWeights: [CGFloat] = [1, 1.4, 1]
  static let bottomRowWeights: [CGFloat] = [1, 1, 1.2, 1.4]
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
  /// Least height of the bottom row (Risk room, Observers, the journal), in points. It takes
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
      weighted(bottomRowWeights, [.riskRoom, .observers, .fastMovers, .journal],
        height: .fillsRest(atLeast: bottomRowMinHeight)),
    ]),
    CardArrangement(minWidth: headerBesideNarrowResultMinGridWidth,
      rows: [headerBesideResult(OverviewView.dayResultNarrowWidth)] + twoColumnRows),
    CardArrangement(minWidth: twoColumnsMinGridWidth, rows: [single(.header), single(.result)] + twoColumnRows),
    CardArrangement(minWidth: 0, rows: [
      single(.header), single(.result), single(.safety), single(.flow), single(.positions), single(.watching),
      single(.riskRoom), single(.observers), single(.fastMovers), single(.journal),
    ]),
  ]

  /// Below the header and the result on the two-column board (MainNarrow v110, 1024 points).
  private static let twoColumnRows: [CardRow] = [
    single(.flow),
    sized(positionsSafetyWeights, [.positions, .safety]),
    single(.watching),
    sized(twoColumnWeights, [.riskRoom, .observers]),
    sized(twoColumnWeights, [.fastMovers, .journal]),
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
            PositionsCard().filling().rise(step: Order.positions.rawValue)
            SafetyCard().filling().rise(step: Order.middle.rawValue).id(SafetyCard.id)
            Group {
              RiskRoomCard().filling()
              ObserversCard().filling()
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
  }

  /// UI tests (`LayoutSweep.safetyFirst`): the Safety · bot card at the top of the screen, kept
  /// there while the cards above it load, so a test clicks its commands without a scroll.
  private func showSafetyFirstIfAsked(_ proxy: ScrollViewProxy) {
    #if DEBUG
    if LayoutSweep.safetyFirst { proxy.scrollTo(SafetyCard.id, anchor: .top) }
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
      BrandMark(live: model.ornamentsMove(reduceMotion: reduceMotion), drawsIn: model.openingPlayed)
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
        banner
      }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// "Tickr Operator", the environment badge and the shown day's clean-day verdict.
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
      // The shown day's clean-day verdict from the bot's journal, as in the design.
      if let clean = model.days.first(where: { $0.day == model.shownDay })?.clean {
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

  /// Size of the result's sparkline, in points, as the design draws it.
  static let sparklineWidth: CGFloat = 200
  static let sparklineHeight: CGFloat = 26

  var body: some View {
    Group {
      if layout.resultInline {
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
    withAnimation(Tokens.Motion.fill) { counted = model.shownResult }
  }
}

// MARK: live flow

private struct LiveFlowCard: View {
  @Environment(AppModel.self) private var model
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    Card(L10n.Flow.title) {
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
      // The latest event under the title, then the screeners' chips, as in the design.
      LatestEvent()
      if let chips = model.flow?.chips, !chips.isEmpty {
        FlowChips(chips: chips, moving: model.ornamentsMove(reduceMotion: reduceMotion))
      }
      // A failed /flow read: the stages and dots below then lack the day's flow.
      if let error = model.flowError {
        Footnote(L10n.Screener.unavailable(error), color: Palette.warningText)
      }
      Pipeline(stages: stages, marks: FlowBoard.marks(flow: model.flow, skipped: model.skipped,
        positions: model.isLive ? model.status?.positions ?? [] : []), moving: model.isLive,
        sources: StageSources(flow: model.flow, skipped: model.skipped, watching: model.watching,
          status: model.isLive ? model.status : nil, settings: model.settings))
    }
  }

  private var stages: [Pipeline.Stage] {
    let status = model.isLive ? model.status : nil
    let positions = status.map(Board.positions) ?? []
    // An open position whose stop is not verified outranks the day's count of verified stops.
    let unprotected = positions.first { !$0.stop.state.isProtected }
    // The one stage rule of both apps (`StopState.stageTone`): neutral with no position, else the
    // worst of the open and the day's stops.
    let stopTone = StopState.stageTone(open: positions.map(\.stop.state), day: (model.flow?.stops ?? []).map(\.state))
    return [
      .init(id: .screeners, name: L10n.Flow.screeners, value: count(.screeners, L10n.Flow.seen),
        glyph: .screeners, color: Palette.accent, text: Palette.accentText),
      .init(id: .universe, name: L10n.Flow.universe, value: count(.universe, L10n.Flow.stocks),
        glyph: .universe, color: Palette.seriesUniverse, text: Palette.seriesATRText),
      // Quote and bars come from GET /symbols only (the flow keeps its six stages for older apps).
      .init(id: .quote, name: L10n.Flow.quote, value: reached(.quote, L10n.Flow.quoted), note: model.symbolsError,
        glyph: .quote, color: Palette.accent, text: Palette.accentText),
      .init(id: .bars, name: L10n.Flow.bars, value: reached(.bars, L10n.Flow.liquid), note: model.symbolsError,
        glyph: .bars, color: Palette.info, text: Palette.infoText),
      .init(id: .strategy, name: L10n.Common.strategy,
        value: count(.strategy, L10n.Flow.decided) ?? status.map { Format.strategy($0.strategy) },
        glyph: .strategy, color: Palette.highlight, text: Palette.highlightText),
      // The day's count, as in the design; only an entry block that needs the operator outranks
      // it. A calm pause ("not now") shows only when there is no count yet.
      .init(id: .risk, name: L10n.Common.risk,
        value: (status?.entryBlock?.attention == true ? String(localized: L10n.Flow.blocked) : nil)
          ?? count(.risk, L10n.Flow.passed)
          ?? status?.entryBlock.map { _ in String(localized: L10n.Flow.waiting) }
          ?? status.map { _ in String(localized: L10n.Flow.entriesAllowed) },
        glyph: .risk, color: Palette.warning, text: Palette.warningText),
      .init(id: .order, name: L10n.Flow.order,
        value: count(.order, L10n.Flow.filled) ?? status.map { String(localized: L10n.Flow.closedCount($0.tradesToday.count)) },
        glyph: .order, color: Palette.info, text: Palette.infoText),
      .init(id: .stop, name: L10n.Flow.brokerStop,
        value: unprotected.map { $0.stop.state.title } ?? count(.stop, L10n.Flow.verified)
          ?? positions.first.map { $0.stop.state.title }
          ?? status.map { _ in String(localized: L10n.Common.noPosition) },
        glyph: .brokerStop, color: stopTone.fill, text: stopTone.text),
      .init(id: .reconcile, name: L10n.Flow.reconcile, value: reconcile.value, note: reconcile.note,
        glyph: .reconcile, color: Palette.infoText, text: Palette.infoText),
    ]
  }
}

extension LiveFlowCard {
  /// "412 seen": how many symbols reached `stage` on the shown day, in the stage's word; nil
  /// without a flow.
  fileprivate func count(_ stage: FlowStage, _ word: (Int) -> LocalizedStringResource) -> String? {
    model.flow?.stages.first { $0.stage == stage }.map { String(localized: word($0.count)) }
  }

  /// "141 quoted": how many symbols got to `stage` (GET /symbols), in the stage's word; nil
  /// before the symbols are read.
  fileprivate func reached(_ stage: SymbolStage, _ word: (Int) -> LocalizedStringResource) -> String? {
    model.symbols?.stages.first { $0.stage == stage }.map { String(localized: word($0.count)) }
  }

  fileprivate var reconcile: FlowStages.Reconcile {
    FlowStages.reconcile(liveFences: model.isLive ? model.status?.fences : nil, latest: model.flow?.reconcile)
  }
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
  /// Refused symbols a tray names before it counts the rest.
  static let trayNamed = 2
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
      if let flowStage = stage.id.flowStage {
        // Only a stage that holds symbols shows its pool or tray: empty boxes read as broken
        // placeholders. A stop dot is green unless its own stop is waiting or unconfirmed: one
        // unprotected position reddens the stage, never the day's other stops.
        let here = marks.filter { $0.stage == flowStage && !$0.refused }
        let out = marks.filter { $0.stage == flowStage && $0.refused }
        if !here.isEmpty {
          pool(here, color: flowStage == .stop ? Palette.profit : stage.color)
        }
        if (flowStage == .universe || flowStage == .risk) && !out.isEmpty {
          tray(out, title: flowStage == .universe ? L10n.Flow.trayExcluded : L10n.Flow.trayRefused,
            color: flowStage == .universe ? Palette.textQuaternary : Palette.seriesATRText)
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

  /// The symbols this stage left out or refused, named in a dashed tray as the design draws it:
  /// its word, then the first symbols and how many more; each one's reason on hover.
  private func tray(_ out: [FlowMark], title: LocalizedStringResource, color: Color) -> some View {
    let named = out.prefix(Self.trayNamed).map(\.id)
    let more = out.count - named.count
    let text = (named + (more > 0 ? [String(localized: L10n.Flow.more(more))] : [])).joined(separator: Format.itemSeparator)
    return HStack(spacing: Tokens.Space.xs) {
      Text(title).bold().foregroundStyle(color)
      Text(verbatim: text).foregroundStyle(Palette.textTertiary)
    }
    .font(Tokens.Typography.annotation)
    .padding(.horizontal, Tokens.Space.s)
    .padding(.vertical, Tokens.Space.xxs)
    .overlay {
      RoundedRectangle(cornerRadius: Tokens.Radius.small)
        .strokeBorder(color, style: StrokeStyle(lineWidth: Tokens.Stroke.thin, dash: Tokens.Stroke.dashFine))
    }
    // Wraps inside its stage's cell rather than run under the next stage's value.
    .fixedSize(horizontal: false, vertical: true)
    .hint(verbatim: out.map { [$0.id, $0.note].compactMap { $0 }.joined(separator: Format.itemSeparator) }
      .joined(separator: Format.lineSeparator))
    .accessibilityElement(children: .combine)
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
        if rows.count > 1 {
          ForEach(rows) { row in
            PositionTab(row: row, selected: row.id == shown?.id) { selected = row.id }
          }
        }
        HeaderLink(L10n.Position.openChart, systemImage: AppSection.chartSymbol) {
          if let shown { chartSymbol = shown.position.symbol }
          model.section = .chart
        }
        .disabled(rows.isEmpty)
      }
    } content: {
      if let row = rows.first(where: { $0.id == selected }) ?? rows.first {
        PositionDetail(row: row)
          .id(row.id)
          .transition(.opacity.combined(with: .scale(scale: PositionsCard.switchScale)))
      } else {
        EmptyPositions()
      }
    }
    .animation(Tokens.Motion.standard, value: selected)
  }

  /// Scale a position's detail starts from when the selection changes.
  static let switchScale = 0.98

  private var title: LocalizedStringResource {
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
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: Tokens.Space.xs) {
        StopDot(row.position.stop.state)
        SymbolText(row.position.symbol).foregroundStyle(Palette.textPrimary)
        if let value = row.unrealized {
          Text(verbatim: Money.signedUSD(value)).foregroundStyle(Palette.result(value))
        }
      }
    }
    .buttonStyle(.chip(selected: selected))
    // The dot's state in words, as the iPhone's position tab says it.
    .accessibilityValue(Text(verbatim: Board.stopStateTitle(row.position.stop.state)))
  }
}

private struct PositionDetail: View {
  @Environment(AppModel.self) private var model
  let row: PositionRow

  /// Smallest size of the price chart, and width of the figures column, in points.
  static let chartMinWidth: CGFloat = 160
  static let chartMinHeight: CGFloat = 210
  static let figuresWidth: CGFloat = 200

  var body: some View {
    // The chart beside the figures; above them in a card too narrow for both (the two-column
    // Overview, MainNarrow v110), so no figure runs under the next card.
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .top, spacing: Tokens.Space.l) {
        chart
        // A long figure ("Once · acknowledged") wraps inside the column the design gives it.
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
      MiniChart(closes: row.line, entry: row.entry, stop: row.stop)
        .frame(minWidth: Self.chartMinWidth, minHeight: Self.chartMinHeight)
    }
  }

  /// The symbol, its result, the entry, stop, size and time, and the stop's distance.
  private var facts: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      HStack(spacing: Tokens.Space.s) {
        StopGlyph(state: row.position.stop.state, symbol: row.position.symbol, price: row.position.stop.price,
          style: .tile)
        SymbolText(row.position.symbol).font(Tokens.Typography.metric)
        Spacer()
        if let value = row.unrealized {
          DeltaTag(value, text: Money.signedUSD(value), large: true)
            .hint(L10n.Position.unrealized)
        } else {
          Text(verbatim: Format.missing).foregroundStyle(Palette.textQuaternary)
        }
      }
      Grid(horizontalSpacing: Tokens.Space.s, verticalSpacing: Tokens.Space.s) {
        GridRow {
          IconMetric(Self.entrySymbol, label: L10n.Position.entry, value: Format.price(row.entry), tone: .info)
          IconMetric(StopState.levelSymbol, label: L10n.Position.stop, value: Format.price(row.stop),
            tone: row.position.stop.state.tone)
        }
        GridRow {
          IconMetric(Self.quantitySymbol, label: L10n.Position.quantity, value: Format.quantity(row.quantity))
          IconMetric(Self.openedSymbol, label: L10n.Position.opened,
            value: Format.marketMinute(row.position.openedAt.date))
        }
      }
      if let range = stopToLast {
        MeterBar(fraction: range.fraction, tone: range.tone, marks: [
          MeterMark(Format.price(row.stop), tone: .loss),
          MeterMark(Format.price(row.price)),
        ])
        .hint(L10n.Position.chartLabel)
      }
      figures
    }
  }

  /// Symbols of the position's figures.
  static let entrySymbol = "arrow.right.to.line"
  static let quantitySymbol = "number"
  static let openedSymbol = "clock"
  static let lastBarSymbol = "chart.bar.xaxis"
  static let maxLossSymbol = "arrow.down.to.line"
  static let rSymbol = "scalemass"
  static let sentSymbol = "paperplane"
  /// The stop-to-price meter spans this many risks (entry minus stop) above the stop, so the entry
  /// sits half way and a full meter is a 1 R gain.
  static let meterRisks: Decimal = 2

  private var figures: some View {
    VStack(spacing: Tokens.Space.s) {
      StatLine(label: lastBarLabel, value: lastBarValue, color: isStale ? Palette.textQuaternary : Palette.textPrimary,
        symbol: Self.lastBarSymbol)
        .help(staleHelp)
      StatLine(L10n.Position.maxLoss,
        value: Risk.plannedLoss(entry: row.entry, stop: row.stop, quantity: row.quantity).map(Money.usd)
          ?? Format.missing, symbol: Self.maxLossSymbol)
        .help(Text(L10n.Position.maxLossHelp))
      if isStale, let time = row.lastBarAt {
        StatLine(label: Text(L10n.Position.rAt(Format.marketMinute(time))),
          value: row.latestResultR.map(Risk.text) ?? Format.missing, color: Palette.textQuaternary, symbol: Self.rSymbol)
          .help(staleHelp)
      } else {
        StatLine(L10n.Position.rNow, value: row.resultR.map(Risk.text) ?? Format.missing, symbol: Self.rSymbol)
      }
      let sent = EntrySent.line(row.position.entry,
        cause: ApiText.prose(row.position.entryCauseCodes, text: row.position.entryCause))
      let line = StatLine(L10n.EntrySent.title, value: sent.text, color: sent.color, symbol: Self.sentSymbol)
      // A hint only when there is something to add (the bot's cause of a missing record).
      if let help = sent.help {
        line.hint(verbatim: help)
      } else {
        line
      }
    }
  }

  /// Where the last close sits between the stop (empty) and the entry's mirror above it (full):
  /// half way is the entry. Nothing without a stop or a close.
  private var stopToLast: (fraction: Double, tone: Tone)? {
    guard let stop = row.stop, let last = row.price, row.entry > stop else { return nil }
    let span = (row.entry - stop) * Self.meterRisks
    let fraction = NSDecimalNumber(decimal: (last - stop) / span).doubleValue
    return (fraction, last >= row.entry ? .profit : .warning)
  }

  private var lastBarLabel: Text {
    if let live = row.live {
      return Text(L10n.Position.bidAt(ClockText.seconds(live.quotedAt)))
    }
    if let time = row.lastBarAt {
      return Text(L10n.Position.lastBarCloseAt(Format.marketMinute(time)))
    }
    return Text(L10n.Position.lastBarClose)
  }

  private var lastBarValue: String {
    (row.price ?? row.latestClose).map { Format.price($0) } ?? Format.missing
  }

  /// The newest bar is too old to be the current price: shown greyed, as of its time.
  private var isStale: Bool { row.isStale }

  private var staleHelp: Text {
    guard isStale, let time = row.lastBarAt else { return Text(L10n.Position.lastBarClose) }
    return Text(L10n.Position.staleHelp(Format.marketMinute(time)))
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
  @State private var drawn: CGFloat = 0
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    let values = closes.map(Self.double)
    Group {
      if let last = values.last, values.count > 1 {
        let domain = priceDomain(values)
        let bars = 0...(values.count - 1)
        ZStack {
          Chart {
            level(entry, color: Palette.info, label: Text(L10n.Position.entryLevel(Money.price(entry))))
            if let stop {
              level(stop, color: Palette.loss, label: Text(L10n.Position.stopLevel(Money.price(stop))))
            }
          }
          .plain(bars: bars, prices: domain)
          Chart {
            ForEach(Array(values.enumerated()), id: \.offset) { point in
              LineMark(x: .value(Self.barKey, point.offset), y: .value(Self.priceKey, point.element))
                .foregroundStyle(Palette.accent)
                .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.bold, lineJoin: .round))
            }
            PointMark(x: .value(Self.barKey, values.count - 1), y: .value(Self.priceKey, last))
              .symbol { PulseDot(Palette.accent, event: values.count) }
          }
          .plain(bars: bars, prices: domain)
          // Each new M1 bar: the line and the last-price dot glide to their new places (and the
          // dot pulses once), still in between.
          .animation(reduceMotion ? nil : Tokens.Motion.standard, value: values.count)
          .reveal(drawn)
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
    .onAppear {
      if reduceMotion { drawn = 1 } else { withAnimation(Tokens.Motion.draw) { drawn = 1 } }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(L10n.Position.chartLabel))
  }

  /// The price range shown: every close and level, with some room above and below.
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

  /// Fence names the bot raises for a position or an open order it did not place (engine
  /// Fence.FOREIGN_POSITION and FOREIGN_ORDER). A fence kind is the name, then ":" and a key
  /// when it has one, as in "foreign-position:ABCD".
  static let foreignPositionFence = "foreign-position"
  static let foreignOrderFence = "foreign-order"
  /// Separator between a fence's name and its key (protocol value).
  static let fenceKeySeparator: Character = ":"

  /// Columns of the safety tiles, as in the design.
  static let tileColumns = 2

  var body: some View {
    // One card as in the design: "Safety · bot" with the bot's state and Stop bot, the safety
    // facts as tiles in two columns, then the commands. The tiles scroll when the card is short;
    // the commands never do, so they are always in reach.
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      // Stop bot beside the bot's state; under the header when the card is too narrow for both.
      // The state is one short word, always on one line: a pill that may wrap was squeezed by
      // the header's spacer to one letter per line instead of the button moving down.
      ViewThatFits(in: .horizontal) {
        SectionHeader(L10n.Safety.titleWithBot) {
          HStack(spacing: Tokens.Space.s) {
            BotPill().fixedSize()
            BotStopButton()
          }
        }
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
          SectionHeader(L10n.Safety.titleWithBot) { BotPill().fixedSize() }
          BotStopButton()
        }
      }
      ScrollsWhenTall {
        TimelineView(.periodic(from: .now, by: Tokens.Motion.clockTickSeconds)) { context in
          let list = rows(now: model.botTime(context.date))
          let lines = stride(from: 0, to: list.count, by: Self.tileColumns)
            .map { Array(list[$0..<min($0 + Self.tileColumns, list.count)]) }
          Grid(horizontalSpacing: Tokens.Space.s, verticalSpacing: Tokens.Space.xs) {
            ForEach(lines.indices, id: \.self) { index in
              GridRow {
                // Each fact opens Risk & account, where its details are.
                ForEach(lines[index]) { row in
                  LinkTile(L10n.Safety.opensRisk, radius: Tokens.Radius.small) {
                    model.section = .risk
                  } label: {
                    SafetyTile(symbol: row.symbol, label: row.label, value: row.value, tone: row.tone)
                  }
                }
              }
            }
          }
        }
      }
      Spacer(minLength: 0)
      BotSection()
    }
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, maxHeight: fills ? .infinity : nil, alignment: .topLeading)
    .tickrCard(radius: Tokens.Radius.large)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(Self.id)
  }

  private enum RowID: Hashable { case status, stops, entries, reconcile, stream, read, foreign }

  private struct Row: Identifiable {
    let id: RowID
    let label: LocalizedStringResource
    let value: String
    let tone: Tone
    /// The open positions' stops, for the stops row's symbol (the worst one's, never a fixed check).
    var stops: [StopState] = []

    /// Symbols of the rows.
    static let statusSymbol = "questionmark.circle"
    static let entriesSymbol = "paperplane"
    static let reconcileSymbol = "arrow.triangle.2.circlepath"
    static let streamSymbol = "waveform.path.ecg"
    static let readSymbol = "building.columns"
    static let foreignSymbol = "person.crop.circle.badge.questionmark"

    var symbol: String {
      switch id {
      case .status: return Self.statusSymbol
      case .stops: return StopState.combinedSymbol(stops)
      case .entries: return Self.entriesSymbol
      case .reconcile: return Self.reconcileSymbol
      case .stream: return Self.streamSymbol
      case .read: return Self.readSymbol
      case .foreign: return Self.foreignSymbol
      }
    }
  }

  private func rows(now: Date) -> [Row] {
    guard model.isLive, let status = model.status else {
      let value = String(localized: model.isLive ? L10n.Common.unavailable : L10n.Safety.recordedDay)
      return [Row(id: .status, label: L10n.Safety.status, value: value, tone: .neutral)]
    }
    let positions = Board.positions(status)
    let verified = positions.filter { $0.stop.state.isProtected }.count
    let fenceNames = Set(status.fences.map { String($0.kind.prefix { $0 != Self.fenceKeySeparator }) })
    // Positions or orders the bot did not place, in one tile.
    let foreign = fenceNames.contains(Self.foreignPositionFence) || fenceNames.contains(Self.foreignOrderFence)
    let stream = status.freshness.stream
    let entries = positions.map { (symbol: $0.symbol, entry: $0.entry) }
      + status.tradesToday.map { (symbol: $0.symbol, entry: $0.entry) }
    let sent = EntrySent.summary(entries)
    // The design's six tiles, in its order. The entry pause has no tile: Pause or Resume below
    // shows it.
    return [
      Row(id: .reconcile, label: L10n.Safety.reconciliation,
        value: status.fences.isEmpty
          ? String(localized: L10n.Safety.noFences) : String(localized: L10n.Common.fences(status.fences.count)),
        tone: status.fences.isEmpty ? .profit : .warning),
      Row(id: .stops, label: L10n.Safety.brokerStops,
        value: positions.isEmpty
          ? String(localized: L10n.Common.noPosition) : String(localized: L10n.Safety.verified(verified, positions.count)),
        tone: StopState.combinedTone(positions.map(\.stop.state)), stops: positions.map(\.stop.state)),
      Row(id: .entries, label: L10n.EntrySent.safetyRow,
        value: sent?.text ?? String(localized: L10n.Common.none), tone: sent?.tone ?? .neutral),
      Row(id: .stream, label: L10n.Safety.quoteStream, value: stream.title,
        tone: stream == .fresh ? .profit : stream == .off ? .neutral : .warning),
      Row(id: .read, label: L10n.Safety.lastBrokerRead,
        value: Format.age(since: status.freshness.lastBrokerReadAt?.date, now: now),
        tone: BrokerReadAge.tone(since: status.freshness.lastBrokerReadAt?.date, now: now,
          limits: BrokerReadAge.Limits(model.settings))),
      Row(id: .foreign, label: L10n.Safety.foreignAtBroker,
        value: String(localized: foreign ? L10n.Safety.present : L10n.Common.none),
        tone: foreign ? .loss : .profit),
    ]
  }
}

/// The bot's state as a pill, in the Safety card's header.
private struct BotPill: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    if let status = model.status {
      let running = status.botState == .running
      let isCurrent = model.isLive && model.fetchError == nil && model.response?.stale == false
      StatusPill(verbatim: status.entryStop ? String(localized: L10n.Common.entriesPaused) : status.botState.title,
        tone: status.entryStop ? .warning : running ? .accent : .neutral,
        live: running && isCurrent, event: [AnyHashable(status.botState), AnyHashable(status.entryStop)])
    }
  }
}

/// One safety fact as the design draws it: a sunken tile with its glyph, its name and its value.
private struct SafetyTile: View {
  let symbol: String
  let label: LocalizedStringResource
  let value: String
  let tone: Tone

  var body: some View {
    HStack(spacing: Tokens.Space.s) {
      StateGlyph(symbol, tone: tone, label: label, style: .compact)
      // The name above its value, each wrapping rather than cut.
      VStack(alignment: .leading, spacing: 0) {
        Text(label).font(Tokens.Typography.caption).foregroundStyle(Palette.textSecondary)
        Text(verbatim: value)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(tone.text)
          .contentTransition(.numericText())
      }
      // As tall as its words need: a long name wraps, never cut.
      .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
    }
    .padding(Tokens.Space.xs)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Palette.surfaceSunken, in: RoundedRectangle(cornerRadius: Tokens.Radius.small))
    .overlay {
      RoundedRectangle(cornerRadius: Tokens.Radius.small).strokeBorder(Palette.separator, lineWidth: Tokens.Stroke.thin)
    }
    .help(Text(verbatim: "\(String(localized: label)): \(value)"))
  }
}

/// The bot's commands at the foot of the Safety card, as the design draws them.
private struct BotSection: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      BotControls()
      if !model.isLive {
        Footnote(L10n.Safety.offWhileRecorded)
      } else if model.response?.stale == true || model.fetchError != nil {
        Footnote(L10n.Safety.offWhileUntrusted, color: Palette.lossText)
      }
    }
  }
}

// MARK: right column

private struct RiskRoomCard: View {
  @Environment(AppModel.self) private var model
  @State private var shown: Double = 0

  @State private var shownReserved: Double = 0

  var body: some View {
    Card(L10n.RiskRoom.title) {
      HeaderLink(L10n.RiskRoom.details) { model.section = .risk }
    } content: {
      if let risk = model.settings?.risk {
        let limit = risk.maxDailyLossUsd.value
        // The bot's own room for today; the app never computes one the bot did not report.
        let room = model.dailyRoom
        let fraction = room.map { limit > 0 ? NSDecimalNumber(decimal: $0 / limit).doubleValue : 0 } ?? 0
        let reservations = model.status?.openReservationsUsd?.value
        let reserved = reservations.map { limit > 0 ? NSDecimalNumber(decimal: $0 / limit).doubleValue : 0 } ?? 0
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
          if let room {
            MoneyText(value: room, font: Tokens.Typography.metric, colored: false, signed: false, tint: Palette.accentText)
          } else {
            Text(verbatim: Format.missing).font(Tokens.Typography.metric).foregroundStyle(Palette.textQuaternary)
          }
          Text(L10n.RiskRoom.left(Money.usd(limit))).font(Tokens.Typography.callout).foregroundStyle(Palette.textTertiary)
        }
        bar(room: fraction, reserved: reserved)
        VStack(spacing: Tokens.Space.s) {
          // The design's order: the net day, what open orders hold, the positions, the records.
          StatLine(L10n.RiskRoom.netResult, value: Money.signedUSD(model.shownResult), color: Palette.result(model.shownResult))
          StatLine(L10n.RiskRoom.reservations, value: reservations.map(Money.usd) ?? Format.missing,
            color: reservations.map { Tone.amount($0, .warning).text } ?? Palette.textQuaternary)
          let count = String(localized: L10n.Common.countOf(model.positions.count, risk.maxOpenPositions))
          StatLine(L10n.RiskRoom.positions, value: count)
          let records = FlowStages.reconcile(liveFences: model.isLive ? model.status?.fences : nil,
            latest: model.flow?.reconcile)
          StatLine(L10n.RiskRoom.recordsAgree, value: records.value ?? Format.missing,
            color: records.agrees.map { $0 ? Palette.profitText : Palette.warningText } ?? Palette.textQuaternary)
            .help(records.note.map { Text(verbatim: $0) } ?? Text(L10n.RiskRoom.recordsAgree))
        }
        if let size = model.watching?.latestSize {
          Spacer(minLength: 0)
          LatestSizeLine(size: size)
        }
      } else if let error = model.settingsError {
        ReadFailureNote(L10n.ReadFailed.settings, detail: error)
      } else {
        Footnote(L10n.RiskRoom.reading)
      }
    }
  }

  /// The room left (the bot's own, already net of the open reservations), then the reservations
  /// themselves, as in the design: the room in the accent colour, the reservations in amber after it.
  private func bar(room: Double, reserved: Double) -> some View {
    GeometryReader { proxy in
      HStack(spacing: 0) {
        Rectangle().fill(Palette.accent).frame(width: proxy.size.width * shown)
        Rectangle().fill(Palette.warning).frame(width: proxy.size.width * shownReserved)
        Spacer(minLength: 0)
      }
      .background(Palette.surfaceSunken)
      .clipShape(Capsule())
    }
    .frame(height: Tokens.Size.bar)
    .onAppear {
      withAnimation(Tokens.Motion.fill) {
        shown = Self.share(room)
        shownReserved = Self.clamped(reserved, after: Self.share(room))
      }
    }
    .onChange(of: [room, reserved]) { _, values in
      withAnimation(Tokens.Motion.fill) {
        shown = Self.share(values[0])
        shownReserved = Self.clamped(values[1], after: Self.share(values[0]))
      }
    }
    .accessibilityHidden(true)
  }

  /// A share of the bar, 0...1: the bot's room may be negative after a gap through a stop.
  static func share(_ value: Double) -> Double {
    min(max(value, 0), 1)
  }

  /// The reservations' share, never past the end of the bar.
  static func clamped(_ reserved: Double, after room: Double) -> Double {
    min(max(reserved, 0), max(1 - room, 0))
  }
}

/// The latest entry size the bot worked out today and what bound it, in amber mono at the foot of
/// the risk room, as in the design: "last size: QRTZ 20 sh · binding: daily room". Without a
/// binding the bot named it is a dash, with the bot's cause on hover when it gave one.
private struct LatestSizeLine: View {
  let size: LatestSizeV1

  var body: some View {
    // Without a binding the bot named, a dash (its cause, if any, is on hover).
    let binding = size.binding.map { binding in
      switch binding {
      case .dailyRoom: String(localized: L10n.RiskRoom.bindingDailyRoom)
      }
    } ?? Format.missing
    Text(L10n.RiskRoom.latestSize(size.symbol, Format.quantity(size.quantity.value), binding))
      .font(Tokens.Typography.captionMono)
      .foregroundStyle(Palette.warningText)
      .help(Text(verbatim: [String(localized: L10n.Watching.decidedAt(Format.marketMinute(size.at.date))),
        size.bindingCauseText].compactMap { $0 }.joined(separator: Format.lineSeparator)))
  }
}

private struct ObserversCard: View {
  @Environment(AppModel.self) private var model
  @Environment(AdvisorModel.self) private var advisor

  var body: some View {
    Card(L10n.Observers.title) {
      HeaderLink(L10n.Observers.lab) {
        // The Lab's cards, where the observers are, not the advisor page left open earlier.
        advisor.pageOpen = false
        model.section = .lab
      }
    } content: {
      if let observers = model.observers?.observers {
        if observers.isEmpty {
          Text(L10n.Observers.none).font(Tokens.Typography.callout).foregroundStyle(Palette.textTertiary)
        }
        // The design's compact rows: name and result, then a bar of the result against the
        // largest; the decisions are in the Lab and on hover.
        let largest = observers.compactMap { $0.resultGrossUSD.map { abs($0.value) } }.max() ?? 0
        ForEach(observers) { observer in
          OverviewObserverRow(observer: observer, largest: largest)
        }
      } else if model.observersError != nil {
        Footnote(L10n.Lab.observersUnavailable, color: Palette.warningText)
      }
      Spacer(minLength: 0)
      AdvisorRow()
    }
  }
}

/// The AI advisor under the observers: its leading run and how many wait for the owner, and
/// Review, which opens the run in the Lab.
private struct AdvisorRow: View {
  @Environment(AppModel.self) private var model
  @Environment(AdvisorModel.self) private var advisor

  var body: some View {
    // On one line while everything fits whole; in a narrow column the pill and the link go on
    // a line of their own, and in the narrowest one each on its own line, so no word is broken
    // or cut. The last arrangement is the narrowest: a `ViewThatFits` keeps its last child even
    // when it is wider than the column, which pushed the card over its neighbour (Fast movers).
    ViewThatFits(in: .horizontal) {
      HStack(spacing: Tokens.Space.s) {
        words.fixedSize()
        Spacer(minLength: Tokens.Space.s)
        HStack(spacing: Tokens.Space.s) { actions }
      }
      VStack(alignment: .leading, spacing: Tokens.Space.s) {
        words
        HStack(spacing: Tokens.Space.s) { actions }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      VStack(alignment: .leading, spacing: Tokens.Space.s) {
        words
        actions
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    // The design's violet strip at the foot of the card; all of it opens the Lab.
    .padding(.horizontal, Tokens.Space.m)
    .padding(.vertical, Tokens.Space.s)
    .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.medium))
    .onTapGesture(perform: open)
    .background(Palette.highlight.opacity(Tokens.Opacity.wash), in: RoundedRectangle(cornerRadius: Tokens.Radius.medium))
    .overlay {
      RoundedRectangle(cornerRadius: Tokens.Radius.medium)
        .strokeBorder(Palette.highlight.opacity(Tokens.Opacity.border), lineWidth: Tokens.Stroke.thin)
    }
  }

  private var words: some View {
    HStack(spacing: Tokens.Space.s) {
      Image(systemName: AdvisorLook.symbol).foregroundStyle(Palette.highlightText)
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        Text(L10n.Observers.advisor).font(Tokens.Typography.callout)
        if let lead = advisor.runs?.lead {
          Text(verbatim: lead.title)
            .font(Tokens.Typography.captionMono)
            .foregroundStyle(Palette.textQuaternary)
        }
      }
    }
  }

  /// The pill and the link, laid out by the stack around them (a row, or one under the other).
  @ViewBuilder private var actions: some View {
    if let count = advisor.runs?.awaitingReview, count > 0 {
      StatusPill(AdvisorWords.awaiting(count), tone: .highlight).fixedSize()
    }
    HeaderLink(advisor.runs?.lead == nil ? L10n.Observers.lab : AdvisorWords.review, tone: .highlight, action: open)
      .fixedSize()
  }

  /// Opens the Lab, on the latest proposal when there is one.
  private func open() {
    if let lead = advisor.runs?.lead { advisor.open(lead.id) }
    model.section = .lab
  }
}

/// An observer on the Overview as the design draws it: its version and what sets it apart from
/// the active strategy ("v3 · rel vol 1.5×", ObserverLabel), its result, and a
/// bar of the result's size against the largest observer's, violet for a gain, amber for a loss.
private struct OverviewObserverRow: View {
  let observer: ObserverV1
  /// The largest absolute result among the observers, in USD.
  let largest: Decimal

  var body: some View {
    let result = observer.resultGrossUSD?.value
    let share = result.map { largest > 0 ? NSDecimalNumber(decimal: abs($0) / largest).doubleValue : 0 } ?? 0
    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      HStack(spacing: Tokens.Space.s) {
        Text(verbatim: ObserverLabel.observer(observer))
        Spacer(minLength: Tokens.Space.s)
        if let result {
          Text(verbatim: Money.signedUSD(result)).foregroundStyle(Palette.result(result))
        } else {
          Text(verbatim: Format.missing).foregroundStyle(Palette.textQuaternary)
        }
      }
      .font(Tokens.Typography.calloutMono)
      GeometryReader { proxy in
        Capsule().fill(Palette.surfaceSunken)
          .overlay(alignment: .leading) {
            Capsule().fill((result ?? 0) >= 0 ? Palette.highlight : Palette.warning)
              .frame(width: proxy.size.width * share)
              // Grows in, then moves only when the observer's result changes.
              .grows(with: share)
          }
      }
      .frame(height: Tokens.Size.barThin)
    }
    .help(Text(verbatim: [String(localized: L10n.Lab.decisionCount(observer.decisions.count)),
      ApiText.prose(observer.resultCauseCodes, text: observer.resultCause)].compactMap { $0 }
      .joined(separator: Format.lineSeparator)))
    .accessibilityElement(children: .combine)
  }
}

private struct JournalCard: View {
  @Environment(AppModel.self) private var model
  /// Events the bot added in the latest read: each flashes once as it slides in.
  @State private var arrived: Set<Board.Event.ID> = []

  /// Most recent events shown here; the full journal is in Trades & days.
  static let shown = 10
  /// A new line's flash reaches half the gaps between the cells, so the line flashes as one.
  static let cellOutset = EdgeInsets(
    top: Tokens.Space.xs / 2, leading: Tokens.Space.s / 2, bottom: Tokens.Space.xs / 2, trailing: Tokens.Space.s / 2)

  var body: some View {
    // A console on the sunken surface, as in the design.
    Card(L10n.Journal.title, fill: Palette.surfaceSunken) {
      Text(L10n.Journal.latestFirst).font(Tokens.Typography.captionMono).foregroundStyle(Palette.textQuaternary)
    } content: {
      let events = model.isLive ? (model.status.map(Board.events) ?? []) : []
      if events.isEmpty {
        Group {
          if model.isLive { Text(L10n.Journal.nothingYet) } else { Text(L10n.Journal.seeTrades) }
        }
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textTertiary)
      } else {
        // Time and tag in fixed columns, so the lines read down like a log.
        Grid(alignment: .leading, horizontalSpacing: Tokens.Space.s, verticalSpacing: Tokens.Space.xs) {
          ForEach(events.prefix(Self.shown)) { event in
            GridRow {
              let new = arrived.contains(event.id)
              Text(verbatim: Format.marketTime(event.time)).foregroundStyle(Palette.textQuaternary)
                .arrivalFlash(new, color: event.tone.color, outset: Self.cellOutset)
              Text(verbatim: event.tag).fontWeight(.bold).foregroundStyle(event.tone.color)
                .arrivalFlash(new, color: event.tone.color, outset: Self.cellOutset)
              Text(verbatim: event.text).foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .arrivalFlash(new, color: event.tone.color, outset: Self.cellOutset)
            }
            .font(Tokens.Typography.captionMono)
            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
          }
        }
        .animation(Tokens.Motion.standard, value: events.map(\.id))
        .onArrival(of: events.prefix(Self.shown).map(\.id)) { arrived = $0 }
        .textSelection(.enabled)
      }
    }
  }
}

#if DEBUG
#Preview {
  OverviewView()
    .environment(PreviewAPI.model())
    .environment(PreviewAPI.advisor())
    .frame(width: PreviewAPI.windowWidth, height: PreviewAPI.windowHeight)
}
#endif
