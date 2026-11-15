import ApertureDesign
import ApertureKit
import SwiftUI

/// The first screen: the day's result, the one line that says what the bot is doing, live events,
/// open positions and the live flow. The power button opens bot control.
struct HomeView: View {
  /// Order in which the blocks rise in (`rise(step:)`); open positions follow one step apart.
  private enum Order: Int { case day = 1, summary, ticker, positions, flow = 6 }

  @Environment(AppModel.self) private var model
  @State private var showControl = false
  @State private var prices = Container.shared.positionsModel()
  @State private var dayModel = Container.shared.homeDayModel()

  var body: some View {
    Screen(L10n.App.name) {
      ConnectionPrompt()
      DayLine(days: dayModel).rise(step: Order.day.rawValue)
      Summary(past: dayModel.shown).rise(step: Order.summary.rawValue)
      if let past = dayModel.shown {
        // A recorded day: its result above, nothing live below.
        Text(L10n.Home.pastDayNote(Format.day(past.day.noonInNewYork)))
          .font(.subheadline)
          .foregroundStyle(Palette.textTertiary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(Tokens.Space.l)
          .apertureCard()
          .rise(step: Order.positions.rawValue)
      } else if let status = model.status {
        if let event = Board.events(status).first {
          LatestEventLine(event: event)
            .rise(step: Order.ticker.rawValue)
        }
        ForEach(Array(Board.positions(status).enumerated()), id: \.element.symbol) { index, position in
          PositionRow(position: position, marks: prices.marks[position.symbol])
            .rise(step: Order.positions.rawValue + index)
        }
        if status.positions.isEmpty {
          Text(L10n.Home.noPosition)
            .font(.subheadline)
            .foregroundStyle(Palette.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Tokens.Space.l)
            .apertureCard()
            .rise(step: Order.positions.rawValue)
        }
        let todayFlow = model.flow?.day == model.today ? model.flow : nil
        LiveFlowCard(status: status, flow: todayFlow, flowPending: model.flowPending,
          marks: FlowBoard.marks(flow: todayFlow, skipped: model.skipped?.day == model.today ? model.skipped : nil),
          maxPositions: model.settings?.risk.maxOpenPositions,
          current: model.isFresh && WireDate(newYorkDateOf: status.writtenAt.date) == model.today)
          .rise(step: Order.flow.rawValue)
      }
    }
    .toolbar {
      // The mark the opening animation flies into (LaunchHandoff); it pulses while data is current.
      ToolbarItem(placement: .topBarLeading) {
        BrandMark(size: Tokens.Size.logoSmall, live: model.isFresh)
          .onGeometryChange(for: CGPoint.self) { proxy in
            let frame = proxy.frame(in: .global)
            return CGPoint(x: frame.midX, y: frame.midY)
          } action: { centre in
            model.homeMarkCentre = centre
          }
      }
      .sharedBackgroundVisibility(.hidden)
      ToolbarItemGroup(placement: .topBarTrailing) {
        if let environment = model.status?.environment {
          EnvironmentBadge(environment: environment)
        }
        Button {
          showControl = true
        } label: {
          Image(systemName: "power")
            .fontWeight(.semibold)
            .foregroundStyle(model.canCommand && dayModel.shown == nil ? Palette.warningText : Palette.textQuaternary)
        }
        .disabled(!model.canCommand || dayModel.shown != nil)
        .accessibilityLabel(Text(L10n.Control.title))
        NavigationLink {
          SettingsView()
        } label: {
          Image(systemName: "gearshape")
        }
        .accessibilityLabel(Text(L10n.Home.settings))
      }
    }
    .botControl(isPresented: $showControl)
    .refreshable {
      await model.refreshAll()
      if let url = model.connection.url { await dayModel.load(url) }
    }
    // A new address or a new day (the bot's clock, known once its status arrives) reads at once.
    .task(id: DaysKey(url: model.connection.url, today: model.today)) { await model.followFlow() }
    .task(id: DaysKey(url: model.connection.url, today: model.today)) {
      guard let url = model.connection.url else { return }
      await dayModel.load(url)
    }
    .task(id: followKey) {
      guard let url = model.connection.url, let status = model.status, !status.positions.isEmpty else { return }
      await prices.follow(url, status: status)
    }
  }
}

extension HomeView {
  /// Changes when the address, the session or the open positions change, restarting the reads.
  fileprivate var followKey: FollowKey {
    FollowKey(url: model.connection.url, day: model.status.map { WireDate(newYorkDateOf: $0.writtenAt.date) },
      positions: model.status?.positions ?? [])
  }

