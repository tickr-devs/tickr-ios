import ApertureDesign
import ApertureKit
import Charts
import SwiftUI

/// Overview: what the bot is doing now, its positions and protection, the day's result, and the
/// bot controls. For a recorded day it shows that day read-only.
struct OverviewView: View {
  @Environment(AppModel.self) private var model

  /// The order in which the cards rise in as the screen appears.
  private enum Order: Int { case header = 0, result, flow, watching, positions, middle, right }

  /// Columns of the three-column grid the Positions card spans.
  static let positionsColumns = 2
  /// Narrowest screen, in points, with the day's result beside the header: the mark, the name,
  /// its badges and the result column. Measured on the screen's width, which the window sets, so
  /// the choice never feeds back into it.
  static let headerBesideResultMinWidth: CGFloat = 1000

  @State private var headerBesideResult = true

  var body: some View {
    ScrollView {
      VStack(spacing: Tokens.Space.l) {
        // The day's result beside the header; under it on a narrower screen (side by side they
        // were wider than a 1000-point window and pushed every card off the right edge).
        if headerBesideResult {
          HStack(alignment: .top, spacing: Tokens.Space.xl) {
            Header().rise(step: Order.header.rawValue)
            DayResult().frame(width: Tokens.Size.dayResultWidth).rise(step: Order.result.rawValue)
          }
        } else {
          VStack(alignment: .leading, spacing: Tokens.Space.l) {
            Header().rise(step: Order.header.rawValue)
            DayResult().rise(step: Order.result.rawValue)
          }
        }
        LiveFlowCard().rise(step: Order.flow.rawValue)
        WatchingCard().rise(step: Order.watching.rawValue)
        // The design's grid: positions over two columns beside safety and the bot, then risk room,
        // observers and the journal in three equal columns, each row's cards one height. A window
        // too narrow for three columns stacks the cards instead.
        ViewThatFits(in: .horizontal) {
          Grid(horizontalSpacing: Tokens.Space.l, verticalSpacing: Tokens.Space.l) {
            GridRow {
              positions.gridCellColumns(Self.positionsColumns)
              middleColumn
            }
            GridRow {
              Group {
                RiskRoomCard().filling()
                ObserversCard().filling()
                JournalCard().filling()
              }
              .gridColumn()
              .rise(step: Order.right.rawValue)
            }
          }
          VStack(spacing: Tokens.Space.l) {
            positions
            HStack(alignment: .top, spacing: Tokens.Space.l) {
              middleColumn
              VStack(spacing: Tokens.Space.l) {
                RiskRoomCard()
                ObserversCard()
                JournalCard()
              }
              .rise(step: Order.right.rawValue)
            }
          }
        }
      }
      .padding(Tokens.Space.xl)
    }
    .onGeometryChange(for: Bool.self) { [threshold = Self.headerBesideResultMinWidth] in $0.size.width >= threshold } action: {
      headerBesideResult = $0
    }
  }

  private var positions: some View {
    PositionsCard()
      .filling()
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .rise(step: Order.positions.rawValue)
  }

  private var middleColumn: some View {
    VStack(spacing: Tokens.Space.l) {
      SafetyCard()
      BotCard().filling()
    }
    .gridColumn()
    .rise(step: Order.middle.rawValue)
  }
}

// MARK: header

private struct Header: View {
  @Environment(AppModel.self) private var model

  /// Symbols of the trading gate, open and closed.
  static let gateOpenSymbol = "lock.open.fill"
  static let gateClosedSymbol = "lock.fill"

