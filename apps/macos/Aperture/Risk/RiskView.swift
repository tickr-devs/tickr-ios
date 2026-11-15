import ApertureDesign
import ApertureKit
import SwiftUI

/// Risk & account: how much of the daily loss limit is left, whether entries are allowed and
/// why not, the configured limits, the trading session, and (once the API serves it) the account.
struct RiskView: View {
  /// Entrance order of the cards.
  private enum Order: Int {
    case lossRoom = 0, gate, fences, limits, session, account
  }

  var body: some View {
    ScrollView {
      // The design's grid: three equal columns in two rows, each row's cards one height. A window
      // too narrow for three columns gets two.
      ViewThatFits(in: .horizontal) {
        Grid(horizontalSpacing: Tokens.Space.l, verticalSpacing: Tokens.Space.l) {
          GridRow {
            lossRoom
            limits
            account
          }
          GridRow {
            session
            gate
            fences
          }
        }
        Grid(horizontalSpacing: Tokens.Space.l, verticalSpacing: Tokens.Space.l) {
          GridRow {
            lossRoom
            account
          }
          GridRow {
            limits
            session
          }
          GridRow {
            gate
            fences
          }
        }
      }
      .filling()
      .padding(Tokens.Space.xl)
    }
  }

  private var lossRoom: some View { LossRoomCard().gridColumn().rise(step: Order.lossRoom.rawValue) }
  private var gate: some View { EntryGateCard().gridColumn().rise(step: Order.gate.rawValue) }
  private var fences: some View { FencesCard().gridColumn().rise(step: Order.fences.rawValue) }
  private var limits: some View { LimitsCard().gridColumn().rise(step: Order.limits.rawValue) }
  private var session: some View { SessionCard().gridColumn().rise(step: Order.session.rawValue) }
  private var account: some View { AccountCard().gridColumn().rise(step: Order.account.rawValue) }
}

/// The daily loss limit as a ring: the room the bot reports after the net day result (profits
/// offset losses) and open reservations, against the limit.
private struct LossRoomCard: View {
  @Environment(AppModel.self) private var model

  /// Diameter of the ring, in points.
  static let ringSize: CGFloat = 220
  /// Smallest scale the amount in the ring shrinks to.
  static let amountMinimumScale = 0.5
  /// Room left below this share of the limit turns the ring amber, below `alarm` red.
  static let calm = 0.5
  static let alarm = 0.2

  private var limit: Decimal? { model.settings?.risk.maxDailyLossUsd.value }
  /// Today's net result; nil while the bot's status is unknown. The limit counts the live day only.
  private var result: Decimal? { model.status?.resultTodayGrossUsd.value }
  /// The bot's own number; the app never computes a room the bot did not report.
  private var room: Decimal? { model.dailyRoom }

  private var fraction: Double {
    guard let limit, let room, limit > 0 else { return 0 }
    return NSDecimalNumber(decimal: room / limit).doubleValue
  }

  /// Symbols of the loss-room figures.
  static let limitSymbol = "gauge.with.dots.needle.67percent"
  static let resultSymbol = "plusminus"
  static let realizedSymbol = "arrow.down.right"
  static let reservationsSymbol = "lock.circle"

  private var color: Color {
    if room == nil { return Palette.textQuaternary }
    if fraction < Self.alarm { return Palette.loss }
    if fraction < Self.calm { return Palette.warning }
    return Palette.profit
  }