  /// The recorded days are listed again for another bot and when a new day begins.
  fileprivate struct DaysKey: Hashable {
    let url: URL?
    let today: WireDate
  }

  fileprivate struct FollowKey: Hashable {
    let url: URL?
    let day: WireDate?
    let positions: [Position]
  }
}

/// The session the status describes: "today" only when it is today's New York date on the bot's
/// clock, else the last session (a weekend, a day off), which is never shown as live.
private struct DayLine: View {
  @Environment(AppModel.self) private var model
  let days: HomeDayModel

  var body: some View {
    let written = model.status?.writtenAt.date ?? model.botNow
    let isToday = WireDate(newYorkDateOf: written) == model.today
    HStack(spacing: Tokens.Space.s) {
      Button { days.back() } label: { Image(systemName: "chevron.left") }
        .disabled(!days.canGoBack)
        .accessibilityLabel(Text(L10n.Home.previousDay))
      if let past = days.shown {
        Text(verbatim: Format.day(past.day.noonInNewYork))
          .foregroundStyle(Palette.highlightText)
        Spacer()
        Button { days.showToday() } label: { Text(L10n.Home.backToToday) }
      } else {
        if isToday, model.response?.stale == false {
          PulseDot(Palette.profit, size: Tokens.Size.dotSmall)
        }
        Text(isToday ? L10n.Common.today(Format.day(written)) : L10n.Activity.lastSession(Format.day(written)))
        Spacer()
        Text(Format.age(model.response))
          .contentTransition(.numericText())
      }
      Button { days.forward() } label: { Image(systemName: "chevron.right") }
        .disabled(!days.canGoForward)
        .accessibilityLabel(Text(L10n.Home.nextDay))
    }
    .font(Tokens.Typography.captionMono)
    .foregroundStyle(Palette.textQuaternary)
    .buttonStyle(.borderless)
    .animation(Tokens.Motion.standard, value: days.shown)
  }
}

/// The ring with the day's result next to the headline.
private struct Summary: View {
  /// Side of the result ring, in points.
  static let ringSide: CGFloat = 136
  /// Smallest scale the result may shrink to inside the ring.
  static let minimumScale = 0.6
  /// Symbol of a closed trading gate.
  static let gateClosedSymbol = "lock.fill"

  @Environment(AppModel.self) private var model
  /// A recorded past day to summarize instead of today's status.
  let past: DaySummary?

