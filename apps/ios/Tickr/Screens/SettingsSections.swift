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

/// The trading day in New York time as a bar, extended hours either side of the regular session,
/// with a cursor at now; then the bot's last entry and close-everything times.
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
  /// Whether the planned stripes drift (`stripesMove`).
  let moving: Bool

  var body: some View {
    SettingsCard(L10n.Settings.session, note: L10n.Settings.sessionFooter) {
      SessionBar(moving: moving)
        .padding(.vertical, Tokens.Space.s)
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

/// Extended hours (04:00 to 20:00 New York), striped as planned, with the regular session (09:30 to
/// 16:00) filled and a cursor at now. US exchange hours; half days are not drawn.
///
/// Its motion, as the design's: the cursor glides to each new minute at an even pace
/// (`Motion.nowGlide`), once per real change of the time; the planned stripes drift while `moving`
/// (ornament). Under Reduce Motion both stand still.
private struct SessionBar: View {
  let moving: Bool
  @Environment(AppModel.self) private var model
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Minutes after New York midnight where the bar starts and ends (extended hours), and the
  /// regular session.
  static let extendedOpen = 240
  static let regularOpen = 570
  static let regularClose = 960
  static let extendedClose = 1200
  /// Minutes in an hour, and seconds in a minute.
  static let minutesPerHour = 60
  static let secondsPerMinute = 60.0
  /// Height of the bar, in points.
  static let height: CGFloat = 18

  var body: some View {
    TimelineView(.periodic(from: .now, by: Tokens.Motion.clockTickSeconds)) { context in
      // The bot's clock, as the Mac's strip: the phone's own may be off.
      let now = model.botTime(context.date)
      VStack(alignment: .leading, spacing: Tokens.Space.s) {
        HStack {
          Text(verbatim: Format.clock(now))
            .font(Tokens.Typography.bodyMono.bold())
            .monospacedDigit()
            .contentTransition(.numericText())
          Spacer()
          Text(phase(at: now))
            .font(Tokens.Typography.captionMono)
            .foregroundStyle(Palette.textTertiary)
        }
        GeometryReader { proxy in
          let width = proxy.size.width
          ZStack(alignment: .leading) {
            Capsule().fill(Palette.separator)
            Hatch(Palette.highlight, moving: moving)
              .frame(width: width * share(Self.regularOpen))
            Hatch(Palette.highlight, moving: moving)
              .frame(width: width - width * share(Self.regularClose))
              .offset(x: width * share(Self.regularClose))
            Rectangle()
              .fill(Palette.accent.opacity(Tokens.Opacity.border))
              .frame(width: width * share(Self.regularClose) - width * share(Self.regularOpen))
              .offset(x: width * share(Self.regularOpen))
            if let minute = minutes(of: now), (Self.extendedOpen...Self.extendedClose).contains(minute) {
              Rectangle()
                .fill(Palette.textPrimary)
                .frame(width: Tokens.Stroke.bold)
                .offset(x: width * share(minute))
                .animation(reduceMotion ? nil : Tokens.Motion.nowGlide, value: minute)
            }
          }
          .clipShape(Capsule())
        }
        .frame(height: Self.height)
        HStack {
          ForEach([Self.extendedOpen, Self.regularOpen, Self.regularClose, Self.extendedClose], id: \.self) { mark in
            if mark != Self.extendedOpen { Spacer() }
            Text(verbatim: Format.time(label(mark, on: now)))
          }
        }
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
      }
      .environment(\.timeZone, WireDate.newYork.timeZone)
    }
    .accessibilityElement(children: .combine)
  }

  /// Where `minute` falls on the bar, from 0 at its start to 1 at its end.
  private func share(_ minute: Int) -> CGFloat {
    CGFloat(minute - Self.extendedOpen) / CGFloat(Self.extendedClose - Self.extendedOpen)
  }

  /// Minutes after New York midnight of `date`.
  private func minutes(of date: Date) -> Int? {
    let parts = WireDate.newYork.dateComponents([.hour, .minute], from: date)
    guard let hour = parts.hour, let minute = parts.minute else { return nil }
    return hour * Self.minutesPerHour + minute
  }

  /// Today at `minute` after New York midnight, for its label.
  private func label(_ minute: Int, on day: Date) -> Date {
    let midnight = WireDate.newYork.startOfDay(for: day)
    return midnight.addingTimeInterval(Double(minute) * Self.secondsPerMinute)
  }

  private func phase(at date: Date) -> LocalizedStringResource {
    guard let now = minutes(of: date) else { return L10n.Settings.closed }
    switch now {
    case Self.regularOpen..<Self.regularClose: return L10n.Settings.regularHours
    case Self.extendedOpen..<Self.regularOpen: return L10n.Settings.preMarket
    case Self.regularClose..<Self.extendedClose: return L10n.Settings.afterHours
    default: return L10n.Settings.closed
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
