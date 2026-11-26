#if os(macOS)
import SwiftUI
import TickrDesign
import TickrKit

/// The menu-bar extra: what the bot is doing, today's result, the open positions against their
/// stops, the bot's flow and Pause entries, without opening the main window. It always
/// shows today, even while the main window shows a recorded day. Drawn as the design's solid card:
/// the panel's own surface replaces the window's translucent material, which greyed it out.
struct MenuBarPanel: View {
  /// Width of the panel, in points: the design's 420-point board less its 14-point margins.
  static let width: CGFloat = 392

  /// Entrance order of the panel's parts.
  private enum Order: Int {
    case status = 0, result, positions, flow, controls, footer
  }

  /// SF Symbol of the demo day banner.
  static let demoSymbol = "theatermasks.fill"

  @Environment(AppModel.self) private var model

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      if model.demoDay {
        // Commands below go to the demo day: said above them, as loud as a warning.
        WarningBanner(L10n.MenuBar.demoTitle, detail: L10n.MenuBar.demoDetail, systemImage: Self.demoSymbol)
      }
      StatusBanner().rise(step: Order.status.rawValue)
      TodayResult().rise(step: Order.result.rawValue)
      MenuPositions().rise(step: Order.positions.rawValue)
      FlowDots().rise(step: Order.flow.rawValue)
      // Only Pause entries (Resume while paused), as designed; closing positions and stopping the
      // bot are in the main window, and the line under it says so.
      VStack(alignment: .leading, spacing: Tokens.Space.xs) {
        BotCommandButton(action: model.pauseAction, place: .menuBar, size: .compact)
        Text(L10n.MenuBar.moreInApp)
          .font(Tokens.Typography.caption)
          .foregroundStyle(Palette.textQuaternary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .rise(step: Order.controls.rawValue)
      Rectangle()
        .fill(Palette.separator)
        .frame(height: Tokens.Stroke.thin)
      MenuFooter().rise(step: Order.footer.rawValue)
    }
    .padding(Tokens.Space.l)
    .frame(width: Self.width)
    .foregroundStyle(Palette.textPrimary)
    .background(Palette.surface)
    // The panel's commands ask here, on the panel that lives while it is open.
    .botCommandQuestions(in: .menuBar)
    // Esc closes it, as every transient panel of the system.
    .onExitCommand { Self.close() }
  }

  /// Closes the panel, as the system's menu-bar panels do on any action that takes the person
  /// elsewhere (a window, Settings). Called from the panel's own controls, so its window is the
  /// key one. The bot commands keep it open: their questions and results show on it.
  static func close() {
    NSApplication.shared.keyWindow?.close()
  }
}

/// The headline as on Overview (`HeadlineBanner`, MacMenuBar board): the pill with its detail and,
/// beside it, the session countdown and the gate badge; its dot pulses once per new headline.
private struct StatusBanner: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    let headline = model.headline
    HeadlineBanner(headline.text, detail: headline.detail, tone: headline.tone, alarm: headline.severity == .alarm,
      pulse: AnyHashable(headline.pulse), facts: model.headlineFacts)
  }
}

/// Today's net result over its trades and the room under the daily loss limit, with the day's
/// curve beside them.
private struct TodayResult: View {
  @Environment(AppModel.self) private var model

  /// Size of the day's curve, in points.
  static let curveWidth: CGFloat = 120
  static let curveHeight: CGFloat = 44

  var body: some View {
    HStack(alignment: .bottom, spacing: Tokens.Space.m) {
      VStack(alignment: .leading, spacing: 0) {
        CardLabel(L10n.MenuBar.dayResult)
        if let status = model.status {
          // Counts up from zero each time the panel opens, then on to each new result.
          let result = status.resultTodayUsd.value
          CountingText(NSDecimalNumber(decimal: result).doubleValue) { Money.signedUSD(Decimal($0)) }
            .font(Tokens.Typography.panelFigure)
            .foregroundStyle(Palette.result(result))
            .tracking(Tokens.Typography.panelFigureTracking)
          // Wraps rather than being cut short (Spanish runs longer).
          Text(summary(status))
            .font(Tokens.Typography.subheadlineMono)
            .foregroundStyle(Palette.textQuaternary)
            .fixedSize(horizontal: false, vertical: true)
        } else {
          Text(verbatim: Format.missing)
            .font(Tokens.Typography.panelFigure)
            .foregroundStyle(Palette.textQuaternary)
            .accessibilityLabel(Text(L10n.Overview.dayResultUnavailable))
        }
      }
      Spacer(minLength: 0)
      if let status = model.status {
        DrawnSparkline(values: curve(status), color: Tone.result(status.resultTodayUsd.value).fill)
          .frame(width: Self.curveWidth, height: Self.curveHeight)
      }
    }
  }