  var body: some View {
    let stats = past.map(Board.dayStats) ?? model.status.map(Board.dayStats)
    let result = stats?.resultGrossUsd ?? 0
    let headline = model.headline
    // A recorded day says so, in the highlight colour and without a pulse; the live headline is about today.
    let text = past == nil ? headline.text : String(localized: L10n.Home.recordedDay)
    let tint = past == nil ? headline.severity.tint : Palette.highlightText
    HStack(spacing: Tokens.Space.l) {
      ResultRing(fraction: stats?.winShare ?? 0, color: result < 0 ? Palette.seriesATR : Palette.accent) {
        VStack(spacing: Tokens.Space.xxs) {
          CardLabel(L10n.Home.day)
          Text(verbatim: Money.signed(result))
            .font(Tokens.Typography.metric)
            .foregroundStyle(result < 0 ? Palette.seriesATRText : Palette.profitText)
            .contentTransition(.numericText(value: NSDecimalNumber(decimal: result).doubleValue))
            .minimumScaleFactor(Self.minimumScale)
            .lineLimit(1)
          Group {
            if let stats {
              Text(L10n.Common.winsLosses(stats.wins, stats.losses))
            } else {
              Text(verbatim: Format.missing)
            }
          }
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
        }
        .padding(Tokens.Space.l)
      }
      .frame(width: Self.ringSide, height: Self.ringSide)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Text(L10n.Home.dayResult(Money.signedUSD(result), stats?.wins ?? 0, stats?.losses ?? 0)))

      VStack(alignment: .leading, spacing: Tokens.Space.s) {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
          PulseDot(tint, pulsing: past == nil && (headline.severity != .ok || model.response?.stale == false),
            event: model.status?.writtenAt.date)
          Text(verbatim: text)
            .font(.subheadline.bold())
            .foregroundStyle(tint)
            .fixedSize(horizontal: false, vertical: true)
        }
        if let past {
          Text(L10n.Home.recordedNote)
            .font(.footnote)
            .foregroundStyle(Palette.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
          CleanLine(clean: past.clean)
        } else if let status = model.status {
          // Each position's protection and the gate as glyphs; the words are in their hints.
          HStack(spacing: Tokens.Space.xs) {
            ForEach(status.positions, id: \.symbol) { position in
              StopGlyph(state: position.stop.state, symbol: position.symbol,
                read: status.freshness.lastBrokerReadAt?.date)
            }
            if !status.tradingGate.open {
              StateGlyph(Self.gateClosedSymbol, tone: .warning,
                label: L10n.Home.gateClosed(status.tradingGate.cause), style: .compact)
            }
            Badge(verbatim: status.strategy.version, tone: .highlight)
          }
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(Text(verbatim: subline(status)))
        }
      }
      .animation(.default, value: text)
    }
  }

  private func subline(_ status: StatusV1) -> String {
    var parts: [LocalizedStringResource] = []
    for position in status.positions {
      parts.append(position.stop.state.isProtected
        ? L10n.Home.protected(position.symbol)
        : L10n.Home.stopIs(position.symbol, Board.stopStateTitle(position.stop.state)))
    }
    parts.append(L10n.Home.strategy(status.strategy.name, status.strategy.version))
    if !status.tradingGate.open { parts.append(L10n.Home.gateClosed(status.tradingGate.cause)) }
    return parts.map { String(localized: $0) }.joined(separator: " ")
  }
}

/// One open position on Home with its price since the fill and open result while they are current;
/// tapping it opens it on the Positions tab.
private struct PositionRow: View {
  /// Size of the price sparkline, in points.
  static let sparkWidth: CGFloat = 64
  static let sparkHeight: CGFloat = 26

  @Environment(AppModel.self) private var model
  let position: Position
  let marks: PositionMarks?

