import ApertureDesign
import ApertureKit
import Charts
import SwiftUI

/// Overview: what the bot is doing now, its positions and protection, the day's result, and the
/// bot controls. For a recorded day it shows that day read-only.
struct OverviewView: View {
  @Environment(AppModel.self) private var model

  /// The order in which the cards rise in as the screen appears.
  private enum Order: Int { case header = 0, result, flow, positions, middle, right }

  var body: some View {
    ScrollView {
      VStack(spacing: Tokens.Space.l) {
        HStack(alignment: .top, spacing: Tokens.Space.l) {
          HeaderCard().rise(step: Order.header.rawValue)
          DayResultCard().frame(width: Tokens.Size.sideColumn).rise(step: Order.result.rawValue)
        }
        LiveFlowCard().rise(step: Order.flow.rawValue)
        // Three columns when the window is wide; a narrow window puts the positions on their own
        // row and the two side columns below them, so nothing is pushed off screen.
        ViewThatFits(in: .horizontal) {
          HStack(alignment: .top, spacing: Tokens.Space.l) {
            positions
            middleColumn.frame(width: Tokens.Size.sideColumn)
            rightColumn.frame(width: Tokens.Size.sideColumn)
          }
          VStack(spacing: Tokens.Space.l) {
            positions
            HStack(alignment: .top, spacing: Tokens.Space.l) {
              middleColumn
              rightColumn
            }
          }
        }
      }
      .padding(Tokens.Space.xl)
      .frame(maxWidth: Tokens.Size.contentMaxWidth)
      .frame(maxWidth: .infinity)
    }
  }

  private var positions: some View {
    PositionsCard().rise(step: Order.positions.rawValue)
  }

  private var middleColumn: some View {
    VStack(spacing: Tokens.Space.l) {
      SafetyCard()
      BotCard()
    }
    .rise(step: Order.middle.rawValue)
  }

  private var rightColumn: some View {
    VStack(spacing: Tokens.Space.l) {
      RiskRoomCard()
      ObserversCard()
      JournalCard()
    }
    .rise(step: Order.right.rawValue)
  }
}

// MARK: header

private struct HeaderCard: View {
  @Environment(AppModel.self) private var model

  /// Lines the banner's detail may wrap to.
  static let detailLines = 2

