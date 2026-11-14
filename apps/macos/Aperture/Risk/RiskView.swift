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
      HStack(alignment: .top, spacing: Tokens.Space.l) {
        VStack(spacing: Tokens.Space.l) {
          LossRoomCard().rise(step: Order.lossRoom.rawValue)
          SessionCard().rise(step: Order.session.rawValue)
        }
        .frame(width: Tokens.Size.sideColumn)
        VStack(spacing: Tokens.Space.l) {
          EntryGateCard().rise(step: Order.gate.rawValue)
          FencesCard().rise(step: Order.fences.rawValue)
          HStack(alignment: .top, spacing: Tokens.Space.l) {
            LimitsCard().rise(step: Order.limits.rawValue)
            AccountCard().rise(step: Order.account.rawValue)
          }
        }
      }
      .padding(Tokens.Space.xl)
      .frame(maxWidth: Tokens.Size.contentMaxWidth)
    }
  }
}

/// The daily loss limit as a ring: the net day result (profits offset losses) against the limit.
private struct LossRoomCard: View {
  @Environment(AppModel.self) private var model

  /// Diameter of the ring, in points.
  static let ringSize: CGFloat = 220
  /// Room left below this share of the limit turns the ring amber, below `alarm` red.
  static let calm = 0.5
  static let alarm = 0.2

  private var limit: Decimal? { model.settings?.risk.maxDailyLossUsd.value }
  /// Today's net result; nil while the bot's status is unknown. The limit counts the live day only.
  private var result: Decimal? { model.status?.resultTodayGrossUsd.value }
  private var room: Decimal? {
    guard let limit, let result else { return nil }
    return DailyRoom.left(limit: limit, netResult: result)
  }

  private var fraction: Double {
    guard let limit, let room, limit > 0 else { return 0 }
    return NSDecimalNumber(decimal: room / limit).doubleValue
  }

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
              MoneyText(value: room, usd: true, font: Tokens.Typography.hero, colored: false)
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
          StatLine(L10n.Risk.limit, value: limit.map(Money.signedUSD) ?? Format.missing)
          StatLine(
            L10n.Risk.resultToday, value: result.map(Money.signedUSD) ?? Format.missing,
            color: result.map(Palette.result) ?? Palette.textQuaternary)
          HStack {
            Text(L10n.Risk.reservationsExcluded)
              .font(Tokens.Typography.callout)
              .foregroundStyle(Palette.textTertiary)
            Spacer()
            PlannedTag(.needsAPI)
          }
        }
        Footnote(L10n.Risk.lossRoomNote)
      }
    }
  }
}

/// Whether the bot may open a position now, and the one recorded cause when it may not.
private struct EntryGateCard: View {
  @Environment(AppModel.self) private var model

  private var allowed: Bool {
    guard let status = model.status else { return false }
    return status.entryBlock == nil && !status.entryStop && status.tradingGate.open
  }

  var body: some View {
    Card(L10n.Risk.entryGate, tint: allowed ? nil : Palette.warning, trailing: {
      Badge(allowed ? L10n.Risk.allowed : L10n.Risk.blocked, color: allowed ? Palette.profitText : Palette.warningText)
    }) {
      if let status = model.status {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
          if let block = status.entryBlock {
            Text(verbatim: block.text)
              .font(Tokens.Typography.body)
              .foregroundStyle(Palette.textPrimary)
            Footnote(verbatim: block.cause, color: Palette.textQuaternary)
          }
          StatLine(
            L10n.Risk.operatorPause, value: String(localized: status.entryStop ? L10n.Common.on : L10n.Common.off),
            color: status.entryStop ? Palette.warningText : Palette.textPrimary)
          StatLine(
            L10n.Risk.tradingGate, value: String(localized: status.tradingGate.open ? L10n.Risk.gateOpen : L10n.Risk.gateClosed),
            color: status.tradingGate.open ? Palette.profitText : Palette.warningText)
          if !status.tradingGate.open {
            Footnote(verbatim: status.tradingGate.cause, color: Palette.textQuaternary)
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
              Text(verbatim: fence.text).foregroundStyle(Palette.textPrimary)
              Text(L10n.Risk.fenceSince(fence.kind, Format.marketTime(fence.since.date)))
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
          StatLine(L10n.Risk.plannedLoss, value: Money.signedUSD(risk.plannedLossUsd.value))
          StatLine(L10n.Risk.notionalCap, value: Money.signedUSD(risk.positionNotionalCapUsd.value))
          StatLine(L10n.Risk.dailyLoss, value: Money.signedUSD(risk.maxDailyLossUsd.value))
          StatLine(L10n.Risk.openPositions, value: String(risk.maxOpenPositions))
          StatLine(L10n.Risk.quoteAge, value: String(localized: L10n.Risk.seconds(Money.plain(risk.maxQuoteAgeSeconds.value))))
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
          Text(context.date, format: .dateTime.hour().minute().second().timeZone(.exemplarLocation))
            .environment(\.timeZone, Format.newYork)
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

/// The broker account: equity, buying power and the broker's own view of positions and orders.
/// Needs a new local-API read, so it shows what it will hold, disabled.
private struct AccountCard: View {
  var body: some View {
    Card(L10n.Risk.account, trailing: { PlannedTag(.needsAPI) }) {
      VStack(spacing: Tokens.Space.s) {
        StatLine(L10n.Risk.equity, value: Format.missing, color: Palette.textQuaternary)
        StatLine(L10n.Risk.buyingPower, value: Format.missing, color: Palette.textQuaternary)
        StatLine(L10n.Risk.brokerPositions, value: Format.missing, color: Palette.textQuaternary)
        StatLine(L10n.Risk.brokerOrders, value: Format.missing, color: Palette.textQuaternary)
        Footnote(L10n.Risk.accountNote)
      }
    }
  }
}
