import SwiftUI
import TickrDesign
import TickrKit

/// Risk & account, as the design's board (MacRisk v134): three columns of cards. The room left of
/// the daily loss limit as a half gauge with whether entries are open, the market's session, and
/// the planned request budget; the position slots, the configured limits with the last entry's
/// size, and the broker check with the safety stops; the broker account and the planned
/// quote-stream health. Each column's last card fills it to the bottom.
struct RiskView: View {
  /// Entrance order of the cards.
  private enum Order: Int {
    case lossRoom = 0, slots, limits, account, session, fences, budget, stream
  }

  /// Positions of the cards in the screen's `CardGrid`.
  private enum Slot: Int { case lossRoom = 0, session, budget, slots, limits, fences, account, stream }

  /// The design's three columns; a screen too narrow for three columns of the least width gets
  /// two. The same cards in both: a resize moves them and never makes them anew. Each column's
  /// last card fills it to the bottom of the window.
  static let arrangements: [CardArrangement] = [
    CardArrangement(minWidth: CardArrangement.columnsMinWidth(CardArrangement.wideColumns), rows: [
      columns([[.lossRoom, .session, .budget], [.slots, .limits, .fences], [.account, .stream]])
    ]),
    CardArrangement(minWidth: 0, rows: [
      columns([[.lossRoom, .session, .slots, .limits, .budget], [.account, .fences, .stream]])
    ]),
  ]

  private static func columns(_ stacks: [[Slot]]) -> CardRow {
    CardRow(columns: stacks.map { CardColumn(width: .share(1), cards: $0.map(\.rawValue)) },
      height: .fillsRest(atLeast: 0))
  }

  var body: some View {
    // The visible height is read in the same layout pass that places the cards (no view state),
    // so the columns follow the window's bottom edge during a resize.
    GeometryReader { viewport in
      ScrollView {
        CardGrid(arrangements: Self.arrangements, spacing: Tokens.Space.l,
          minHeight: max(viewport.size.height - Tokens.Space.l * CardArrangement.paddedEdges, 0)) {
          lossRoom.hugging()
          session.hugging()
          budget.filling()
          slots.hugging()
          limits.hugging()
          fences.filling()
          account.hugging()
          stream.filling()
        }
        .padding(Tokens.Space.l)
      }
      .scrollEdgeHints()
    }
  }

  private var lossRoom: some View { LossRoomCard().rise(step: Order.lossRoom.rawValue) }
  private var slots: some View { SlotsCard().rise(step: Order.slots.rawValue) }
  private var limits: some View { LimitsCard().rise(step: Order.limits.rawValue) }
  private var account: some View { AccountCard().rise(step: Order.account.rawValue) }
  // The New York clock is this Mac's own: it stays while the link is down.
  private var session: some View { SessionCard().keepsContentOffline().rise(step: Order.session.rawValue) }
  private var fences: some View { ReconciliationCard().rise(step: Order.fences.rawValue) }
  private var budget: some View {
    PlannedCard(title: L10n.Risk.budget, note: L10n.Risk.budgetNote).keepsContentOffline().rise(step: Order.budget.rawValue)
  }
  private var stream: some View {
    PlannedCard(title: L10n.Risk.stream, note: L10n.Risk.streamNote).keepsContentOffline().rise(step: Order.stream.rawValue)
  }
}

extension View {
  /// A card at its own height in a column: its texts never shrink to make room for the card that
  /// fills the column.
  fileprivate func hugging() -> some View { fixedSize(horizontal: false, vertical: true) }
}

/// A card the design draws for data the bot does not serve yet: its title, the BACKLOG tag and
/// what it will show. No sample figures.
private struct PlannedCard: View {
  let title: LocalizedStringResource
  let note: LocalizedStringResource

  var body: some View {
    Card(title, tone: .highlight, trailing: {
      Badge.backlog
    }, content: {
      Text.joined(Text(L10n.Risk.notServed), Text(verbatim: Format.itemSeparator), Text(note))
        .font(Tokens.Typography.caption)
        .foregroundStyle(Palette.textTertiary)
        .fixedSize(horizontal: false, vertical: true)
    })
  }
}

/// Whether the bot may open a position now: allowed; waiting for an ordinary reason that passes
/// on its own (calm); or blocked for a reason the operator should look at. Read by the loss
/// card's pill and the free slot tiles.
private enum EntryGate: Hashable {
  case allowed, waiting, blocked

  init(_ status: StatusV1?) {
    guard let status else {
      self = .blocked
      return
    }
    if status.entryStop || !status.tradingGate.open {
      self = .blocked
    } else if let block = status.entryBlock {
      self = block.attention ? .blocked : .waiting
    } else {
      self = .allowed
    }
  }

  var tone: Tone {
    switch self {
    case .allowed: .accent
    case .waiting: .neutral
    case .blocked: .warning
    }
  }

  /// The pill on the loss card ("ENTRIES OPEN").
  var entriesTitle: LocalizedStringResource {
    switch self {
    case .allowed: L10n.Risk.entriesOpen
    case .waiting: L10n.Risk.entriesWaiting
    case .blocked: L10n.Risk.entriesBlocked
    }
  }
}

/// A figure row of the design's mono list: the label, the value at the right.
private struct FigureRow: View {
  let label: Text
  let value: String
  var color: Color = Palette.textSecondary

  init(_ label: LocalizedStringResource, value: String, color: Color = Palette.textSecondary) {
    self.label = Text(label)
    self.value = value
    self.color = color
  }

  var body: some View {
    HStack(spacing: Tokens.Space.s) {
      label
        .foregroundStyle(Palette.textTertiary)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: Tokens.Space.s)
      Text(verbatim: value)
        .foregroundStyle(color)
        .monospacedDigit()
        .layoutPriority(1)
    }
    .font(Tokens.Typography.calloutMono)
    .accessibilityElement(children: .combine)
  }
}

