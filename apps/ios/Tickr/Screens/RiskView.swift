import SwiftUI
import TickrDesign
import TickrKit

/// Risk (IOS2Risk board, mockup v155): what is left of the daily loss limit and what used it, how
/// the last entry was sized, and the broker account's balances. Every figure is what the bot wrote
/// in its status or account file or reads from its configuration (GET /settings); the phone
/// computes nothing the bot acts on. Whether entries are allowed is on Home, the fences on Home's
/// broker check, the session and the trading gate in Settings, every limit in its configuration.
struct RiskView: View {
  /// Order in which the cards rise in (`rise(step:)`).
  private enum Order: Int { case room = 1, sizing, account }

  @Environment(AppModel.self) private var model

  var body: some View {
    Screen(L10n.Risk.title, back: L10n.App.home) {
      if let status = model.status {
        RoomCard(status: status, risk: model.settings?.risk).rise(step: Order.room.rawValue)
      }
      if let sizing {
        EntrySizingSection(sizing: sizing)
          .padding(Tokens.Space.l)
          .tickrCard()
          .rise(step: Order.sizing.rawValue)
      }
      AccountCard(response: model.account, failure: model.accountError).rise(step: Order.account.rawValue)
    }
    .refreshable { await model.refreshAll() }
    .task(id: model.connection.url) { await model.followAccount() }
    // The records' reconciliation and the latest entry size of the Risk room card.
    .task(id: model.connection.url) { await model.refreshFlow() }
  }

  /// "Last entry size" (mockup IOSRisk), its own card: nil while the day's latest size is not
  /// read (never "no entry"), or on a recorded day (this screen is live only).
  private var sizing: EntrySizing? {
    guard model.isLive, let risk = model.settings?.risk else { return nil }
    return model.watching.map { watching in
      EntrySizing(size: watching.latestSize, configured: SizingLimits(
        plannedLossUsd: risk.plannedLossUsd.value, notionalCapUsd: risk.positionNotionalCapUsd.value,
        dailyRoomUsd: model.status?.dailyRoomUsd?.value), text: .money)
    }
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
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      CardLabel(title)
      content
    }
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, alignment: .leading)
    .tickrCard()
  }
}

/// A label with its value on the right.
private struct RiskLine: View {
  let label: LocalizedStringResource
  /// The value; nil while it is read, when a sample of its length stands as skeleton.
  let value: String?
  var color: Color = Palette.textPrimary

  var body: some View {
    // At large text sizes the value goes under its label, so neither breaks mid-word.
    RowStack(alignment: .firstTextBaseline, spacing: Tokens.Space.xxs) {
      Text(label)
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textTertiary)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: Tokens.Space.s)
      Text(verbatim: value ?? Money.price(SkeletonSample.price))
        .font(Tokens.Typography.calloutMono)
        .foregroundStyle(color)
        .contentTransition(.numericText())
        .fixedSize(horizontal: false, vertical: true)
        .skeleton(value == nil)
    }
    .accessibilityElement(children: .combine)
  }
}

/// The Risk room card both apps share (mockup IOSRisk): the room the bot says is left of the
/// daily loss limit, the net day, the reservations, the positions and the records. How the last
/// entry was sized is its own card under it.
private struct RoomCard: View {
  let status: StatusV1
  let risk: RiskSettings?
  @Environment(AppModel.self) private var model

  var body: some View {
    RiskCard(title: L10n.Risk.room) {
      if !model.isLive {
        // This screen is always live: the limits and the broker now, never the picked day.
        InfoCaption(L10n.Risk.liveOnly(DayText.day(model.shownDay.noonInNewYork)), tone: .highlight)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      if let risk {
        let reservations = status.openReservationsUsd?.value
        let result = status.resultTodayUsd.value
        let room = status.dailyRoomUsd?.value
        RiskRoomPanel(room: room, limit: risk.maxDailyLossUsd.value, reserved: reservations, facts: [
          RiskFact(.netResult, RiskRoomText.netResult, value: Money.signedUSD(result), color: Palette.result(result)),
          RiskFact(.reservations, RiskRoomText.reservations, value: RiskFormat.amount(reservations),
            color: reservations.map { Tone.amount($0, .warning).text } ?? Palette.textQuaternary),
          RiskFact(.positions, RiskRoomText.positions,
            value: String(localized: L10n.Risk.positionsOf(status.positions.count, risk.maxOpenPositions))),
          .records(RecordsAgreement(fences: status.fences, latest: model.isLive ? model.flow?.reconcile : nil)),
        ], sizing: nil, roomNote: RiskRoomText.roomNote(status))
      } else {
        RiskLine(label: L10n.Risk.room, value: RiskFormat.amount(status.dailyRoomUsd?.value))
        // The limits come from the configuration (GET /settings): why the card has only the room.
        if let failure = model.settingsError {
          ReadFailureNote(L10n.Risk.settingsFailed, detail: failure)
        }
      }
    }
  }
}

/// The broker account at the bot's latest read (mockup IOSRisk): equity big with the account kind
/// and the read's time, four balances, then the rest of the balances, the broker's positions and
/// today's fills, each one tap away. Display only: the bot's limits are its settings, never these
/// numbers. The account id is never shown.
private struct AccountCard: View {
  let response: AccountResponseV1?
  let failure: String?