  var body: some View {
    Button {
      model.selectedSymbol = position.symbol
      model.selectedTab = .positions
    } label: {
      HStack(spacing: Tokens.Space.m) {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
          HStack(spacing: Tokens.Space.s) {
            StopGlyph(state: position.stop.state, symbol: position.symbol,
              read: model.status?.freshness.lastBrokerReadAt?.date)
            Text(verbatim: position.symbol)
              .font(.headline.monospaced())
              .foregroundStyle(Palette.textPrimary)
          }
          Label {
            Text(verbatim: position.stop.price?.text ?? Format.missing)
          } icon: {
            Image(systemName: StopGlyph.levelSymbol)
          }
          .labelStyle(ControlLabelStyle())
          .font(Tokens.Typography.annotation)
          .foregroundStyle(position.stop.state.isProtected ? Palette.profitText : Palette.lossText)
          .accessibilityLabel(Text(stopLine))
          // Long press names the stop, as on the shield beside the symbol, instead of opening the row.
          .hint(stopLine)
        }
        Spacer()
        // An old last bar (capture stopped, a quiet minute past the limit) shows muted with its
        // time, as on Positions, never as a live result.
        let current = marks.map(model.isCurrent) ?? false
        if let marks, marks.closes.count > 1 {
          ViewThatFits(in: .horizontal) {
            DrawnSparkline(values: marks.closes.map { NSDecimalNumber(decimal: $0).doubleValue },
              color: current ? Palette.result(marks.unrealized) : Palette.textQuaternary)
              .frame(width: Self.sparkWidth, height: Self.sparkHeight)
            Color.clear.frame(width: 0, height: 0)
          }
          .accessibilityHidden(true)
        }
        VStack(alignment: .trailing, spacing: Tokens.Space.xs) {
          if let marks {
            if current {
              DeltaTag(marks.unrealized, text: Money.signedUSD(marks.unrealized))
            } else {
              Text(verbatim: Money.signedUSD(marks.unrealized))
                .font(Tokens.Typography.calloutMono.weight(.semibold))
                .foregroundStyle(Palette.textQuaternary)
                .contentTransition(.numericText())
            }
            if !current {
              Text(L10n.Positions.asOf(Format.clock(marks.lastAt.addingTimeInterval(PositionMarks.barSeconds))))
                .font(Tokens.Typography.annotationBold)
                .foregroundStyle(Palette.warningText)
            }
          }
          Text(L10n.Common.quantityAt(position.quantity.text, position.entryPrice.text))
            .font(Tokens.Typography.calloutMono.weight(.semibold))
            .foregroundStyle(Palette.textPrimary)
          Text(L10n.Home.since(Format.time(position.openedAt.date)))
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textQuaternary)
        }
        // Each value on one line; the sparkline gives way first when the row is narrow.
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(1)
        Image(systemName: "chevron.right")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(Palette.textQuaternary)
      }
      .padding(.horizontal, Tokens.Space.l)
      .padding(.vertical, Tokens.Space.m)
      .apertureCard(tint: position.stop.state.isProtected ? nil : Palette.loss)
    }
    .buttonStyle(.plain)
  }

  private var stopLine: LocalizedStringResource {
    switch position.stop.state {
    case .verified: return L10n.Home.stopVerified(position.stop.price?.text ?? "")
    case .pending: return L10n.Home.stopPending
    case .missing: return L10n.Home.noStop
    case .unknown: return L10n.Home.stopUnknown
    }
  }
}

/// The live flow as on the design: the stages a setup passes, each a dot in its colour with what
/// the bot reports for it, today's symbols as small dots under the stage they reached (a dot moves
/// on only when a new read moves it), and the bot's inputs (quote stream, last broker read) below.
/// A status that is stale, failed or from an earlier session shows still, faint dots and says so.
/// Tapping it opens Risk (the room and why entries are blocked).
private struct LiveFlowCard: View {
  let status: StatusV1
  /// Today's flow: stage counts and the day's stops; nil until read.
  let flow: FlowV1?
  /// The first /flow read has not answered yet: the stages show a placeholder, not the status's
  /// numbers they would jump from.
  let flowPending: Bool
  /// Today's symbols, each at the furthest stage it reached; empty until the flow is read.
  let marks: [FlowMark]
  let maxPositions: Int?
  /// The status is fresh and describes today's session.
  let current: Bool

  /// The stages, in the order a setup passes them.
  private enum StageID: Int {
    case screen = 0, stocks, strategy, risk, order, stop

    /// The flow stage whose symbols sit under this one.
    var flowStage: FlowStage {
      switch self {
      case .screen: .screeners
      case .stocks: .universe
      case .strategy: .strategy
      case .risk: .risk
      case .order: .order
      case .stop: .stop
      }
    }
  }

  @Namespace private var board
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Symbol dots per row under a stage, and the most shown before "+N".
  static let poolColumns = 3
  static let poolCap = 9

  private struct Stage: Identifiable {
    let id: StageID
    let name: LocalizedStringResource
    /// nil = the API does not report this stage yet.
    let value: String?
    let color: Color
    /// A blocked entry or an unprotected position from the status: shown at once, never under
    /// the placeholder that waits for the first /flow read.
    var urgent = false
    /// A state under the value that must stay visible next to the day's count ("blocked",
    /// "not now"), in `flagColor`.
    var flag: LocalizedStringResource?
    var flagColor = Palette.textQuaternary
  }