/// "Room left today", the design's half gauge with a needle: the room the bot reports after the
/// net day result (profits offset losses) and open reservations, against the limit; then the day
/// result, what losers lost and what open orders hold. How the room works is in the header's "i".
private struct LossRoomCard: View {
  @Environment(AppModel.self) private var model

  private var limit: Decimal? { model.settings?.risk.maxDailyLossUsd.value }
  /// Today's net result after the broker's fees once read (before them until then); nil while
  /// the bot's status is unknown. The limit counts the live day only.
  private var result: Decimal? { model.status?.resultTodayUsd.value }
  /// The bot's own number; the app never computes a room the bot did not report.
  private var room: Decimal? { model.dailyRoom }

  private var fraction: Double {
    guard let limit, let room, limit > 0 else { return 0 }
    return NSDecimalNumber(decimal: room / limit).doubleValue
  }

  /// Symbol beside the title whose tooltip says how the room works.
  static let infoSymbol = "info.circle"

  /// Fill colour of the gauge: the accent while the room is calm, amber, then red near the limit.
  private var color: Color {
    if room == nil { return Palette.textQuaternary }
    if fraction < Tokens.Room.alarm { return Palette.loss }
    if fraction < Tokens.Room.calm { return Palette.warning }
    return Palette.accent
  }

  private var textColor: Color {
    if room == nil { return Palette.textQuaternary }
    if fraction < Tokens.Room.alarm { return Palette.lossText }
    if fraction < Tokens.Room.calm { return Palette.warningText }
    return Palette.accentText
  }

  var body: some View {
    let gate = EntryGate(model.status)
    Card(L10n.Risk.lossRoom, trailing: {
      // How the room works, on hover: profits, open orders, sizing down, the minimum room.
      Image(systemName: Self.infoSymbol)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
        .tip(Text(L10n.Risk.lossRoomNote))
        .accessibilityLabel(Text(L10n.Risk.lossRoomNote))
      if let status = model.status {
        // Why entries wait or are blocked, in the bot's words, on hover.
        StatusPill(gate.entriesTitle, tone: gate.tone, live: gate == .allowed, event: gate)
          .tip(Text(verbatim: Self.gateCause(status)))
      } else {
        StatusPill(L10n.Risk.entriesUnknown, tone: .warning)
          .tip(Text(verbatim: model.fetchError ?? model.response?.unavailableCauseText ?? String()))
      }
    }, content: {
      VStack(spacing: Tokens.Space.m) {
        if !model.isLive {
          // This screen is always live: the limits and the broker now, never the picked day.
          InfoCaption(L10n.Risk.liveOnly(DayText.day(model.shownDay)), tone: .highlight)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        VStack(spacing: Tokens.Space.xxs) {
          LossGauge(fraction: fraction, color: color)
            .frame(width: LossGauge.width, height: LossGauge.height)
          Text(verbatim: room.map(Money.usd) ?? Format.missing)
            .font(Tokens.Typography.metric)
            .foregroundStyle(textColor)
            .monospacedDigit()
            .contentTransition(.numericText(value: room.map { NSDecimalNumber(decimal: $0).doubleValue } ?? 0))
            .animation(Tokens.Motion.quick, value: room)
            .fixedSize()
          Text(L10n.Risk.ofLimit(amount(model.settings?.risk.maxDailyLossUsd)))
            .font(Tokens.Typography.caption)
            .foregroundStyle(Palette.textQuaternary)
        }
        .frame(maxWidth: .infinity)
        .modifier(AlarmPulse(active: room != nil && fraction < Tokens.Room.alarm))
        VStack(spacing: Tokens.Space.xs) {
          FigureRow(L10n.Risk.resultToday, value: result.map(Money.signedUSD) ?? Format.missing,
            color: result.map(Palette.result) ?? Palette.textQuaternary)
          // A loss and a reservation in their colour only while they show more than "$0.00".
          let lossTone = model.status?.realizedLossTodayUsd.map { Tone.loss($0.value) } ?? .neutral
          let reservedTone = model.status?.openReservationsUsd.map { Tone.amount($0.value, .warning) } ?? .neutral
          FigureRow(L10n.Risk.realizedLoss, value: loss(model.status?.realizedLossTodayUsd), color: lossTone.text)
          FigureRow(L10n.Risk.reservations(model.positions.count), value: amount(model.status?.openReservationsUsd),
            color: reservedTone.text)
        }
        if let note = RiskRoomText.roomNote(model.status) {
          Footnote(note, color: Palette.warningText)
        }
      }
    })
  }

  /// What keeps entries from opening: the operator stop, a closed gate, or the bot's block.
  private static func gateCause(_ status: StatusV1) -> String {
    if status.entryStop { return String(localized: L10n.Risk.fenceOperator) }
    if !status.tradingGate.open { return ApiText.gate(status.tradingGate) }
    return status.entryBlock.map(ApiText.entryBlock) ?? String(localized: L10n.Risk.entriesOpen)
  }

  /// A loss the bot reported, with its minus ("−$1.60"), or the missing mark.
  private func loss(_ value: DecimalString?) -> String {
    value.map { Money.signedUSD(-$0.value) } ?? Format.missing
  }

  /// An amount the bot reported ("$250.00"), or the missing mark when it did not.
  private func amount(_ value: DecimalString?) -> String {
    value.map { Money.usd($0.value) } ?? Format.missing
  }
}

/// The design's half gauge: a 180° track, the room left drawn from the left end, and a needle at
/// the room's position. It moves only when the room changes.
private struct LossGauge: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var drawn = false
  let fraction: Double
  let color: Color