  var body: some View {
    Card(L10n.Risk.lossRoom) {
      VStack(spacing: Tokens.Space.l) {
        ResultRing(fraction: fraction, color: color) {
          VStack(spacing: Tokens.Space.xxs) {
            if let room {
              // One line inside the ring, shrinking for a long amount ("248.40 USD" wrapped).
              MoneyText(value: room, usd: true, font: Tokens.Typography.hero, colored: false, signed: false)
                .lineLimit(1)
                .minimumScaleFactor(Self.amountMinimumScale)
                .contentTransition(.numericText())
            } else {
              Text(verbatim: Format.missing).font(Tokens.Typography.hero)
            }
            CardLabel(L10n.Risk.roomLeft)
          }
        }
        .frame(width: Self.ringSize, height: Self.ringSize)
        .frame(maxWidth: .infinity)
        .modifier(AlarmPulse(active: room != nil && fraction < Self.alarm))
        VStack(spacing: Tokens.Space.s) {
          StatLine(L10n.Risk.limit, value: limit.map(Format.usd) ?? Format.missing, symbol: Self.limitSymbol)
          StatLine(
            L10n.Risk.resultToday, value: result.map(Money.signedUSD) ?? Format.missing,
            color: result.map(Palette.result) ?? Palette.textQuaternary, symbol: Self.resultSymbol)
          StatLine(L10n.Risk.realizedLoss, value: amount(model.status?.realizedLossTodayUsd), symbol: Self.realizedSymbol)
          StatLine(L10n.Risk.reservations, value: amount(model.status?.openReservationsUsd), symbol: Self.reservationsSymbol)
        }
        if model.status != nil && room == nil {
          Footnote(L10n.Risk.roomNotReported, color: Palette.warningText)
        }
        Footnote(L10n.Risk.lossRoomNote)
      }
    }
  }
}

extension LossRoomCard {
  /// A USD amount the bot reported, or the missing mark when it did not.
  fileprivate func amount(_ value: DecimalString?) -> String {
    value.map { Format.usd($0.value) } ?? Format.missing
  }
}

/// Whether the bot may open a position now, and the one recorded cause when it may not.
private struct EntryGateCard: View {
  @Environment(AppModel.self) private var model

  private enum Gate { case allowed, waiting, blocked }

  /// Allowed; waiting for an ordinary reason that passes on its own (calm); or blocked for a
  /// reason the operator should look at.
  private var gate: Gate {
    guard let status = model.status else { return .blocked }
    if status.entryStop || !status.tradingGate.open { return .blocked }
    guard let block = status.entryBlock else { return .allowed }
    return block.attention ? .blocked : .waiting
  }

  var body: some View {
    let gate = self.gate
    let tone: Tone = switch gate {
    case .allowed: .profit
    case .waiting: .neutral
    case .blocked: .warning
    }
    let title = switch gate {
    case .allowed: L10n.Risk.allowed
    case .waiting: L10n.Risk.waiting
    case .blocked: L10n.Risk.blocked
    }
    Card(L10n.Risk.entryGate, tint: gate == .blocked ? Palette.warning : nil, tone: tone, trailing: {
      StatusPill(title, tone: tone, live: gate == .allowed, event: model.status?.freshness.lastBrokerReadAt?.date)
    }) {
      if let status = model.status {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
          if let block = status.entryBlock {
            Text(verbatim: ApiText.entryBlock(block))
              .font(Tokens.Typography.body)
              .foregroundStyle(block.attention ? Palette.textPrimary : Palette.textSecondary)
              // The bot's own words keep the detail (times, amounts) until it sends them as values.
              .help(Text(verbatim: block.text))
          }
          StatLine(
            L10n.Risk.operatorPause, value: String(localized: status.entryStop ? L10n.Common.on : L10n.Common.off),
            color: status.entryStop ? Palette.warningText : Palette.textPrimary)
          StatLine(
            L10n.Risk.tradingGate, value: String(localized: status.tradingGate.open ? L10n.Risk.gateOpen : L10n.Risk.gateClosed),
            color: status.tradingGate.open ? Palette.profitText : Palette.warningText)
          if !status.tradingGate.open {
            Footnote(verbatim: ApiText.gate(status.tradingGate), color: Palette.textQuaternary)
          }
        }
        .animation(Tokens.Motion.standard, value: status.entryBlock)
      } else {
        StatusUnknown()
      }
    }
  }
}

/// Why the bot's status is unknown: the read failed, or the bot has not written one.
private struct StatusUnknown: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      Text(L10n.Risk.statusUnknown)
        .font(Tokens.Typography.body)
        .foregroundStyle(Palette.warningText)
      if let cause = model.fetchError ?? model.response?.unavailableCause {
        Footnote(verbatim: cause)
      }
    }
  }
}

