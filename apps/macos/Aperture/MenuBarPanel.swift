import ApertureDesign
import ApertureKit
import SwiftUI

/// The menu-bar extra: what the bot is doing, today's result, the open positions against their
/// stops, the bot's flow and the common controls, without opening the main window. It always
/// shows today, even while the main window shows a recorded day.
struct MenuBarPanel: View {
  /// Width of the panel, in points.
  static let width: CGFloat = 380
  /// Lines the headline may wrap to.
  static let headlineLines = 2
  /// How often the data ages are re-read, in seconds.
  static let tick: TimeInterval = 1

  /// Entrance order of the panel's parts.
  private enum Order: Int {
    case status = 0, result, positions, flow, controls, footer
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      StatusBanner().rise(step: Order.status.rawValue)
      TodayResult().rise(step: Order.result.rawValue)
      MenuPositions().rise(step: Order.positions.rawValue)
      FlowDots().rise(step: Order.flow.rawValue)
      BotControls(compact: true).rise(step: Order.controls.rawValue)
      Divider()
      MenuFooter().rise(step: Order.footer.rawValue)
    }
    .padding(Tokens.Space.l)
    .frame(width: Self.width)
  }
}

/// The headline in its severity colour, with a pulsing dot.
private struct StatusBanner: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    let color = model.headline.severity.color
    HStack(spacing: Tokens.Space.s) {
      PulseDot(color, pulsing: true)
      Text(verbatim: model.headline.text)
        .font(Tokens.Typography.callout.weight(.semibold))
        .foregroundStyle(color)
        .lineLimit(MenuBarPanel.headlineLines)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, Tokens.Space.m)
    .padding(.vertical, Tokens.Space.s)
    .background(color.opacity(Tokens.Opacity.wash), in: .rect(cornerRadius: Tokens.Radius.medium))
    .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.medium).strokeBorder(color.opacity(Tokens.Opacity.border)))
    .animation(Tokens.Motion.standard, value: model.headline)
  }
}

/// Today's net result with its trades, the room under the daily loss limit and the day's curve.
private struct TodayResult: View {
  @Environment(AppModel.self) private var model

  /// Width of the day's curve, in points.
  static let curveWidth: CGFloat = 120

  var body: some View {
    HStack(alignment: .bottom, spacing: Tokens.Space.m) {
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        CardLabel(L10n.MenuBar.today)
        if let status = model.status {
          MoneyText(value: status.resultTodayGrossUsd.value, usd: true, font: Tokens.Typography.hero)
          Text(summary(status))
            .font(Tokens.Typography.captionMono)
            .foregroundStyle(Palette.textQuaternary)
        } else {
          Text(verbatim: Format.missing)
            .font(Tokens.Typography.hero)
            .foregroundStyle(Palette.textQuaternary)
        }
      }
      Spacer(minLength: Tokens.Space.s)
      if let status = model.status {
        DrawnSparkline(values: curve(status), color: Palette.result(status.resultTodayGrossUsd.value))
          .frame(width: Self.curveWidth, height: Tokens.Size.sparkline)
      }
    }
  }

  private func summary(_ status: StatusV1) -> LocalizedStringResource {
    let results = status.tradesToday.map(\.resultGrossUsd.value)
    let wins = results.filter { $0 > 0 }.count
    let losses = results.filter { $0 < 0 }.count
    guard let limit = model.settings?.risk.maxDailyLossUsd.value else {
      return L10n.MenuBar.trades(results.count, wins, losses)
    }
    let room = DailyRoom.left(limit: limit, netResult: status.resultTodayGrossUsd.value)
    return L10n.MenuBar.tradesAndRoom(results.count, wins, losses, Money.plain(room), Money.plain(limit))
  }

  /// The running sum of today's closed trades, from zero.
  private func curve(_ status: StatusV1) -> [Double] {
    var sum: Decimal = 0
    return [0] + status.tradesToday.map { trade in
      sum += trade.resultGrossUsd.value
      return NSDecimalNumber(decimal: sum).doubleValue
    }
  }
}

