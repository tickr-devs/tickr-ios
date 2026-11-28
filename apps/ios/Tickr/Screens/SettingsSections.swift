import SwiftUI
import TickrDesign
import TickrKit

/// Where the bot trades, as the iOS Settings board draws it: Sandbox | Production with the bot's
/// environment raised and Production locked. The phone only shows it: Sandbox or Production is set
/// in config on the Mac, and Production also needs the owner's authorization file there, so
/// nothing here can be tapped. Another environment (the demo day, a name the owner chose) raises
/// no segment and is named by its badge above them. A section of its own, as is
/// `NotificationsSection`, so the Safety screen (IOSGateAlerts, still a backlog board with no screen
/// in the app) shows the same one.
struct EnvironmentSection: View {
  /// Symbol of the environment row.
  static let symbol = "server.rack"

  let status: StatusV1

  var body: some View {
    let current = BotEnvironment(rawValue: status.environment)
    SettingsCard(L10n.Settings.environment, note: L10n.Settings.environmentFooter) {
      // The board's tag: the Production gate's readiness checks come later.
      Badge(L10n.Settings.productionGateBacklog, tone: .highlight, planned: true)
    } content: {
      if current != .sandbox && current != .production {
        SettingsRow(L10n.Settings.environment, systemImage: Self.symbol,
          tone: EnvironmentBadge.Kind(raw: status.environment).tone) {
          EnvironmentBadge(ApiText.environment(status.environment), raw: status.environment,
            accessibilityLabel: ApiText.environmentLabel(status.environment))
        }
      }
      SegmentSwitch<BotEnvironment?>(options: [
        .init(BotEnvironment.sandbox, title: Text(BotEnvironment.sandbox.title)),
        .init(BotEnvironment.production, title: Text(BotEnvironment.production.title), locked: true),
      ], shown: current)
      .accessibilityLabel(Text(L10n.Settings.environment))
      .accessibilityHint(Text(L10n.Settings.environmentFooter))
      .padding(.vertical, Tokens.Space.xs)
    }
  }
}

/// Today's trading day in New York time as a bar from the bot's `/jobs` session (its exchange
/// calendar: extended hours either side of the regular session, half days included), with a
/// cursor at now; or why there is no session today. Then the bot's last entry and close-everything
/// times.
struct SessionSection: View {
  /// Whether the extended hours' planned stripes drift: an ornament that reads as "the bot is at
  /// work", so only while it is (`OrnamentGate`: running, the live day with a fresh status,
  /// motion allowed).
  static func stripesMove(reduceMotion: Bool, model: AppModel) -> Bool {
    OrnamentGate.moves(reduceMotion: reduceMotion, current: model.showsLiveStatus,
      botState: model.status?.botState)
  }

  /// Symbols of the last-entry and close-everything rows.
  static let lastEntrySymbol = "clock.badge.checkmark"
  static let flattenSymbol = "rectangle.portrait.and.arrow.right"

  let session: SessionSettings?
  /// Today's session from `/jobs`, or why there is none (a weekend, a closure).
  let times: SessionTimesV1?
  let cause: String?
  /// Whether the planned stripes drift (`stripesMove`).
  let moving: Bool

  var body: some View {
    SettingsCard(L10n.Settings.session, note: L10n.Settings.sessionFooter) {
      if let times {
        SessionBar(span: SessionSpan(times), moving: moving)
          .padding(.vertical, Tokens.Space.s)
      } else if let cause {
        Text(verbatim: cause)
          .font(Tokens.Typography.callout)
          .foregroundStyle(Palette.textTertiary)
      }
      if let session {
        SettingsRow(L10n.Risk.lastEntry, systemImage: Self.lastEntrySymbol, tone: .info) {
          Text(L10n.Risk.beforeClose(session.lastEntryMinutesBeforeClose))
        }
        SettingsRow(L10n.Risk.flatten, systemImage: Self.flattenSymbol, tone: .loss) {
          Text(L10n.Risk.beforeClose(session.flattenMinutesBeforeClose))
        }
      }
    }
  }
}

/// The day's extended hours, striped as planned, with the regular session filled and a cursor at
/// now on the bot's clock; every time from `span`.
///
/// Its motion, as the design's: the cursor glides to each new minute at an even pace
/// (`Motion.nowGlide`), once per real change of the time; the planned stripes drift while `moving`
/// (ornament). Under Reduce Motion both stand still.
private struct SessionBar: View {
  let span: SessionSpan
  let moving: Bool
  @Environment(AppModel.self) private var model
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Height of the bar, in points.
  static let height: CGFloat = 18

