import ApertureDesign
import ApertureKit
import SwiftUI

/// Risk: what is left of the daily loss limit and what used it, whether the bot may open a
/// position now and why not, its fences, the configured limits and the trading session. Every
/// figure is what the bot wrote in its status or reads from its configuration (GET /settings);
/// the phone computes nothing the bot acts on.
struct RiskView: View {
  /// Order in which the cards rise in (`rise(step:)`).
  private enum Order: Int { case room = 1, gate, fences, limits, session }

  @Environment(AppModel.self) private var model

  var body: some View {
    Screen(L10n.Risk.title) {
      ConnectionPrompt()
      if let status = model.status {
        RoomCard(status: status, risk: model.settings?.risk).rise(step: Order.room.rawValue)
        GateCard(status: status).rise(step: Order.gate.rawValue)
        FencesCard(fences: status.fences).rise(step: Order.fences.rawValue)
      }
      LimitsCard(risk: model.settings?.risk, failure: model.settingsError).rise(step: Order.limits.rawValue)
      SessionCard(session: model.settings?.session).rise(step: Order.session.rawValue)
    }
    .refreshable { await model.refreshAll() }
  }
}

/// Currency of every amount on this screen.
enum RiskFormat {
  /// ISO code of the account currency.
  static let currency = "USD"

  /// "$123.40" (no sign: room and limits are amounts, not results), or a dash when unknown.
  static func amount(_ value: Decimal?) -> String {
    value.map { $0.formatted(.currency(code: currency)) } ?? Format.missing
  }
}

/// A titled card of this screen.
private struct RiskCard<Content: View>: View {
  let title: LocalizedStringResource
  var tint: Color?
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      CardLabel(title)
      content
    }
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, alignment: .leading)
    .apertureCard(tint: tint)
  }
}

/// A label with its value on the right.
private struct RiskLine: View {
  let label: LocalizedStringResource
  let value: String
  var color: Color = Palette.textPrimary

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(label)
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textTertiary)
      Spacer(minLength: Tokens.Space.s)
      Text(verbatim: value)
        .font(Tokens.Typography.calloutMono)
        .foregroundStyle(color)
        .contentTransition(.numericText())
    }
    .accessibilityElement(children: .combine)
  }
}

/// The daily loss limit as a ring: the room the bot says is left, and what used the rest.
private struct RoomCard: View {
  /// Side of the ring, in points.
  static let ringSide: CGFloat = 180
  /// Room left below this share of the limit turns the ring amber, below `alarm` red.
  static let calm = 0.5
  static let alarm = 0.2

  let status: StatusV1
  let risk: RiskSettings?

  private var room: Decimal? { status.dailyRoomUsd?.value }
  private var limit: Decimal? { risk?.maxDailyLossUsd.value }

  private var share: Double {
    guard let room, let limit, limit > 0 else { return 0 }
    return NSDecimalNumber(decimal: room / limit).doubleValue
  }

  private var color: Color {
    guard room != nil, limit != nil else { return Palette.textQuaternary }
    if share < Self.alarm { return Palette.loss }
    if share < Self.calm { return Palette.warning }
    return Palette.profit
  }

  var body: some View {
    RiskCard(title: L10n.Risk.room) {
      ResultRing(fraction: share, color: color) {
        VStack(spacing: Tokens.Space.xxs) {
          Text(verbatim: RiskFormat.amount(room))
            .font(Tokens.Typography.metric)
            .foregroundStyle(Palette.textPrimary)
            .contentTransition(.numericText())
          CardLabel(L10n.Risk.left)
        }
      }
      .frame(width: Self.ringSide, height: Self.ringSide)
      .frame(maxWidth: .infinity)
      .padding(.vertical, Tokens.Space.s)
      .accessibilityElement(children: .combine)
      RiskLine(label: L10n.Risk.limit, value: RiskFormat.amount(limit))
      RiskLine(label: L10n.Risk.realizedLoss, value: RiskFormat.amount(status.realizedLossTodayUsd?.value),
        color: Palette.lossText)
      RiskLine(label: L10n.Risk.reservations, value: RiskFormat.amount(status.openReservationsUsd?.value),
        color: Palette.warningText)
      RiskLine(label: L10n.Risk.resultToday, value: Money.signedUSD(status.resultTodayGrossUsd.value),
        color: Palette.result(status.resultTodayGrossUsd.value))
      Text(L10n.Risk.roomNote(RiskFormat.amount(risk?.minDailyRoomUsd.value)))
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .animation(Tokens.Motion.fill, value: share)
  }
}

/// Whether the bot may open a position now, and the one recorded cause when it may not.
private struct GateCard: View {
  let status: StatusV1

  private var allowed: Bool { status.entriesAllowed }
  /// Held by an ordinary state, not a problem: grey and still.
  private var calm: Bool { status.entriesCalm }