/// The bot's open positions, each with where its price sits on a scale from the stop up.
private struct MenuPositions: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    if let status = model.status {
      list(Board.positions(status))
    } else {
      Text(L10n.Common.unavailable)
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textQuaternary)
    }
  }

  @ViewBuilder private func list(_ positions: [Position]) -> some View {
    if positions.isEmpty {
      Text(L10n.Menu.noOpenPosition)
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textTertiary)
    } else {
      VStack(spacing: Tokens.Space.s) {
        ForEach(positions, id: \.symbol) { position in
          MenuPosition(position: position, row: model.positions.first { $0.id == position.symbol })
            .transition(.move(edge: .top).combined(with: .opacity))
        }
      }
      .animation(Tokens.Motion.standard, value: positions.map(\.symbol))
    }
  }
}

/// One open position: result so far, a bar from the stop up, stop, entry and last.
private struct MenuPosition: View {
  let position: Position
  /// The position with its latest bar; nil until a fresh bar arrives.
  let row: PositionRow?

  /// Right end of the bar, in R: a display scale only, not a target the bot trades to. Its left
  /// end is the stop (−1 R).
  static let scaleEndR: Decimal = 2

  /// Where the last price sits on the bar, 0 at the stop and 1 at `scaleEndR`.
  private var progress: Double? {
    guard let r = row?.resultR else { return nil }
    let share = NSDecimalNumber(decimal: (r + 1) / (Self.scaleEndR + 1)).doubleValue
    return min(max(share, 0), 1)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.xs) {
        Text(verbatim: position.symbol)
          .font(Tokens.Typography.bodyMono.weight(.bold))
          .foregroundStyle(Palette.textPrimary)
        Text(L10n.MenuBar.shares(Format.quantity(position.quantity.value)))
          .font(Tokens.Typography.captionMono)
          .foregroundStyle(Palette.textQuaternary)
        Spacer()
        if let unrealized = row?.unrealized {
          MoneyText(value: unrealized, usd: true, font: Tokens.Typography.calloutMono.weight(.bold))
        } else {
          Text(verbatim: Format.missing)
            .font(Tokens.Typography.calloutMono)
            .foregroundStyle(Palette.textQuaternary)
        }
      }
      StopTargetBar(progress: progress)
      HStack {
        StopBadge(state: position.stop.state)
        Spacer()
        Text(L10n.MenuBar.entry(Format.price(position.entryPrice.value)))
        Spacer()
        Text(L10n.MenuBar.last(Format.price(row?.lastBarClose)))
      }
      .font(Tokens.Typography.captionMono)
      .foregroundStyle(Palette.textQuaternary)
    }
    .padding(Tokens.Space.m)
    .background(Palette.surfaceSunken, in: .rect(cornerRadius: Tokens.Radius.medium))
    .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.medium).strokeBorder(Palette.separator))
  }
}

/// A track from the stop up the R scale with a knob at the last price that glides as it moves.
private struct StopTargetBar: View {
  let progress: Double?

  /// Diameter of the knob, in points.
  static let knob: CGFloat = 12

  var body: some View {
    GeometryReader { proxy in
      let filled = proxy.size.width * (progress ?? 0)
      ZStack(alignment: .leading) {
        Capsule()
          .fill(Palette.separator)
          .frame(height: Tokens.Size.bar)
        if progress != nil {
          Capsule()
            .fill(LinearGradient(colors: [Palette.loss, Palette.warning, Palette.accent], startPoint: .leading,
              endPoint: .trailing))
            .frame(width: filled, height: Tokens.Size.bar)
          Circle()
            .fill(Palette.textPrimary)
            .frame(width: Self.knob, height: Self.knob)
            .shadow(color: Palette.accent.opacity(Tokens.Opacity.border), radius: Tokens.Space.xs)
            .offset(x: filled - Self.knob / 2)
        }
      }
      .frame(maxHeight: .infinity)
    }
    .frame(height: Self.knob)
    .animation(Tokens.Motion.fill, value: progress)
  }
}