  var body: some View {
    TimelineView(.periodic(from: .now, by: Tokens.Motion.clockTickSeconds)) { context in
      // The bot's clock, as the Mac's strip: the phone's own may be off.
      let now = model.botTime(context.date)
      let minute = SessionSpan.minute(now)
      VStack(alignment: .leading, spacing: Tokens.Space.s) {
        HStack {
          Text(verbatim: Format.clock(now))
            .font(Tokens.Typography.bodyMono.bold())
            .monospacedDigit()
            .contentTransition(.numericText())
          Spacer()
          Text(Self.partName(span.part(at: now)))
            .font(Tokens.Typography.captionMono)
            .foregroundStyle(Palette.textTertiary)
        }
        GeometryReader { proxy in
          let width = proxy.size.width
          let x = { (date: Date) -> CGFloat in CGFloat(span.share(date)) * width }
          ZStack(alignment: .leading) {
            Capsule().fill(Palette.separator)
            Hatch(Palette.highlight, moving: moving)
              .frame(width: x(span.regularOpen))
            Hatch(Palette.highlight, moving: moving)
              .frame(width: width - x(span.regularClose))
              .offset(x: x(span.regularClose))
            Rectangle()
              .fill(Palette.accent.opacity(Tokens.Opacity.border))
              .frame(width: x(span.regularClose) - x(span.regularOpen))
              .offset(x: x(span.regularOpen))
            if span.contains(minute) {
              Rectangle()
                .fill(Palette.textPrimary)
                .frame(width: Tokens.Stroke.bold)
                .offset(x: x(minute))
                .animation(reduceMotion ? nil : Tokens.Motion.nowGlide, value: minute)
            }
          }
          .clipShape(Capsule())
        }
        .frame(height: Self.height)
        // Each time under its own place on the bar (16:00 under the regular close, not spread
        // evenly), the first and last kept inside the bar's ends.
        AxisMarks(shares: marks.map { span.share($0) }) {
          ForEach(marks, id: \.self) { mark in
            Text(verbatim: Format.time(mark)).fixedSize()
          }
        }
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
      }
      .environment(\.timeZone, WireDate.newYork.timeZone)
    }
    .accessibilityElement(children: .combine)
  }

  /// The times named under the bar: the day's start, the regular open and close, its end.
  private var marks: [Date] { [span.start, span.regularOpen, span.regularClose, span.end] }

  /// What the part of the day is called beside the clock.
  static func partName(_ part: SessionSpan.Part) -> LocalizedStringResource {
    switch part {
    case .regular: L10n.Settings.regularHours
    case .preMarket: L10n.Settings.preMarket
    case .afterHours: L10n.Settings.afterHours
    case .closed: L10n.Settings.closed
    }
  }
}

