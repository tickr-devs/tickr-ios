import SwiftUI
import TickrDesign
import TickrKit

/// Open positions (IOSPosition board): Close all in the title row, one picker chip per position,
/// then the selected one with its result big, its price against entry and stop, its protection
/// (the broker stop, three figures, the steps behind a disclosure) and Close position. Prices come
/// from the captured bars (`PositionsModel`), for display only.
struct PositionsView: View {
  @Environment(AppModel.self) private var model
  @State private var prices = Container.shared.positionsModel()
  @State private var watching = Container.shared.watchingModel()

  var body: some View {
    Screen(L10n.App.positions, tab: .positions) {
      // The slots in use, mono and dim at the end of the title row, then Close all, as on the design.
      if model.isLive, let status = model.status {
        if let limit = model.settings?.risk.maxOpenPositions {
          Text(L10n.Positions.slots(status.positions.count, limit))
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textQuaternary)
            .contentTransition(.numericText())
        }
        if !status.positions.isEmpty {
          PositionsCloseAll(symbols: Board.positions(status).map(\.symbol))
        }
      }
    } content: {
      if !model.isLive {
        // A recorded day has no open positions: they are today's, live. What it watched follows.
        Text(L10n.Home.pastDayNote(DayText.day(model.shownDay.noonInNewYork)))
          .font(.subheadline)
          .foregroundStyle(Palette.textTertiary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(Tokens.Space.l)
          .tickrCard()
          .rise()
        WatchingCard(watching: watching.watching, failure: watching.failure)
          .rise(step: PositionDetail.Order.watching.rawValue)
      } else if let status = model.status {
        let positions = Board.positions(status)
        if positions.isEmpty {
          ContentUnavailableView {
            Label { Text(L10n.Positions.none) } icon: { Image(systemName: EmptyState.nothingSymbol) }
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
      if let url = model.connection.url { await watching.load(url, day: model.shownDay) }
    }
    .task(id: model.connection.url) { await model.followAccount() }
    .task(id: WatchKey(url: model.connection.url, day: model.shownDay)) {
      guard let url = model.connection.url else { return }
      await watching.follow(url, day: model.shownDay)
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

/// "Close all" in the title row (IOSPosition board): POST /commands/emergency, which pauses
/// entries, cancels the bot's working entry orders and closes every position it holds at market.
/// It asks first, with the symbols it closes, then Face ID (`BotControl.confirmAndSend`).
struct PositionsCloseAll: View {
  @Environment(AppModel.self) private var model
  @State private var confirm = false
  /// The open positions' symbols, in the screen's order.
  let symbols: [String]

  /// The command Close all sends: the existing emergency (docs/api.md), never a new one.
  static let command = OperatorCommand.emergency

  /// The confirmation's title: "Close the last position?" for one, else "Close all N positions?".
  static func title(_ count: Int) -> LocalizedStringResource {
    count == 1 ? L10n.Positions.closeLastTitle : L10n.Positions.closeAllTitle(count)
  }

  var body: some View {
    Button(role: .destructive) {
      confirm = true
    } label: {
      Label { Text(L10n.Control.flattenAll) } icon: { Image(systemName: BotControl.flattenSymbol) }
        .fixedSize()
    }
    .buttonStyle(.action(.destructive, size: .compact))
    .disabled(!model.canCommand)
    .inFlight(model.inFlight == Self.command ? Text(Self.command.inFlightTitle) : nil)
    .confirmationDialog(Text(Self.title(symbols.count)), isPresented: $confirm, titleVisibility: .visible) {
      if model.canCommand {
        Button(role: .destructive) {
          Task { await BotControl.confirmAndSend(Self.command, model: model) }
        } label: {
          Text(L10n.Control.flattenAll)
        }
      }
      Button(role: .cancel) {} label: { Text(L10n.Common.cancel) }
    } message: {
      let list = symbols.formatted(.list(type: .and))
      Text(BotControl.target(String(localized: L10n.Positions.closeAllMessage(list)), demo: model.connection.demo))
    }
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
    // A tab never wraps or cuts its symbol or result: the equal row when every tab fits whole,
    // else the tabs at their own width in a sideways scroll.
    ViewThatFits(in: .horizontal) {
      row(stretch: true)
      ScrollView(.horizontal) { row(stretch: false) }
        .withoutScrollIndicators()
    }
    .animation(Tokens.Motion.standard, value: positions.map(\.symbol))
  }

  @ViewBuilder
  private func row(stretch: Bool) -> some View {
    let selected = model.selectedSymbol ?? positions.first?.symbol
    let empty = stretch ? max(0, Self.columns - positions.count - freeSlots) : 0
    HStack(spacing: Tokens.Space.s) {
      ForEach(positions, id: \.symbol) { position in
        let isSelected = position.symbol == selected
        Button {
          model.selectedSymbol = position.symbol
        } label: {
          VStack(spacing: Tokens.Space.xxs) {
            HStack(spacing: Tokens.Space.xs) {
              // Every tab carries its stop's dot, as on the Mac and the Main board: green verified,
              // amber pending, red missing (`StopState.tone`); the words are the tab's accessibility value.
              StopDot(position.stop.state)
              SymbolText(position.symbol)
            }
            .font(.footnote.monospaced().bold())
            .fixedSize()
            if let unrealized = marks[position.symbol]?.unrealized {
              Text(verbatim: Money.signedUSD(unrealized))
                .font(Tokens.Typography.annotationBold)
                .foregroundStyle(Palette.result(unrealized))
                .contentTransition(.numericText())
                .fixedSize()
            }
          }
          .padding(.horizontal, Tokens.Space.s)
          .frame(maxWidth: stretch ? .infinity : nil, minHeight: Self.chipHeight)
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
        .accessibilityValue(Text(verbatim: Board.stopStateTitle(position.stop.state)))
        .transition(.scale.combined(with: .opacity))
      }
      ForEach(0..<freeSlots, id: \.self) { _ in
        // Plain text, not a control: a free slot does nothing when tapped.
        Text(L10n.Positions.freeSlot)
          .font(.footnote.bold())
          .fixedSize()
          .padding(.horizontal, Tokens.Space.s)
          .frame(maxWidth: stretch ? .infinity : nil, minHeight: Self.chipHeight)
          .foregroundStyle(Palette.textQuaternary)
          .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous)
              .strokeBorder(Palette.separatorStrong, style: StrokeStyle(lineWidth: Tokens.Stroke.thin, dash: Tokens.Stroke.dash)))
      }
      ForEach(0..<empty, id: \.self) { _ in
        Color.clear.frame(maxWidth: .infinity).accessibilityHidden(true)
      }
    }
    .fixedSize(horizontal: false, vertical: true)
  }
}

private struct PositionDetail: View {
  /// Order in which the blocks rise in (`rise(step:)`).
  enum Order: Int { case chips = 1, title, levels, protection, close, watching }

  @Environment(AppModel.self) private var model
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var confirmClose = false
  let position: Position
  let marks: PositionMarks?

  var body: some View {
    let entry = position.entryPrice.value
    let stop = position.stop.price?.value
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      // As on the design: the symbol with its shares, entry and fill time under it; the open result
      // with the last price and R at the right. At large text sizes the result goes under.
      RowStack(alignment: .bottom, spacing: Tokens.Space.s) {
        VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
          SymbolText(position.symbol)
            .font(.largeTitle.monospaced().bold())
            .fixedSize()
          Text(L10n.Positions.shares(position.quantity.text, Money.price(position.entryPrice.value),
            Format.clock(position.openedAt.date)))
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textTertiary)
            // Wraps beside the result rather than being cut.
            .fixedSize(horizontal: false, vertical: true)
        }
        .layoutPriority(1)
        Spacer(minLength: 0)
        if let marks {
          // An old last bar (capture stopped, a past session) is shown as history: muted and
          // dated, never as a live result.
          let current = model.isCurrent(marks)
          VStack(alignment: typeSize.stacksRows ? .leading : .trailing, spacing: Tokens.Space.xxs) {
            Text(verbatim: Money.signedUSD(marks.unrealized))
              .font(Tokens.Typography.metric)
              .foregroundStyle(current ? Palette.result(marks.unrealized) : Palette.textQuaternary)
              .contentTransition(.numericText())
            Text(marks.resultR.map { (marks.isLive ? L10n.Positions.bidAndR : L10n.Positions.lastAndR)(
              Money.price(marks.last), Risk.text($0)) } ?? marks.priceText)
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
      ProtectionCard(position: position, marks: marks, brokerReadAt: model.status?.freshness.lastBrokerReadAt?.date,
        reconciled: model.isFresh && model.account?.stale == false)
        .rise(step: Order.protection.rawValue)

      Button(role: .destructive) {
        confirmClose = true
      } label: {
        Label { Text(L10n.Positions.closePosition) } icon: { Image(systemName: BotControl.flattenSymbol) }
      }
      .buttonStyle(.command(.destructive, tag: model.connection.demo ? Text(L10n.Control.demoTag) : nil))
      // As tall as its title needs: it wraps at large text sizes, never cut.
      .fixedSize(horizontal: false, vertical: true)
      .disabled(!model.canCommand)
      .inFlight(model.inFlight == .flattenSymbol(position.symbol)
        ? Text(OperatorCommand.flattenSymbol(position.symbol).inFlightTitle) : nil)
      .rise(step: Order.close.rawValue)
      .confirmationDialog(Text(L10n.Positions.closeNow(position.symbol)), isPresented: $confirmClose,
        titleVisibility: .visible) {
        if model.canCommand {
          Button(role: .destructive) {
            Task { await BotControl.confirmAndSend(.flattenSymbol(position.symbol), model: model) }
          } label: {
            Text(L10n.Positions.closePosition)
          }
        }
        Button(role: .cancel) {} label: { Text(L10n.Common.cancel) }
      } message: {
        Text(BotControl.target(String(localized: L10n.Positions.closeMessage(position.quantity.text)),
          demo: model.connection.demo))
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
      // No label (the board's chart speaks for itself): the note or the link to the full chart.
      HStack {
        Spacer(minLength: 0)
        if marks == nil {
          Text(L10n.Positions.waitingForBars)
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textQuaternary)
            .fixedSize(horizontal: false, vertical: true)
        } else {
          HeaderLink(L10n.Positions.openChart, action: openChart)
        }
      }
      GeometryReader { geometry in
        let height = geometry.size.height
        let width = geometry.size.width
        ZStack(alignment: .topLeading) {
          if let marks {
            price(marks, width: width, height: height)
          }
          line(L10n.Positions.entryLevel(Money.price(entry)), color: Palette.textQuaternary,
            textColor: Palette.textTertiary, y: height * level(of: entry), width: width)
          if let stop {
            // The lower level's label hangs under its line, so the two labels never meet.
            line(L10n.Positions.stopLevel(Money.price(stop)), color: Palette.loss, textColor: Palette.lossText,
              y: height * level(of: stop), width: width, below: stop < entry)
          }
        }
      }
      .frame(height: Self.height)
      .dynamicTypeSize(...Self.largestLabelSize)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Text(L10n.Positions.levels(Money.price(entry),
        stop.map { Money.price($0) } ?? String(localized: L10n.Common.unknown))))
    }
    .padding(Tokens.Space.m)
    .tickrCard()
    .onAppear {
      withAnimation(Tokens.Motion.draw.delay(Tokens.Motion.stagger * Double(PositionDetail.Order.levels.rawValue))) {
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

/// The board's Protection card: the broker stop as the headline in its state's colour (`StopState`),
/// three figures (the planned loss, the distance to the stop, the worst and best excursion), and
/// "How it was protected ›" opening the steps the bot proved, with when it last read the broker.
private struct ProtectionCard: View {
  /// Digits after the point of the distance to the stop, in percent.
  static let percentDigits = 1

  @State private var open = false
  let position: Position
  let marks: PositionMarks?
  /// When the bot last read the broker, and whether that read is current (`ProtectionSteps`).
  let brokerReadAt: Date?
  let reconciled: Bool

  /// "−0.6 / +1.2 R", or in dollars while R is undefined; a dash without bars.
  private var excursion: String {
    guard let marks else { return Format.missing }
    if let adverse = marks.adverseR, let favorable = marks.favorableR {
      return Money.signed(adverse, fractionDigits: 1) + Format.slash + Risk.text(favorable)
    }
    return Money.signedUSD(marks.adverse) + Format.slash + Money.signedUSD(marks.favorable)
  }

  var body: some View {
    let entry = position.entryPrice.value
    let stop = position.stop.price?.value
    let state = position.stop.state
    let price = stop.map { Money.price($0) } ?? Format.missing
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      CardLabel(L10n.Positions.protection)
      Label {
        Text(state == .verified ? L10n.Positions.stopAtBroker(price)
          : L10n.Positions.stopState(price, Board.stopStateTitle(state)))
          .fixedSize(horizontal: false, vertical: true)
      } icon: {
        Image(systemName: state.symbol).foregroundStyle(state.tone.text)
      }
      .font(.headline)
      .foregroundStyle(state == .verified ? Palette.textPrimary : state.tone.text)
      // Three figures in a row; one under another at large text sizes, so labels and figures stay whole.
      RowStack(alignment: .top, spacing: Tokens.Space.s) {
        figure(L10n.Positions.maxLoss,
          Risk.plannedLoss(entry: entry, stop: stop, quantity: position.quantity.value).map(Money.usd) ?? Format.missing)
        figure(L10n.Positions.toStop, stop.map {
          Percent.signed(fraction: ($0 - entry) / entry, fractionDigits: Self.percentDigits)
        } ?? Format.missing)
        figure(L10n.Positions.excursion, excursion)
      }
      DisclosureGroup(isExpanded: $open) {
        ProtectionSteps(position: position, brokerReadAt: brokerReadAt, reconciled: reconciled)
          .padding(.top, Tokens.Space.s)
      } label: {
        HStack(spacing: Tokens.Space.s) {
          Text(L10n.Positions.howProtected)
            .foregroundStyle(Palette.textPrimary)
          Spacer(minLength: Tokens.Space.s)
          // When the bot last read the broker; amber while that read is not current.
          Text(L10n.Positions.checkedAt(brokerReadAt.map(Format.clock) ?? Format.missing))
            .font(Tokens.Typography.annotation)
            .foregroundStyle(reconciled && brokerReadAt != nil ? Palette.textQuaternary : Palette.warningText)
        }
        .font(.subheadline)
        .frame(minHeight: Tokens.Size.touchTarget)
      }
      .tint(Palette.textQuaternary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, Tokens.Space.l)
    .padding(.vertical, Tokens.Space.m)
    .tickrCard(tint: state.isProtected ? nil : Palette.loss)
  }

  /// One of the three figures: its name over a bold mono value, as on the board.
  private func figure(_ label: LocalizedStringResource, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
      Text(label)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textTertiary)
      Text(verbatim: value)
        .font(.subheadline.monospaced().bold())
        .foregroundStyle(Palette.textPrimary)
        .contentTransition(.numericText())
        .fixedSize()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

/// What the bot proved about this position, step by step, drawn top to bottom.
private struct ProtectionSteps: View {
  /// Side of a step's dot, in points.
  static let dotSide: CGFloat = 14
  /// Glow around a step's dot, in points.
  static let glowRadius: CGFloat = 5

  @State private var progress: CGFloat = 0
  /// Once the chain has assembled, a dot that changes pops at once instead of in its turn.
  @State private var assembled = false
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
                // As on the board: the dots pop in one after another as the line comes down, and
                // a step pops again when the bot proves it (or loses it): one pop per real change.
                .popIn(delay: assembled ? 0 : Self.firstDelay + Double(index) * Tokens.Motion.popStagger)
                .id(step.ok)
              Text(step.label).font(.footnote)
              Spacer()
              if step.badge {
                // The stop's state as a tag, as on the design: green VERIFIED, red otherwise.
                Badge(verbatim: step.detail, color: step.ok ? Palette.profitText : Palette.lossText)
              } else {
                Text(verbatim: step.detail)
                  .font(Tokens.Typography.annotation)
                  .foregroundStyle(Palette.textQuaternary)
              }
            }
            // The dot's colour says it to the eye; VoiceOver hears it.
            .accessibilityElement(children: .combine)
            .accessibilityValue(Text(step.ok ? L10n.Access.proven : L10n.Access.notProven))
          }
        }
      }
    }
    .padding(.vertical, Tokens.Space.xs)
    .onAppear {
      withAnimation(Tokens.Motion.fill.delay(Self.firstDelay)) { progress = 1 }
    }
    .task {
      // Later changes pop at once; the first assembly keeps its rhythm.
      try? await Task.sleep(for: .seconds(Self.firstDelay + Double(steps.count) * Tokens.Motion.popStagger))
      assembled = true
    }
  }

  /// When the line starts down and the first dot pops: one beat after the disclosure opens.
  private static var firstDelay: Double { Tokens.Motion.stagger }

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

  /// One step of the chain: its line, the detail on the right (a time, or the stop's state as a
  /// tag), and whether it is proven.
  private struct Step {
    let label: LocalizedStringResource
    let detail: String
    var badge = false
    let ok: Bool
  }

  private var steps: [Step] {
    let state = position.stop.state
    return [
      Step(label: L10n.Positions.entrySent, detail: entryDetail, ok: entryProven),
      Step(label: L10n.Positions.filled(position.quantity.text, Money.price(position.entryPrice.value)),
        detail: Format.clock((position.entry.filledAt ?? position.openedAt).date), ok: true),
      // No time: the status does not say when the stop was sent, and its order id means nothing here.
      Step(label: L10n.Positions.stopSent(position.stop.price.map { Money.price($0.value) } ?? Format.missing),
        detail: "", ok: state == .pending || state == .verified),
      Step(label: L10n.Positions.stopWorking, detail: Board.stopStateTitle(state), badge: true, ok: state.isProtected),
      Step(label: L10n.Positions.reconciled, detail: brokerReadAt.map(Format.clock) ?? Format.missing,
        ok: brokerReadAt != nil && reconciled),
    ]
  }
}
