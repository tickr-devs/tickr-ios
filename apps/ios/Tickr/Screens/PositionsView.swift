import SwiftUI
import TickrDesign
import TickrKit

/// Open positions: one picker chip per position, then the selected one with its price against
/// entry and stop, its protection chain, risk numbers and a Flatten button. Prices come from the
/// captured bars (`PositionsModel`), for display only.
struct PositionsView: View {
  @Environment(AppModel.self) private var model
  @State private var prices = Container.shared.positionsModel()
  @State private var watching = Container.shared.watchingModel()

  var body: some View {
    Screen(L10n.App.positions, tab: .positions) {
      // The slots in use, mono and dim at the end of the title row, as on the design.
      if let status = model.status, let limit = model.settings?.risk.maxOpenPositions {
        Text(L10n.Positions.slots(status.positions.count, limit))
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
          .contentTransition(.numericText())
      }
    } content: {
      ConnectionPrompt()
      if let status = model.status {
        let positions = Board.positions(status)
        if positions.isEmpty {
          ContentUnavailableView {
            Label { Text(L10n.Positions.none) } icon: { BrandMark.empty() }
          } description: {
            if let block = status.entryBlock {
              Text(verbatim: ApiText.entryBlock(block))
            } else {
              Text(L10n.Positions.watching)
            }
          }
          .rise()
        } else {
          PositionChips(positions: positions, marks: prices.marks.filter { model.isCurrent($0.value) })
            .rise(step: PositionDetail.Order.chips.rawValue)
          if let position = positions.first(where: { $0.symbol == model.selectedSymbol }) ?? positions.first {
            PositionDetail(position: position, marks: prices.marks[position.symbol])
              .id(position.symbol)
              .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
          }
        }
        WatchingCard(watching: watching.watching, failure: watching.failure)
          .rise(step: PositionDetail.Order.watching.rawValue)
      }
    }
    .animation(Tokens.Motion.standard, value: model.selectedSymbol)
    .refreshable {
      await model.refresh()
      if let url = model.connection.url, let status = model.status { await prices.load(url, status: status) }
      if let url = model.connection.url { await watching.load(url, day: model.today) }
    }
    .task(id: model.connection.url) { await model.followAccount() }
    .task(id: WatchKey(url: model.connection.url, day: model.today)) {
      guard let url = model.connection.url else { return }
      await watching.follow(url, day: model.today)
    }
    .task(id: followKey) {
      guard let url = model.connection.url, let status = model.status, !status.positions.isEmpty else { return }
      await prices.follow(url, status: status)
    }
  }

  /// Changes when the address, the session or the open positions change, restarting the reads.
  private var followKey: FollowKey {
    FollowKey(url: model.connection.url, day: model.status.map { WireDate(newYorkDateOf: $0.writtenAt.date) },
      positions: model.status?.positions ?? [])
  }

  private struct WatchKey: Hashable {
    let url: URL?
    let day: WireDate
  }

  private struct FollowKey: Hashable {
    let url: URL?
    let day: WireDate?
    let positions: [Position]
  }
}

private struct PositionChips: View {
  @Environment(AppModel.self) private var model
  let positions: [Position]
  let marks: [String: PositionMarks]

  /// Slots the bot may still fill, from max_open_positions in its settings; none while unknown.
  private var freeSlots: Int {
    guard let limit = model.settings?.risk.maxOpenPositions else { return 0 }
    return max(0, limit - positions.count)
  }

  /// Columns of the chip row: positions and free slots share them equally, so a lone position's
  /// chip is a third of the row as on the design, never the whole width.
  static let columns = 3
  /// Least height of a chip, in points.
  static let chipHeight: CGFloat = 40