  private var stages: [Stage] {
    let positions = status.positions
    let verified = positions.filter { $0.stop.state.isProtected }.count
    // Green only while every open position's stop, and every stop of the day's trades the flow
    // knows, is verified at the broker.
    let flowVerified = flow?.stops.filter { $0.state == .verified }.count
    let allProtected = verified == positions.count && flowVerified == flow?.stops.count
    guard current else {
      // Nothing here is live: no counts, no green, nothing breathing.
      return [StageID.screen, .stocks, .strategy, .risk, .order, .stop].map { id in
        Stage(id: id, name: Self.names[id.rawValue], value: nil, color: Palette.textQuaternary)
      }
    }
    // An open position waiting for its stop shows first; then the day's stops from the flow.
    let stops: String? = if verified < positions.count || flow?.stops.isEmpty != false {
      positions.isEmpty ? nil : String(localized: L10n.Flow.stopsVerified(verified, positions.count))
    } else {
      flow.map { String(localized: L10n.Flow.stopsVerified(flowVerified ?? 0, $0.stops.count)) }
    }
    // The day's count stays; an entry block shows under it, red when it needs the operator.
    let blocked = !status.entriesAllowed && !status.entriesCalm
    let riskCount = count(.risk)
    // With a flow, every count comes from it; the status's numbers only stand in when /flow failed.
    let fromStatus = flow == nil
    return [
      Stage(id: .screen, name: L10n.Flow.screen, value: count(.screeners), color: Palette.accent),
      Stage(id: .stocks, name: L10n.Flow.stocks, value: count(.universe), color: Palette.seriesUniverse),
      Stage(id: .strategy, name: L10n.Flow.strategy,
        value: count(.strategy) ?? (fromStatus ? status.strategy.version : nil), color: Palette.highlight),
      Stage(id: .risk, name: L10n.Flow.risk,
        value: riskCount ?? (status.entriesAllowed ? RiskFormat.amount(status.dailyRoomUsd?.value) : nil),
        color: blocked ? Palette.loss : status.entriesAllowed ? Palette.warning : Palette.textQuaternary,
        urgent: blocked,
        flag: status.entriesAllowed ? nil : blocked ? L10n.Flow.blocked : L10n.Risk.notNow,
        flagColor: blocked ? Palette.lossText : Palette.textQuaternary),
      Stage(id: .order, name: L10n.Flow.order,
        value: count(.order) ?? (fromStatus ? String(status.tradesToday.count) : nil), color: Palette.info),
      Stage(id: .stop, name: L10n.Flow.stop, value: stops ?? Format.missing,
        color: allProtected ? Palette.profit : Palette.loss, urgent: verified < positions.count),
    ]
  }

  /// How many symbols reached `stage` today; nil until the flow is read.
  private func count(_ stage: FlowStage) -> String? {
    flow?.stages.first { $0.stage == stage }.map { String($0.count) }
  }