  /// Size of the gauge, in points: the arc's diameter plus its stroke, and half that high.
  static let width: CGFloat = 200
  static let height: CGFloat = 108
  /// Width of the arc, in points.
  static let arcWidth: CGFloat = 14
  /// Width of the needle and size of its hub, in points.
  static let needleWidth: CGFloat = 3
  static let hub: CGFloat = 12

  private var shown: Double { drawn ? min(max(fraction, 0), 1) : 0 }

  var body: some View {
    GaugeShape(share: 1, arcWidth: Self.arcWidth)
      .stroke(Palette.separator, style: StrokeStyle(lineWidth: Self.arcWidth, lineCap: .round))
      .overlay {
        GaugeShape(share: shown, arcWidth: Self.arcWidth)
          .stroke(color, style: StrokeStyle(lineWidth: Self.arcWidth, lineCap: .round))
          .opacity(shown > 0 ? 1 : 0)
      }
      .overlay {
        NeedleShape(share: shown, arcWidth: Self.arcWidth)
          .stroke(Palette.textPrimary, style: StrokeStyle(lineWidth: Self.needleWidth, lineCap: .round))
      }
      .overlay(alignment: .bottom) {
        Circle()
          .fill(Palette.textPrimary)
          .frame(width: Self.hub, height: Self.hub)
          .offset(y: Self.hub / 2 - Self.arcWidth / 2)
      }
      .animation(reduceMotion ? nil : Tokens.Motion.fill, value: shown)
      .onAppear {
        withAnimation(reduceMotion ? nil : Tokens.Motion.fill) { drawn = true }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Text(L10n.Risk.roomLeft))
      .accessibilityValue(Text(fraction, format: .percent.precision(.fractionLength(0))))
  }
}

/// Fixed geometry of the gauge's shapes (outside the view, so the shapes may read it anywhere).
private enum GaugeGeometry {
  /// The arc starts at nine o'clock and runs half a turn to three o'clock.
  static let leftDegrees: Double = 180
  static let halfTurnDegrees: Double = 180
  /// Needle length as a share of the arc's radius.
  static let needleShare: CGFloat = 0.78
}

/// The gauge's arc from the left end over `share` of the half circle, across the top.
private struct GaugeShape: Shape {
  var share: Double
  let arcWidth: CGFloat

  var animatableData: Double {
    get { share }
    set { share = newValue }
  }

  func path(in rect: CGRect) -> Path {
    let radius = (rect.width - arcWidth) / 2
    let center = CGPoint(x: rect.midX, y: rect.maxY - arcWidth / 2)
    var path = Path()
    path.addArc(center: center, radius: radius, startAngle: .degrees(GaugeGeometry.leftDegrees),
      endAngle: .degrees(GaugeGeometry.leftDegrees + GaugeGeometry.halfTurnDegrees * share), clockwise: false)
    return path
  }
}

/// The gauge's needle: from the hub towards the room's position on the arc.
private struct NeedleShape: Shape {
  var share: Double
  let arcWidth: CGFloat

  var animatableData: Double {
    get { share }
    set { share = newValue }
  }

  func path(in rect: CGRect) -> Path {
    let radius = (rect.width - arcWidth) / 2 * GaugeGeometry.needleShare
    let center = CGPoint(x: rect.midX, y: rect.maxY - arcWidth / 2)
    let angle = Double.pi * (1 - share)
    var path = Path()
    path.move(to: center)
    path.addLine(to: CGPoint(x: center.x + cos(angle) * radius, y: center.y - sin(angle) * radius))
    return path
  }
}

/// The design's fence groups: every kind of fence the bot can raise, under the name the operator
/// knows it by, so the card always lists each one with its state, not only the active ones.
private enum FenceGroup: CaseIterable, Identifiable {
  case foreign, quantity, orderStatus, protection, exits, brokerReads, session, operatorStop

  var id: Self { self }

  var kinds: Set<FenceKind> {
    switch self {
    case .foreign: [.foreignPosition, .foreignOrder]
    case .quantity: [.quantityMismatch, .overProtected, .resurrected]
    case .orderStatus: [.unknownOrder, .orderMissing, .statusUnknown, .detailUnreadable, .cancelUnknown, .replaceUnresolved]
    case .protection: [.unprotected, .unprotectedTimeout, .stopRejected, .stopHeld]
    case .exits: [.exitRefused, .exitNotFilled, .cancelFailed, .cancelNotSent]
    case .brokerReads: [.startupReconcile, .brokerReadFailed, .detailBudget]
    case .session: [.shuttingDown, .marketClosed]
    case .operatorStop: [.entryStop, .watchdogStarted]
    }
  }

  var title: LocalizedStringResource {
    switch self {
    case .foreign: L10n.Risk.fenceForeign
    case .quantity: L10n.Risk.fenceQuantity
    case .orderStatus: L10n.Risk.fenceOrderStatus
    case .protection: L10n.Risk.fenceProtection
    case .exits: L10n.Risk.fenceExits
    case .brokerReads: L10n.Risk.fenceBrokerReads
    case .session: L10n.Risk.fenceSession
    case .operatorStop: L10n.Risk.fenceOperator
    }
  }

  /// The group of a fence; nil for a kind this app does not know (listed on its own).
  static func of(_ fence: Fence) -> FenceGroup? {
    let name = String(fence.kind.prefix { $0 != Fence.keySeparator })
    guard let kind = ApiText.fenceKindCase(name) else { return nil }
    return allCases.first { $0.kinds.contains(kind) }
  }
}

/// "Broker check": whether the broker's positions, orders and stops match the bot's records, big;
/// how many stops cover the positions and when the bot reads the broker next (GET /jobs); then the
/// safety stops (fences) in one line that opens to every kind with its state.
private struct ReconciliationCard: View {
  @Environment(AppModel.self) private var model

  /// The bot's fences; nil while its status is unknown (never shown as "no fences").
  private var fences: [Fence]? { model.status?.fences }