  private var account: AccountV1? { response?.account }
  /// The account is being read for the first time.
  private var loading: Bool { response == nil && failure == nil }

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      RowStack(alignment: .firstTextBaseline, spacing: Tokens.Space.xxs) {
        CardLabel(L10n.Risk.account)
        Spacer(minLength: Tokens.Space.s)
        if let account {
          Text(verbatim: [account.accountLabel, String(localized: L10n.Risk.readAt(
            Format.timeOrDash(account.balanceReadAt ?? account.readAt)))].compactMap { $0 }
            .joined(separator: Format.separator))
            .font(Tokens.Typography.caption)
            .foregroundStyle(Palette.textQuaternary)
            .fixedSize(horizontal: false, vertical: true)
        }
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
        RiskLine(label: L10n.Risk.dayResult, value: Money.signedUSD(b.dayPlUsd.value),
          color: Palette.result(b.dayPlUsd.value))
        RiskLine(label: L10n.Risk.unrealized, value: Money.signedUSD(b.unrealizedPlUsd.value),
          color: Palette.result(b.unrealizedPlUsd.value))
        FooterDetail(L10n.Risk.moreBalances, endsCard: false) {
          RiskLine(label: L10n.Risk.overnightBuyingPower, value: RiskFormat.amount(b.overnightBuyingPowerUsd.value))
          RiskLine(label: L10n.Risk.positionsValue, value: RiskFormat.amount(b.positionsValueUsd.value))
          RiskLine(label: L10n.Risk.dayTradesLeft,
            value: b.dayTradesLeft.map { String($0) } ?? String(localized: L10n.Risk.noLimit))
          RiskLine(label: L10n.Risk.marginCalls, value: String(b.marginCalls),
            color: b.marginCalls > 0 ? Palette.warningText : Palette.textPrimary)
          RiskLine(label: L10n.Risk.maintenance, value: RiskFormat.amount(b.maintenanceMarginUsd.value))
        }
      } else if loading {
        // The equity and the lines in their places while the account is read, values as skeleton.
        Text(verbatim: RiskFormat.amount(Decimal(SkeletonSample.price)))
          .font(Tokens.Typography.metric)
          .skeleton(true, .value)
        ForEach([L10n.Risk.cash, L10n.Risk.buyingPower, L10n.Risk.dayResult, L10n.Risk.unrealized], id: \.key) { label in
          RiskLine(label: label, value: nil)
        }
      }
      if account?.balances == nil, !loading {
        Text(failure == nil || response != nil ? L10n.Risk.balanceNote : L10n.Risk.accountUnavailable)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
          .fixedSize(horizontal: false, vertical: true)
      }
      if let account {
        FooterDetail(L10n.Risk.brokerPositions, summary: String(account.positions.count), endsCard: false) {
          if account.positions.isEmpty {
            none
          }
          ForEach(account.positions, id: \.self) { positionRow($0) }
        }
        // The day's fills, latest first, in their sheet: the list grows all day.
        FooterDetail(L10n.Risk.fillsToday, summary: String(account.fills.count), endsCard: false) {
          if account.fills.isEmpty {
            none
          }
          ForEach(account.fillsLatestFirst, id: \.self) { fillRow($0) }
        }
      }
    }
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, alignment: .leading)
    .tickrCard(tint: response?.stale == true ? Palette.warning : nil)
    .animation(Tokens.Motion.standard, value: response?.state)
  }

  /// A broker position: the symbol with quantity and last price under it, and its result.
  private func positionRow(_ position: AccountPositionV1) -> some View {
    let last: String = position.lastPrice.map { Money.price($0.value) } ?? Format.missing
    let result: String = position.unrealizedPlUsd.map { Money.signedUSD($0.value) } ?? Format.missing
    return row(position.symbol, detail: [position.quantity.text, last].joined(separator: Format.separator),
      value: result, color: position.unrealizedPlUsd.map { Palette.result($0.value) } ?? Palette.textQuaternary)
  }

  /// A fill: its symbol, with time, side and quantity under it, and its price and fees.
  private func fillRow(_ fill: AccountFillV1) -> some View {
    let price: String = (fill.exactPrice ?? fill.price).map { Money.price($0.value) } ?? Format.missing
    let feeAmount: String = fill.feesUsd.map { RiskFormat.amount($0.value) } ?? Format.missing
    let fees: String = String(localized: L10n.Risk.fees(feeAmount))
    return row(fill.symbol,
      detail: [Format.timeOrDash(fill.filledAt), ApiText.orderSide(fill.side), fill.quantity.text]
        .joined(separator: Format.separator),
      value: [price, fees].joined(separator: Format.separator), color: Palette.textPrimary)
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
        SymbolText(symbol)
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