/// Fences: blocks on new entries the bot raised itself, each with its cause and time.
private struct FencesCard: View {
  @Environment(AppModel.self) private var model

  /// The bot's fences; nil while its status is unknown (never shown as "no fences").
  private var fences: [Fence]? { model.status?.fences }

  var body: some View {
    Card(L10n.Risk.fences, trailing: {
      if let fences {
        Badge(L10n.Common.fences(fences.count), color: fences.isEmpty ? Palette.textQuaternary : Palette.warningText)
      }
    }) {
      if let fences {
        list(fences)
      } else {
        Footnote(L10n.Common.unavailable)
      }
    }
  }

  @ViewBuilder private func list(_ fences: [Fence]) -> some View {
    if fences.isEmpty {
      Footnote(L10n.Risk.noFences)
    } else {
      VStack(alignment: .leading, spacing: Tokens.Space.s) {
        ForEach(fences, id: \.self) { fence in
          HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Palette.warning)
            VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
              Text(verbatim: ApiText.fence(fence)).foregroundStyle(Palette.textPrimary)
              // What the fence says often tells what to do, so it stays visible; the bot's own
              // words are the tooltip.
              Text(verbatim: ApiText.fenceDetail(fence))
                .font(Tokens.Typography.callout)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .help(Text(verbatim: fence.text))
              Text(L10n.Risk.fenceSince(Format.marketTime(fence.since.date)))
                .font(Tokens.Typography.captionMono)
                .foregroundStyle(Palette.textQuaternary)
            }
          }
          .transition(.move(edge: .top).combined(with: .opacity))
        }
      }
      .animation(Tokens.Motion.standard, value: fences)
    }
  }
}

/// The configured risk limits (config/bot.toml, read through GET /settings).
private struct LimitsCard: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    Card(L10n.Risk.limits) {
      if let risk = model.settings?.risk {
        VStack(spacing: Tokens.Space.s) {
          StatLine(L10n.Risk.plannedLoss, value: Format.usd(risk.plannedLossUsd.value))
          StatLine(L10n.Risk.notionalCap, value: Format.usd(risk.positionNotionalCapUsd.value))
          StatLine(L10n.Risk.dailyLoss, value: Format.usd(risk.maxDailyLossUsd.value))
          StatLine(L10n.Risk.minRoom, value: Format.usd(risk.minDailyRoomUsd.value))
          StatLine(L10n.Risk.openPositions, value: String(risk.maxOpenPositions))
          StatLine(L10n.Risk.quoteAge, value: String(localized: L10n.Risk.seconds(Format.secondsNumber(risk.maxQuoteAgeSeconds.value))))
        }
      } else {
        Footnote(model.settingsError == nil ? L10n.Common.unavailable : L10n.Risk.settingsUnavailable)
      }
    }
  }
}

/// The trading session in New York time: the clock, the last entry and the flatten time.
private struct SessionCard: View {
  @Environment(AppModel.self) private var model

  /// How often the clock ticks, in seconds.
  static let tick: TimeInterval = 1

  var body: some View {
    Card(L10n.Risk.session) {
      VStack(alignment: .leading, spacing: Tokens.Space.s) {
        TimelineView(.periodic(from: .now, by: Self.tick)) { context in
          Text(L10n.Risk.clock(Format.marketTime(model.botTime(context.date))))
            .font(Tokens.Typography.metric)
            .monospacedDigit()
            .contentTransition(.numericText())
            .foregroundStyle(Palette.textPrimary)
        }
        if let session = model.settings?.session {
          StatLine(L10n.Risk.lastEntry, value: String(localized: L10n.Risk.minutesBeforeClose(session.lastEntryMinutesBeforeClose)))
          StatLine(L10n.Risk.flatten, value: String(localized: L10n.Risk.minutesBeforeClose(session.flattenMinutesBeforeClose)))
          StatLine(L10n.Risk.halfDays, value: String(localized: session.halfDaysEnabled ? L10n.Common.on : L10n.Common.off))
        }
      }
    }
  }
}

