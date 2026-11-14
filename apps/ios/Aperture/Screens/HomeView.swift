import ApertureDesign
import ApertureKit
import SwiftUI

/// The first screen: the day's result, the one line that says what the bot is doing, live events,
/// open positions and the health of the bot's inputs. The power button opens bot control.
struct HomeView: View {
  /// Order in which the blocks rise in (`rise(step:)`); open positions follow one step apart.
  private enum Order: Int { case day = 1, summary, ticker, positions, health = 6 }

  @Environment(AppModel.self) private var model
  @State private var showControl = false

  var body: some View {
    Screen(L10n.App.name) {
      ConnectionPrompt()
      DayLine().rise(step: Order.day.rawValue)
      Summary().rise(step: Order.summary.rawValue)
      if let status = model.status {
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
          PositionRow(position: position)
            .rise(step: Order.positions.rawValue + index)
        }
        if status.position == nil {
          Text(L10n.Home.noPosition)
            .font(.subheadline)
            .foregroundStyle(Palette.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Tokens.Space.l)
            .apertureCard()
            .rise(step: Order.positions.rawValue)
        }
        HealthCard(status: status).rise(step: Order.health.rawValue)
      }
    }
    .toolbar {
      ToolbarItemGroup(placement: .topBarTrailing) {
        if let environment = model.status?.environment {
          EnvironmentBadge(environment: environment)
        }
        Button {
          showControl = true
        } label: {
          Image(systemName: "power")
            .fontWeight(.semibold)
            .foregroundStyle(model.canCommand ? Palette.warningText : Palette.textQuaternary)
        }
        .disabled(!model.canCommand)
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
    .refreshable { await model.refresh() }
  }
}

/// The trading day being shown. Past days arrive with the days API; until then this is today only.
private struct DayLine: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    HStack(spacing: Tokens.Space.s) {
      if model.response?.stale == false {
        PulseDot(Palette.profit, size: Tokens.Size.dotSmall)
      }
      Text(L10n.Common.today(Format.day(model.status?.writtenAt.date ?? .now)))
      Spacer()
      Text(Format.age(model.response))
        .contentTransition(.numericText())
    }
    .font(Tokens.Typography.captionMono)
    .foregroundStyle(Palette.textQuaternary)
  }
}

/// The ring with the day's result next to the headline.
private struct Summary: View {
  /// Side of the result ring, in points.
  static let ringSide: CGFloat = 136
  /// Smallest scale the result may shrink to inside the ring.
  static let minimumScale = 0.6

  @Environment(AppModel.self) private var model

  var body: some View {
    let stats = model.status.map(Board.dayStats)
    let result = stats?.resultGrossUsd ?? 0
    let headline = model.headline
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
          PulseDot(headline.severity.tint, pulsing: headline.severity != .ok || model.response?.stale == false)
          Text(verbatim: headline.text)
            .font(.subheadline.bold())
            .foregroundStyle(headline.severity.tint)
            .fixedSize(horizontal: false, vertical: true)
        }
        if let status = model.status {
          Text(verbatim: subline(status))
            .font(.footnote)
            .foregroundStyle(Palette.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .animation(.default, value: headline)
    }
  }

  private func subline(_ status: StatusV1) -> String {
    var parts: [LocalizedStringResource] = []
    if let position = status.position {
      parts.append(position.stop.state.isProtected
        ? L10n.Home.protected(position.symbol)
        : L10n.Home.stopIs(position.symbol, Board.stopStateTitle(position.stop.state)))
    }
    parts.append(L10n.Home.strategy(status.strategy.name, status.strategy.version))
    if !status.tradingGate.open { parts.append(L10n.Home.gateClosed(status.tradingGate.cause)) }
    return parts.map { String(localized: $0) }.joined(separator: " ")
  }
}

/// One open position on Home; tapping it opens it on the Positions tab.
private struct PositionRow: View {
  @Environment(AppModel.self) private var model
  let position: Position

  var body: some View {
    Button {
      model.selectedSymbol = position.symbol
      model.selectedTab = .positions
    } label: {
      HStack(spacing: Tokens.Space.m) {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
          Text(verbatim: position.symbol)
            .font(.headline.monospaced())
            .foregroundStyle(Palette.textPrimary)
          Text(stopLine)
            .font(Tokens.Typography.annotation)
            .foregroundStyle(position.stop.state.isProtected ? Palette.profitText : Palette.lossText)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: Tokens.Space.xs) {
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

/// The bot's inputs at a glance: broker reads, quote stream, gate, and outstanding fences.
private struct HealthCard: View {
  /// Glow around each input's dot, in points.
  static let glowRadius: CGFloat = 6

  let status: StatusV1

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      HStack {
        CardLabel(L10n.Home.inputs)
        Spacer()
        Text(status.botState.title)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(status.botState == .running ? Palette.profitText : Palette.warningText)
      }
      HStack(alignment: .top) {
        let broker = status.freshness.lastBrokerReadAt
        item(L10n.Home.broker, Text(verbatim: Format.timeOrDash(broker)), broker != nil ? Palette.info : Palette.loss)
        Spacer()
        item(L10n.Home.quotes, Text(status.freshness.stream.title), streamColor)
        Spacer()
        let open = status.tradingGate.open
        item(L10n.Home.gate, Text(open ? L10n.Home.gateOpen : L10n.Home.gateShut), open ? Palette.profit : Palette.warning)
        Spacer()
        let allowed = status.entryBlock == nil
        item(L10n.Home.entries, Text(allowed ? L10n.Home.entriesAllowed : L10n.Home.entriesBlocked),
          allowed ? Palette.accent : Palette.warning)
      }
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

  private var streamColor: Color {
    switch status.freshness.stream {
    case .fresh: return Palette.profit
    case .quiet: return Palette.warning
    case .lost: return Palette.loss
    case .off: return Palette.textQuaternary
    }
  }

  private func item(_ name: LocalizedStringResource, _ value: Text, _ color: Color) -> some View {
    VStack(spacing: Tokens.Space.xs) {
      PulseDot(color, pulsing: color != Palette.textQuaternary)
        .shadow(color: color, radius: Self.glowRadius)
      Text(name).font(Tokens.Typography.annotation).foregroundStyle(Palette.textTertiary)
      value.font(Tokens.Typography.annotationBold).foregroundStyle(Palette.textPrimary)
    }
    .accessibilityElement(children: .combine)
  }
}
