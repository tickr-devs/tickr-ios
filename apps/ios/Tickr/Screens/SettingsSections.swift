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
    Section {
      SettingsRow(L10n.Settings.environment, systemImage: Self.symbol, tone: .warning) {
        StatusPill(verbatim: ApiText.environment(status.environment), tone: .warning)
      }
    } header: {
      Text(L10n.Settings.environment)
    } footer: {
      Text(L10n.Settings.environmentFooter)
    }
  }
}

/// The trading day in New York time as a bar, extended hours either side of the regular session,
/// with a cursor at now; then the bot's last entry and close-everything times.
struct SessionSection: View {
  /// Symbols of the last-entry and close-everything rows.
  static let lastEntrySymbol = "clock.badge.checkmark"
  static let flattenSymbol = "rectangle.portrait.and.arrow.right"

  let session: SessionSettings?

  var body: some View {
    Section {
      SessionBar()
        .padding(.vertical, Tokens.Space.s)
      if let session {
        SettingsRow(L10n.Risk.lastEntry, systemImage: Self.lastEntrySymbol, tone: .info) {
          Text(L10n.Risk.beforeClose(session.lastEntryMinutesBeforeClose))
        }
        SettingsRow(L10n.Risk.flatten, systemImage: Self.flattenSymbol, tone: .loss) {
          Text(L10n.Risk.beforeClose(session.flattenMinutesBeforeClose))
        }
      }
    } header: {
      Text(L10n.Settings.session)
    } footer: {
      Text(L10n.Settings.sessionFooter)
    }
  }
}

/// Extended hours (04:00 to 20:00 New York) with the regular session (09:30 to 16:00) filled and a
/// cursor at now. US exchange hours; half days are not drawn.
private struct SessionBar: View {
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
  /// Seconds between moves of the cursor.
  static let tick: TimeInterval = 1

  var body: some View {
    TimelineView(.periodic(from: .now, by: Self.tick)) { context in
      VStack(alignment: .leading, spacing: Tokens.Space.s) {
        HStack {
          Text(verbatim: Format.clock(context.date))
            .font(Tokens.Typography.bodyMono.bold())
            .monospacedDigit()
            .contentTransition(.numericText())
          Spacer()
          Text(phase(at: context.date))
            .font(Tokens.Typography.captionMono)
            .foregroundStyle(Palette.textTertiary)
        }
        GeometryReader { proxy in
          let width = proxy.size.width
          ZStack(alignment: .leading) {
            Capsule().fill(Palette.separator)
            Rectangle()
              .fill(Palette.accent.opacity(Tokens.Opacity.border))
              .frame(width: width * share(Self.regularClose) - width * share(Self.regularOpen))
              .offset(x: width * share(Self.regularOpen))
            if let now = minutes(of: context.date), (Self.extendedOpen...Self.extendedClose).contains(now) {
              Rectangle()
                .fill(Palette.textPrimary)
                .frame(width: Tokens.Stroke.bold)
                .offset(x: width * share(now))
                .animation(Tokens.Motion.standard, value: now)
            }
          }
          .clipShape(Capsule())
        }
        .frame(height: Self.height)
        HStack {
          ForEach([Self.extendedOpen, Self.regularOpen, Self.regularClose, Self.extendedClose], id: \.self) { mark in
            if mark != Self.extendedOpen { Spacer() }
            Text(verbatim: Format.time(label(mark)))
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
  private func label(_ minute: Int) -> Date {
    let midnight = WireDate.newYork.startOfDay(for: .now)
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
    Section {
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
    } header: {
      HStack {
        Text(L10n.Settings.preflight)
        Spacer()
        StatusPill(summary(results), tone: summaryTone(results))
          .contentTransition(.opacity)
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