/// The broker account at the bot's last read: positions and open orders as the broker reports
/// them, and whether they match the bot's records. The broker is the source of truth; a mismatch
/// blocks new entries until reconciled.
private struct AccountCard: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    Card(L10n.Risk.account, tint: tint, trailing: { badges }) {
      if let response = model.account {
        content(response)
      } else if model.accountError != nil {
        Footnote(L10n.Risk.accountUnavailable, color: Palette.warningText)
      } else {
        Footnote(L10n.Risk.accountReading)
      }
    }
    .animation(Tokens.Motion.standard, value: model.account)
  }

  private var tint: Color? {
    guard let response = model.account else { return nil }
    return response.account.matchesRecords && !response.stale ? nil : Palette.warning
  }

  @ViewBuilder private var badges: some View {
    if let response = model.account {
      HStack(spacing: Tokens.Space.xs) {
        if response.stale {
          Badge(L10n.Risk.stale, color: Palette.warningText)
        }
        Badge(response.account.matchesRecords ? L10n.Risk.matches : L10n.Risk.mismatch,
          color: response.account.matchesRecords ? Palette.profitText : Palette.lossText)
      }
    }
  }

  private func content(_ response: AccountResponseV1) -> some View {
    let account = response.account
    return VStack(alignment: .leading, spacing: Tokens.Space.s) {
      if let mismatch = account.mismatch {
        Text(verbatim: mismatch)
          .font(Tokens.Typography.callout)
          .foregroundStyle(Palette.lossText)
      }
      StatLine(L10n.Risk.equity, value: account.equityUsd.map { Format.usd($0.value) } ?? Format.missing,
        color: account.equityUsd == nil ? Palette.textQuaternary : Palette.textPrimary)
      StatLine(L10n.Risk.buyingPower, value: account.buyingPowerUsd.map { Format.usd($0.value) } ?? Format.missing,
        color: account.buyingPowerUsd == nil ? Palette.textQuaternary : Palette.textPrimary)
      if account.equityUsd == nil || account.buyingPowerUsd == nil {
        Footnote(L10n.Risk.balanceNote)
      }
      Divider()
      CardLabel(L10n.Risk.brokerPositions)
      if account.positions.isEmpty {
        Footnote(L10n.Risk.none)
      }
      ForEach(account.positions, id: \.self) { position in
        HStack(spacing: Tokens.Space.s) {
          Text(verbatim: position.symbol).font(Tokens.Typography.calloutMono)
          Spacer()
          Text(verbatim: position.quantity.text).font(Tokens.Typography.captionMono)
          Text(verbatim: position.avgPrice?.text ?? Format.missing)
            .font(Tokens.Typography.captionMono)
            .foregroundStyle(Palette.textTertiary)
        }
      }
      CardLabel(L10n.Risk.brokerOrders)
      if account.orders.isEmpty {
        Footnote(L10n.Risk.none)
      }
      ForEach(account.orders, id: \.self) { order in
        HStack(spacing: Tokens.Space.s) {
          Text(verbatim: order.symbol).font(Tokens.Typography.calloutMono)
          Group {
            Text(verbatim: ApiText.orderSide(order.side))
            Text(verbatim: ApiText.orderType(order.type))
            Text(verbatim: order.quantity.text)
          }
          .font(Tokens.Typography.captionMono)
          Spacer()
          if let price = order.stopPrice ?? order.limitPrice {
            Text(verbatim: price.text).font(Tokens.Typography.captionMono)
          }
          Text(verbatim: ApiText.orderStatus(order.status))
            .font(Tokens.Typography.captionMono)
            .foregroundStyle(Palette.textTertiary)
          if !order.ours {
            Badge(L10n.Risk.notOurs, color: Palette.warningText)
          }
        }
      }
      Footnote(L10n.Risk.readAt(Format.marketTime(account.readAt.date), Format.wholeSeconds(response.ageSeconds.value)))
    }
  }
}

#if DEBUG
#Preview {
  RiskView()
    .environment(PreviewAPI.model())
    .frame(width: PreviewAPI.windowWidth, height: PreviewAPI.windowHeight)
}
#endif
