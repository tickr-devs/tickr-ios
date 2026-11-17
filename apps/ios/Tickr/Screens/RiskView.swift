import SwiftUI
import TickrDesign
import TickrKit

/// Risk: what is left of the daily loss limit and what used it, whether the bot may open a
/// position now and why not, its fences, the broker account's balances, the configured limits
/// and the trading session. Every figure is what the bot wrote in its status or account file or
/// reads from its configuration (GET /settings); the phone computes nothing the bot acts on.
struct RiskView: View {
  /// Order in which the cards rise in (`rise(step:)`).
  private enum Order: Int { case room = 1, gate, fences, account, limits, session }

  @Environment(AppModel.self) private var model

  var body: some View {
    Screen(L10n.Risk.title, back: L10n.App.home) {
      if let status = model.status {
        RoomCard(status: status, risk: model.settings?.risk).rise(step: Order.room.rawValue)
        GateCard(status: status).rise(step: Order.gate.rawValue)
        FencesCard(status: status).rise(step: Order.fences.rawValue)
      }
      AccountCard(response: model.account, failure: model.accountError).rise(step: Order.account.rawValue)
      LimitsCard(risk: model.settings?.risk, failure: model.settingsError).rise(step: Order.limits.rawValue)
      SessionCard(session: model.settings?.session).rise(step: Order.session.rawValue)
    }
    .refreshable { await model.refreshAll() }
    .task(id: model.connection.url) { await model.followAccount() }
  }
}

/// Every amount on this screen.
enum RiskFormat {
  /// "$123.40" (no plus: room and limits are amounts, not results; `Money.usd`, as on the Mac),
  /// or a dash when unknown.
  static func amount(_ value: Decimal?) -> String {
    value.map(Money.usd) ?? Format.missing
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
    .tickrCard(tint: tint)
  }
}

/// A label with its value on the right.
private struct RiskLine: View {
  let label: LocalizedStringResource
  let value: String
  var color: Color = Palette.textPrimary

  var body: some View {
    // At large text sizes the value goes under its label, so neither breaks mid-word.
    RowStack(alignment: .firstTextBaseline, spacing: Tokens.Space.xxs) {
      Text(label)
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textTertiary)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: Tokens.Space.s)
      Text(verbatim: value)
        .font(Tokens.Typography.calloutMono)
        .foregroundStyle(color)
        .contentTransition(.numericText())
        .fixedSize(horizontal: false, vertical: true)
    }
    .accessibilityElement(children: .combine)
  }
}

/// The daily loss limit as a ring: the room the bot says is left, and what used the rest.
private struct RoomCard: View {
  /// Side of the ring, in points.
  static let ringSide: CGFloat = 180

  let status: StatusV1
  let risk: RiskSettings?
  /// The ring grows with the figure inside it, up to the card's width.
  @ScaledMetric(relativeTo: .title2) private var ringSide = RoomCard.ringSide

  private var room: Decimal? { status.dailyRoomUsd?.value }
  private var limit: Decimal? { risk?.maxDailyLossUsd.value }

  private var share: Double {
    guard let room, let limit, limit > 0 else { return 0 }
    return NSDecimalNumber(decimal: room / limit).doubleValue
  }

  private var color: Color {
    guard room != nil, limit != nil else { return Palette.textQuaternary }
    if share < Tokens.Room.alarm { return Palette.loss }
    if share < Tokens.Room.calm { return Palette.warning }
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
            // One line at its full size; the ring is wide enough for it.
            .fixedSize()
          CardLabel(L10n.Risk.left)
        }
        .padding(Tokens.Space.l)
      }
      .aspectRatio(1, contentMode: .fit)
      .frame(maxWidth: ringSide)
      .frame(maxWidth: .infinity)
      .padding(.vertical, Tokens.Space.s)
      .accessibilityElement(children: .combine)
      RiskLine(label: L10n.Risk.limit, value: RiskFormat.amount(limit))
      // A loss with its minus ("−$1.60"), as on the Mac; "$0.00" neutral, never pink.
      RiskLine(label: L10n.Risk.realizedLoss,
        value: status.realizedLossTodayUsd.map { Money.signedUSD(-$0.value) } ?? Format.missing,
        color: status.realizedLossTodayUsd.map { Tone.loss($0.value).text } ?? Palette.textQuaternary)
      RiskLine(label: L10n.Risk.reservations, value: RiskFormat.amount(status.openReservationsUsd?.value),
        color: status.openReservationsUsd.map { Tone.amount($0.value, .warning).text } ?? Palette.textQuaternary)
      RiskLine(label: L10n.Risk.resultToday, value: Money.signedUSD(status.resultTodayUsd.value),
        color: Palette.result(status.resultTodayUsd.value))
      RiskLine(label: L10n.Risk.feesToday, value: RiskFormat.amount(status.feesTodayUsd?.value))
      Text(L10n.Risk.roomNote(RiskFormat.amount(risk?.minDailyRoomUsd.value)))
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .animation(Tokens.Motion.fill, value: share)
  }
}

/// The broker account's money at the bot's latest balance read, and the account kind. Display
/// only: the bot's limits are its settings, never these numbers. The account id is never shown.
private struct AccountCard: View {
  let response: AccountResponseV1?
  let failure: String?

  private var account: AccountV1? { response?.account }

