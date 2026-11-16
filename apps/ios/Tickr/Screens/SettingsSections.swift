import SwiftUI
import TickrDesign
import TickrKit

/// Where the bot trades. The phone only shows it: Sandbox or Production is set in config on the
/// Mac, and Production also needs the owner's authorization file there.
struct EnvironmentSection: View {
  /// Symbol of the environment row.
  static let symbol = "server.rack"

  let status: StatusV1

  var body: some View {
    SettingsCard(L10n.Settings.environment, note: L10n.Settings.environmentFooter) {
      SettingsRow(L10n.Settings.environment, systemImage: Self.symbol, tone: .warning) {
        StatusPill(verbatim: ApiText.environment(status.environment), tone: .warning)
      }
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
        HStack {
          ForEach([span.start, span.regularOpen, span.regularClose, span.end], id: \.self) { mark in
            if mark != span.start { Spacer() }
            Text(verbatim: Format.time(mark))
          }
        }
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
      }
      .environment(\.timeZone, WireDate.newYork.timeZone)
    }
    .accessibilityElement(children: .combine)
  }

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
            .transition(.scale.combined(with: .opacity))
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
          .font(.footnote)
          .foregroundStyle(Palette.lossText)
      } else if let failure = model.accountError {
        Text(L10n.Settings.accountFailed(failure))
          .font(.footnote)
          .foregroundStyle(Palette.warningText)
      }
    }
  }

  @ViewBuilder
  private func icon(_ outcome: Preflight.Outcome) -> some View {
    switch outcome {
    case .passed:
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(Palette.profit)
        .symbolEffect(.bounce, value: outcome)
        .accessibilityLabel(Text(L10n.Access.passed))
    case .failed:
      Image(systemName: "xmark.octagon.fill").foregroundStyle(Palette.loss)
        .accessibilityLabel(Text(L10n.Access.failed))
    case .unknown:
      Image(systemName: "circle.dashed").foregroundStyle(Palette.textQuaternary)
        .accessibilityLabel(Text(L10n.Access.checking))
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
      return status?.freshness.stream.title ?? L10n.Common.unknown
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