  /// Size and stroke of the countdown ring, in points.
  static let ringSize: CGFloat = 76
  static let ringWidth: CGFloat = 7
  /// The ring starts at twelve o'clock.
  static let topDegrees: Double = -90
  /// Symbols of a passed and a failed check, and of the next read.
  static let checkSymbol = "checkmark"
  static let crossSymbol = "xmark"
  static let clockSymbol = "clock"

  var body: some View {
    Card(L10n.Risk.reconciliation, trailing: { badges }, content: {
      VStack(alignment: .leading, spacing: Tokens.Space.m) {
        HStack(alignment: .center, spacing: Tokens.Space.l) {
          countdown
          VStack(alignment: .leading, spacing: Tokens.Space.s) {
            checks
          }
        }
        if let fences {
          let active = fences.count + (model.status?.entryStop == true ? 1 : 0)
          FooterDetail(L10n.Risk.safetyStops,
            summary: String(localized: active == 0 ? L10n.Risk.noneActive : L10n.Common.fences(active)),
            summaryColor: active == 0 ? Palette.profitText : Palette.warningText) {
            groups(fences)
          }
        } else {
          Footnote(L10n.Common.unavailable)
        }
      }
    })
    .task(id: model.baseURL) { await model.followJobs() }
    // Keyed on the account, not the read: a new read of the same account moves nothing.
    .animation(Tokens.Motion.standard, value: model.account?.state)
  }

  /// An old read says so in the header: its "All match" may no longer hold.
  @ViewBuilder private var badges: some View {
    if model.account?.stale == true {
      Badge(L10n.Risk.stale, color: Palette.warningText)
    }
  }

  /// The ring counts down to the bot's next broker read; it reads the clock each second, as the
  /// session clock does, and is still between ticks.
  private var countdown: some View {
    TimelineView(.periodic(from: .now, by: Tokens.Motion.clockTickSeconds)) { context in
      let left = secondsLeft(at: model.botTime(context.date))
      ZStack {
        Circle().stroke(Palette.surfaceSunken, lineWidth: Self.ringWidth)
        if let left, let interval, interval > 0 {
          Circle()
            .trim(from: 0, to: min(1, max(0, left / interval)))
            .stroke(Palette.info, style: StrokeStyle(lineWidth: Self.ringWidth, lineCap: .round))
            .rotationEffect(.degrees(Self.topDegrees))
        }
        Text(left.map { String(localized: L10n.Risk.seconds(Format.wholeSeconds(Decimal($0)))) } ?? Format.missing)
          .font(Tokens.Typography.chip)
          .foregroundStyle(left == nil ? Palette.textQuaternary : Palette.textPrimary)
          .monospacedDigit()
      }
      .frame(width: Self.ringSize, height: Self.ringSize)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Text(L10n.Risk.nextRead))
      .accessibilityValue(Text(verbatim: left.map { Format.wholeSeconds(Decimal($0)) } ?? Format.missing))
    }
  }

  private var interval: Double? {
    model.jobs.map { NSDecimalNumber(decimal: $0.reconcile.intervalSeconds.value).doubleValue }
  }

  /// Seconds to the next read; nil while the bot does not run (no next read) or the jobs are unread.
  private func secondsLeft(at now: Date) -> Double? {
    guard let next = model.jobs?.reconcile.nextAt?.date else { return nil }
    return max(0, next.timeIntervalSince(now).rounded())
  }

  @ViewBuilder private var checks: some View {
    if let response = model.account {
      let matches = response.account.matchesRecords
      // The verdict big, in its colour, then what it covers.
      HStack(spacing: Tokens.Space.s) {
        glyph(matches ? Self.checkSymbol : Self.crossSymbol, color: matches ? Palette.profitText : Palette.lossText)
        Text(matches ? L10n.Risk.matches : L10n.Risk.mismatch)
          .font(Tokens.Typography.figure)
          .foregroundStyle(matches ? Palette.profitText : Palette.lossText)
      }
      .accessibilityElement(children: .combine)
      Text(L10n.Risk.checkCovers)
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textTertiary)
      if let mismatch = response.account.mismatch {
        Text(verbatim: mismatch)
          .font(Tokens.Typography.caption)
          .foregroundStyle(Palette.lossText)
          .fixedSize(horizontal: false, vertical: true)
      }
    } else {
      check(nil, Text(model.accountError == nil ? L10n.Risk.accountReading : L10n.Risk.accountUnavailable))
    }
    if let status = model.status, !status.positions.isEmpty {
      let covered = status.positions.filter { $0.stop.state.isProtected }.count
      check(covered == status.positions.count, Text(L10n.Risk.stopsCover(covered, status.positions.count)))
    }
    HStack(spacing: Tokens.Space.s) {
      glyph(Self.clockSymbol, color: Palette.infoText)
      if let at = model.jobs?.reconcile.nextAt?.date {
        Text(L10n.Risk.nextReadAt(Format.marketTime(at)))
      } else {
        Text(model.jobsError == nil ? L10n.Risk.nextReadUnknown : L10n.Risk.jobsUnavailable)
      }
    }
    .font(Tokens.Typography.callout)
    .foregroundStyle(Palette.textTertiary)
  }

  /// A check row: a green tick, a red cross, or a grey clock while unknown.
  private func check(_ passed: Bool?, _ text: Text) -> some View {
    HStack(spacing: Tokens.Space.s) {
      switch passed {
      case true?: glyph(Self.checkSymbol, color: Palette.profitText)
      case false?: glyph(Self.crossSymbol, color: Palette.lossText)
      case nil: glyph(Self.clockSymbol, color: Palette.textQuaternary)
      }
      text
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textSecondary)
    }
    .accessibilityElement(children: .combine)
  }

  /// The design's small tinted square around a symbol.
  private func glyph(_ symbol: String, color: Color) -> some View {
    Image(systemName: symbol)
      .font(Tokens.Typography.annotationBold)
      .foregroundStyle(color)
      .frame(width: Tokens.Size.glyphCompact, height: Tokens.Size.glyphCompact)
      .background(color.opacity(Tokens.Opacity.wash), in: .rect(cornerRadius: Tokens.Radius.small))
      .overlay {
        RoundedRectangle(cornerRadius: Tokens.Radius.small)
          .strokeBorder(color.opacity(Tokens.Opacity.border), lineWidth: Tokens.Stroke.thin)
      }
      .accessibilityHidden(true)
  }

  /// Every fence group with its state, then any fence of a kind this app does not know.
  private func groups(_ fences: [Fence]) -> some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      ForEach(FenceGroup.allCases) { group in
        // The operator's own entry stop is a fence too, though the bot reports it apart.
        fenceRow(Text(group.title), active: fences.filter { FenceGroup.of($0) == group },
          extra: group == .operatorStop && model.status?.entryStop == true, switched: group == .operatorStop)
      }
      ForEach(fences.filter { FenceGroup.of($0) == nil }, id: \.self) { fence in
        fenceRow(Text(verbatim: ApiText.fence(fence)), active: [fence], extra: false)
      }
    }
    .animation(Tokens.Motion.standard, value: fences)
  }

  /// A fence group's row; a `switched` one (the operator's stop) reads on or off, grey when off.
  private func fenceRow(_ title: Text, active: [Fence], extra: Bool, switched: Bool = false) -> some View {
    let on = !active.isEmpty || extra
    let calm = switched ? Palette.textQuaternary : Palette.profit
    return HStack(spacing: Tokens.Space.s) {
      PulseDot(on ? Palette.warning : calm, size: Tokens.Size.dotSmall, pulsing: on, event: active)
      title
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textSecondary)
      Spacer(minLength: Tokens.Space.s)
      Group {
        if switched {
          Text(on ? L10n.Common.on : L10n.Common.off)
        } else if active.count > 1 {
          Text(L10n.Common.fences(active.count))
        } else if on {
          Text(L10n.Risk.fenceActive)
        } else {
          Text(L10n.Risk.fenceNone)
        }
      }
      .font(Tokens.Typography.annotation)
      .foregroundStyle(on ? Palette.warningText : switched ? Palette.textQuaternary : Palette.profitText)
    }
    // What each active fence says, and since when, on hover: it often says what to do.
    .tip(Text(verbatim: active.map(detail).joined(separator: Format.lineSeparator)))
    .accessibilityElement(children: .combine)
  }

  private func detail(_ fence: Fence) -> String {
    let title = model.status.map { Board.fenceTitle(fence, status: $0) } ?? ApiText.fence(fence)
    return [title, ApiText.fenceDetail(fence), String(localized: L10n.Risk.fenceSince(Format.marketTime(fence.since.date)))]
      .joined(separator: Format.itemSeparator)
  }
}