  private func summary(_ status: StatusV1) -> LocalizedStringResource {
    let results = status.tradesToday.map(\.resultUsd.value)
    let wins = results.filter { $0 > 0 }.count
    let losses = results.filter { $0 < 0 }.count
    // The room is the bot's own number; without it (or the limit) the line shows trades only.
    guard let limit = model.settings?.risk.maxDailyLossUsd.value, let room = status.dailyRoomUsd?.value else {
      return L10n.MenuBar.trades(results.count, wins, losses)
    }
    return L10n.MenuBar.tradesAndRoom(results.count, wins, losses, Money.usd(room), Money.usd(limit))
  }

  /// The running sum of today's closed trades, from zero.
  private func curve(_ status: StatusV1) -> [Double] {
    var sum: Decimal = 0
    return [0] + status.tradesToday.map { trade in
      sum += trade.resultUsd.value
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
      HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
        SymbolText(position.symbol)
          .font(Tokens.Typography.headingMono.weight(.bold))
          .foregroundStyle(Palette.textPrimary)
        Text(L10n.MenuBar.shares(Format.quantity(position.quantity.value)))
          .font(Tokens.Typography.subheadlineMono.weight(.medium))
          .foregroundStyle(Palette.textQuaternary)
        Spacer()
        if let unrealized = row?.unrealized {
          MoneyText(value: unrealized, font: Tokens.Typography.chipValue)
        } else if let latest = row?.latestUnrealized, let staleHelp {
          // The newest bar is older than current: its result, greyed, never a blank.
          MoneyText(value: latest, font: Tokens.Typography.chipValue, muted: true)
            .hint(staleHelp)
        } else {
          Text(verbatim: Format.missing)
            .font(Tokens.Typography.chipValue)
            .foregroundStyle(Palette.textQuaternary)
        }
      }
      StopTargetBar(progress: progress, muted: row?.isStale ?? false)
      // As designed: shield and stop | entry mark and entry | last; the words are the hints.
      HStack {
        HStack(spacing: Tokens.Space.xs + Tokens.Space.xxs) {
          StopGlyph(state: position.stop.state, symbol: position.symbol, price: position.stop.price)
          if let stop = position.stop.price?.value {
            Text(verbatim: Format.price(stop))
              .hint(L10n.Position.stopLevel(Format.price(stop)))
          }
        }
        Spacer()
        Text(L10n.MenuBar.entry(Format.price(position.entryPrice.value)))
          .hint(L10n.Position.entryLevel(Format.price(position.entryPrice.value)))
        Spacer()
        Text(verbatim: Format.price(row?.price ?? row?.latestClose))
          .hint(row?.live == nil ? L10n.Position.lastBarClose : L10n.Position.bid)
      }
      .font(Tokens.Typography.annotation)
      .foregroundStyle(Palette.textQuaternary)
    }
    .padding(.horizontal, Tokens.Space.m)
    .padding(.vertical, Tokens.Space.s + Tokens.Space.xxs)
    .background(Palette.surfaceSunken, in: .rect(cornerRadius: Tokens.Radius.medium))
    .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.medium)
      .strokeBorder(Palette.separator, lineWidth: Tokens.Stroke.thin))
  }
}

/// A track from the stop up the R scale with a knob at the last price that glides as it moves.
private struct StopTargetBar: View {
  let progress: Double?
  /// The position is as of an older bar: greyed like its figure.
  var muted = false

  /// Diameter of the knob, and of the knob with its 4-point accent ring, in points.
  static let knob: CGFloat = 15
  static let knobWithRing: CGFloat = 23

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
            .background(Circle()
              .fill(Palette.accent.opacity(Tokens.Opacity.faint))
              .frame(width: Self.knobWithRing, height: Self.knobWithRing))
            .offset(x: filled - Self.knob / 2)
        }
      }
      .frame(maxHeight: .infinity)
      .saturation(muted ? 0 : 1)
      .opacity(muted ? Tokens.Opacity.medium : 1)
    }
    .frame(height: Self.knobWithRing)
    .animation(Tokens.Motion.fill, value: progress)
  }
}

/// The stages a setup passes, as glowing dots over one-word names: bright while the bot runs,
/// dim otherwise. They move only when the bot's state changes (one pulse), never on a timer.
private struct FlowDots: View {
  @Environment(AppModel.self) private var model

  private struct Stage: Identifiable {
    let id: Int
    let name: LocalizedStringResource
    let color: Color
  }

  private var stages: [Stage] {
    let stops = model.status.map(Board.positions)?.map(\.stop.state) ?? []
    // The one stage rule of both apps, as on Overview (`StopState.stageTone`).
    let stopColor = StopState.stageTone(open: stops, day: (model.flow?.stops ?? []).map(\.state)).fill
    let items: [(LocalizedStringResource, Color)] = [
      (L10n.MenuBar.flowScreen, Palette.accent),
      (L10n.MenuBar.flowStrategy, Palette.highlight),
      (L10n.MenuBar.flowRisk, Palette.warning),
      (L10n.MenuBar.flowOrder, Palette.info),
      (L10n.MenuBar.flowStop, stopColor),
      (L10n.MenuBar.flowReconcile, Palette.infoText),
    ]
    return items.enumerated().map { Stage(id: $0.offset, name: $0.element.0, color: $0.element.1) }
  }