  var body: some View {
    HStack(alignment: .center, spacing: Tokens.Space.l) {
      ApertureLogo()
      VStack(alignment: .leading, spacing: Tokens.Space.m) {
        HStack(spacing: Tokens.Space.s) {
          Text(verbatim: AppInfo.name).font(Tokens.Typography.title)
          Text(L10n.Common.operatorTitle).font(Tokens.Typography.subtitle).foregroundStyle(Palette.textQuaternary)
          #if DEBUG
          // Fixture data looks live; say so on the screen it would be mistaken on.
          if PreviewAPI.servesFixtures {
            Badge(L10n.Overview.fixtures, color: Palette.warningText).help(Text(L10n.Overview.fixturesHelp))
          }
          #endif
          if let status = model.status {
            Badge(verbatim: status.environment, color: Palette.highlightText)
            Group {
              if status.tradingGate.open {
                Badge(L10n.Overview.gateOpen, color: Palette.accentText)
              } else {
                Badge(L10n.Overview.gateClosed, color: Palette.warningText)
              }
            }
            .help(Text(verbatim: status.tradingGate.cause))
          }
        }
        banner
      }
      Spacer(minLength: 0)
    }
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, alignment: .leading)
    .apertureCard()
  }

  private var banner: some View {
    let content = content
    let shape = RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
    return HStack(spacing: Tokens.Space.m) {
      PulseDot(content.color, pulsing: model.isLive)
      Text(verbatim: content.title).font(.headline).foregroundStyle(content.color)
      if let detail = content.detail {
        Text(verbatim: detail).font(Tokens.Typography.callout).foregroundStyle(Palette.textTertiary).lineLimit(Self.detailLines)
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

/// A soft red glow that breathes around something that needs attention now.
struct AlarmPulse: ViewModifier {
  let active: Bool
  @State private var on = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Blur radius of the glow at its weakest and strongest, in points.
  static let glowRest: CGFloat = 2
  static let glowPeak: CGFloat = 10

  func body(content: Content) -> some View {
    content
      .shadow(
        color: active ? Palette.loss.opacity(on ? Tokens.Opacity.medium : Tokens.Opacity.wash) : .clear,
        radius: on ? Self.glowPeak : Self.glowRest)
      .onAppear { breathe(active) }
      .onChange(of: active) { _, now in
        on = false
        breathe(now)
      }
  }

  private func breathe(_ now: Bool) {
    guard now, !reduceMotion else { return }
    withAnimation(.easeInOut(duration: Tokens.Motion.breatheSeconds / 2).repeatForever(autoreverses: true)) {
      on = true
    }
  }
}

private struct DayResultCard: View {
  @Environment(AppModel.self) private var model
  @State private var counted: Decimal = 0

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      CardLabel(L10n.Overview.dayResult)
      MoneyText(value: counted, usd: true, font: Tokens.Typography.hero)
      Text(verbatim: subtitle).font(Tokens.Typography.captionMono).foregroundStyle(Palette.textQuaternary)
      DrawnSparkline(values: model.cumulativeResults, color: Palette.result(model.shownResult))
        .frame(height: Tokens.Size.sparkline)
    }
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, alignment: .leading)
    .apertureCard()
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

  /// Id of the ticker's placeholder item when nothing happened yet.
  static let quietID = "quiet"
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
      Group {
        if model.isLive { Text(L10n.Flow.live) } else { Text(L10n.Flow.recorded) }
      }
      .font(Tokens.Typography.captionMono)
      .foregroundStyle(Palette.textQuaternary)
    } content: {
      Ticker(tickerItems, moving: model.isLive)
        .frame(height: Tokens.Size.ticker)
      Pipeline(stages: stages, moving: model.isLive)
        .frame(height: Pipeline.height)
    }
  }

  private var tickerItems: [TickerItem] {
    guard let status = model.status, model.isLive else {
      return model.shownTrades.map {
        TickerItem(id: $0.tradeId, tag: Board.exitReasonTitle($0.exitReason).uppercased(),
          text: "\($0.symbol) \(Money.signed($0.resultGrossUsd.value))",
          tone: $0.resultGrossUsd.value >= 0 ? .green : .red)
      }
    }
    let events = Board.events(status)
    if events.isEmpty {
      return [TickerItem(id: Self.quietID, tag: String(localized: L10n.Flow.quietTag),
        text: String(localized: L10n.Flow.nothingYet), tone: .muted)]
    }
    return events.map { TickerItem(id: $0.id, tag: $0.tag, text: $0.text, tone: $0.tone.tickerTone) }
  }

  private var stages: [Pipeline.Stage] {
    let status = model.isLive ? model.status : nil
    let position = status.flatMap { Board.positions($0).first }
    let stopColor = position.map { $0.stop.state == .verified ? Palette.profit : Palette.loss } ?? Palette.profit
    return [
      .init(id: .screeners, name: L10n.Flow.screeners, value: nil, symbol: Self.screenersSymbol, color: Palette.accent),
      .init(id: .universe, name: L10n.Flow.universe, value: nil, symbol: Self.universeSymbol,
        color: Palette.seriesUniverse),
      .init(id: .strategy, name: L10n.Common.strategy, value: status.map { Format.strategy($0.strategy) },
        symbol: Self.strategySymbol, color: Palette.highlight),
      .init(id: .risk, name: L10n.Common.risk,
        value: status.map { String(localized: $0.entryBlock == nil ? L10n.Flow.entriesAllowed : L10n.Flow.blocked) },
        symbol: Self.riskSymbol, color: Palette.warning),
      .init(id: .order, name: L10n.Flow.order, value: status.map { String(localized: L10n.Flow.closedCount($0.tradesToday.count)) },
        symbol: Self.orderSymbol, color: Palette.info),
      .init(id: .stop, name: L10n.Flow.brokerStop,
        value: status.map { _ in position.map { $0.stop.state.title } ?? String(localized: L10n.Common.noPosition) },
        symbol: Self.stopSymbol, color: stopColor),
      .init(id: .reconcile, name: L10n.Flow.reconcile,
        value: status.map {
          $0.fences.isEmpty ? String(localized: L10n.Flow.match) : String(localized: L10n.Common.fences($0.fences.count))
        },
        symbol: Self.reconcileSymbol, color: Palette.info),
    ]
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

/// The stages a setup passes through, with light travelling along the line between them.
private struct Pipeline: View {
  /// The stages, in the order a setup passes them.
  enum StageID: Hashable { case screeners, universe, strategy, risk, order, stop, reconcile }

  struct Stage: Identifiable {
    let id: StageID
    let name: LocalizedStringResource
    /// nil = the API does not report this stage yet.
    let value: String?
    let symbol: String
    let color: Color
  }

  let stages: [Stage]
  let moving: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Height of the whole pipeline: icon well, name and value.
  static let height: CGFloat = 96
  /// Lights travelling along the line at once, evenly spaced.
  static let lights = 3
  /// Share of the trip over which a light fades in at the start and out at the end.
  static let fadeShare = 0.08
  /// Blur of a light's glow, in points.
  static let glow: CGFloat = 6
  /// Seconds between the pulses of neighbouring stages, so they do not beat together.
  static let pulseOffset = 0.35

  var body: some View {
    ZStack(alignment: .top) {
      GeometryReader { proxy in
        let inset = proxy.size.width / CGFloat(stages.count) / 2
        // The track runs from the centre of the first stage to the centre of the last.
        let width = proxy.size.width - proxy.size.width / CGFloat(stages.count)
        Capsule().fill(Palette.separator)
          .frame(width: width, height: Tokens.Stroke.bold)
          .offset(x: inset, y: (Tokens.Size.iconWell - Tokens.Stroke.bold) / 2)
        if moving && !reduceMotion {
          TimelineView(.animation) { context in
            lights(time: context.date.timeIntervalSinceReferenceDate, inset: inset, width: width)
          }
        }
      }
      HStack(spacing: 0) {
        ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
          column(stage, index: index)
        }
      }
    }
    .accessibilityElement(children: .combine)
  }

  private func lights(time: TimeInterval, inset: CGFloat, width: CGFloat) -> some View {
    ForEach(0..<Self.lights, id: \.self) { index in
      let phase = (time / Tokens.Motion.pipelineSeconds + Double(index) / Double(Self.lights))
        .truncatingRemainder(dividingBy: 1)
      Circle()
        .fill(Palette.accent)
        .frame(width: Tokens.Size.dot, height: Tokens.Size.dot)
        .shadow(color: Palette.accent.opacity(Tokens.Opacity.medium), radius: Self.glow)
        .opacity(min(phase, 1 - phase, Self.fadeShare) / Self.fadeShare)
        .offset(x: inset + width * phase - Tokens.Size.dot / 2, y: (Tokens.Size.iconWell - Tokens.Size.dot) / 2)
    }
  }

  private func column(_ stage: Stage, index: Int) -> some View {
    let reported = stage.value != nil
    return VStack(spacing: Tokens.Space.s) {
      ZStack {
        Circle().fill(Palette.surface)
        Circle().strokeBorder(stage.color.opacity(reported ? 1 : Tokens.Opacity.faint), lineWidth: Tokens.Stroke.regular)
        Image(systemName: stage.symbol)
          .font(Tokens.Typography.symbol)
          .foregroundStyle(stage.color.opacity(reported ? 1 : Tokens.Opacity.border))
      }
      .frame(width: Tokens.Size.iconWell, height: Tokens.Size.iconWell)
      .overlay {
        if reported && moving {
          PulseDot(stage.color, size: Tokens.Size.iconWell, pulsing: true)
            .opacity(Tokens.Opacity.faint)
            .animation(.default.delay(Double(index) * Self.pulseOffset), value: moving)
        }
      }
      Text(stage.name)
        .textCase(.uppercase)
        .font(Tokens.Typography.annotationBold)
        .foregroundStyle(Palette.textSecondary)
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
          .help(Text(L10n.Flow.notReported))
      }
    }
    .frame(maxWidth: .infinity)
  }
}

