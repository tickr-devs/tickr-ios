import SwiftUI
import TickrDesign
import TickrKit

/// Sidebar sections, ordered by how often they are used during a trading day.
enum AppSection: String, CaseIterable, Identifiable {
  case overview, chart, trades, risk, lab

  var id: String { rawValue }

  var title: LocalizedStringResource {
    switch self {
    case .overview: return L10n.Section.overview
    case .chart: return L10n.Section.chart
    case .trades: return L10n.Section.trades
    case .risk: return L10n.Section.risk
    case .lab: return L10n.Section.lab
    }
  }

  /// SF Symbols of the sections in the sidebar.
  static let overviewSymbol = "square.grid.2x2"
  static let chartSymbol = "chart.line.uptrend.xyaxis"
  static let tradesSymbol = "text.alignleft"
  static let riskSymbol = "shield"
  static let labSymbol = "star"
  /// SF Symbol of the sidebar's Settings row.
  static let settingsSymbol = "gearshape"

  /// Accessibility ids of a section's sidebar row and its screen (the UI tests find them by these).
  static let rowIDPrefix = "sidebar-"
  static let screenIDPrefix = "screen-"
  var rowID: String { Self.rowIDPrefix + rawValue }
  var screenID: String { Self.screenIDPrefix + rawValue }

  var symbol: String {
    switch self {
    case .overview: return Self.overviewSymbol
    case .chart: return Self.chartSymbol
    case .trades: return Self.tradesSymbol
    case .risk: return Self.riskSymbol
    case .lab: return Self.labSymbol
    }
  }
}

struct RootView: View {
  @Environment(AppModel.self) private var model

  /// Sidebar width: least, preferred (the design's) and most, in points.
  static let sidebarMin: CGFloat = 200
  static let sidebarIdeal: CGFloat = 212
  static let sidebarMax: CGFloat = 260
  /// Least size of a screen, in points: with the sidebar (200) and the inspector (240) it stays
  /// under the window's least size (TickrMacApp.minWidth, minHeight).
  static let screenMinWidth: CGFloat = 420
  static let screenMinHeight: CGFloat = 400

  /// Width of the screen column and of the title bar's right-hand group, as last laid out: the
  /// title line gets the room between them (see `WindowLine`).
  @State private var detailWidth: CGFloat = 0
  @State private var stepperWidth: CGFloat = 0

  private var section: AppSection { model.section }