  var body: some View {
    HStack(alignment: .center, spacing: Tokens.Space.l) {
      // Drawn at once while the opening flies the mark here; it draws itself on later visits.
      BrandMark(live: model.isCurrent, drawsIn: model.openingPlayed)
        .onGeometryChange(for: CGPoint.self) { proxy in
          let frame = proxy.frame(in: .global)
          return CGPoint(x: frame.midX, y: frame.midY)
        } action: { centre in
          model.overviewMarkCentre = centre
        }
      VStack(alignment: .leading, spacing: Tokens.Space.m) {
        HStack(spacing: Tokens.Space.m) {
          HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
            Text(L10n.App.name).font(Tokens.Typography.title).foregroundStyle(Palette.infoText)
            Text(L10n.Common.operatorTitle).font(Tokens.Typography.subtitle).foregroundStyle(Palette.textPrimary)
          }
          // The product name never wraps ("Tickr Operat / or" in a narrow window): badges give way first.
          .lineLimit(1)
          .fixedSize()
          #if DEBUG
          // Fixture data looks live; say so on the screen it would be mistaken on.
          if PreviewAPI.servesFixtures {
            Badge(L10n.Overview.fixtures, color: Palette.warningText).help(Text(L10n.Overview.fixturesHelp))
          }
          #endif
          if let status = model.status {
            Badge(verbatim: status.environment, color: Palette.warningText)
            let open = status.tradingGate.open
            StateGlyph(open ? Self.gateOpenSymbol : Self.gateClosedSymbol, tone: open ? .profit : .warning,
              label: Text(verbatim: String(localized: open ? L10n.Overview.gateOpen : L10n.Overview.gateClosed)
                + Format.lineSeparator + ApiText.gate(status.tradingGate)))
          }
        }
        banner
      }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var banner: some View {
    let content = content
    let shape = RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
    return HStack(spacing: Tokens.Space.m) {
      PulseDot(content.color, pulsing: model.isLive, event: content.title)
      Text(verbatim: content.title).font(Tokens.Typography.button).foregroundStyle(content.color)
        .lineLimit(1)
        .fixedSize()
      if let detail = content.detail {
        // Wraps to as many lines as it needs: a narrow window cut the cause of a block mid-sentence.
        Text(verbatim: detail).font(Tokens.Typography.callout).foregroundStyle(Palette.textTertiary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(Tokens.Space.m)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(content.color.opacity(Tokens.Opacity.wash), in: shape)
    .overlay(shape.strokeBorder(content.color.opacity(Tokens.Opacity.border)))
    .modifier(AlarmPulse(active: content.alarm))
    .textSelection(.enabled)
  }

  private struct Content {
    let title: String
    let detail: String?
    let color: Color
    let alarm: Bool
  }

  private var content: Content {
    if !model.isLive {
      return Content(
        title: String(localized: L10n.Common.recordedDay(Format.dayLabel(model.shownDay))),
        detail: String(localized: L10n.Overview.recordedDetail),
        color: Palette.highlightText, alarm: false)
    }
    let headline = model.headline
    var detail: String?
    if let status = model.status, model.fetchError == nil, model.response?.stale == false {
      let positions = Board.positions(status)
      if positions.isEmpty {
        detail = String(localized: L10n.Overview.noOpenPosition)
      } else {
        let protected = positions.filter { $0.stop.state == .verified }.count
        detail = String(localized: L10n.Overview.protectedPositions(positions.count, protected))
      }
    }
    return Content(title: headline.text, detail: detail, color: headline.severity.color,
      alarm: headline.severity == .alarm)
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
/// from the cards.
private struct DayResult: View {
  @Environment(AppModel.self) private var model
  @State private var counted: Decimal = 0

  /// Width of the result's sparkline, in points.
  static let sparklineWidth: CGFloat = 200
  /// Smallest scale a long result shrinks to before it truncates.
  static let minimumScale = 0.7

  var body: some View {
    VStack(alignment: .trailing, spacing: Tokens.Space.xs) {
      CardLabel(L10n.Overview.dayResult)
      MoneyText(value: counted, usd: true, font: Tokens.Typography.display)
        .lineLimit(1)
        .minimumScaleFactor(Self.minimumScale)
      Text(verbatim: subtitle).font(Tokens.Typography.annotation).foregroundStyle(Palette.textQuaternary)
      DrawnSparkline(values: model.cumulativeResults, color: Palette.result(model.shownResult))
        .frame(width: Self.sparklineWidth, height: Tokens.Size.sparkline)
    }
    .frame(maxWidth: .infinity, alignment: .trailing)
    .onAppear { countUp() }
    .onChange(of: model.shownResult) { countUp() }
  }

  private var subtitle: String {
    var text = String(localized: L10n.Overview.dayCounts(model.shownTradeCount, model.shownWins, model.shownLosses))
    let unrealized = model.positions.compactMap(\.unrealized)
    // Only when every open position has a fresh price; a partial sum would mislead.
    if model.isLive && !model.positions.isEmpty && unrealized.count == model.positions.count {
      text += String(localized: L10n.Overview.openResult(Money.signed(unrealized.reduce(0, +))))
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

  /// SF Symbols of the pipeline stages.
  static let screenersSymbol = "magnifyingglass"
  static let universeSymbol = "line.3.horizontal.decrease"
  static let strategySymbol = "chart.bar"
  static let riskSymbol = "shield"
  static let orderSymbol = "bolt"
  static let stopSymbol = "lock"
  static let reconcileSymbol = "arrow.triangle.2.circlepath"

  var body: some View {
    Card(L10n.Flow.title) {
      // Live: a green dot and the New York time of the bot's last status write, as in the design.
      if model.isLive, let written = model.status?.writtenAt.date {
        HStack(spacing: Tokens.Space.xs) {
          PulseDot(Palette.profit, size: Tokens.Size.dotSmall, event: written)
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
      LatestEvent()
      Pipeline(stages: stages, marks: FlowBoard.marks(flow: model.flow, skipped: model.skipped), moving: model.isLive)
    }
  }

  private var stages: [Pipeline.Stage] {
    let status = model.isLive ? model.status : nil
    let positions = status.map(Board.positions) ?? []
    // An open position whose stop is not verified outranks the day's count of verified stops.
    let unprotected = positions.first { $0.stop.state != .verified }
    // Green only while every open position's stop is verified at the broker.
    // and no trade of the day ended without one (or with one the bot cannot account for).
    let stopVerified = positions.allSatisfy { $0.stop.state == .verified }
      && !(model.flow?.stops ?? []).contains { $0.state == .neverVerified || $0.state == .unknown }
    let stopColor = stopVerified ? Palette.profit : Palette.loss
    let stopText = stopVerified ? Palette.profitText : Palette.lossText
    return [
      .init(id: .screeners, name: L10n.Flow.screeners, value: count(.screeners, L10n.Flow.seen), symbol: Self.screenersSymbol,
        color: Palette.accent, text: Palette.accentText),
      .init(id: .universe, name: L10n.Flow.universe, value: count(.universe, L10n.Flow.stocks), symbol: Self.universeSymbol,
        color: Palette.seriesUniverse, text: Palette.seriesATRText),
      .init(id: .strategy, name: L10n.Common.strategy,
        value: count(.strategy, L10n.Flow.decided) ?? status.map { Format.strategy($0.strategy) },
        symbol: Self.strategySymbol, color: Palette.highlight, text: Palette.highlightText),
      // The day's count, as in the design; only an entry block that needs the operator outranks
      // it. A calm pause ("not now") shows only when there is no count yet.
      .init(id: .risk, name: L10n.Common.risk,
        value: (status?.entryBlock?.attention == true ? String(localized: L10n.Flow.blocked) : nil)
          ?? count(.risk, L10n.Flow.passed)
          ?? status?.entryBlock.map { _ in String(localized: L10n.Flow.waiting) }
          ?? status.map { _ in String(localized: L10n.Flow.entriesAllowed) },
        symbol: Self.riskSymbol, color: Palette.warning, text: Palette.warningText),
      .init(id: .order, name: L10n.Flow.order,
        value: count(.order, L10n.Flow.filled) ?? status.map { String(localized: L10n.Flow.closedCount($0.tradesToday.count)) },
        symbol: Self.orderSymbol, color: Palette.info, text: Palette.infoText),
      .init(id: .stop, name: L10n.Flow.brokerStop,
        value: unprotected.map { $0.stop.state.title } ?? count(.stop, L10n.Flow.verified)
          ?? positions.first.map { $0.stop.state.title }
          ?? status.map { _ in String(localized: L10n.Common.noPosition) },
        symbol: Self.stopSymbol, color: stopColor, text: stopText),
      .init(id: .reconcile, name: L10n.Flow.reconcile, value: reconcile.value, note: reconcile.note,
        symbol: Self.reconcileSymbol, color: Palette.info, text: Palette.infoText),
    ]
  }
}

extension LiveFlowCard {
  /// "412 seen": how many symbols reached `stage` on the shown day, in the stage's word; nil
  /// without a flow.
  fileprivate func count(_ stage: FlowStage, _ word: (Int) -> LocalizedStringResource) -> String? {
    model.flow?.stages.first { $0.stage == stage }.map { String(localized: word($0.count)) }
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

  var color: Color {
    switch self {
    case .teal: return Palette.accentText
    case .green: return Palette.profitText
    case .blue: return Palette.infoText
    case .amber: return Palette.warningText
    case .violet: return Palette.highlightText
    case .red: return Palette.lossText
    case .muted: return Palette.textTertiary
    }
  }
}

/// The stages a setup passes through, on one line, with today's symbols as dots under the stage
/// each reached. Nothing moves on a timer: a dot flies to its new stage only when a read of the
/// bot's flow moves it there, a refused symbol drops into its stage's tray, and a stage pulses
/// once when its value changes.
private struct Pipeline: View {
  /// The stages, in the order a setup passes them.
  enum StageID: Hashable {
    case screeners, universe, strategy, risk, order, stop, reconcile

    /// The flow stage whose symbols sit under this one; nil for reconcile.
    var flowStage: FlowStage? {
      switch self {
      case .screeners: .screeners
      case .universe: .universe
      case .strategy: .strategy
      case .risk: .risk
      case .order: .order
      case .stop: .stop
      case .reconcile: nil
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
    let symbol: String
    /// Fill colour of the stage (ring, glow) and the colour of its name.
    let color: Color
    let text: Color
  }

  let stages: [Stage]
  /// Today's symbols, each at its furthest stage (FlowBoard).
  let marks: [FlowMark]
  /// The shown day is today: a stage whose value changes pulses once. On a past day nothing moves.
  let moving: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Namespace private var board

  /// Most dots a stage shows; the rest are counted ("+388").
  static let poolCap = 24
  /// Blur of the soft glow around a reporting stage, in points.
  static let stageGlow: CGFloat = 9

  var body: some View {
    ZStack(alignment: .top) {
      GeometryReader { proxy in
        let inset = proxy.size.width / CGFloat(stages.count) / 2
        // The track runs from the centre of the first stage to the centre of the last.
        let width = proxy.size.width - proxy.size.width / CGFloat(stages.count)
        Capsule().fill(Palette.separatorStrong)
          .frame(width: width, height: Tokens.Stroke.bold)
          .offset(x: inset, y: (Tokens.Size.stage - Tokens.Stroke.bold) / 2)
      }
      HStack(alignment: .top, spacing: 0) {
        ForEach(stages) { stage in
          column(stage)
        }
      }
      // A dot's flight is the change of its mark between two reads, never a loop.
      .animation(reduceMotion ? nil : Tokens.Motion.standard, value: marks)
    }
  }

  private func column(_ stage: Stage) -> some View {
    let reported = stage.value != nil
    let strength = reported ? 1 : Tokens.Opacity.faint
    return VStack(spacing: Tokens.Space.s) {
      ZStack {
        Circle().fill(Palette.surface)
        Circle().fill(stage.color.opacity(Tokens.Opacity.wash * strength))
        Circle().strokeBorder(stage.color.opacity(strength), lineWidth: Tokens.Stroke.bold)
        Image(systemName: stage.symbol)
          .font(Tokens.Typography.stageSymbol)
          .foregroundStyle(stage.color.opacity(reported ? 1 : Tokens.Opacity.border))
      }
      .frame(width: Tokens.Size.stage, height: Tokens.Size.stage)
      .shadow(color: reported ? stage.color.opacity(Tokens.Opacity.faint) : .clear, radius: Self.stageGlow)
      // One pulse when the stage's value changes (a new count, a verified stop): a real event.
      .eventPulse(Circle(), color: stage.color, scale: Tokens.Motion.pulseScale,
        event: reported && moving ? stage.value : nil)
      Text(stage.name)
        .textCase(.uppercase)
        .font(Tokens.Typography.annotationBold)
        .tracking(Tokens.Typography.labelTracking)
        .foregroundStyle(reported ? stage.text : Palette.textQuaternary)
        .lineLimit(1)
      if let value = stage.value {
        Text(verbatim: value)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textTertiary)
          .lineLimit(1)
          .contentTransition(.numericText())
      } else {
        Text(verbatim: Format.missing)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
          .help(stage.note.map { Text(verbatim: $0) } ?? Text(L10n.Flow.notReported))
      }
      if let flowStage = stage.id.flowStage, !marks.isEmpty {
        pool(marks.filter { $0.stage == flowStage && !$0.refused }, color: stage.color)
        if flowStage == .universe || flowStage == .risk {
          tray(marks.filter { $0.stage == flowStage && $0.refused },
            title: flowStage == .universe ? L10n.Flow.trayExcluded : L10n.Flow.trayRefused)
        }
      }
    }
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .contain)
  }

  /// The symbols whose furthest stage this is, as dots; past `poolCap` the rest are counted.
  private func pool(_ here: [FlowMark], color: Color) -> some View {
    VStack(spacing: Tokens.Space.xs) {
      CentredFlow(spacing: Tokens.Space.xs) {
        ForEach(here.prefix(Self.poolCap)) { mark in
          MarkDot(mark: mark, color: color)
            .matchedGeometryEffect(id: mark.id, in: board)
            .transition(.scale.combined(with: .opacity))
        }
      }
      if here.count > Self.poolCap {
        Text(L10n.Flow.more(here.count - Self.poolCap))
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      }
    }
    .padding(Tokens.Space.xs)
    .frame(maxWidth: .infinity, minHeight: Tokens.Size.flowPool, alignment: .top)
    .background(Palette.surfaceSunken, in: RoundedRectangle(cornerRadius: Tokens.Radius.medium))
    .overlay {
      RoundedRectangle(cornerRadius: Tokens.Radius.medium).strokeBorder(Palette.separator, lineWidth: Tokens.Stroke.thin)
    }
    .padding(.horizontal, Tokens.Space.xs)
  }

  /// The symbols this stage refused, as outlined dots in a dashed tray, the reason on hover.
  private func tray(_ out: [FlowMark], title: LocalizedStringResource) -> some View {
    VStack(spacing: Tokens.Space.xxs) {
      Text(title)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
      CentredFlow(spacing: Tokens.Space.xs) {
        ForEach(out.prefix(Self.poolCap)) { mark in
          MarkDot(mark: mark, color: Palette.loss)
            .matchedGeometryEffect(id: mark.id, in: board)
            .transition(.scale.combined(with: .opacity))
        }
      }
      .padding(Tokens.Space.xs)
      .frame(maxWidth: .infinity, minHeight: Tokens.Size.flowMark + Tokens.Space.s)
      .overlay {
        RoundedRectangle(cornerRadius: Tokens.Radius.medium)
          .strokeBorder(Palette.separatorStrong, style: StrokeStyle(lineWidth: Tokens.Stroke.thin, dash: Tokens.Stroke.dashFine))
      }
    }
    .padding(.horizontal, Tokens.Space.xs)
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
/// red when it was never confirmed; an outline when refused. Hover names it and why.
private struct MarkDot: View {
  let mark: FlowMark
  let color: Color

  var body: some View {
    let fill: Color = switch mark.tone {
    case .normal: color
    case .pending: Palette.warning
    case .alarm: Palette.loss
    }
    Group {
      if mark.refused {
        Circle().strokeBorder(Palette.loss, lineWidth: Tokens.Stroke.regular)
      } else {
        Circle().fill(fill)
      }
    }
    .frame(width: Tokens.Size.flowMark, height: Tokens.Size.flowMark)
    .hint(verbatim: [mark.id, mark.note].compactMap { $0 }.joined(separator: Format.lineSeparator))
    .accessibilityLabel(Text(verbatim: mark.id))
  }
}

// MARK: positions

private struct PositionsCard: View {
  @Environment(AppModel.self) private var model
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
        MoreButton(L10n.Position.openChart, systemImage: AppSection.chartSymbol) { model.section = .chart }
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
        Circle()
          .fill(row.position.stop.state == .verified ? Palette.profit : Palette.loss)
          .frame(width: Tokens.Size.dotSmall, height: Tokens.Size.dotSmall)
        Text(verbatim: row.position.symbol).foregroundStyle(Palette.textPrimary)
        if let value = row.unrealized {
          Text(verbatim: Money.signed(value)).foregroundStyle(Palette.result(value))
        }
      }
    }
    .buttonStyle(.chip(selected: selected))
  }
}

private struct PositionDetail: View {
  @Environment(AppModel.self) private var model
  let row: PositionRow

  /// Smallest size of the price chart, and width of the figures column, in points.
  static let chartMinWidth: CGFloat = 260
  static let chartMinHeight: CGFloat = 210
  static let figuresWidth: CGFloat = 250

  var body: some View {
    HStack(alignment: .top, spacing: Tokens.Space.l) {
      MiniChart(closes: row.closes, entry: row.entry, stop: row.stop)
        .frame(minWidth: Self.chartMinWidth, minHeight: Self.chartMinHeight)
      VStack(alignment: .leading, spacing: Tokens.Space.m) {
        HStack(spacing: Tokens.Space.s) {
          StopBadge(state: row.position.stop.state, read: model.status?.freshness.lastBrokerReadAt?.date)
          Text(verbatim: row.position.symbol).font(Tokens.Typography.metric)
          Spacer()
          if let value = row.unrealized {
            DeltaTag(value, text: Money.signed(value), large: true)
              .hint(L10n.Position.unrealized)
          } else {
            Text(verbatim: Format.missing).foregroundStyle(Palette.textQuaternary)
          }
        }
        Grid(horizontalSpacing: Tokens.Space.s, verticalSpacing: Tokens.Space.s) {
          GridRow {
            IconMetric(Self.entrySymbol, label: L10n.Position.entry, value: Format.price(row.entry), tone: .info)
            IconMetric(Self.stopSymbol, label: L10n.Position.stop, value: Format.price(row.stop),
              tone: row.position.stop.state == .verified ? .profit : .loss)
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
            MeterMark(Format.price(row.lastBarClose)),
          ])
          .hint(L10n.Position.chartLabel)
        }
        figures
      }
      .frame(width: Self.figuresWidth)
    }
  }

  /// Symbols of the position's figures.
  static let entrySymbol = "arrow.right.to.line"
  static let stopSymbol = "shield.lefthalf.filled"
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
        value: Risk.plannedLoss(entry: row.entry, stop: row.stop, quantity: row.quantity).map { Money.plain($0) }
          ?? Format.missing, symbol: Self.maxLossSymbol)
        .help(Text(L10n.Position.maxLossHelp))
      if isStale, let time = row.lastBarAt {
        StatLine(label: Text(L10n.Position.rAt(Format.marketMinute(time))),
          value: row.latestResultR.map(Risk.text) ?? Format.missing, color: Palette.textQuaternary, symbol: Self.rSymbol)
          .help(staleHelp)
      } else {
        StatLine(L10n.Position.rNow, value: row.resultR.map(Risk.text) ?? Format.missing, symbol: Self.rSymbol)
      }
      let sent = EntrySent.line(row.position.entry, cause: row.position.entryCause)
      StatLine(L10n.EntrySent.title, value: sent.text, color: sent.color, symbol: Self.sentSymbol)
        .hint(sent.help.map { Text(verbatim: $0) } ?? Text(L10n.EntrySent.title))
    }
  }

  /// Where the last close sits between the stop (empty) and the entry's mirror above it (full):
  /// half way is the entry. Nothing without a stop or a close.
  private var stopToLast: (fraction: Double, tone: Tone)? {
    guard let stop = row.stop, let last = row.lastBarClose, row.entry > stop else { return nil }
    let span = (row.entry - stop) * Self.meterRisks
    let fraction = NSDecimalNumber(decimal: (last - stop) / span).doubleValue
    return (fraction, last >= row.entry ? .profit : .warning)
  }

  private var lastBarLabel: Text {
    if let time = row.lastBarAt {
      return Text(L10n.Position.lastBarCloseAt(Format.marketMinute(time)))
    }
    return Text(L10n.Position.lastBarClose)
  }

  private var lastBarValue: String {
    (row.lastBarClose ?? row.latestClose).map { Format.price($0) } ?? Format.missing
  }

  /// The newest bar is too old to be the current price: shown greyed, as of its time.
  private var isStale: Bool { row.lastBarClose == nil && row.latestClose != nil }

  private var staleHelp: Text {
    guard isStale, let time = row.lastBarAt else { return Text(L10n.Position.lastBarClose) }
    return Text(L10n.Position.staleHelp(Format.marketMinute(time)))
  }
}

/// A position's protection as a shield glyph: green when the broker stop is verified, red otherwise,
/// pulsing once per broker read that still finds it unprotected; the state's words are its hint.
struct StopBadge: View {
  let state: StopState
  var compact = false
  /// The bot's last broker read: an unprotected stop pulses once per read that still finds it so.
  var read: Date?

  /// Symbols of the stop states.
  static let verifiedSymbol = "checkmark.shield.fill"
  static let pendingSymbol = "hourglass"
  static let missingSymbol = "xmark.shield.fill"
  static let unknownSymbol = "exclamationmark.shield.fill"

  var body: some View {
    StateGlyph(symbol, tone: state == .verified ? .profit : state == .pending ? .warning : .loss,
      label: Text(verbatim: state.title), live: state != .verified, event: read, style: compact ? .compact : .tile)
  }

  private var symbol: String {
    switch state {
    case .verified: return Self.verifiedSymbol
    case .pending: return Self.pendingSymbol
    case .missing: return Self.missingSymbol
    case .unknown: return Self.unknownSymbol
    }
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
            level(entry, color: Palette.info, label: Text(L10n.Position.entryLevel(Money.plain(entry))))
            if let stop {
              level(stop, color: Palette.loss, label: Text(L10n.Position.stopLevel(Money.plain(stop))))
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
          MoreButton(L10n.Position.openTrades, systemImage: AppSection.tradesSymbol) { model.section = .trades }
        }
      }
      Spacer()
    }
    .frame(minHeight: Self.minHeight)
  }
}

/// A slow radar sweep while the bot scans for setups.
private struct Radar: View {
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
        color: Palette.accent.opacity(Tokens.Opacity.border), width: Self.sweep, turning: !reduceMotion,
        active: scenePhase == .active)
        .allowsHitTesting(false)
    }
    .accessibilityHidden(true)
  }
}

// MARK: safety and bot

private struct SafetyCard: View {
  @Environment(AppModel.self) private var model