// MARK: positions

private struct PositionsCard: View {
  @Environment(AppModel.self) private var model
  @State private var selected: String?

  var body: some View {
    let rows = model.positions
    Card(title) {
      Button(String(localized: L10n.Position.openChart)) { model.section = .chart }
        .buttonStyle(.link)
        .disabled(rows.isEmpty)
    } content: {
      if rows.count > 1 {
        Picker(String(localized: L10n.Position.picker), selection: Binding(get: { selected ?? rows.first?.id }, set: { selected = $0 })) {
          ForEach(rows) { row in Text(verbatim: row.position.symbol).tag(Optional(row.id)) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
      }
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

private struct PositionDetail: View {
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
        HStack {
          Text(verbatim: row.position.symbol).font(Tokens.Typography.metric)
          Spacer()
          StopBadge(state: row.position.stop.state)
        }
        figures
        Divider()
        HStack {
          Text(L10n.Position.unrealized).font(Tokens.Typography.callout).foregroundStyle(Palette.textTertiary)
          Spacer()
          if let value = row.unrealized {
            MoneyText(value: value, font: Tokens.Typography.metric)
          } else {
            Text(verbatim: Format.missing).foregroundStyle(Palette.textQuaternary)
          }
        }
      }
      .frame(width: Self.figuresWidth)
    }
  }

  private var figures: some View {
    VStack(spacing: Tokens.Space.s) {
      StatLine(L10n.Position.quantity, value: Format.quantity(row.quantity))
      StatLine(L10n.Position.entry, value: Format.price(row.entry))
      StatLine(label: lastBarLabel, value: lastBarValue)
      StatLine(L10n.Position.stop, value: Format.price(row.stop),
        color: row.position.stop.state == .verified ? Palette.profitText : Palette.lossText)
      StatLine(L10n.Position.maxLoss,
        value: Risk.plannedLoss(entry: row.entry, stop: row.stop, quantity: row.quantity).map { Money.plain($0) }
          ?? Format.missing)
      StatLine(L10n.Position.rNow, value: row.resultR.map(Risk.text) ?? Format.missing)
      StatLine(L10n.Position.opened, value: Format.marketTime(row.position.openedAt.date))
    }
  }

  private var lastBarLabel: Text {
    if let time = row.lastBarAt {
      return Text(L10n.Position.lastBarCloseAt(Format.marketMinute(time)))
    }
    return Text(L10n.Position.lastBarClose)
  }

  private var lastBarValue: String {
    if let close = row.lastBarClose { return Format.price(close) }
    return row.lastBarAt == nil ? Format.missing : String(localized: L10n.Position.old)
  }
}

struct StopBadge: View {
  let state: StopState

  var body: some View {
    Badge(verbatim: state.title, color: state == .verified ? Palette.profitText : Palette.lossText)
      .modifier(AlarmPulse(active: state != .verified))
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
              .symbol { PulseDot(Palette.accent) }
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
          Button(String(localized: L10n.Position.openTrades)) { model.section = .trades }.buttonStyle(.link)
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

  /// Rings, as a share of the radar's radius.
  static let rings = [1.0, 2.0 / 3, 1.0 / 3]
  /// Width of the sweep's tail.
  static let sweep = Angle.degrees(90)

  var body: some View {
    TimelineView(.animation(paused: reduceMotion)) { context in
      let turn = context.date.timeIntervalSinceReferenceDate
        .truncatingRemainder(dividingBy: Tokens.Motion.rotationSeconds) / Tokens.Motion.rotationSeconds
      ZStack {
        ForEach(Self.rings, id: \.self) { scale in
          Circle().stroke(Palette.separatorStrong, lineWidth: Tokens.Stroke.thin).scaleEffect(scale)
        }
        AngularGradient(colors: [Palette.accent.opacity(Tokens.Opacity.border), .clear], center: .center,
          startAngle: .zero, endAngle: Self.sweep)
          .clipShape(Circle())
          .rotationEffect(.radians(turn * Geometry.fullTurn))
      }
    }
    .accessibilityHidden(true)
  }
}

// MARK: safety and bot

private struct SafetyCard: View {
  @Environment(AppModel.self) private var model

  /// How often the ages ("3 s ago") refresh, in seconds.
  static let tick: TimeInterval = 1
  /// Fence kind the bot raises for positions it did not open (protocol value).
  static let foreignExposureKind = "foreign_exposure"

  var body: some View {
    Card(L10n.Safety.title) {
      TimelineView(.periodic(from: .now, by: Self.tick)) { context in
        VStack(spacing: Tokens.Space.s) {
          ForEach(rows(now: context.date)) { row in
            HStack(spacing: Tokens.Space.s) {
              Circle().fill(row.color).frame(width: Tokens.Size.dotSmall, height: Tokens.Size.dotSmall)
              Text(row.label).font(Tokens.Typography.callout).foregroundStyle(Palette.textTertiary)
              Spacer()
              Text(verbatim: row.value)
                .font(Tokens.Typography.calloutMono)
                .foregroundStyle(row.color)
                .lineLimit(1)
                .contentTransition(.numericText())
            }
          }
        }
      }
    }
  }

  private enum RowID: Hashable { case status, stops, reconcile, stream, read, foreign, pause }

  private struct Row: Identifiable {
    let id: RowID
    let label: LocalizedStringResource
    let value: String
    let color: Color
  }

  private func rows(now: Date) -> [Row] {
    guard model.isLive, let status = model.status else {
      let value = String(localized: model.isLive ? L10n.Common.unavailable : L10n.Safety.recordedDay)
      return [Row(id: .status, label: L10n.Safety.status, value: value, color: Palette.textQuaternary)]
    }
    let positions = Board.positions(status)
    let verified = positions.filter { $0.stop.state == .verified }.count
    let foreign = status.fences.contains { $0.kind == Self.foreignExposureKind }
    let stream = status.freshness.stream
    return [
      Row(id: .stops, label: L10n.Safety.brokerStops,
        value: positions.isEmpty
          ? String(localized: L10n.Common.noPosition) : String(localized: L10n.Safety.verified(verified, positions.count)),
        color: verified == positions.count ? Palette.profitText : Palette.lossText),
      Row(id: .reconcile, label: L10n.Safety.reconciliation,
        value: status.fences.isEmpty
          ? String(localized: L10n.Safety.noFences) : String(localized: L10n.Common.fences(status.fences.count)),
        color: status.fences.isEmpty ? Palette.profitText : Palette.warningText),
      Row(id: .stream, label: L10n.Safety.quoteStream, value: stream.title,
        color: stream == .fresh ? Palette.profitText : stream == .off ? Palette.textQuaternary : Palette.warningText),
      Row(id: .read, label: L10n.Safety.lastBrokerRead,
        value: Format.age(since: status.freshness.lastBrokerReadAt?.date, now: now), color: Palette.profitText),
      Row(id: .foreign, label: L10n.Safety.foreignPositions,
        value: String(localized: foreign ? L10n.Safety.present : L10n.Common.none),
        color: foreign ? Palette.lossText : Palette.profitText),
      Row(id: .pause, label: L10n.Safety.entryPause,
        value: String(localized: status.entryStop ? L10n.Common.on : L10n.Common.off),
        color: status.entryStop ? Palette.warningText : Palette.textQuaternary),
    ]
  }
}

private struct BotCard: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    Card(L10n.Common.bot) {
      if let status = model.status {
        HStack(spacing: Tokens.Space.s) {
          PulseDot(status.botState == .running ? Palette.accent : Palette.textQuaternary, size: Tokens.Size.dotSmall,
            pulsing: status.botState == .running && model.isLive)
          Text(verbatim: status.entryStop ? String(localized: L10n.Common.entriesPaused) : status.botState.title)
            .font(Tokens.Typography.captionMono)
            .foregroundStyle(Palette.textTertiary)
        }
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

  var body: some View {
    Card(L10n.RiskRoom.title) {
      Button { model.section = .risk } label: { Text(L10n.RiskRoom.details) }.buttonStyle(.link)
    } content: {
      if let risk = model.settings?.risk {
        let limit = risk.maxDailyLossUsd.value
        // The bot's own room for today; the app never computes one the bot did not report.
        let room = model.dailyRoom
        let fraction = room.map { limit > 0 ? NSDecimalNumber(decimal: $0 / limit).doubleValue : 0 } ?? 0
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
          if let room {
            MoneyText(value: room, font: Tokens.Typography.metric, colored: false)
          } else {
            Text(verbatim: Format.missing).font(Tokens.Typography.metric).foregroundStyle(Palette.textQuaternary)
          }
          Text(L10n.RiskRoom.left(Money.plain(limit))).font(Tokens.Typography.callout).foregroundStyle(Palette.textTertiary)
        }
        bar(fraction: fraction)
        VStack(spacing: Tokens.Space.s) {
          StatLine(L10n.RiskRoom.netResult, value: Money.signed(model.shownResult), color: Palette.result(model.shownResult))
          StatLine(L10n.RiskRoom.positions, value: String(localized: L10n.Common.countOf(model.positions.count, risk.maxOpenPositions)))
          StatLine(L10n.RiskRoom.plannedLoss, value: Money.plain(risk.plannedLossUsd.value))
          StatLine(L10n.RiskRoom.notionalCap, value: Money.plain(risk.positionNotionalCapUsd.value))
          StatLine(L10n.RiskRoom.reservations,
            value: model.status?.openReservationsUsd.map { Money.plain($0.value) } ?? Format.missing)
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
      Button { model.section = .lab } label: { Text(L10n.RiskRoom.details) }.buttonStyle(.link)
    } content: {
      if let observers = model.observers?.observers {
        if observers.isEmpty {
          Text(L10n.Observers.none).font(Tokens.Typography.callout).foregroundStyle(Palette.textTertiary)
        }
        ForEach(observers, id: \.self) { observer in
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