  var body: some View {
    let selected = model.selectedSymbol ?? positions.first?.symbol
    let empty = max(0, Self.columns - positions.count - freeSlots)
    HStack(spacing: Tokens.Space.s) {
      ForEach(positions, id: \.symbol) { position in
        let isSelected = position.symbol == selected
        Button {
          model.selectedSymbol = position.symbol
        } label: {
          VStack(spacing: Tokens.Space.xxs) {
            HStack(spacing: Tokens.Space.xs) {
              // Only a stop that is not verified shows here; a protected position needs no word.
              if !position.stop.state.isProtected {
                Image(systemName: StopGlyph.stateSymbol(position.stop.state))
                  .foregroundStyle(Palette.lossText)
                  .accessibilityLabel(Text(verbatim: Board.stopStateTitle(position.stop.state)))
              }
              Text(verbatim: position.symbol)
            }
            .font(.footnote.monospaced().bold())
            if let unrealized = marks[position.symbol]?.unrealized {
              Text(verbatim: Money.signed(unrealized))
                .font(Tokens.Typography.annotationBold)
                .foregroundStyle(Palette.result(unrealized))
                .contentTransition(.numericText())
            }
          }
          .lineLimit(1)
          .minimumScaleFactor(Tokens.Shrink.standard)
          .frame(maxWidth: .infinity, minHeight: Self.chipHeight)
          .foregroundStyle(Palette.textPrimary)
          .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous)
              .fill(isSelected ? Palette.info.opacity(Tokens.Opacity.wash) : Palette.surface))
          .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous)
              .strokeBorder(isSelected ? Palette.info : Palette.separatorStrong))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .transition(.scale.combined(with: .opacity))
      }
      ForEach(0..<freeSlots, id: \.self) { index in
        VStack(spacing: Tokens.Space.xxs) {
          Text(L10n.Positions.freeSlot).font(.footnote.monospaced().bold())
          Text(L10n.Positions.slotNumber(positions.count + index + 1)).font(Tokens.Typography.annotationBold)
        }
        .lineLimit(1)
        .minimumScaleFactor(Tokens.Shrink.standard)
        .frame(maxWidth: .infinity, minHeight: Self.chipHeight)
        .foregroundStyle(Palette.textQuaternary)
        .overlay(
          RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous)
            .strokeBorder(Palette.separatorStrong, style: StrokeStyle(lineWidth: Tokens.Stroke.thin, dash: Tokens.Stroke.dash)))
        .accessibilityElement(children: .combine)
      }
      ForEach(0..<empty, id: \.self) { _ in
        Color.clear.frame(maxWidth: .infinity).accessibilityHidden(true)
      }
    }
    .fixedSize(horizontal: false, vertical: true)
    .animation(Tokens.Motion.standard, value: positions.map(\.symbol))
  }
}

private struct PositionDetail: View {
  /// Order in which the blocks rise in (`rise(step:)`).
  enum Order: Int { case chips = 1, title, levels, chain, stats, flatten, watching }

  /// Height of the Flatten button, in points.
  static let buttonHeight: CGFloat = 50
  /// Multiplies a fraction into percent.
  static let percent: Decimal = 100
  /// Digits after the point of the distance to the stop, in percent.
  static let percentDigits = 1

  @Environment(AppModel.self) private var model
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var confirmFlatten = false
  let position: Position
  let marks: PositionMarks?

  /// "−0.6 / +1.2 R", or per share in dollars while R is undefined; a dash without bars.
  private var excursion: String {
    guard let marks else { return Format.missing }
    if let adverse = marks.adverseR, let favorable = marks.favorableR {
      return Money.signed(adverse, fractionDigits: 1) + Format.slash + Risk.text(favorable)
    }
    return Money.signed(marks.adverse) + Format.slash + Money.signed(marks.favorable)
  }