/// "Positions · 2 of 3": one tile per slot the config allows (`PositionSlots`); a working entry
/// holds one, as the engine counts it.
private struct SlotsCard: View {
  @Environment(AppModel.self) private var model

  /// The working entries, each holding a slot (one just cancelled no longer does).
  private var entries: [EntryRow] { model.entryRows.filter { $0.phase != .cancelled } }

  var body: some View {
    Card(L10n.Risk.slots(model.positions.count + entries.count,
      model.settings.map { String($0.risk.maxOpenPositions) } ?? Format.missing)) {
      if let risk = model.settings?.risk {
        PositionSlots(limit: risk.maxOpenPositions, positions: model.positions, entries: entries)
      } else {
        Footnote(model.settingsError == nil ? L10n.Common.unavailable : L10n.Risk.settingsUnavailable)
      }
    }
  }
}

/// The configured risk limits (config/bot.toml, read through GET /settings, read only), then how
/// the last entry was sized, the same block as on the iPhone (`EntrySizingSection`).
private struct LimitsCard: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    Card(L10n.Risk.limits, trailing: {
      Text(L10n.Risk.limitsSource)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
    }, content: {
      if let risk = model.settings?.risk {
        VStack(spacing: Tokens.Space.xs) {
          FigureRow(L10n.Risk.plannedLoss, value: Money.usd(risk.plannedLossUsd.value))
          FigureRow(L10n.Risk.notionalCap, value: Money.usd(risk.positionNotionalCapUsd.value))
          FigureRow(L10n.Risk.dailyLoss, value: Money.usd(risk.maxDailyLossUsd.value))
          FigureRow(L10n.Risk.openPositions, value: String(risk.maxOpenPositions))
          FigureRow(L10n.Risk.minRoom, value: Money.usd(risk.minDailyRoomUsd.value))
          FigureRow(L10n.Risk.quoteAge,
            value: String(localized: L10n.Risk.seconds(Format.secondsNumber(risk.maxQuoteAgeSeconds.value))))
        }
        // Nil while the day's latest size is unread: never "no entry". This screen is live only.
        if model.isLive, let watching = model.watching {
          Divider()
          EntrySizingSection(sizing: EntrySizing(size: watching.latestSize, configured: SizingLimits(
            plannedLossUsd: risk.plannedLossUsd.value, notionalCapUsd: risk.positionNotionalCapUsd.value,
            dailyRoomUsd: model.dailyRoom), text: .money))
        }
      } else {
        Footnote(model.settingsError == nil ? L10n.Common.unavailable : L10n.Risk.settingsUnavailable)
      }
    })
  }
}

/// One tile per position the config allows, as on the design: an open position's symbol, size,
/// entry and what it can lose at its stop, then the stop with its state (confirmed green, pending
/// amber, missing or unknown red), and one word, "Free", for each unused slot. More positions than
/// the limit (a broker mismatch) still show every one.
private struct PositionSlots: View {
  let limit: Int
  let positions: [PositionRow]
  let entries: [EntryRow]