  var body: some View {
    @Bindable var model = model
    NavigationSplitView {
      Sidebar(selection: $model.section)
        // The design's title bar has no sidebar button; View > Hide Sidebar (⌃⌘S) still hides it.
        .toolbar(removing: .sidebarToggle)
        .navigationSplitViewColumnWidth(min: Self.sidebarMin, ideal: Self.sidebarIdeal, max: Self.sidebarMax)
    } detail: {
      ZStack(alignment: .bottom) {
        TickrBackground()
        // The strip stacked above the screen rather than a top safe-area inset whose content
        // comes and goes, which made the screen's safe area change during layout.
        VStack(spacing: 0) {
          if section != .overview { EventStrip() }
          detail
            // One container element per screen.
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(section.screenID)
            // A new section replaces the screen at once, as a sidebar does in Apple's apps; the
            // screen's own cards then rise in. Sliding whole screens in and out kept two of them
            // (one maybe the chart) laid out and animating together, and stuttered.
            .id(section)
            // A fixed least size for every screen, its content cut at it: a screen whose least
            // size followed its content (a row of controls wider than the column, a layout
            // that switches with the width) asked for more than the window beside the sidebar
            // and the inspector, the split view shifted it inside its layout pass, and on
            // macOS 27 AppKit threw ("needs another Update Constraints in Window pass").
            .frame(minWidth: Self.screenMinWidth, maxWidth: .infinity, minHeight: Self.screenMinHeight,
              maxHeight: .infinity, alignment: .topLeading)
            .clipped()
        }
        if let unattended = model.unattendedPositions {
          UnattendedBanner(unattended: unattended)
            .padding(Tokens.Space.l)
            .frame(maxHeight: .infinity, alignment: .top)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
        if let toast = model.toast {
          CommandToast(command: toast)
            .padding(.bottom, Tokens.Space.xl)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
      }
      // The title bar's hairline over the screen (the sidebar draws its own).
      .overlay(alignment: .top) { Hairline(axis: .horizontal) }
      .animation(Tokens.Motion.standard, value: model.toast)
      .animation(Tokens.Motion.standard, value: model.unattendedPositions)
      // Hints of the screen, the banner and the toast, drawn above all of them.
      .hintHost()
      // The window keeps the section's name (Window menu, Mission Control); the title bar shows
      // the design's one centred line instead.
      .navigationTitle(Text(section.title))
      .toolbar(removing: .title)
      .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { detailWidth = $0 }
      .toolbar {
        WindowToolbar(lineWidth: WindowLine.width(detail: detailWidth, stepper: stepperWidth)) { stepperWidth = $0 }
      }
      .toolbarBackground(Palette.titleBar, for: .windowToolbar)
      .toolbarBackgroundVisibility(.visible, for: .windowToolbar)
    }
  }

  @ViewBuilder private var detail: some View {
    switch section {
    case .overview: OverviewView()
    case .chart: ChartView()
    case .trades: TradesView()
    case .risk: RiskView()
    case .lab: LabView()
    }
  }
}

/// The sidebar as the design draws it: the "OPERATOR" label, the sections, the Settings row and
/// the bot's state at the bottom, on the sidebar's own fill.
private struct Sidebar: View {
  @Environment(AppModel.self) private var model
  @Binding var selection: AppSection
  /// Whether the section rows have the keyboard focus (the arrow keys then move the selection).
  @FocusState private var rowsFocused: Bool

  /// Space under the "OPERATOR" label, in points.
  static let labelBottom: CGFloat = 10

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      CardLabel(L10n.Common.operatorTitle)
        .padding(.horizontal, Tokens.Space.m)
        .padding(.top, Tokens.Space.xs)
        .padding(.bottom, Self.labelBottom)
      VStack(alignment: .leading, spacing: Tokens.Space.xs) {
        ForEach(AppSection.allCases) { item in
          Button {
            selection = item
            rowsFocused = true
          } label: {
            SidebarRow(title: item.title, symbol: item.symbol, badge: badge(for: item), selected: selection == item)
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier(item.rowID)
          .accessibilityAddTraits(selection == item ? .isSelected : [])
        }
      }
      // ↑ and ↓ move between the sections, as in a sidebar list; a click on a row (or Tab) gives
      // the rows the focus. The selected row's tint already shows where the focus is.
      .focusable()
      .focused($rowsFocused)
      .focusEffectDisabled()
      .onMoveCommand(perform: move)
      SettingsLink {
        SidebarRow(title: L10n.Root.settingsRow, symbol: AppSection.settingsSymbol, badge: nil, selected: false)
      }
      .buttonStyle(.plain)
      Spacer(minLength: 0)
      BotStateCard()
    }
    .padding(.horizontal, Tokens.Space.m)
    .padding(.vertical, Tokens.Space.l)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Palette.sidebar)
    // The design's hairlines: under the title bar and between the sidebar and the screen.
    .overlay(alignment: .top) { Hairline(axis: .horizontal) }
    .overlay(alignment: .trailing) { Hairline(axis: .vertical) }
  }

  /// Selects the section above or below the selected one; the ends stay where they are.
  private func move(_ direction: MoveCommandDirection) {
    let sections = AppSection.allCases
    guard let index = sections.firstIndex(of: selection) else { return }
    switch direction {
    case .up where index > sections.startIndex: selection = sections[sections.index(before: index)]
    case .down where sections.index(after: index) < sections.endIndex: selection = sections[sections.index(after: index)]
    default: break
    }
  }

  /// The Trades row counts the shown day's trades; no other row has a number behind it.
  private func badge(for item: AppSection) -> Int? {
    guard item == .trades, model.shownTradeCount > 0 else { return nil }
    return model.shownTradeCount
  }
}

/// A `separator` line one point thick along the edge it is placed on.
private struct Hairline: View {
  let axis: Axis

  var body: some View {
    Rectangle()
      .fill(Palette.separator)
      .frame(width: axis == .vertical ? Tokens.Stroke.thin : nil, height: axis == .horizontal ? Tokens.Stroke.thin : nil)
      .accessibilityHidden(true)
  }
}