  private var moving: Bool {
    model.status?.botState == .running && model.fetchError == nil
  }

  var body: some View {
    HStack(alignment: .top, spacing: 0) {
      ForEach(stages) { stage in
        if stage.id > 0 { Spacer(minLength: Tokens.Space.xs) }
        VStack(spacing: Tokens.Space.xs) {
          // Still unless the bot's state changes: the dots show the stages, not activity.
          PulseDot(stage.color, size: Tokens.Size.flowMark, pulsing: moving, event: model.status?.botState)
            .shadow(color: stage.color, radius: Tokens.Size.flowMark / 2)
            .opacity(moving ? 1 : Tokens.Opacity.medium)
          // One short word on one line, as drawn.
          Text(stage.name)
            .font(Tokens.Typography.captionMono)
            .foregroundStyle(Palette.textTertiary)
            .fixedSize()
        }
      }
    }
    .padding(.horizontal, Tokens.Space.xs + Tokens.Space.xxs)
    .padding(.vertical, Tokens.Space.xxs)
  }
}

/// One row as designed: open the window, the environment badge, how fresh the broker read is (a
/// bank symbol and its short age in the read's colour, named in its hint), settings and quit.
/// When the row does not fit (longer Spanish), it splits into two.
private struct MenuFooter: View {
  @Environment(AppModel.self) private var model
  @Environment(\.openWindow) private var openWindow
  @Environment(\.openSettings) private var openSettings

  /// Symbols of the footer's actions and of the broker read.
  static let openSymbol = "macwindow"
  static let quitSymbol = "power"
  static let readSymbol = "building.columns"

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 0) {
        open
        Spacer().frame(width: Tokens.Space.xxs)
        badges
        Spacer(minLength: Tokens.Space.s)
        readAge
          .padding(.trailing, Tokens.Space.s)
        icons
      }
      VStack(alignment: .leading, spacing: Tokens.Space.s) {
        HStack(spacing: Tokens.Space.s) {
          badges
          Spacer(minLength: Tokens.Space.s)
          readAge
        }
        HStack(spacing: Tokens.Space.s) {
          open
          Spacer(minLength: Tokens.Space.s)
          icons
        }
      }
    }
  }

  private var open: some View {
    Button {
      MenuBarPanel.close()
      openWindow(id: WindowID.main)
      NSApplication.shared.activate()
    } label: {
      Label { Text(L10n.App.openApp) } icon: { Image(systemName: Self.openSymbol) }
    }
    .buttonStyle(.action(.primary, size: .medium))
  }

  /// The environment badge (the demo day's own warning stands above the panel's banner).
  private var badges: some View {
    HStack(spacing: Tokens.Space.xs) {
      if let environment = model.status?.environment {
        EnvironmentBadge(ApiText.environment(environment), raw: environment,
          accessibilityLabel: ApiText.environmentLabel(environment))
          .hint(L10n.Settings.environment)
      }
    }
  }

  /// The age of the bot's last broker read, coloured like the Safety card's row.
  private var readAge: some View {
    TimelineView(.periodic(from: .now, by: Tokens.Motion.clockTickSeconds)) { context in
      let read = model.status?.freshness.lastBrokerReadAt?.date
      let now = model.botTime(context.date)
      HStack(spacing: Tokens.Space.xs) {
        Image(systemName: Self.readSymbol)
        Text(verbatim: Self.shortAge(since: read, now: now))
          .contentTransition(.numericText())
      }
      .font(Tokens.Typography.calloutMono)
      .foregroundStyle(BrokerReadAge.color(since: read, now: now, limits: BrokerReadAge.Limits(model.settings)))
      .fixedSize()
      .hint(L10n.Safety.lastBrokerRead)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Text(L10n.Safety.lastBrokerRead))
      .accessibilityValue(Text(verbatim: Format.age(since: read, now: now)))
    }
  }

  /// "3 s", "4 min": the read's age as the design writes it, without "ago".
  static func shortAge(since date: Date?, now: Date) -> String {
    guard let date else { return String(localized: L10n.Format.never) }
    let seconds = max(0, Int(now.timeIntervalSince(date)))
    if seconds < Format.secondsShownUpTo { return Format.seconds(Decimal(seconds)) }
    return String(localized: L10n.MenuBar.ageMinutes(seconds / Format.secondsPerMinute))
  }

  private var icons: some View {
    HStack(spacing: Tokens.Space.xs + Tokens.Space.xxs) {
      // A button rather than `SettingsLink`, which cannot close the panel as it opens Settings.
      Button {
        MenuBarPanel.close()
        openSettings()
        NSApplication.shared.activate()
      } label: {
        Label { Text(L10n.App.settings) } icon: {
          DesignGlyphView(.settings, side: Tokens.Size.menuGlyph, gridStroke: Tokens.Stroke.glyphHeavy)
        }
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

#if DEBUG
#Preview {
  MenuBarPanel()
    .environment(PreviewAPI.model())
}
#endif
#endif