  var body: some View {
    RiskCard(title: L10n.Risk.account, tint: response?.stale == true ? Palette.warning : nil) {
      if let label = account?.accountLabel {
        Text(verbatim: label)
          .font(Tokens.Typography.caption)
          .foregroundStyle(Palette.textSecondary)
      }
      if let b = account?.balances {
        Text(verbatim: RiskFormat.amount(b.equityUsd.value))
          .font(Tokens.Typography.metric)
          .foregroundStyle(Palette.textPrimary)
          .contentTransition(.numericText())
          .accessibilityLabel(Text(L10n.Risk.equity))
          .accessibilityValue(Text(verbatim: RiskFormat.amount(b.equityUsd.value)))
        RiskLine(label: L10n.Risk.cash, value: RiskFormat.amount(b.cashUsd.value))
        RiskLine(label: L10n.Risk.buyingPower, value: RiskFormat.amount(b.buyingPowerUsd.value),
          color: Palette.accentText)
        RiskLine(label: L10n.Risk.overnightBuyingPower, value: RiskFormat.amount(b.overnightBuyingPowerUsd.value))
        RiskLine(label: L10n.Risk.positionsValue, value: RiskFormat.amount(b.positionsValueUsd.value))
        RiskLine(label: L10n.Risk.unrealized, value: Money.signedUSD(b.unrealizedPlUsd.value),
          color: Palette.result(b.unrealizedPlUsd.value))
        RiskLine(label: L10n.Risk.dayResult, value: Money.signedUSD(b.dayPlUsd.value),
          color: Palette.result(b.dayPlUsd.value))
        Text(L10n.Risk.marginLine(
          b.dayTradesLeft.map { String($0) } ?? String(localized: L10n.Risk.noLimit),
          String(b.marginCalls), RiskFormat.amount(b.maintenanceMarginUsd.value),
          Format.timeOrDash(account?.balanceReadAt)))
          .font(Tokens.Typography.annotation)
          .foregroundStyle(b.marginCalls > 0 ? Palette.warningText : Palette.textQuaternary)
          .fixedSize(horizontal: false, vertical: true)
      }
      if let account {
        CardLabel(L10n.Risk.brokerPositions)
          .padding(.top, Tokens.Space.xs)
        if account.positions.isEmpty {
          none
        }
        ForEach(account.positions, id: \.self) { position in
          let last: String = position.lastPrice.map { Money.price($0.value) } ?? Format.missing
          let result: String = position.unrealizedPlUsd.map { Money.signedUSD($0.value) } ?? Format.missing
          row(position.symbol, detail: [position.quantity.text, last].joined(separator: Format.separator),
            value: result, color: position.unrealizedPlUsd.map { Palette.result($0.value) } ?? Palette.textQuaternary)
        }
        CardLabel(L10n.Risk.fillsToday)
          .padding(.top, Tokens.Space.xs)
        if account.fills.isEmpty {
          none
        }
        ForEach(account.fills, id: \.self) { fill in
          let price: String = (fill.exactPrice ?? fill.price).map { Money.price($0.value) } ?? Format.missing
          let feeAmount: String = fill.feesUsd.map { RiskFormat.amount($0.value) } ?? Format.missing
          let fees: String = String(localized: L10n.Risk.fees(feeAmount))
          row(fill.symbol,
            detail: [Format.timeOrDash(fill.filledAt), ApiText.orderSide(fill.side), fill.quantity.text]
              .joined(separator: Format.separator),
            value: [price, fees].joined(separator: Format.separator), color: Palette.textPrimary)
        }
      }
      if account?.balances == nil {
        Text(failure == nil || response != nil ? L10n.Risk.balanceNote : L10n.Risk.accountUnavailable)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .animation(Tokens.Motion.standard, value: response?.state)
  }

  private var none: some View {
    Text(L10n.Risk.none)
      .font(Tokens.Typography.callout)
      .foregroundStyle(Palette.textQuaternary)
  }

  /// A broker row: the symbol with its detail under it, and its figure on the right.
  private func row(_ symbol: String, detail: String, value: String, color: Color) -> some View {
    RowStack(alignment: .firstTextBaseline, spacing: Tokens.Space.xxs) {
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        Text(verbatim: symbol)
          .font(Tokens.Typography.calloutMono.bold())
        Text(verbatim: detail)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textTertiary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: Tokens.Space.s)
      Text(verbatim: value)
        .font(Tokens.Typography.calloutMono)
        .foregroundStyle(color)
        .fixedSize(horizontal: false, vertical: true)
    }
    .accessibilityElement(children: .combine)
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
  let status: StatusV1
  private var fences: [Fence] { status.fences }

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
            Text(verbatim: Board.fenceText(fence, status: status))
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
        RiskLine(label: L10n.Risk.openPositions, value: String(risk.maxOpenPositions))
        RiskLine(label: L10n.Risk.quoteAge,
          value: String(localized: L10n.Risk.seconds(Money.plain(risk.maxQuoteAgeSeconds.value, fractionDigits: 0))))
      } else if let failure {
        ReadFailureNote(L10n.Risk.settingsFailed, detail: failure)
      } else {
        Skeleton(L10n.Common.loading) { SkeletonRows(Tokens.Loading.manyRows) }
      }
    }
  }
}

/// The trading session in New York time: the clock, the last entry and the flatten time.
private struct SessionCard: View {
  let session: SessionSettings?

  var body: some View {
    RiskCard(title: L10n.Risk.session) {
      TimelineView(.periodic(from: .now, by: Tokens.Motion.clockTickSeconds)) { context in
        // The shared 24-hour New York clock, as every other time of the apps.
        Text(verbatim: ClockText.seconds(context.date))
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