/// One sidebar row: a line icon and the title in the row's colour, a count on the right; the
/// selected row on a soft tint with a hairline.
private struct SidebarRow: View {
  let title: LocalizedStringResource
  let symbol: String
  let badge: Int?
  let selected: Bool

  @State private var hovered = false

  /// Gap between the icon and the title, in points.
  static let iconGap: CGFloat = 10

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
    HStack(spacing: Self.iconGap) {
      Image(systemName: symbol)
        .frame(width: Tokens.Size.rowSymbol)
      Text(title)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
      if let badge {
        Text(verbatim: badge.formatted())
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      }
    }
    .font(Tokens.Typography.body.weight(.medium))
    .foregroundStyle(selected || hovered ? Palette.textPrimary : Palette.textTertiary)
    .padding(.horizontal, Tokens.Space.m)
    .padding(.vertical, Tokens.Space.s)
    .background {
      if selected {
        shape.fill(Palette.selection)
          .overlay(shape.strokeBorder(Palette.separatorStrong, lineWidth: Tokens.Stroke.thin))
      } else if hovered {
        shape.fill(Palette.selection)
      }
    }
    .contentShape(shape)
    .onHover { hovered = $0 }
  }
}

/// Bot state at the foot of the sidebar: a pulsing dot and the state, how long the bot has been
/// up (GET /jobs `bot_started_at`, read again when the run changes) and the run it is in.
private struct BotStateCard: View {
  @Environment(AppModel.self) private var model

  /// Gap between the card's lines, in points.
  static let lineGap: CGFloat = 6
  /// Characters of the run id shown (the whole id is in the tooltip).
  static let runIdShown = 8
  /// Digits of the uptime's hours ("01:42:20").
  static let hourDigits = 2

  var body: some View {
    VStack(alignment: .leading, spacing: Self.lineGap) {
      CardLabel(L10n.Common.bot)
      HStack(spacing: Tokens.Space.s) {
        PulseDot(color, pulsing: model.isLive, event: model.status?.botState)
        Text(verbatim: stateText)
          .font(Tokens.Typography.body.weight(.semibold))
          .foregroundStyle(Palette.textPrimary)
      }
      if let started = startedAt {
        TimelineView(.periodic(from: .now, by: Tokens.Motion.clockTickSeconds)) { context in
          Text(L10n.Root.uptime(uptime(since: started, now: model.botTime(context.date))))
        }
        .font(Tokens.Typography.calloutMono)
        .foregroundStyle(Palette.textQuaternary)
      }
      if let run = model.status?.runId {
        Text(L10n.Root.run(String(run.prefix(Self.runIdShown))))
          .font(Tokens.Typography.calloutMono)
          .foregroundStyle(Palette.textQuaternary)
          .help(Text(verbatim: run))
      }
    }
    .padding(Tokens.Space.m)
    .frame(maxWidth: .infinity, alignment: .leading)
    .tickrCard(radius: Tokens.Radius.large)
    // The start time changes only with a new run: read it once per run.
    .task(id: model.status?.runId) { await model.refreshJobs() }
  }

  /// When the running bot started; nil while it is not running or the time is unknown.
  private var startedAt: Date? {
    guard let response = model.response, let status = response.status, !response.stale,
      status.botState == .running else { return nil }
    return model.jobs?.botStartedAt?.date
  }

  private func uptime(since start: Date, now: Date) -> String {
    let seconds = max(0, Int(now.timeIntervalSince(start)))
    return Duration.seconds(seconds).formatted(.time(pattern: .hourMinuteSecond(padHourToLength: Self.hourDigits)))
  }

  private var stateText: String {
    if model.fetchError != nil { return String(localized: L10n.Root.apiUnreachable) }
    guard let response = model.response else { return String(localized: L10n.Root.connecting) }
    guard let status = response.status else { return String(localized: L10n.Common.unavailable) }
    if response.stale { return String(localized: L10n.Root.stale(status.botState.title)) }
    return status.entryStop ? String(localized: L10n.Root.statePaused(status.botState.title)) : status.botState.title
  }