  /// Tiles in a row, as the design draws three slots across the card.
  static let columns = 3
  /// Height of a tile, so free and taken tiles line up, in points.
  static let tileHeight: CGFloat = 74
  /// Symbol after a confirmed stop.
  static let confirmedSymbol = "checkmark"

  private var free: Int { max(0, limit - positions.count - entries.count) }

  var body: some View {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Tokens.Space.s, alignment: .top),
      count: Self.columns), spacing: Tokens.Space.s) {
      ForEach(positions) { row in
        taken(row)
      }
      ForEach(entries) { row in
        pending(row)
      }
      ForEach(0..<free, id: \.self) { _ in
        freeTile
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(Text(L10n.Risk.slots(positions.count + entries.count, String(limit))))
  }

  /// Colours of a stop state: its tone (`StopState.tone`): green verified, amber pending, red missing.
  private func colors(_ state: StopState) -> (frame: Color, text: Color) {
    (state.tone.fill, state.tone.text)
  }

  private func taken(_ row: PositionRow) -> some View {
    let state = row.position.stop.state
    let colors = colors(state)
    return tile(frame: colors.frame) {
      SymbolText(row.position.symbol)
        .font(Tokens.Typography.bodyMono.bold())
        .foregroundStyle(Palette.textPrimary)
      Text(L10n.Risk.slotSize(Format.quantity(row.quantity), Format.price(row.entry),
        Risk.plannedLoss(entry: row.entry, stop: row.stop, quantity: row.quantity).map(Money.usd) ?? Format.missing))
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textTertiary)
        .fixedSize(horizontal: false, vertical: true)
      // Without a stop price the line says the state ("No stop"), never a bare dash.
      HStack(spacing: Tokens.Space.xxs) {
        if let stop = row.stop { Text(L10n.Risk.slotStop(Format.price(stop))) } else { Text(verbatim: state.title) }
        if state.isProtected {
          Image(systemName: Self.confirmedSymbol).accessibilityHidden(true)
        }
      }
      .font(Tokens.Typography.annotationBold)
      .foregroundStyle(colors.text)
    }
    // The state in words too, not only in colour: read by VoiceOver and shown on hover.
    .tip(Text(verbatim: state.title))
    .accessibilityElement(children: .combine)
    .accessibilityValue(Text(verbatim: state.title))
  }

  /// A slot a working entry holds: its symbol and label, framed in the entry's colour.
  private func pending(_ row: EntryRow) -> some View {
    tile(frame: EntryLook.color(row.phase)) {
      HStack(spacing: Tokens.Space.xs) {
        EntryDot(row.phase)
        SymbolText(row.symbol)
          .font(Tokens.Typography.bodyMono.bold())
          .foregroundStyle(Palette.textPrimary)
      }
      EntryBadge(row)
    }
    .accessibilityElement(children: .combine)
  }

  private var freeTile: some View {
    tile(frame: Palette.separatorStrong) {
      Text(L10n.Risk.freeSlot)
        .font(Tokens.Typography.bodyMono.bold())
        .foregroundStyle(Palette.textQuaternary)
    }
    .accessibilityElement(children: .combine)
  }

  private func tile(frame: Color, @ViewBuilder content: () -> some View) -> some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      content()
    }
    .padding(Tokens.Space.s)
    .frame(maxWidth: .infinity, minHeight: Self.tileHeight, alignment: .topLeading)
    .background(Palette.surfaceSunken, in: .rect(cornerRadius: Tokens.Radius.medium))
    .overlay {
      RoundedRectangle(cornerRadius: Tokens.Radius.medium)
        .strokeBorder(frame, lineWidth: Tokens.Stroke.thin)
    }
  }
}

/// The trading session in New York time, as the design's compact card: the clock with whether
/// the regular session is open and its hours (GET /jobs), then the last entry and flatten times.
private struct SessionCard: View {
  @Environment(AppModel.self) private var model

  /// Width of the clock's side, in points.
  static let clockWidth: CGFloat = 132
  /// Least width of the times beside the clock, in points: narrower, they go under it.
  static let figuresMinWidth: CGFloat = 180

  /// Today's regular session, when the bot reported it for today.
  private var session: SessionTimesV1? {
    model.jobs?.session.flatMap { $0.day == model.today ? $0 : nil }
  }