  var body: some View {
    let entry = position.entryPrice.value
    let stop = position.stop.price?.value
    let quantity = position.quantity.value
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      // As on the design: the symbol with its shares, entry and fill time under it; the open result
      // with the last price and R at the right. At large text sizes the result goes under.
      RowStack(alignment: .bottom, spacing: Tokens.Space.s) {
        VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
          Text(verbatim: position.symbol)
            .font(.title.monospaced().bold())
            .lineLimit(1)
            .fixedSize()
          Text(L10n.Positions.shares(position.quantity.text, Money.price(position.entryPrice.value),
            Format.clock(position.openedAt.date)))
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textTertiary)
            // One line beside the result, as on the design; wrapped only when the result goes under.
            .lineLimit(typeSize.stacksRows ? nil : 1)
            .minimumScaleFactor(typeSize.stacksRows ? 1 : Tokens.Shrink.slight)
            .fixedSize(horizontal: false, vertical: true)
        }
        .layoutPriority(1)
        Spacer(minLength: 0)
        if let marks {
          // An old last bar (capture stopped, a past session) is shown as history: muted and
          // dated, never as a live result.
          let current = model.isCurrent(marks)
          VStack(alignment: typeSize.stacksRows ? .leading : .trailing, spacing: Tokens.Space.xxs) {
            Text(verbatim: Money.signed(marks.unrealized))
              .font(Tokens.Typography.metric)
              .foregroundStyle(current ? Palette.result(marks.unrealized) : Palette.textQuaternary)
              .contentTransition(.numericText())
            Text(marks.resultR.map { L10n.Positions.lastAndR(Money.plain(marks.last), Risk.text($0)) }
              ?? L10n.Positions.last(Money.plain(marks.last)))
              .font(Tokens.Typography.annotation)
              .foregroundStyle(Palette.textTertiary)
            if !current {
              Text(L10n.Positions.asOf(Format.clock(marks.lastAt.addingTimeInterval(PositionMarks.barSeconds))))
                .font(Tokens.Typography.annotationBold)
                .foregroundStyle(Palette.warningText)
            }
          }
          .accessibilityElement(children: .combine)
        }
      }
      .rise(step: Order.title.rawValue)

      LevelsCard(entry: entry, stop: stop, marks: marks, current: marks.map(model.isCurrent) ?? false) {
        model.selectedSymbol = position.symbol
        model.selectedTab = .chart
      }
        .rise(step: Order.levels.rawValue)
      ProtectionChain(position: position, brokerReadAt: model.status?.freshness.lastBrokerReadAt?.date,
        reconciled: model.isFresh && model.account?.stale == false)
        .rise(step: Order.chain.rawValue)

      // Three tiles in a row; one under another at large text sizes, so labels and figures stay whole.
      RowStack(alignment: .top, spacing: Tokens.Space.s) {
        StatTile(label: L10n.Positions.maxLoss,
          value: Risk.plannedLoss(entry: entry, stop: stop, quantity: quantity).map { Money.plain($0) }
            ?? Format.missing)
        StatTile(label: L10n.Positions.toStop,
          value: stop.map {
            Money.signed(($0 - entry) / entry * Self.percent, fractionDigits: Self.percentDigits) + Format.percentSign
          } ?? Format.missing)
        StatTile(label: L10n.Positions.excursion, value: excursion)
      }
      // One height for the three tiles, as on the design.
      .fixedSize(horizontal: false, vertical: true)
      .rise(step: Order.stats.rawValue)

      Button(role: .destructive) {
        confirmFlatten = true
      } label: {
        Text(L10n.Positions.flattenEllipsis(position.symbol))
          .font(.subheadline.weight(.semibold))
          .frame(maxWidth: .infinity, minHeight: Self.buttonHeight)
          .foregroundStyle(Palette.lossText)
          .background(Palette.loss.opacity(Tokens.Opacity.wash),
            in: RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous))
          .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous)
            .strokeBorder(Palette.loss.opacity(Tokens.Opacity.border)))
      }
      .buttonStyle(.plain)
      .disabled(!model.canCommand)
      .opacity(model.canCommand ? 1 : Tokens.Opacity.border)
      .rise(step: Order.flatten.rawValue)
      .confirmationDialog(Text(L10n.Positions.closeNow(position.symbol)), isPresented: $confirmFlatten,
        titleVisibility: .visible) {
        if model.canCommand {
          Button(role: .destructive) {
            Task { await BotControl.confirmAndSend(.flattenSymbol(position.symbol), model: model) }
          } label: {
            Text(L10n.Positions.flatten(position.symbol))
          }
        }
        Button(role: .cancel) {} label: { Text(L10n.Common.cancel) }
      } message: {
        Text(BotControl.target(String(localized: L10n.Positions.flattenMessage), demo: model.connection.demo))
      }
    }
  }
}

/// The design's risk band: entry and broker stop as two dashed levels, with the price since the
/// fill as a line over a soft area, all on one price scale measured in R (entry to stop) so the
/// entry sits near the middle and the stop near the bottom with room under it. Without bars only
/// the levels show, with a note that the price line waits for them.
private struct LevelsCard: View {
  /// Height of the band drawing, in points.
  static let height: CGFloat = 112
  /// Room shown above the entry and below the stop, in R, as the design spaces them.
  static let roomAbove: Decimal = 1.15
  static let roomBelow: Decimal = 0.55
  /// Space kept above the highest and below the lowest price when the scale has no R, as a
  /// fraction of the height.
  static let inset: CGFloat = 0.12
  /// Where everything sits when the scale has no range (one price only), as a fraction from the top.
  static let middle: CGFloat = 0.5
  /// Width of the price line, in points.
  static let priceLine: CGFloat = 2.4
  /// Largest text size of the level labels: they sit on their lines in a drawing of fixed height,
  /// so larger text would cover the other level. The levels are also in the drawing's VoiceOver label.
  static let largestLabelSize = DynamicTypeSize.xxLarge

  @State private var drawn = false
  let entry: Decimal
  let stop: Decimal?
  let marks: PositionMarks?
  /// Whether the marks are current; an old last close does not pulse.
  let current: Bool
  /// Opens the Chart tab on this symbol.
  let openChart: () -> Void