  private var color: Color {
    guard let response = model.response, let status = response.status, !response.stale,
      model.fetchError == nil else { return Palette.loss }
    switch status.botState {
    case .running: return status.entryStop ? Palette.warning : Palette.profit
    case .starting, .stopping: return Palette.warning
    case .stopped: return Palette.textQuaternary
    }
  }
}

/// The title bar as the design draws it: one centred mono line, and on the right the connection
/// status, the day stepper ‹ day › and Today.
private struct WindowToolbar: ToolbarContent {
  /// Width of the title line (`WindowLine.width`).
  let lineWidth: CGFloat
  /// Called with the right-hand group's width whenever it changes.
  let stepperWidthChanged: (CGFloat) -> Void

  var body: some ToolbarContent {
    ToolbarItem(placement: .navigation) {
      WindowLine(width: lineWidth)
    }
    .sharedBackgroundVisibility(.hidden)
    ToolbarItem(placement: .primaryAction) {
      DayStepper()
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { stepperWidthChanged($0) }
    }
    .sharedBackgroundVisibility(.hidden)
  }
}

/// "tickr — sandbox — price-action-v1 v1 — up to 3 positions", from the status and the settings.
/// The line fills the room between the screen column's leading edge and the right-hand group,
/// centred in it as the design centres it between the window buttons and the controls. A toolbar
/// item is as wide as its view asks, so the width is given outright: a line wider than the room
/// pushed the connection status and the day stepper into the toolbar's overflow menu in a narrow
/// window (the 1000-point least width, the CI runner's 1024-point display); now the line is cut
/// at its end instead.
private struct WindowLine: View {
  @Environment(AppModel.self) private var model
  let width: CGFloat

  /// Least width of the line, in points.
  static let minWidth: CGFloat = 120
  /// The toolbar's own margins and item spacing around the two items, in points.
  static let toolbarInsets: CGFloat = 40

  /// The room the line gets beside the right-hand group in a screen column `detail` wide.
  static func width(detail: CGFloat, stepper: CGFloat) -> CGFloat {
    max(minWidth, detail - stepper - toolbarInsets)
  }

  var body: some View {
    Text(line)
      .font(Tokens.Typography.calloutMono)
      .foregroundStyle(Palette.textQuaternary)
      .lineLimit(1)
      .truncationMode(.tail)
      .frame(width: width)
  }

  private var line: LocalizedStringResource {
    guard let status = model.status else { return L10n.Toolbar.windowLineEmpty }
    let environment = ApiText.environment(status.environment).localizedLowercase
    let strategy = Format.strategy(status.strategy)
    guard let limit = model.settings?.risk.maxOpenPositions else {
      return L10n.Toolbar.windowLine(environment, strategy)
    }
    return L10n.Toolbar.windowLineLimit(environment, strategy, limit)
  }
}

/// The right side of the title bar: the connection status, then ‹ day › with a menu of recorded
/// days, and Today.
private struct DayStepper: View {
  @Environment(AppModel.self) private var model

  /// SF Symbols of the previous and next day buttons.
  static let previousSymbol = "chevron.left"
  static let nextSymbol = "chevron.right"
  /// Gap between the connection status and the stepper, in points (added to the items' gap).
  static let connectionGap: CGFloat = 10
  /// Least width of the day label, in points, so the arrows keep their place from day to day:
  /// holds the longest live-day label in 12-point mono, the Russian "ср, 30 сент. · сегодня"
  /// (22 characters) as well as the English "Wed, Sep 30 · today" (19).
  static let dayMinWidth: CGFloat = 162