  var body: some View {
    NavigationLink {
      RiskView()
    } label: {
      VStack(alignment: .leading, spacing: Tokens.Space.m) {
        HStack {
          CardLabel(L10n.Flow.title)
          Spacer()
          if !current {
            Text(L10n.Flow.notCurrent)
              .font(Tokens.Typography.annotation)
              .foregroundStyle(Palette.warningText)
          } else if let maxPositions {
            Text(L10n.Flow.slots(status.positions.count, maxPositions))
              .font(Tokens.Typography.annotation)
              .foregroundStyle(Palette.textQuaternary)
          }
        }
        HStack(alignment: .top) {
          // Equal columns, as in the design: a long value never widens its stage.
          ForEach(stages) { stage in
            column(stage).frame(maxWidth: .infinity, alignment: .top)
          }
        }
        // Until the first /flow read answers, a placeholder instead of numbers that would jump.
        .redacted(reason: current && flowPending ? .placeholder : [])
        // A symbol's dot flies to its next stage only when a new read moves it.
        .animation(reduceMotion ? nil : Tokens.Motion.standard, value: marks)
        HStack(spacing: Tokens.Space.s) {
          StateGlyph(Self.streamSymbol, tone: streamTone,
            label: L10n.Flow.quotes(String(localized: status.freshness.stream.title)),
            live: current && status.freshness.stream == .fresh, event: status.writtenAt.date, style: .compact)
          Label {
            Text(verbatim: Format.timeOrDash(status.freshness.lastBrokerReadAt))
          } icon: {
            Image(systemName: Self.brokerSymbol)
          }
          .labelStyle(ControlLabelStyle())
          .foregroundStyle(current && status.freshness.lastBrokerReadAt == nil ? Palette.lossText : Palette.textQuaternary)
          .accessibilityLabel(Text(L10n.Flow.brokerRead(Format.timeOrDash(status.freshness.lastBrokerReadAt))))
        }
        .font(Tokens.Typography.annotation)
        ForEach(status.fences, id: \.kind) { fence in
          Label { Text(verbatim: fence.text) } icon: { Image(systemName: "exclamationmark.triangle.fill") }
            .font(.caption)
            .foregroundStyle(Palette.warningText)
        }
      }
      .padding(.horizontal, Tokens.Space.l)
      .padding(.vertical, Tokens.Space.m)
      .apertureCard()
    }
    .buttonStyle(.plain)
  }

  /// Stage names, in `StageID` order.
  private static let names = [L10n.Flow.screen, L10n.Flow.stocks, L10n.Flow.strategy, L10n.Flow.risk, L10n.Flow.order,
    L10n.Flow.stop]

  /// Symbols of the quote stream and the last broker read.
  static let streamSymbol = "waveform.path.ecg"
  static let brokerSymbol = "building.columns"

  /// The quote stream's state as a tone: a lost stream is an alarm.
  private var streamTone: Tone {
    // An old status says nothing about the stream now.
    guard current else { return .neutral }
    switch status.freshness.stream {
    case .fresh: return .profit
    case .quiet: return .warning
    case .lost: return .loss
    case .off: return .neutral
    }
  }

  private func column(_ stage: Stage) -> some View {
    VStack(spacing: Tokens.Space.xs) {
      FlowDot(color: stage.color, lit: stage.value != nil || stage.flag != nil, event: stage.value)
      Text(stage.name)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textTertiary)
        .lineLimit(1)
        .minimumScaleFactor(FlowDot.minimumScale)
      Group {
        if stage.value != nil || stage.flag == nil {
          Text(verbatim: stage.value ?? Format.missing)
            .font(Tokens.Typography.annotationBold)
            .foregroundStyle(stage.value == nil ? Palette.textQuaternary : Palette.textPrimary)
            .contentTransition(.numericText())
        }
        if let flag = stage.flag {
          Text(flag)
            .font(Tokens.Typography.annotationBold)
            .foregroundStyle(stage.flagColor)
        }
      }
      .lineLimit(1)
      .minimumScaleFactor(FlowDot.minimumScale)
      pool(stage)
    }
    .accessibilityElement(children: .combine)
    .unredacted(when: stage.urgent)
  }

  /// Today's symbols at this stage as small dots, "+N" past the cap; under the stocks and risk
  /// stages the symbols they refused sit in a dashed tray as outlines, as in the design.
  @ViewBuilder
  private func pool(_ stage: Stage) -> some View {
    let here = current ? marks.filter { $0.stage == stage.id.flowStage } : []
    let passed = here.filter { !$0.refused }
    let refused = here.filter(\.refused)
    VStack(spacing: Tokens.Space.xs) {
      if !passed.isEmpty { dots(passed, color: stage.color) }
      if !refused.isEmpty {
        dots(refused, color: Palette.loss)
          .padding(Tokens.Space.xs)
          .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.small)
              .strokeBorder(Palette.separatorStrong,
                style: StrokeStyle(lineWidth: Tokens.Stroke.thin, dash: Tokens.Stroke.dashFine))
          }
      }
    }
    .accessibilityHidden(true)
  }

  private func dots(_ marks: [FlowMark], color: Color) -> some View {
    VStack(spacing: Tokens.Space.xxs) {
      LazyVGrid(columns: Array(repeating: GridItem(.fixed(Tokens.Size.dotSmall), spacing: Tokens.Space.xxs),
        count: Self.poolColumns), spacing: Tokens.Space.xxs) {
        ForEach(marks.prefix(Self.poolCap)) { mark in
          SymbolDot(mark: mark, color: color)
            .matchedGeometryEffect(id: mark.id, in: board)
            .transition(.scale.combined(with: .opacity))
        }
      }
      if marks.count > Self.poolCap {
        Text(L10n.Flow.more(marks.count - Self.poolCap))
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      }
    }
  }
}