  var body: some View {
    Card(L10n.Risk.market) {
      // The clock beside the times; in a narrow card the times go under the clock rather than
      // being squeezed into slivers.
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .top, spacing: Tokens.Space.m) {
          clock.frame(width: Self.clockWidth, alignment: .leading)
          if let settings = model.settings?.session {
            figures(settings)
              .frame(minWidth: Self.figuresMinWidth)
              .padding(.leading, Tokens.Space.m)
              .overlay(alignment: .leading) {
                Rectangle().fill(Palette.separator).frame(width: Tokens.Stroke.thin)
              }
          }
        }
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
          clock
          if let settings = model.settings?.session {
            figures(settings)
          }
        }
      }
    }
    .task(id: model.baseURL) { await model.followJobs() }
  }

  /// The New York time and whether the session is open.
  private var clock: some View {
    TimelineView(.periodic(from: .now, by: Tokens.Motion.clockTickSeconds)) { context in
      let now = model.botTime(context.date)
      VStack(alignment: .leading, spacing: Tokens.Space.xs) {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.xs) {
          Text(verbatim: Format.marketTime(now))
            .font(Tokens.Typography.metric)
            .monospacedDigit()
            .foregroundStyle(Palette.textPrimary)
          Text(L10n.Risk.timeZone)
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textQuaternary)
        }
        .fixedSize()
        hours(now)
      }
    }
  }

  /// The last entry, the flatten and half days.
  private func figures(_ settings: SessionSettings) -> some View {
    VStack(spacing: Tokens.Space.xs) {
      FigureRow(L10n.Risk.lastEntry,
        value: String(localized: L10n.Risk.minutesBeforeClose(settings.lastEntryMinutesBeforeClose)))
      FigureRow(L10n.Risk.flatten,
        value: String(localized: L10n.Risk.minutesBeforeClose(settings.flattenMinutesBeforeClose)))
      FigureRow(L10n.Risk.halfDays, value: String(localized: settings.halfDaysEnabled ? L10n.Common.on : L10n.Common.off))
    }
  }

  /// "● open · 09:30–16:00", "● closed · …", or nothing while the session times are unread.
  @ViewBuilder private func hours(_ now: Date) -> some View {
    if let session {
      let open = now >= session.regularOpen.date && now < session.regularClose.date
      let span = Format.marketMinute(session.regularOpen.date) + Self.dash + Format.marketMinute(session.regularClose.date)
      HStack(spacing: Tokens.Space.xs) {
        // One pulse as the session opens or closes, still in between.
        PulseDot(open ? Palette.accent : Palette.textQuaternary, size: Tokens.Size.dotSmall, event: open)
        Text(open ? L10n.Risk.sessionOpen(span) : L10n.Risk.sessionClosed(span))
      }
      .font(Tokens.Typography.annotation)
      .foregroundStyle(open ? Palette.accentText : Palette.textQuaternary)
      .fixedSize()
    } else if let cause = model.jobs?.sessionCauseText {
      Text(verbatim: cause)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
    }
  }

  /// Between the session's opening and closing times.
  static let dash = "\u{2013}"
}

/// The broker account at the bot's last read, as the design's list (MacRisk v134): the account kind
/// and the read's time, equity big, three balances, the other balances and the broker's positions
/// one click away, then the orders open at the broker (its stops) and today's fills. The broker is
/// the source of truth; whether it matches the bot's records is on the broker check. Balances are
/// display only: the bot's limits are its settings, never these numbers.
private struct AccountCard: View {
  @Environment(AppModel.self) private var model

  /// The design's equity figure: larger than the other balances.
  static let equityFont = Font.system(.title3, design: .monospaced, weight: .bold)

  var body: some View {
    // The account kind sits under the title, not beside it: beside it the title gets cut.
    Card(L10n.Risk.account, tint: tint, trailing: {
      if let account = model.account?.account {
        Text(verbatim: [account.accountLabel, String(localized: L10n.Risk.readAt(
          Format.marketTime((account.balanceReadAt ?? account.readAt).date)))].compactMap { $0 }
          .joined(separator: Format.itemSeparator))
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
          .tip(Text(L10n.Risk.accountKindHelp))
      }
    }, content: {
      if let response = model.account {
        content(response)
      } else if model.accountError != nil {
        ReadFailureNote(L10n.Risk.accountUnavailable, detail: nil)
      } else {
        Footnote(L10n.Risk.accountReading)
      }
    })
    // Keyed on the account, not the read: a new read of the same account moves nothing.
    .animation(Tokens.Motion.standard, value: model.account?.state)
  }

  private var tint: Color? {
    guard let response = model.account else { return nil }
    return response.account.matchesRecords && !response.stale ? nil : Palette.warning
  }

  private func content(_ response: AccountResponseV1) -> some View {
    let account = response.account
    return VStack(alignment: .leading, spacing: Tokens.Space.s) {
      if let b = account.balances {
        balance(L10n.Risk.equity, b.equityUsd, font: Self.equityFont)
        balance(L10n.Risk.cash, b.cashUsd, font: Self.figureFont)
        balance(L10n.Risk.buyingPower, b.buyingPowerUsd, font: Self.figureFont, color: Palette.accentText)
        balance(L10n.Risk.dayResult, b.dayPlUsd, font: Self.figureFont, signed: true)
        let more = moreBalances(b)
        FooterDetail(L10n.Risk.moreBalances, count: more.count, endsCard: false) {
          ForEach(more.indices, id: \.self) { FigureRow(more[$0].label, value: more[$0].value, color: more[$0].color) }
        }
      } else {
        balance(L10n.Risk.equity, nil, font: Self.equityFont)
        balance(L10n.Risk.buyingPower, nil, font: Self.figureFont)
        Footnote(L10n.Risk.balanceNote)
      }
      let unrealized = account.positions.compactMap { $0.unrealizedPlUsd?.value }
      FooterDetail(L10n.Risk.brokerPositions,
        summary: ([String(account.positions.count)] + (unrealized.isEmpty ? [] : [Money.signedUSD(unrealized.reduce(0, +))]))
          .joined(separator: Format.itemSeparator), endsCard: false) {
        if account.positions.isEmpty {
          empty
        }
        ForEach(account.positions, id: \.self) { positionRow($0) }
      }
      SectionHeader(Text(L10n.Risk.brokerOrders)) { EmptyView() }
        .padding(.top, Tokens.Space.xs)
      if account.orders.isEmpty {
        empty
      }
      CappedList(account.orders, id: \.self, title: L10n.Risk.brokerOrders, limit: Tokens.Lists.brokerRows,
        endsCard: false) { _, order in orderRow(order) }
      SectionHeader(Text(L10n.Risk.fillsToday)) { EmptyView() }
        .padding(.top, Tokens.Space.xs)
      if account.fills.isEmpty {
        empty
      }
      // The latest fills, then "Show all N ›" on the card's bottom edge: the list grows all day.
      CappedList(account.fillsLatestFirst, id: \.self, title: L10n.Risk.fillsToday) { _, fill in fillRow(fill) }
    }
  }