  var body: some View {
    HStack(spacing: Tokens.Space.s) {
      ConnectionStatus()
        .padding(.trailing, Self.connectionGap)
      Button { model.showPreviousDay() } label: {
        Label(String(localized: L10n.Toolbar.previousDay), systemImage: Self.previousSymbol)
      }
      .buttonStyle(TitleBarButtonStyle(square: true))
      .disabled(model.previousDay == nil)
      .help(Text(L10n.Toolbar.previousDayHelp))
      Menu {
        Button(String(localized: L10n.Common.today)) { model.showToday() }
        if !model.days.isEmpty { Divider() }
        ForEach(model.days.filter { $0.day != model.today }) { day in
          Button {
            model.selectedDay = day.day
          } label: {
            Text(L10n.Toolbar.dayRow(Format.dayLabel(day.day), Money.signed(day.resultGrossUsd.value), day.trades))
          }
        }
      } label: {
        Group {
          if model.isLive {
            Text(L10n.Toolbar.dayToday(Format.dayLabel(model.today)))
          } else {
            Text(verbatim: Format.dayLabel(model.shownDay))
          }
        }
        .font(Tokens.Typography.calloutMono)
        .foregroundStyle(Palette.textPrimary)
        .frame(minWidth: Self.dayMinWidth)
      }
      .menuStyle(.button)
      .buttonStyle(.plain)
      .menuIndicator(.hidden)
      .fixedSize()
      .help(Text(L10n.Toolbar.pickDayHelp))
      Button { model.showNextDay() } label: {
        Label(String(localized: L10n.Toolbar.nextDay), systemImage: Self.nextSymbol)
      }
      .buttonStyle(TitleBarButtonStyle(square: true))
      .disabled(model.isLive)
      .help(Text(L10n.Toolbar.nextDayHelp))
      Button(String(localized: L10n.Common.today)) { model.showToday() }
        .buttonStyle(TitleBarButtonStyle(square: false))
        .help(Text(L10n.Toolbar.todayHelp))
    }
  }
}

/// The title bar's small bordered buttons (‹ › Today): a sunken fill, a strong hairline and the
/// label in the muted text colour.
private struct TitleBarButtonStyle: ButtonStyle {
  /// An icon-only button of the design's fixed size; otherwise the title with side padding.
  let square: Bool

  @Environment(\.isEnabled) private var isEnabled

  /// Size of an icon-only button, in points.
  static let width: CGFloat = 30
  static let height: CGFloat = 26

  func makeBody(configuration: Configuration) -> some View {
    let shape = RoundedRectangle(cornerRadius: Tokens.Radius.small, style: .continuous)
    configuration.label
      .labelStyle(.iconOnly)
      .font(Tokens.Typography.buttonCompact)
      .foregroundStyle(Palette.textTertiary)
      .padding(.horizontal, square ? 0 : Tokens.Space.s)
      .frame(minWidth: Self.width, minHeight: Self.height)
      .background(shape.fill(Palette.surfaceSunken))
      .overlay(shape.strokeBorder(Palette.separatorStrong, lineWidth: Tokens.Stroke.thin))
      .contentShape(shape)
      .opacity(isEnabled ? 1 : Tokens.Opacity.faint)
      .scaleEffect(configuration.isPressed ? Tokens.Motion.pressScale : 1)
  }
}

/// The bot's address and how old its status is ("127.0.0.1 · 3 s ago"), with a dot in the
/// connection's colour (green while fresh statuses arrive); the tooltip says what the headline says.
struct ConnectionStatus: View {
  @Environment(AppModel.self) private var model

  /// Accessibility id of the item, for the UI tests.
  static let id = "toolbar-connection"
  /// Width of the item, in points: fixed, so the age ticking from "9 s" to "10 s" or to "1 min"
  /// never changes the toolbar's width, which AppKit would answer with a new layout of the whole
  /// window every second. Holds "127.0.0.1 · 59 s ago" in English and "127.0.0.1 · 59 с назад" in
  /// Russian (11-point mono, with the dot), right-aligned so
  /// the text keeps to the stepper; a longer address is shortened in the middle (the whole line
  /// is in the tooltip).
  static let width: CGFloat = 176

  var body: some View {
    TimelineView(.periodic(from: .now, by: Tokens.Motion.clockTickSeconds)) { context in
      HStack(spacing: Tokens.Space.s) {
        // Pulses only while a fresh status keeps arriving; a down or silent bot's dot holds still.
        PulseDot(Self.color(hasStatus: model.status != nil, stale: model.response?.stale, failed: model.fetchError != nil),
          size: Tokens.Size.dotSmall, pulsing: isFresh, event: model.headline.pulse)
        Text(verbatim: text(now: model.botTime(context.date)))
          .font(Tokens.Typography.label)
          .foregroundStyle(Palette.textQuaternary)
          .lineLimit(1)
          .truncationMode(.middle)
      }
      .frame(width: Self.width, alignment: .trailing)
    }
    .help(Text(verbatim: model.headline.text))
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier(Self.id)
  }