/// The stages a setup passes, as dots that pulse one after another while the bot runs.
private struct FlowDots: View {
  @Environment(AppModel.self) private var model
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Seconds between the pulses of neighbouring dots.
  static let pulseOffset = 0.25

  private struct Stage: Identifiable {
    let id: Int
    let name: LocalizedStringResource
    let color: Color
  }

  private var stages: [Stage] {
    let stops = model.status.map(Board.positions)?.map(\.stop.state) ?? []
    let stopColor: Color
    if stops.isEmpty {
      stopColor = Palette.textQuaternary
    } else {
      stopColor = stops.allSatisfy { $0 == .verified } ? Palette.profit : Palette.loss
    }
    let items: [(LocalizedStringResource, Color)] = [
      (L10n.Flow.screeners, Palette.accent),
      (L10n.Common.strategy, Palette.highlight),
      (L10n.Common.risk, Palette.warning),
      (L10n.Flow.order, Palette.info),
      (L10n.Flow.brokerStop, stopColor),
      (L10n.Flow.reconcile, Palette.info),
    ]
    return items.enumerated().map { Stage(id: $0.offset, name: $0.element.0, color: $0.element.1) }
  }

  private var moving: Bool {
    model.status?.botState == .running && model.fetchError == nil && !reduceMotion
  }

  var body: some View {
    HStack(spacing: Tokens.Space.xs) {
      ForEach(stages) { stage in
        VStack(spacing: Tokens.Space.xs) {
          FlowDot(color: stage.color, delay: Double(stage.id) * Self.pulseOffset, moving: moving)
          Text(stage.name)
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textTertiary)
            .lineLimit(1)
            .minimumScaleFactor(BotControls.titleMinimumScale)
        }
        .frame(maxWidth: .infinity)
      }
    }
  }
}

/// A dot that glows and grows, then settles, over and over while `moving`.
private struct FlowDot: View {
  let color: Color
  let delay: Double
  let moving: Bool
  @State private var lit = false

  var body: some View {
    Circle()
      .fill(color)
      .frame(width: Tokens.Size.dot, height: Tokens.Size.dot)
      .shadow(color: color, radius: lit ? Tokens.Space.s : Tokens.Space.xxs)
      .scaleEffect(lit ? Tokens.Motion.breatheScale : 1)
      .opacity(lit || !moving ? 1 : Tokens.Opacity.medium)
      .onAppear { pulse() }
      .onChange(of: moving) { pulse() }
  }

  private func pulse() {
    guard moving else {
      withAnimation(Tokens.Motion.quick) { lit = false }
      return
    }
    withAnimation(.easeInOut(duration: Tokens.Motion.breatheSeconds / 2).repeatForever().delay(delay)) {
      lit = true
    }
  }
}

/// Environment, how fresh the broker read is, and the window, settings and quit actions.
private struct MenuFooter: View {
  @Environment(AppModel.self) private var model
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      HStack {
        if let environment = model.status?.environment {
          Badge(verbatim: environment, color: Palette.accentText)
        }
        Spacer()
        TimelineView(.periodic(from: .now, by: MenuBarPanel.tick)) { context in
          Text(L10n.MenuBar.brokerRead(Format.age(since: model.status?.freshness.lastBrokerReadAt?.date, now: context.date)))
            .font(Tokens.Typography.captionMono)
            .foregroundStyle(Palette.textQuaternary)
            .contentTransition(.numericText())
        }
      }
      HStack(spacing: Tokens.Space.m) {
        Button {
          openWindow(id: WindowID.main)
          NSApplication.shared.activate()
        } label: {
          Text(L10n.App.openApp)
        }
        SettingsLink { Text(L10n.App.settings) }
        Spacer()
        Button { NSApplication.shared.terminate(nil) } label: { Text(L10n.App.quit) }
      }
      .buttonStyle(.link)
    }
  }
}