  /// How often the ages ("3 s ago") refresh, in seconds.
  static let tick: TimeInterval = 1
  /// Fence names the bot raises for a position or an open order it did not place (engine
  /// Fence.FOREIGN_POSITION and FOREIGN_ORDER). A fence kind is the name, then ":" and a key
  /// when it has one, as in "foreign-position:ABCD".
  static let foreignPositionFence = "foreign-position"
  static let foreignOrderFence = "foreign-order"
  /// Separator between a fence's name and its key (protocol value).
  static let fenceKeySeparator: Character = ":"

  var body: some View {
    Card(L10n.Safety.title) {
      TimelineView(.periodic(from: .now, by: Self.tick)) { context in
        VStack(spacing: Tokens.Space.s) {
          ForEach(rows(now: model.botTime(context.date))) { row in
            HStack(spacing: Tokens.Space.s) {
              StateGlyph(row.symbol, tone: row.tone, label: row.label, style: .compact)
              Text(row.label).font(Tokens.Typography.callout).foregroundStyle(Palette.textTertiary)
              Spacer()
              Text(verbatim: row.value)
                .font(Tokens.Typography.calloutMono)
                .foregroundStyle(row.tone.text)
                .lineLimit(1)
                .contentTransition(.numericText())
            }
          }
        }
      }
    }
  }