  /// The balances behind "More balances ›": label, value and its colour.
  private func moreBalances(_ b: AccountBalances) -> [(label: LocalizedStringResource, value: String, color: Color)] {
    [
      (L10n.Risk.overnightBuyingPower, Money.usd(b.overnightBuyingPowerUsd.value), Palette.textSecondary),
      (L10n.Risk.positionsValue, Money.usd(b.positionsValueUsd.value), Palette.textSecondary),
      (L10n.Risk.unrealized, Money.signedUSD(b.unrealizedPlUsd.value), Palette.result(b.unrealizedPlUsd.value)),
      (L10n.Risk.dayTradesLeft, b.dayTradesLeft.map { String($0) } ?? String(localized: L10n.Risk.noLimit),
        Palette.textSecondary),
      (L10n.Risk.marginCalls, String(localized: L10n.Risk.marginValue(String(b.marginCalls),
        Money.usd(b.maintenanceMarginUsd.value))), b.marginCalls > 0 ? Palette.warningText : Palette.textSecondary),
    ]
  }

  /// A broker position: symbol, quantity, average and last price, unrealized result.
  private func positionRow(_ position: AccountPositionV1) -> some View {
    HStack(spacing: Tokens.Space.s) {
      SymbolText(position.symbol).fontWeight(.bold)
      Spacer()
      Text(verbatim: position.quantity.text)
      Text(verbatim: position.avgPrice.map { Money.price($0.value) } ?? Format.missing)
        .foregroundStyle(Palette.textTertiary)
      Text(verbatim: position.lastPrice.map { Money.price($0.value) } ?? Format.missing)
      Text(verbatim: position.unrealizedPlUsd.map { Money.signedUSD($0.value) } ?? Format.missing)
        .foregroundStyle(position.unrealizedPlUsd.map { Palette.result($0.value) } ?? Palette.textQuaternary)
    }
    .font(Tokens.Typography.calloutMono)
  }

  /// An open order at the broker: symbol, side, type, quantity, its price and status.
  private func orderRow(_ order: AccountOrderV1) -> some View {
    HStack(spacing: Tokens.Space.s) {
      SymbolText(order.symbol).fontWeight(.bold)
      Text(verbatim: ApiText.orderSide(order.side))
      Text(verbatim: ApiText.orderType(order.type))
      Text(verbatim: order.quantity.text)
      Spacer()
      if let price = order.stopPrice ?? order.limitPrice {
        Text(verbatim: Money.price(price.value))
      }
      Badge(verbatim: ApiText.orderStatus(order.status), color: Palette.profitText)
      if !order.ours {
        Badge(L10n.Risk.notOurs, color: Palette.warningText)
      }
    }
    .font(Tokens.Typography.calloutMono)
  }

  /// A fill: its time, symbol, side, type and quantity, then its price and fees. On one line when
  /// it fits; else the order on the first line and price and fees on the second, each part whole
  /// (a time or "Stop loss" never breaks inside).
  private func fillRow(_ fill: AccountFillV1) -> some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: Tokens.Space.s) {
        fillOrder(fill)
        Spacer()
        fillMoney(fill)
      }
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        fillOrder(fill)
        HStack(spacing: Tokens.Space.s) {
          Spacer()
          fillMoney(fill)
        }
      }
    }
    .font(Tokens.Typography.calloutMono)
  }

  private func fillOrder(_ fill: AccountFillV1) -> some View {
    HStack(spacing: Tokens.Space.s) {
      Text(verbatim: Format.marketTime(fill.filledAt?.date))
        .foregroundStyle(Palette.textTertiary)
      SymbolText(fill.symbol).fontWeight(.bold)
      Text(verbatim: ApiText.orderSide(fill.side))
      Text(verbatim: ApiText.orderType(fill.type))
      Text(verbatim: fill.quantity.text)
    }
    .fixedSize()
  }

  /// The price at its tick (two decimals from $1, four below); the exact fill stays in the
  /// records, the screen shows what a price reads as everywhere else. Then the fees.
  private func fillMoney(_ fill: AccountFillV1) -> some View {
    HStack(spacing: Tokens.Space.s) {
      Text(verbatim: (fill.exactPrice ?? fill.price).map { Money.price($0.value) } ?? Format.missing)
      Text(verbatim: fill.feesUsd.map { Money.usd($0.value) } ?? Format.missing)
        .foregroundStyle(Palette.warningText)
      if !fill.ours {
        Badge(L10n.Risk.notOurs, color: Palette.warningText)
      }
    }
    .fixedSize()
  }

  private var empty: some View {
    Text(L10n.Risk.none)
      .font(Tokens.Typography.callout)
      .foregroundStyle(Palette.textQuaternary)
  }

  /// The other balance figures: one size below equity.
  static let figureFont = Tokens.Typography.bodyMono.bold()

  /// A balance row with a hairline below, as the design draws them. `signed`: a result, shown
  /// with its sign and coloured as a gain or a loss.
  private func balance(
    _ label: LocalizedStringResource, _ value: DecimalString?, font: Font, color: Color = Palette.textPrimary,
    signed: Bool = false
  ) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text(label)
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textTertiary)
      Spacer()
      Group {
        if let value {
          // Counts up as it appears and on to each new balance the broker reports.
          CountingText(NSDecimalNumber(decimal: value.value).doubleValue) {
            signed ? Money.signedUSD(Decimal($0)) : Money.usd(Decimal($0))
          }
        } else {
          Text(verbatim: Format.missing)
        }
      }
      .font(font)
      .foregroundStyle(value.map { signed ? Palette.result($0.value) : color } ?? Palette.textQuaternary)
    }
    .padding(.vertical, Tokens.Space.xxs)
    .overlay(alignment: .bottom) {
      Rectangle().fill(Palette.separator).frame(height: Tokens.Stroke.thin)
    }
  }
}

#if DEBUG
#Preview {
  RiskView()
    .environment(PreviewAPI.model())
    .frame(width: PreviewAPI.windowWidth, height: PreviewAPI.windowHeight)
}
#endif