/// The bot's latest event on one still line, as in the design: its New York time, its tag in its
/// tone and what happened. A new event replaces the line; nothing scrolls.
private struct LatestEventLine: View {
  let event: Board.Event

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
      Text(L10n.Home.clockET(Format.clock(event.time)))
        .foregroundStyle(Palette.textQuaternary)
      Text(verbatim: event.tag).bold().foregroundStyle(event.tone.color)
      Text(verbatim: event.text).foregroundStyle(Palette.textSecondary).truncationMode(.tail)
      Spacer(minLength: 0)
    }
    .font(Tokens.Typography.annotation.monospaced())
    .lineLimit(1)
    .padding(.horizontal, Tokens.Space.m)
    .padding(.vertical, Tokens.Space.s)
    .background(Palette.surfaceSunken, in: RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous).strokeBorder(Palette.separator))
    .accessibilityElement(children: .combine)
  }
}

private extension View {
  /// Shows the view even under a placeholder redaction when `urgent`.
  @ViewBuilder func unredacted(when urgent: Bool) -> some View {
    if urgent { unredacted() } else { self }
  }
}

/// One of today's symbols on the live flow: filled in its stage's colour, amber while its broker
/// stop waits, red when it was never confirmed; an outline when the universe left it out. A long
/// press names it and why.
private struct SymbolDot: View {
  let mark: FlowMark
  let color: Color

  /// Joins the symbol and its note in the hint.
  static let separator = "\n"

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
    .frame(width: Tokens.Size.dotSmall, height: Tokens.Size.dotSmall)
    .hint(verbatim: [mark.id, mark.note].compactMap { $0 }.joined(separator: Self.separator))
  }
}

/// A live-flow stage: a glowing dot, faint for an unreported stage. It moves only on a real
/// event: one pulse each time the stage's value changes (a new count, a verified stop).
private struct FlowDot: View {
  let color: Color
  let lit: Bool
  /// The stage's value; a change plays one pulse.
  let event: String?

  /// Diameter of the dot and blur of its glow, in points.
  static let size: CGFloat = 11
  static let glow: CGFloat = 6
  /// Smallest scale a stage's value shrinks to.
  static let minimumScale = 0.7

  var body: some View {
    PulseDot(color, size: Self.size, pulsing: lit, event: event)
      .shadow(color: lit ? color : .clear, radius: Self.glow)
      .opacity(lit ? 1 : Tokens.Opacity.faint)
      .accessibilityHidden(true)
  }
}

/// A recorded day's clean-day verdict from the bot's journal and reconciliation: clean, not clean
/// with its first reason, or unknown with why.
private struct CleanLine: View {
  let clean: CleanDay

  var body: some View {
    Group {
      switch clean.verdict {
      case .clean:
        Text(L10n.Home.cleanDay)
          .foregroundStyle(Palette.profitText)
      case .notClean:
        Text(L10n.Home.notClean(clean.causes.first?.text ?? Format.missing, clean.causes.count))
          .foregroundStyle(Palette.warningText)
      case .unknown:
        Text(L10n.Home.cleanUnknown(clean.cause ?? Format.missing))
          .foregroundStyle(Palette.textQuaternary)
      }
    }
    .font(Tokens.Typography.annotation)
    .fixedSize(horizontal: false, vertical: true)
  }
}