  private var isFresh: Bool { model.response?.stale == false && model.fetchError == nil }

  /// The dot sits next to the status's age, so it tells the connection's health, not the
  /// headline's: green for a fresh status, amber for a stale one, red for none or a failed read.
  static func color(hasStatus: Bool, stale: Bool?, failed: Bool) -> Color {
    guard hasStatus, !failed else { return Palette.loss }
    return stale == false ? Palette.profit : Palette.warning
  }

  private func text(now: Date) -> String {
    let host = model.baseURL.host() ?? model.baseURL.absoluteString
    guard let written = model.status?.writtenAt.date else { return host }
    return String(localized: L10n.Toolbar.connection(host, Format.age(since: written, now: now)))
  }
}

/// Open positions with no running bot behind them: shown above every screen for as long as the
/// status says so, since nothing closes these positions at the session's end.
struct UnattendedBanner: View {
  let unattended: Unattended

  /// SF Symbol of the banner.
  static let symbol = "exclamationmark.octagon.fill"

  var body: some View {
    HStack(alignment: .top, spacing: Tokens.Space.m) {
      Image(systemName: Self.symbol)
        .font(Tokens.Typography.symbol)
        .foregroundStyle(Palette.loss)
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        Text(unattended.reason == .stopped ? L10n.Bot.stoppedTitle : L10n.Bot.silentTitle)
          .font(Tokens.Typography.callout.weight(.semibold))
        Text(unattended.reason == .stopped ? L10n.Bot.stoppedOpen(unattended.count) : L10n.Bot.silentOpen(unattended.count))
          .font(Tokens.Typography.caption)
          .foregroundStyle(Palette.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
    .padding(Tokens.Space.m)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Tokens.Radius.medium))
    .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.medium).strokeBorder(Palette.loss.opacity(Tokens.Opacity.border)))
    .accessibilityElement(children: .combine)
  }
}

/// The result of a command the operator sent, shown at the bottom of the window.
struct CommandToast: View {
  let command: SentCommand

  /// Blur of the floating shadow under the toast, in points (its offset is the cards').
  static let shadowRadius: CGFloat = 12

  var body: some View {
    HStack(spacing: Tokens.Space.m) {
      Image(systemName: symbol).foregroundStyle(color)
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        Text(verbatim: headline).font(Tokens.Typography.callout.weight(.semibold))
        if let detail {
          Text(verbatim: detail).font(Tokens.Typography.caption).foregroundStyle(Palette.textTertiary)
        }
      }
    }
    .padding(.horizontal, Tokens.Space.l)
    .padding(.vertical, Tokens.Space.m)
    .background(.regularMaterial, in: Capsule())
    .overlay(Capsule().strokeBorder(color.opacity(Tokens.Opacity.border)))
    .shadow(radius: Self.shadowRadius, y: Tokens.Size.shadowOffset)
  }

  private var headline: String {
    switch command.outcome {
    case nil: return String(localized: L10n.Toast.queued(command.title))
    case .done: return String(localized: L10n.Toast.done(command.title))
    case .refused: return String(localized: L10n.Toast.refused(command.title))
    }
  }

  private var detail: String? {
    if let cause = command.cause { return cause }
    if let warning = command.warning { return String(localized: L10n.Toast.warning(warning)) }
    return command.outcome == nil ? String(localized: L10n.Toast.resultLater) : nil
  }

  /// SF Symbols of a queued, done and refused command.
  static let queuedSymbol = "clock.arrow.circlepath"
  static let doneSymbol = "checkmark.circle.fill"
  static let refusedSymbol = "xmark.octagon.fill"

  private var symbol: String {
    switch command.outcome {
    case nil: return Self.queuedSymbol
    case .done: return Self.doneSymbol
    case .refused: return Self.refusedSymbol
    }
  }

  private var color: Color {
    switch command.outcome {
    case nil: return Palette.infoText
    case .done: return Palette.profitText
    case .refused: return Palette.lossText
    }
  }
}

#if DEBUG
#Preview {
  RootView()
    .environment(PreviewAPI.model())
    .environment(ChartModel())
    .frame(width: PreviewAPI.windowWidth, height: PreviewAPI.windowHeight)
}
#endif