  private enum RowID: Hashable { case status, stops, entries, reconcile, stream, read, foreign, foreignOrders, pause }

  private struct Row: Identifiable {
    let id: RowID
    let label: LocalizedStringResource
    let value: String
    let tone: Tone

    /// Symbols of the rows.
    static let statusSymbol = "questionmark.circle"
    static let stopsSymbol = "checkmark.shield"
    static let entriesSymbol = "paperplane"
    static let reconcileSymbol = "arrow.triangle.2.circlepath"
    static let streamSymbol = "waveform.path.ecg"
    static let readSymbol = "building.columns"
    static let foreignSymbol = "person.crop.circle.badge.questionmark"
    static let foreignOrdersSymbol = "doc.badge.ellipsis"
    static let pauseSymbol = "pause.circle"

    var symbol: String {
      switch id {
      case .status: return Self.statusSymbol
      case .stops: return Self.stopsSymbol
      case .entries: return Self.entriesSymbol
      case .reconcile: return Self.reconcileSymbol
      case .stream: return Self.streamSymbol
      case .read: return Self.readSymbol
      case .foreign: return Self.foreignSymbol
      case .foreignOrders: return Self.foreignOrdersSymbol
      case .pause: return Self.pauseSymbol
      }
    }
  }

  private func rows(now: Date) -> [Row] {
    guard model.isLive, let status = model.status else {
      let value = String(localized: model.isLive ? L10n.Common.unavailable : L10n.Safety.recordedDay)
      return [Row(id: .status, label: L10n.Safety.status, value: value, tone: .neutral)]
    }
    let positions = Board.positions(status)
    let verified = positions.filter { $0.stop.state == .verified }.count
    let fenceNames = Set(status.fences.map { String($0.kind.prefix { $0 != Self.fenceKeySeparator }) })
    let foreign = fenceNames.contains(Self.foreignPositionFence)
    let foreignOrders = fenceNames.contains(Self.foreignOrderFence)
    let stream = status.freshness.stream
    let entries = positions.map { (symbol: $0.symbol, entry: $0.entry) }
      + status.tradesToday.map { (symbol: $0.symbol, entry: $0.entry) }
    let sent = EntrySent.summary(entries)
    return [
      Row(id: .stops, label: L10n.Safety.brokerStops,
        value: positions.isEmpty
          ? String(localized: L10n.Common.noPosition) : String(localized: L10n.Safety.verified(verified, positions.count)),
        tone: verified == positions.count ? .profit : .loss),
      Row(id: .entries, label: L10n.EntrySent.safetyRow,
        value: sent?.text ?? String(localized: L10n.Common.none), tone: sent?.tone ?? .neutral),
      Row(id: .reconcile, label: L10n.Safety.reconciliation,
        value: status.fences.isEmpty
          ? String(localized: L10n.Safety.noFences) : String(localized: L10n.Common.fences(status.fences.count)),
        tone: status.fences.isEmpty ? .profit : .warning),
      Row(id: .stream, label: L10n.Safety.quoteStream, value: stream.title,
        tone: stream == .fresh ? .profit : stream == .off ? .neutral : .warning),
      Row(id: .read, label: L10n.Safety.lastBrokerRead,
        value: Format.age(since: status.freshness.lastBrokerReadAt?.date, now: now),
        tone: BrokerReadAge.tone(since: status.freshness.lastBrokerReadAt?.date, now: now)),
      Row(id: .foreign, label: L10n.Safety.foreignPositions,
        value: String(localized: foreign ? L10n.Safety.present : L10n.Common.none),
        tone: foreign ? .loss : .profit),
      Row(id: .foreignOrders, label: L10n.Safety.foreignOrders,
        value: String(localized: foreignOrders ? L10n.Safety.present : L10n.Common.none),
        tone: foreignOrders ? .loss : .profit),
      Row(id: .pause, label: L10n.Safety.entryPause,
        value: String(localized: status.entryStop ? L10n.Common.on : L10n.Common.off),
        tone: status.entryStop ? .warning : .neutral),
    ]
  }
}

private struct BotCard: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    Card(L10n.Common.bot) {
      if let status = model.status {
        let running = status.botState == .running
        let isCurrent = model.isLive && model.fetchError == nil && model.response?.stale == false
        StatusPill(verbatim: status.entryStop ? String(localized: L10n.Common.entriesPaused) : status.botState.title,
          tone: status.entryStop ? .warning : running ? .accent : .neutral,
          live: running && isCurrent, event: status.writtenAt.date)
      }
    } content: {
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

  /// Symbols of the risk figures.
  static let resultSymbol = "plusminus"
  static let positionsSymbol = "square.stack.3d.up"
  static let plannedLossSymbol = "arrow.down.to.line"
  static let capSymbol = "dollarsign.circle"
  static let reservationsSymbol = "lock.circle"

  var body: some View {
    Card(L10n.RiskRoom.title) {
      MoreButton(L10n.RiskRoom.details) { model.section = .risk }
    } content: {
      if let risk = model.settings?.risk {
        let limit = risk.maxDailyLossUsd.value
        // The bot's own room for today; the app never computes one the bot did not report.
        let room = model.dailyRoom
        let fraction = room.map { limit > 0 ? NSDecimalNumber(decimal: $0 / limit).doubleValue : 0 } ?? 0
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
          if let room {
            MoneyText(value: room, font: Tokens.Typography.metric, colored: false, signed: false)
          } else {
            Text(verbatim: Format.missing).font(Tokens.Typography.metric).foregroundStyle(Palette.textQuaternary)
          }
          Text(L10n.RiskRoom.left(Money.plain(limit))).font(Tokens.Typography.callout).foregroundStyle(Palette.textTertiary)
        }
        bar(fraction: fraction)
        VStack(spacing: Tokens.Space.s) {
          StatLine(L10n.RiskRoom.netResult, value: Money.signed(model.shownResult), color: Palette.result(model.shownResult),
            symbol: Self.resultSymbol)
          let count = String(localized: L10n.Common.countOf(model.positions.count, risk.maxOpenPositions))
          StatLine(L10n.RiskRoom.positions, value: count, symbol: Self.positionsSymbol)
          StatLine(L10n.RiskRoom.plannedLoss, value: Money.plain(risk.plannedLossUsd.value), symbol: Self.plannedLossSymbol)
          StatLine(L10n.RiskRoom.notionalCap, value: Money.plain(risk.positionNotionalCapUsd.value), symbol: Self.capSymbol)
          StatLine(L10n.RiskRoom.reservations,
            value: model.status?.openReservationsUsd.map { Money.plain($0.value) } ?? Format.missing,
            symbol: Self.reservationsSymbol)
        }
      } else if let error = model.settingsError {
        Footnote(verbatim: error)
      } else {
        Footnote(L10n.RiskRoom.reading)
      }
    }
  }

