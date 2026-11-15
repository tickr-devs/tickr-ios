import SwiftUI
import TickrDesign
import TickrKit

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
      PulseDot(color, event: model.headline.pulse)
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
    // The colour follows the severity, so a severity change animates even under the same words.
    .animation(Tokens.Motion.standard, value: [AnyHashable(model.headline.pulse), AnyHashable(model.headline.severity)])
  }
}

/// Today's net result with its trades, the room under the daily loss limit and the day's curve.
private struct TodayResult: View {
  @Environment(AppModel.self) private var model

  /// Width of the day's curve, in points.
  static let curveWidth: CGFloat = 120

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
      CardLabel(L10n.MenuBar.today)
      HStack(alignment: .bottom, spacing: Tokens.Space.m) {
        if let status = model.status {
          MoneyText(value: status.resultTodayGrossUsd.value, usd: true, font: Tokens.Typography.hero)
          Spacer(minLength: Tokens.Space.s)
          DrawnSparkline(values: curve(status), color: Palette.result(status.resultTodayGrossUsd.value))
            .frame(width: Self.curveWidth, height: Tokens.Size.sparkline)
        } else {
          Text(verbatim: Format.missing)
            .font(Tokens.Typography.hero)
            .foregroundStyle(Palette.textQuaternary)
        }
      }
      if let status = model.status {
        // The full width of the panel, wrapping rather than cut short (Russian runs longer).
        Text(summary(status))
          .font(Tokens.Typography.captionMono)
          .foregroundStyle(Palette.textQuaternary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func summary(_ status: StatusV1) -> LocalizedStringResource {
    let results = status.tradesToday.map(\.resultGrossUsd.value)
    let wins = results.filter { $0 > 0 }.count
    let losses = results.filter { $0 < 0 }.count
    // The room is the bot's own number; without it (or the limit) the line shows trades only.
    guard let limit = model.settings?.risk.maxDailyLossUsd.value, let room = status.dailyRoomUsd?.value else {
      return L10n.MenuBar.trades(results.count, wins, losses)
    }
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
struct MenuPosition: View {
  @Environment(AppModel.self) private var model
  let position: Position
  /// The position with its latest bar; nil until a fresh bar arrives.
  let row: PositionRow?

  /// Right end of the bar, in R: a display scale only, not a target the bot trades to. Its left
  /// end is the stop (−1 R).
  static let scaleEndR: Decimal = 2

  /// Where the last price sits on the bar, 0 at the stop and 1 at `scaleEndR`; as of the newest
  /// bar when that bar is no longer current.
  private var progress: Double? { Self.progress(resultR: row?.resultR ?? row?.latestResultR) }

  /// Tooltip of the figures when the newest bar is not current.
  private var staleHelp: Text? {
    guard let row, row.isStale, let time = row.lastBarAt else { return nil }
    return Text(L10n.Position.staleHelp(Format.marketMinute(time)))
  }

  /// Where a result in R sits on the bar: 0 at the stop, 1 at `scaleEndR`, clamped; nil when the
  /// result is unknown.
  static func progress(resultR r: Decimal?) -> Double? {
    guard let r else { return nil }
    let share = NSDecimalNumber(decimal: (r + 1) / (scaleEndR + 1)).doubleValue
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
        } else if let latest = row?.latestUnrealized, let staleHelp {
          // The newest bar is older than current: its result, greyed, never a blank.
          MoneyText(value: latest, usd: true, font: Tokens.Typography.calloutMono.weight(.bold), muted: true)
            .hint(staleHelp)
        } else {
          Text(verbatim: Format.missing)
            .font(Tokens.Typography.calloutMono)
            .foregroundStyle(Palette.textQuaternary)
        }
      }
      StopTargetBar(progress: progress, muted: row?.isStale ?? false)
      HStack {
        StopBadge(state: position.stop.state, compact: true, price: position.stop.price)
        Spacer()
        Text(L10n.MenuBar.entry(Format.price(position.entryPrice.value)))
        Spacer()
        Text(L10n.MenuBar.last(Format.price(row?.lastBarClose ?? row?.latestClose)))
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
  /// The position is as of an older bar: greyed like its figure.
  var muted = false

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
      .saturation(muted ? 0 : 1)
      .opacity(muted ? Tokens.Opacity.medium : 1)
    }
    .frame(height: Self.knob)
    .animation(Tokens.Motion.fill, value: progress)
  }
}

/// The stages a setup passes, as dots: bright while the bot runs, dim otherwise. They move only
/// when the bot's state changes (one pulse), never on a timer.
private struct FlowDots: View {
  @Environment(AppModel.self) private var model

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
    model.status?.botState == .running && model.fetchError == nil
  }

  /// Lines a stage name may wrap to.
  static let nameLines = 2

  var body: some View {
    HStack(alignment: .top, spacing: Tokens.Space.xs) {
      ForEach(stages) { stage in
        VStack(spacing: Tokens.Space.xs) {
          // Still unless the bot's state changes: the dots show the stages, not activity.
          PulseDot(stage.color, pulsing: moving, event: model.status?.botState)
            .opacity(moving ? 1 : Tokens.Opacity.medium)
          // Every stage in the same size: a long name wraps to a second line instead of shrinking.
          Text(stage.name)
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textTertiary)
            .multilineTextAlignment(.center)
            .lineLimit(FlowDots.nameLines)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .top)
      }
    }
  }
}

/// Environment, how fresh the broker read is, and the window, settings and quit actions.
private struct MenuFooter: View {
  @Environment(AppModel.self) private var model
  @Environment(\.openWindow) private var openWindow

  /// Symbols of the footer's actions.
  static let openSymbol = "macwindow"
  static let settingsSymbol = "gearshape"
  static let quitSymbol = "power"

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      HStack {
        if let environment = model.status?.environment {
          Badge(verbatim: ApiText.environment(environment), color: Palette.accentText)
        }
        Spacer()
        TimelineView(.periodic(from: .now, by: MenuBarPanel.tick)) { context in
          Text(L10n.MenuBar.brokerRead(Format.age(since: model.status?.freshness.lastBrokerReadAt?.date, now: model.botTime(context.date))))
            .font(Tokens.Typography.captionMono)
            .foregroundStyle(Palette.textQuaternary)
            .contentTransition(.numericText())
        }
      }
      HStack(spacing: Tokens.Space.s) {
        Button {
          openWindow(id: WindowID.main)
          NSApplication.shared.activate()
        } label: {
          Label { Text(L10n.App.openApp) } icon: { Image(systemName: Self.openSymbol) }
        }
        .buttonStyle(.action(.primary, size: .compact))
        Spacer()
        SettingsLink {
          Label { Text(L10n.App.settings) } icon: { Image(systemName: Self.settingsSymbol) }
        }
        .buttonStyle(.icon(compact: true))
        .hint(L10n.App.settings)
        Button { NSApplication.shared.terminate(nil) } label: {
          Label { Text(L10n.App.quit) } icon: { Image(systemName: Self.quitSymbol) }
        }
        .buttonStyle(.icon(compact: true))
        .hint(L10n.App.quit)
      }
    }
  }
}

#if DEBUG
#Preview {
  MenuBarPanel()
    .environment(PreviewAPI.model())
}
#endif