/// The checks before trusting the bot with a session, from its status and its last broker read.
/// Each one pops in as it passes; unknown is never shown as passed.
struct PreflightSection: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    let results = Preflight.run(status: model.response, readFailed: model.fetchError != nil, account: model.account)
    SettingsCard(L10n.Settings.preflight) {
      StatusPill(summary(results), tone: summaryTone(results))
        .contentTransition(.opacity)
    } content: {
      ForEach(results) { result in
        HStack(spacing: Tokens.Space.m) {
          icon(result.outcome)
            .transition(.scale(scale: Tokens.Motion.enterScale).combined(with: .opacity))
          Text(title(result.check))
          Spacer()
          Text(detail(result.check))
            .font(Tokens.Typography.captionMono)
            .foregroundStyle(Palette.textTertiary)
            .multilineTextAlignment(.trailing)
        }
        .animation(Tokens.Motion.standard, value: result.outcome)
        .accessibilityElement(children: .combine)
      }
      if let mismatch = model.account?.account.mismatch {
        Text(verbatim: mismatch)
          .font(Tokens.Typography.footnote)
          .foregroundStyle(Palette.lossText)
      } else if let failure = model.accountError {
        ReadFailureNote(L10n.Settings.accountFailed, detail: failure)
      }
    }
  }

  @ViewBuilder
  private func icon(_ outcome: Preflight.Outcome) -> some View {
    switch outcome {
    case .passed:
      Image(systemName: Symbols.passed)
        .foregroundStyle(Palette.profit)
        .symbolEffect(.bounce, value: outcome)
        .accessibilityLabel(Text(L10n.Access.passed))
    case .failed:
      Image(systemName: Symbols.failed).foregroundStyle(Palette.loss)
        .accessibilityLabel(Text(L10n.Access.failed))
    case .unknown:
      Image(systemName: "circle.dashed").foregroundStyle(Palette.textQuaternary)
        .accessibilityLabel(Text(L10n.Access.checking))
    case .notNeeded:
      Image(systemName: "minus.circle").foregroundStyle(Palette.textQuaternary)
        .accessibilityLabel(Text(L10n.Settings.notNeeded))
    }
  }

  private func summaryTone(_ results: [Preflight.Result]) -> Tone {
    if results.contains(where: { $0.outcome == .failed }) { return .loss }
    if results.contains(where: { $0.outcome == .unknown }) { return .neutral }
    return .profit
  }

  private func summary(_ results: [Preflight.Result]) -> LocalizedStringResource {
    let failed = results.filter { $0.outcome == .failed }.count
    if failed > 0 { return L10n.Settings.failing(failed) }
    if results.contains(where: { $0.outcome == .unknown }) { return L10n.Settings.checking }
    return L10n.Settings.allPassed
  }

  private func title(_ check: Preflight.Check) -> LocalizedStringResource {
    switch check {
    case .botRunning: return L10n.Settings.checkBotRunning
    case .statusCurrent: return L10n.Settings.checkStatusCurrent
    case .streamFresh: return L10n.Settings.checkStreamFresh
    case .brokerMatches: return L10n.Settings.checkBrokerMatches
    case .stopsVerified: return L10n.Settings.checkStopsVerified
    case .gateOpen: return L10n.Settings.checkGateOpen
    }
  }

  private func detail(_ check: Preflight.Check) -> LocalizedStringResource {
    let status = model.status
    switch check {
    case .botRunning:
      return status?.botState.title ?? L10n.Common.unknown
    case .statusCurrent:
      return Format.age(model.response)
    case .streamFresh:
      guard let stream = status?.freshness.stream else { return L10n.Common.unknown }
      return stream == .off ? L10n.Settings.streamNoPosition : stream.title
    case .brokerMatches:
      guard let account = model.account?.account else { return L10n.Common.unknown }
      return L10n.Settings.brokerCounts(account.positions.count, account.orders.count)
    case .stopsVerified:
      guard let positions = status?.positions else { return L10n.Common.unknown }
      return L10n.Settings.stops(positions.filter { $0.stop.state == .verified }.count, positions.count)
    case .gateOpen:
      guard let gate = status?.tradingGate else { return L10n.Common.unknown }
      return gate.open ? L10n.Settings.gateOpen : L10n.Settings.gateClosed
    }
  }
}

/// Which alerts go where (GET /alerts, PUT /alerts/routing): the shared `AlertRoutingPanel`, the
/// Mac's Notifications pane, in this app's card. Each switch is one change sent to the bot at once.
struct NotificationsSection: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    let routing = model.alertRouting
    SettingsCard(AlertText.title) {
      if let alerts = routing.alerts {
        AlertRoutingPanel(alerts, routing: routing) { cell, on in
          Task { await model.setAlertRoute(cell, on: on) }
        }
      } else if let error = routing.readError {
        ReadFailureNote(AlertText.readFailed, detail: error)
      } else {
        AlertRoutingPanelLoading()
      }
    }
    .task(id: model.connection.url) { await model.refreshAlerts() }
  }
}

/// Places each label under its share (0 to 1) of the width: centred there, moved in so it stays
/// inside the width, and after the label before it so two never overlap.
private struct AxisMarks: Layout {
  let shares: [Double]

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
    let width = proposal.width ?? sizes.reduce(0) { $0 + $1.width }
    return CGSize(width: width, height: sizes.map(\.height).max() ?? 0)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    var next = bounds.minX
    for (index, subview) in subviews.enumerated() where index < shares.count {
      let size = subview.sizeThatFits(.unspecified)
      let centre = bounds.minX + CGFloat(shares[index]) * bounds.width
      let x = min(max(centre - size.width / 2, next), bounds.maxX - size.width)
      subview.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(size))
      next = x + size.width
    }
  }
}
