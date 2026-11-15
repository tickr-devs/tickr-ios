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
        let events = Board.events(status)
        if !events.isEmpty {
          Ticker(events.map { TickerItem(id: $0.id, tag: $0.tag, text: $0.text, tone: $0.tone.ticker) },
            moving: model.response?.stale == false)
            .padding(.vertical, Tokens.Space.s)
            .background(Palette.surfaceSunken,
              in: RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
              .strokeBorder(Palette.separator))
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
        LiveFlowCard(status: status, flow: model.flow?.day == model.today ? model.flow : nil,
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
    .task(id: model.connection.url) { await model.followFlow() }
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
        if past != nil {
          Text(L10n.Home.recordedNote)
            .font(.footnote)
            .foregroundStyle(Palette.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
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
        }
        Spacer()
        // An old last bar (capture stopped, a quiet minute past the limit) shows muted with its
        // time, as on Positions, never as a live result.
        let current = marks.map(model.isCurrent) ?? false
        if let marks, marks.closes.count > 1 {
          DrawnSparkline(values: marks.closes.map { NSDecimalNumber(decimal: $0).doubleValue },
            color: current ? Palette.result(marks.unrealized) : Palette.textQuaternary)
            .frame(width: Self.sparkWidth, height: Self.sparkHeight)
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

/// The live flow as on the design: the stages a setup passes, each a breathing dot in its colour
/// with what the bot reports for it, and the bot's inputs (quote stream, last broker read) below.
/// A status that is stale, failed or from an earlier session shows still, faint dots and says so.
/// Tapping it opens Risk (the room and why entries are blocked).
private struct LiveFlowCard: View {
  let status: StatusV1
  /// Today's flow: stage counts and the day's stops; nil until read.
  let flow: FlowV1?
  let maxPositions: Int?
  /// The status is fresh and describes today's session.
  let current: Bool

  /// The stages, in the order a setup passes them.
  private enum StageID: Int { case screen = 0, stocks, strategy, risk, order, stop }

  private struct Stage: Identifiable {
    let id: StageID
    let name: LocalizedStringResource
    /// nil = the API does not report this stage yet.
    let value: String?
    let color: Color
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
    return [
      Stage(id: .screen, name: L10n.Flow.screen, value: count(.screeners), color: Palette.accent),
      Stage(id: .stocks, name: L10n.Flow.stocks, value: count(.universe), color: Palette.seriesUniverse),
      Stage(id: .strategy, name: L10n.Flow.strategy, value: count(.strategy) ?? status.strategy.version,
        color: Palette.highlight),
      Stage(id: .risk, name: L10n.Flow.risk,
        value: status.entriesAllowed
          ? count(.risk) ?? RiskFormat.amount(status.dailyRoomUsd?.value)
          : String(localized: status.entriesCalm ? L10n.Risk.notNow : L10n.Flow.blocked),
        color: status.entriesAllowed ? Palette.warning : status.entriesCalm ? Palette.textQuaternary : Palette.loss),
      Stage(id: .order, name: L10n.Flow.order, value: count(.order) ?? String(status.tradesToday.count),
        color: Palette.info),
      Stage(id: .stop, name: L10n.Flow.stop, value: stops ?? Format.missing,
        color: allProtected ? Palette.profit : Palette.loss),
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
          ForEach(stages) { stage in
            if stage.id != .screen { Spacer(minLength: 0) }
            column(stage)
          }
        }
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
      FlowDot(color: stage.color, delay: Double(stage.id.rawValue) * FlowDot.stagger, lit: stage.value != nil)
      Text(stage.name).font(Tokens.Typography.annotation).foregroundStyle(Palette.textTertiary)
      Text(verbatim: stage.value ?? Format.missing)
        .font(Tokens.Typography.annotationBold)
        .foregroundStyle(stage.value == nil ? Palette.textQuaternary : Palette.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(FlowDot.minimumScale)
        .contentTransition(.numericText())
    }
    .accessibilityElement(children: .combine)
  }
}

/// A live-flow stage: a glowing dot that breathes, each stage a little after the one before, so
/// light seems to run along the flow. Still with Reduce Motion, faint for an unreported stage.
private struct FlowDot: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var bright = false
  let color: Color
  let delay: Double
  let lit: Bool

  /// Seconds between neighbouring stages' breaths.
  static let stagger = 0.25
  /// Diameter of the dot and blur of its glow, in points.
  static let size: CGFloat = 11
  static let glow: CGFloat = 6
  /// Smallest scale a stage's value shrinks to.
  static let minimumScale = 0.7
  /// Size of the dot at its dimmest, as a share of its full size.
  static let restScale = 0.8

  var body: some View {
    Circle()
      .fill(color)
      .frame(width: Self.size, height: Self.size)
      .shadow(color: lit ? color : .clear, radius: Self.glow)
      .opacity(lit ? (bright || reduceMotion ? 1 : Tokens.Opacity.faint) : Tokens.Opacity.faint)
      .scaleEffect(bright || reduceMotion || !lit ? 1 : Self.restScale)
      .onAppear {
        guard lit, !reduceMotion else { return }
        withAnimation(.easeInOut(duration: Tokens.Motion.breatheSeconds / 2).repeatForever(autoreverses: true).delay(delay)) {
          bright = true
        }
      }
      .accessibilityHidden(true)
  }
}