  var body: some View {
    RiskCard(title: L10n.Risk.entries, tint: allowed || calm ? nil : Palette.warning) {
      HStack(spacing: Tokens.Space.s) {
        PulseDot(allowed ? Palette.profit : calm ? Palette.textQuaternary : Palette.warning,
          pulsing: !calm, event: allowed)
        Text(allowed ? L10n.Risk.allowed : calm ? L10n.Risk.notNow : L10n.Risk.blocked)
          .font(Tokens.Typography.body.bold())
          .foregroundStyle(allowed ? Palette.profitText : calm ? Palette.textSecondary : Palette.warningText)
          .contentTransition(.opacity)
      }
      if let block = status.entryBlock {
        let title = ApiText.entryBlock(block)
        Text(verbatim: title)
          .font(Tokens.Typography.callout)
          .foregroundStyle(Palette.textPrimary)
          .fixedSize(horizontal: false, vertical: true)
        // The bot's own detail under the translated cause; nothing when the title already is it.
        if title != block.text, !block.text.isEmpty {
          Text(verbatim: block.text)
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textQuaternary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      RiskLine(label: L10n.Risk.pausedByYou,
        value: String(localized: status.entryStop ? L10n.Risk.yes : L10n.Risk.no),
        color: status.entryStop ? Palette.warningText : Palette.textPrimary)
      RiskLine(label: L10n.Risk.tradingGate,
        value: String(localized: status.tradingGate.open ? L10n.Risk.gateOpen : L10n.Risk.gateClosed),
        color: status.tradingGate.open ? Palette.profitText : Palette.warningText)
      if !status.tradingGate.open {
        Text(verbatim: ApiText.gate(status.tradingGate))
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      }
    }
    .animation(Tokens.Motion.standard, value: [allowed, calm])
  }
}

/// Blocks on new entries the bot raised itself, each with its text and since when.
private struct FencesCard: View {
  let fences: [Fence]

  var body: some View {
    RiskCard(title: L10n.Risk.fences, tint: fences.isEmpty ? nil : Palette.warning) {
      if fences.isEmpty {
        Text(L10n.Risk.noFences)
          .font(Tokens.Typography.callout)
          .foregroundStyle(Palette.textTertiary)
      }
      ForEach(fences, id: \.self) { fence in
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
          Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Palette.warning)
          VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
            Text(verbatim: ApiText.fenceWithDetail(fence))
              .font(Tokens.Typography.callout)
              .foregroundStyle(Palette.textPrimary)
              .fixedSize(horizontal: false, vertical: true)
            Text(L10n.Risk.since(Format.time(fence.since.date)))
              .font(Tokens.Typography.annotation)
              .foregroundStyle(Palette.textQuaternary)
          }
        }
        .accessibilityElement(children: .combine)
        .transition(.move(edge: .top).combined(with: .opacity))
      }
    }
    .animation(Tokens.Motion.standard, value: fences)
  }
}

/// The configured risk limits (config/bot.toml, read through GET /settings).
private struct LimitsCard: View {
  let risk: RiskSettings?
  let failure: String?

  var body: some View {
    RiskCard(title: L10n.Risk.limits) {
      if let risk {
        RiskLine(label: L10n.Risk.plannedLoss, value: RiskFormat.amount(risk.plannedLossUsd.value))
        RiskLine(label: L10n.Risk.notionalCap, value: RiskFormat.amount(risk.positionNotionalCapUsd.value))
        RiskLine(label: L10n.Risk.limit, value: RiskFormat.amount(risk.maxDailyLossUsd.value))
        RiskLine(label: L10n.Risk.minRoom, value: RiskFormat.amount(risk.minDailyRoomUsd.value))
        RiskLine(label: L10n.Risk.openPositions, value: risk.maxOpenPositions.formatted())
        RiskLine(label: L10n.Risk.quoteAge,
          value: String(localized: L10n.Risk.seconds(Money.plain(risk.maxQuoteAgeSeconds.value, fractionDigits: 0))))
      } else if let failure {
        Text(L10n.Risk.settingsFailed)
          .font(Tokens.Typography.callout)
          .foregroundStyle(Palette.warningText)
        Text(verbatim: failure)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      } else {
        ProgressView().frame(maxWidth: .infinity)
      }
    }
  }
}

/// The trading session in New York time: the clock, the last entry and the flatten time.
private struct SessionCard: View {
  /// How often the clock ticks, in seconds.
  static let tick: TimeInterval = 1

  let session: SessionSettings?

  var body: some View {
    RiskCard(title: L10n.Risk.session) {
      TimelineView(.periodic(from: .now, by: Self.tick)) { context in
        Text(context.date, format: .dateTime.hour().minute().second())
          .environment(\.timeZone, WireDate.newYork.timeZone)
          .font(Tokens.Typography.metric)
          .monospacedDigit()
          .contentTransition(.numericText())
          .foregroundStyle(Palette.textPrimary)
      }
      if let session {
        RiskLine(label: L10n.Risk.lastEntry,
          value: String(localized: L10n.Risk.beforeClose(session.lastEntryMinutesBeforeClose)))
        RiskLine(label: L10n.Risk.flatten,
          value: String(localized: L10n.Risk.beforeClose(session.flattenMinutesBeforeClose)))
        RiskLine(label: L10n.Risk.halfDays,
          value: String(localized: session.halfDaysEnabled ? L10n.Risk.yes : L10n.Risk.no))
      }
    }
  }
}