  /// Entry minus stop, when the stop is below the entry.
  private var risk: Decimal? {
    guard let stop, stop < entry else { return nil }
    return entry - stop
  }

  /// Highest and lowest price the drawing must show.
  private var top: Decimal {
    let room = risk.map { entry + $0 * Self.roomAbove } ?? entry
    return max(room, marks?.high ?? entry)
  }
  private var bottom: Decimal {
    let room = risk.map { entry - $0 - $0 * Self.roomBelow } ?? min(stop ?? entry, entry)
    return min(room, marks?.low ?? entry)
  }

  /// Where `price` sits, as a fraction of the height from the top.
  private func level(of price: Decimal) -> CGFloat {
    let range = top - bottom
    guard range > 0 else { return Self.middle }
    let share = CGFloat(NSDecimalNumber(decimal: (top - price) / range).doubleValue)
    let inset = risk == nil ? Self.inset : 0
    return inset + share * (1 - inset - inset)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      // The label, then its note; the note goes under it at large text sizes.
      RowStack {
        CardLabel(L10n.Positions.riskBand)
        Spacer()
        if marks == nil {
          Text(L10n.Positions.waitingForBars)
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textQuaternary)
        } else {
          Button(action: openChart) {
            Text(L10n.Positions.openChart)
              .font(Tokens.Typography.annotation)
              .foregroundStyle(Palette.infoText)
          }
          .buttonStyle(.plain)
        }
      }
      GeometryReader { geometry in
        let height = geometry.size.height
        let width = geometry.size.width
        ZStack(alignment: .topLeading) {
          if let marks {
            price(marks, width: width, height: height)
          }
          line(L10n.Positions.entry, color: Palette.textQuaternary,
            textColor: Palette.textTertiary, y: height * level(of: entry), width: width)
          if let stop {
            // The lower level's label hangs under its line, so the two labels never meet.
            line(L10n.Positions.stopLevel(Money.plain(stop)), color: Palette.loss, textColor: Palette.lossText,
              y: height * level(of: stop), width: width, below: stop < entry)
          }
        }
      }
      .frame(height: Self.height)
      .dynamicTypeSize(...Self.largestLabelSize)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Text(L10n.Positions.levels(Money.plain(entry),
        stop.map { Money.plain($0) } ?? String(localized: L10n.Common.unknown))))
    }
    .padding(Tokens.Space.m)
    .tickrCard()
    .onAppear {
      withAnimation(Tokens.Motion.draw.delay(Tokens.Motion.stagger * Double(PositionDetail.Order.flatten.rawValue))) {
        drawn = true
      }
    }
  }

  /// The closes since the fill across the width, drawn in, over a soft area down to the bottom.
  private func price(_ marks: PositionMarks, width: CGFloat, height: CGFloat) -> some View {
    let points = marks.closes.enumerated().map { index, close in
      CGPoint(x: marks.closes.count > 1 ? width * CGFloat(index) / CGFloat(marks.closes.count - 1) : width,
        y: height * level(of: close))
    }
    let color = current ? Palette.accent : Palette.textQuaternary
    return ZStack(alignment: .topLeading) {
      if let first = points.first, let last = points.last {
        Path { path in
          path.move(to: CGPoint(x: first.x, y: height))
          for point in points { path.addLine(to: point) }
          path.addLine(to: CGPoint(x: last.x, y: height))
          path.closeSubpath()
        }
        .fill(color.opacity(Tokens.Opacity.wash))
        .opacity(drawn ? 1 : 0)
      }
      Path { path in path.addLines(points) }
        .trim(from: 0, to: drawn ? 1 : 0)
        .stroke(color, style: StrokeStyle(lineWidth: Self.priceLine, lineCap: .round, lineJoin: .round))
    }
    .frame(width: width, height: height)
  }

  /// A dashed level across the width with its label just above it, or just under it when `below`.
  private func line(
    _ text: LocalizedStringResource, color: Color, textColor: Color, y: CGFloat, width: CGFloat, below: Bool = false
  ) -> some View {
    ZStack(alignment: .leading) {
      Path { path in
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: width, y: 0))
      }
      .stroke(color, style: StrokeStyle(lineWidth: Tokens.Stroke.thin, dash: Tokens.Stroke.dash))
      .frame(height: Tokens.Stroke.thin)
      .clipped()
      Text(text)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(textColor)
        .fixedSize()
        .alignmentGuide(VerticalAlignment.center) { $0[below ? .top : .bottom] }
        .offset(x: Tokens.Space.xs, y: below ? Tokens.Space.xxs : -Tokens.Space.xxs)
    }
    .offset(y: y)
  }
}