  private func bar(fraction: Double) -> some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        Capsule().fill(Palette.separator)
        Capsule()
          .fill(LinearGradient(colors: [Palette.loss, Palette.warning, Palette.accent], startPoint: .leading,
            endPoint: .trailing))
          .frame(width: proxy.size.width * shown)
      }
    }
    .frame(height: Tokens.Size.bar)
    .onAppear { withAnimation(Tokens.Motion.fill) { shown = fraction } }
    .onChange(of: fraction) { _, value in withAnimation(Tokens.Motion.fill) { shown = value } }
  }
}

private struct ObserversCard: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    Card(L10n.Observers.title) {
      MoreButton(L10n.RiskRoom.details) { model.section = .lab }
    } content: {
      if let observers = model.observers?.observers {
        if observers.isEmpty {
          Text(L10n.Observers.none).font(Tokens.Typography.callout).foregroundStyle(Palette.textTertiary)
        }
        ForEach(observers) { observer in
          ObserverRow(observer: observer, live: model.isLive)
        }
      } else if model.observersError != nil {
        Footnote(L10n.Lab.observersUnavailable, color: Palette.warningText)
      }
      HStack(spacing: Tokens.Space.s) {
        Image(systemName: AppSection.labSymbol).foregroundStyle(Palette.highlightText)
        Text(L10n.Observers.advisor).font(Tokens.Typography.callout)
        Spacer()
        PlannedTag()
      }
    }
  }
}

private struct JournalCard: View {
  @Environment(AppModel.self) private var model

  /// Most recent events shown here; the full journal is in Trades & days.
  static let shown = 10

  var body: some View {
    Card(L10n.Journal.title) {
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
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
          ForEach(events.prefix(Self.shown)) { event in
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
              Text(verbatim: Format.marketTime(event.time)).foregroundStyle(Palette.textQuaternary)
              Text(verbatim: event.tag).fontWeight(.bold).foregroundStyle(event.tone.color)
              Text(verbatim: event.text).foregroundStyle(Palette.textSecondary).lineLimit(1)
            }
            .font(Tokens.Typography.annotation)
            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
          }
        }
        .animation(Tokens.Motion.standard, value: events.map(\.id))
        .textSelection(.enabled)
      }
    }
  }
}

#if DEBUG
#Preview {
  OverviewView()
    .environment(PreviewAPI.model())
    .frame(width: PreviewAPI.windowWidth, height: PreviewAPI.windowHeight)
}
#endif