/// What the bot proved about this position, step by step, drawn top to bottom.
private struct ProtectionChain: View {
  /// Side of a step's dot, in points.
  static let dotSide: CGFloat = 14
  /// Glow around a step's dot, in points.
  static let glowRadius: CGFloat = 5
  /// Scale of a dot the drawn line has not reached yet (not zero, so the transform stays invertible).
  static let hiddenScale: CGFloat = 0.01

  @State private var progress: CGFloat = 0
  let position: Position
  /// When the bot last read the broker's positions and orders, and whether that read is current:
  /// the status is current and GET /account says the read is within account_stale_seconds. A
  /// failing reconciliation stops the read while the status keeps updating, so the status alone
  /// proves nothing.
  let brokerReadAt: Date?
  let reconciled: Bool

  var body: some View {
    let steps = self.steps
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      CardLabel(L10n.Positions.chain)
      ZStack(alignment: .topLeading) {
        GeometryReader { geometry in
          Capsule().fill(Palette.separator).frame(width: Tokens.Stroke.bold)
          Capsule().fill(Palette.profit).frame(width: Tokens.Stroke.bold, height: geometry.size.height * progress)
        }
        .frame(width: Tokens.Stroke.bold)
        .padding(.leading, (Self.dotSide - Tokens.Stroke.bold) / 2)
        .padding(.vertical, Self.dotSide / 2)
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
          ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
            HStack(spacing: Tokens.Space.m) {
              Circle()
                .fill(step.ok ? Palette.profit : Palette.loss)
                .frame(width: Self.dotSide, height: Self.dotSide)
                .shadow(color: (step.ok ? Palette.profit : Palette.loss).opacity(Tokens.Opacity.medium),
                  radius: Self.glowRadius)
                .scaleEffect(progress >= CGFloat(index) / CGFloat(max(steps.count - 1, 1)) ? 1 : Self.hiddenScale)
              Text(step.label).font(.footnote)
              Spacer()
              Text(verbatim: step.detail)
                .font(Tokens.Typography.annotation)
                .foregroundStyle(Palette.textQuaternary)
            }
            // The dot's colour says it to the eye; VoiceOver hears it.
            .accessibilityElement(children: .combine)
            .accessibilityValue(Text(step.ok ? L10n.Access.proven : L10n.Access.notProven))
          }
        }
      }
    }
    .padding(.horizontal, Tokens.Space.l)
    .padding(.vertical, Tokens.Space.m)
    .tickrCard()
    .onAppear {
      withAnimation(Tokens.Motion.fill.delay(Tokens.Motion.stagger * Double(PositionDetail.Order.flatten.rawValue))) {
        progress = 1
      }
    }
  }

  /// The entry order went out exactly once and the broker took it: acknowledged, or filled.
  private var entryProven: Bool {
    let entry = position.entry
    return entry.sends == 1 && (entry.latestOutcome == .acknowledged || entry.filledAt != nil)
  }

  /// When the entry was sent; an alarm when it went out other than once; an unknown outcome the
  /// broker later confirmed says so; the bot's cause when it has no record.
  private var entryDetail: String {
    let entry = position.entry
    if entry.sentOtherThanOnce, let sends = entry.sends {
      return String(localized: L10n.Positions.entrySends(sends))
    }
    if entry.sendOutcome == .unknown, entry.latestOutcome == .acknowledged {
      return String(localized: L10n.Positions.entryConfirmedLater)
    }
    return entry.sentAt.map { Format.clock($0.date) }
      ?? ApiText.prose(position.entryCauseCodes, text: position.entryCause) ?? Format.missing
  }

  private var steps: [(label: LocalizedStringResource, detail: String, ok: Bool)] {
    let state = position.stop.state
    return [
      (L10n.Positions.entrySent, entryDetail, entryProven),
      (L10n.Positions.filled(position.quantity.text, Money.price(position.entryPrice.value)),
        Format.clock((position.entry.filledAt ?? position.openedAt).date), true),
      // No time: the status does not say when the stop was sent, and its order id means nothing here.
      (L10n.Positions.stopSent(position.stop.price.map { Money.price($0.value) } ?? Format.missing), "",
        state == .pending || state == .verified),
      (L10n.Positions.stopWorking, Board.stopStateTitle(state), state.isProtected),
      (L10n.Positions.reconciled, brokerReadAt.map(Format.clock) ?? Format.missing, brokerReadAt != nil && reconciled),
    ]
  }
}
