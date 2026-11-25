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

  /// SF Symbols of the Overview's buttons that open the Chart and Trades & days (the sidebar
  /// draws its own `glyph`s).
  static let chartSymbol = "chart.line.uptrend.xyaxis"
  static let tradesSymbol = "text.alignleft"

  /// Accessibility ids of a section's sidebar row and its screen (the UI tests find them by these).
  static let rowIDPrefix = "sidebar-"
  static let screenIDPrefix = "screen-"
  var rowID: String { Self.rowIDPrefix + rawValue }
  var screenID: String { Self.screenIDPrefix + rawValue }

  /// The section's line icon in the sidebar, as the design draws it.
  var glyph: ShellGlyph.Kind {
    switch self {
    case .overview: return .overview
    case .chart: return .chart
    case .trades: return .trades
    case .risk: return .risk
    case .lab: return .lab
    }
  }
}

struct RootView: View {
  @Environment(AppModel.self) private var model
  @Environment(ChartModel.self) private var chart

  /// Sidebar width: least, preferred and most, in points. The design's sidebar is 237 wide: a
  /// 212-point column of rows, 12 points of padding on each side and its hairline.
  static let sidebarMin: CGFloat = 200
  static let sidebarIdeal: CGFloat = 237
  static let sidebarMax: CGFloat = 260
  /// Width of the sidebar as an icon rail in a narrow window (`WindowWidthFit.rail`), in points
  /// (MainNarrow v110, 640-point board: `width:56px`).
  static let railWidth: CGFloat = 56
  /// Least size of a screen, in points. The width is the widest any screen needs at its narrowest,
  /// Trades & days' table with every column whole (`TradesView.leastScreenWidth`); the others,
  /// the Chart with its rail open included, need less. With the sidebar at its widest it makes the
  /// window's least width (TickrMacApp.screensMinWidth), so a screen never asks for more than the window
  /// leaves it.
  static let screenMinWidth: CGFloat = TradesView.leastScreenWidth
  /// The height is the tallest any screen needs at its least: the Chart with every study pane
  /// (`ChartView.leastHeight`). Overview, Trades & days, Risk & account and Strategy lab scroll as
  /// a whole, their card rows at least as tall as their cards, so none of their cards scrolls
  /// inside; the sidebar's rows and bot card need far less (about 360 points).
  static let screenMinHeight: CGFloat = ChartView.leastHeight

  /// Whether the sidebar shows: the title bar's sidebar button and View > Hide Sidebar (⌃⌘S)
  /// switch it.
  @State private var columns = NavigationSplitViewVisibility.all
  /// The window's width as last laid out (nil before the first layout), for its narrow-width fit
  /// (`WindowWidthFit`): what the title bar holds and whether the sidebar is an icon rail.
  @State private var windowWidth: CGFloat?
  /// In a window narrow enough for the icon rail, the sidebar button shows the full sidebar
  /// instead, until it is pressed again.
  @State private var railExpanded = false

  private var section: AppSection { model.section }

  private var fit: WindowWidthFit { WindowWidthFit.make(width: windowWidth, model: model, chart: chart) }

  /// In a window narrow enough for the icon rail, what the sidebar button switches: the full
  /// sidebar in place of the rail.
  private var railToggle: Binding<NavigationSplitViewVisibility> {
    Binding { railExpanded ? .all : .detailOnly } set: { railExpanded = $0 != .detailOnly }
  }

  var body: some View {
    @Bindable var model = model
    let fit = fit
    // The window's own size, whatever the view inside asks for: a view made anew when the rail
    // comes or goes first lays out at a size of its own.
    WindowFrame(minSize: .zero) {
      if fit.rail {
        // No split view in the rail's window: a split view collapses and expands its sidebar by
        // the width itself, which fought the rail for good (UI test at 640 points, 2026-11-17).
        HStack(spacing: 0) {
          if railExpanded {
            Sidebar(selection: $model.section).frame(width: Self.sidebarIdeal)
          } else {
            SidebarRail(selection: $model.section)
          }
          screen
        }
        .modifier(WindowChrome(fit: fit, section: section, sidebarButton: railToggle))
      } else {
        NavigationSplitView(columnVisibility: $columns) {
          Sidebar(selection: $model.section)
            // The design's own sidebar button right after the window buttons replaces the system's.
            .toolbar(removing: .sidebarToggle)
            .toolbar {
              ToolbarItem(placement: .automatic) { SidebarButton(columns: $columns) }
                .sharedBackgroundVisibility(.hidden)
              ToolbarSpacer(.flexible)
            }
            .navigationSplitViewColumnWidth(min: Self.sidebarMin, ideal: Self.sidebarIdeal, max: Self.sidebarMax)
        } detail: {
          screen.modifier(WindowChrome(fit: fit, section: section, sidebarButton: nil))
        }
      }
    }
    // The window's width, for its narrow-width fit; only a crossing of a threshold changes what
    // is drawn, and no fit changes the window's least size. A width under any real window's
    // (`WindowWidthFit.leastMeasured`) is the window's first layout passes.
    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
      if width >= WindowWidthFit.leastMeasured { windowWidth = width }
    }
    // The window's bot command questions (Overview's Safety card), on the view that lives as long
    // as the window: never on the card, which a layout change or a section switch rebuilds.
    .botCommandQuestions(in: .window)
  }

  /// The shown screen under the event strip and the connection banner, with the unattended
  /// banner and the command toast over it.
  private var screen: some View {
    ZStack(alignment: .bottom) {
      TickrBackground()
      // The strip stacked above the screen rather than a top safe-area inset whose content
      // comes and goes, which made the screen's safe area change during layout.
      VStack(spacing: 0) {
        if section != .overview { EventStrip() }
        // The link to the bot, said once above every section: the section keeps its last
        // known data under it.
        ConnectionBanner()
        detail
          // One container element per screen.
          .accessibilityElement(children: .contain)
          .accessibilityIdentifier(section.screenID)
          // A new section replaces the screen at once, as a sidebar does in Apple's apps; the
          // screen's own cards then rise in. Sliding whole screens in and out kept two of them
          // (one maybe the chart) laid out and animating together, and stuttered.
          .id(section)
          // A fixed least size for every screen, scrolled to when the window leaves less (a
          // window capped to a small display, `WindowFit`): a screen whose least size
          // followed its content (a row of controls wider than the column, a layout that
          // switches with the width) asked for more than the window beside the sidebar and
          // the inspector, the split view shifted it inside its layout pass, and on macOS 27
          // AppKit threw ("needs another Update Constraints in Window pass"). The room asks
          // for nothing; the least size is a constant of the section.
          .modifier(ScreenRoomFrame(least: screenLeast))
          .lastKnown(model.connectionState.isLastKnown)
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
    .animation(Tokens.Motion.standard, value: model.connectionState)
    // Hints of the screen, the banner and the toast, drawn above all of them.
    .hintHost()
  }

  /// Least size of the shown screen, in points: Overview stacks its cards down to one column
  /// (`OverviewView.leastSize`); every other screen, the Symbols screen in Overview's place
  /// included, needs the screens' least size (`screenMinWidth`, `screenMinHeight`).
  private var screenLeast: CGSize {
    if section == .overview && model.symbolsTab == nil { return OverviewView.leastSize }
    return CGSize(width: Self.screenMinWidth, height: Self.screenMinHeight)
  }

  @ViewBuilder private var detail: some View {
    switch section {
    case .overview:
      // A funnel stage or the fast movers' "Show all" opens the Symbols screen in its place.
      if model.symbolsTab != nil {
        SymbolsView()
      } else {
        OverviewView()
      }
    case .chart: ChartView()
    case .trades: TradesView()
    case .risk: RiskView()
    case .lab: LabView()
    }
  }
}

/// The sidebar as the design draws it: the "OPERATOR" label, the sections and the bot's state at
/// the bottom, on the sidebar's own fill. Settings opens the standard way (⌘, and the app menu).
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
            SidebarRow(title: item.title, glyph: item.glyph, badge: badge(for: item), selected: selection == item)
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

/// The sidebar as an icon rail in a narrow window (MainNarrow v110, 640-point board): each
/// section's line icon, the selected one on the sidebar's tint, its name in the tooltip and for
/// VoiceOver, and the bot's state as a dot at the bottom. The rows keep the sidebar's
/// accessibility ids, so the UI tests find them in either form.
private struct SidebarRail: View {
  @Environment(AppModel.self) private var model
  @Binding var selection: AppSection

  /// Side of a section's square button, in points: the rail less its padding.
  static let button: CGFloat = RootView.railWidth - Tokens.Space.m * CardArrangement.paddedEdges

  var body: some View {
    VStack(spacing: Tokens.Space.xs) {
      ForEach(AppSection.allCases) { item in
        Button { selection = item } label: {
          ShellIcon(kind: item.glyph, size: Tokens.Size.rowSymbol)
            .foregroundStyle(selection == item ? Palette.textPrimary : Palette.textTertiary)
            .frame(width: Self.button, height: Self.button)
            .background {
              if selection == item {
                let shape = RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
                shape.fill(Palette.selection)
                  .overlay(shape.strokeBorder(Palette.separatorStrong, lineWidth: Tokens.Stroke.thin))
              }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(Text(item.title))
        .accessibilityLabel(Text(item.title))
        .accessibilityIdentifier(item.rowID)
        .accessibilityAddTraits(selection == item ? .isSelected : [])
      }
      Spacer(minLength: 0)
      PulseDot(BotStateCard.color(model), pulsing: model.isLive, event: model.status?.botState)
        .help(Text(verbatim: BotStateCard.stateText(model)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: BotStateCard.stateText(model)))
    }
    .padding(.vertical, Tokens.Space.l)
    .frame(width: RootView.railWidth)
    .frame(maxHeight: .infinity, alignment: .top)
    .background(Palette.sidebar)
    .overlay(alignment: .top) { Hairline(axis: .horizontal) }
    .overlay(alignment: .trailing) { Hairline(axis: .vertical) }
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
  let glyph: ShellGlyph.Kind
  let badge: Int?
  let selected: Bool

  @State private var hovered = false

  /// Gap between the icon and the title, and the row's top and bottom padding, in points.
  static let iconGap: CGFloat = 10
  static let verticalPadding: CGFloat = 9

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
    HStack(spacing: Self.iconGap) {
      ShellIcon(kind: glyph, size: Tokens.Size.rowSymbol)
      Text(title)
        .frame(maxWidth: .infinity, alignment: .leading)
      if let badge {
        Text(verbatim: badge.formatted())
          .font(Tokens.Typography.captionMono)
          .foregroundStyle(Palette.textQuaternary)
      }
    }
    .font(Tokens.Typography.body.weight(.medium))
    .foregroundStyle(selected || hovered ? Palette.textPrimary : Palette.textTertiary)
    .padding(.horizontal, Tokens.Space.m)
    .padding(.vertical, Self.verticalPadding)
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
          Text(L10n.Root.uptime(Self.uptime(since: started, now: model.botTime(context.date))))
        }
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textTertiary)
      }
      // The run's id is a code for the logs, not for reading here (owner, 2026-11-18): it stays
      // on hover only.
    }
    .help(model.status?.runId.map { Text(L10n.Root.run($0)) } ?? Text(verbatim: String()))
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

  /// "15h 54m" in the person's language: hours and minutes, never a clock reading ("15:54:21").
  static func uptime(since start: Date, now: Date) -> String {
    let seconds = max(0, Int(now.timeIntervalSince(start)))
    return Duration.seconds(seconds).formatted(.units(allowed: [.days, .hours, .minutes], width: .narrow))
  }

  private var stateText: String { Self.stateText(model) }
  private var color: Color { Self.color(model) }

  /// The bot's state in words, as the card and the icon rail's dot say it.
  static func stateText(_ model: AppModel) -> String {
    if model.fetchError != nil { return String(localized: L10n.Root.apiUnreachable) }
    guard let response = model.response else { return String(localized: L10n.Root.connecting) }
    guard let status = response.status else { return String(localized: L10n.Common.unavailable) }
    if response.stale { return String(localized: L10n.Root.stale(status.botState.title)) }
    return status.entryStop ? String(localized: L10n.Root.statePaused(status.botState.title)) : status.botState.title
  }

  /// The colour of the bot's state dot.
  static func color(_ model: AppModel) -> Color {
    // No connection says nothing about the bot: a quiet grey, never the red of danger.
    guard model.fetchError == nil else { return Palette.textQuaternary }
    guard let response = model.response, let status = response.status, !response.stale else { return Palette.loss }
    switch status.botState {
    case .running: return status.entryStop ? Palette.warning : Palette.profit
    case .starting, .stopping: return Palette.warning
    case .stopped: return Palette.textQuaternary
    }
  }
}

/// The title bar as the design draws it (the sidebar button right after the window buttons is
/// the sidebar column's item, `SidebarButton`): the mono line at the screen column's leading edge
/// (right after the sidebar, or after the sidebar button while the sidebar is hidden), and at the
/// trailing edge the connection status, the day stepper ‹ day › and Today, a flexible space
/// between them. The window is never narrower than both whole (`TitleBarWidth`), so neither is
/// cut nor moved into the toolbar's overflow menu.
/// The window's title and title bar around the shown screen: the section's name for the Window
/// menu, the design's line and status in the title bar (`WindowToolbar`), and in the rail's window,
/// where no split view holds it, the sidebar button.
private struct WindowChrome: ViewModifier {
  let fit: WindowWidthFit
  let section: AppSection
  let sidebarButton: Binding<NavigationSplitViewVisibility>?

  func body(content: Content) -> some View {
    content
      .environment(\.windowFit, fit)
      // The window keeps the section's name (Window menu, Mission Control); the title bar shows
      // the design's one centred line instead.
      .navigationTitle(Text(section.title))
      .toolbar(removing: .title)
      .toolbar { WindowToolbar(fit: fit.titleBar, sidebarButton: sidebarButton) }
      .toolbarBackground(Palette.titleBar, for: .windowToolbar)
      .toolbarBackgroundVisibility(.visible, for: .windowToolbar)
  }
}

private struct WindowToolbar: ToolbarContent {
  /// What the title bar holds in a window narrower than its comfortable width (`TitleBarFit`).
  let fit: TitleBarFit
  /// The sidebar button, in the rail's window (elsewhere the sidebar column holds it).
  var sidebarButton: Binding<NavigationSplitViewVisibility>?

  var body: some ToolbarContent {
    if let sidebarButton {
      ToolbarItem(placement: .navigation) { SidebarButton(columns: sidebarButton) }
        .sharedBackgroundVisibility(.hidden)
    }
    ToolbarItem(placement: .navigation) {
      WindowLine(code: fit.code)
    }
    .sharedBackgroundVisibility(.hidden)
    ToolbarSpacer(.flexible)
    ToolbarItem(placement: .primaryAction) {
      DayStepper(fit: fit)
    }
    .sharedBackgroundVisibility(.hidden)
  }
}

/// The design's sidebar button: a window outline with the sidebar's edge, in the title bar's
/// small bordered square; hides the sidebar or shows it again. An item of the sidebar column's
/// toolbar, ahead of a flexible space, so it sits right after the window buttons, and stays there
/// while the sidebar is hidden.
struct SidebarButton: View {
  @Binding var columns: NavigationSplitViewVisibility
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Accessibility id of the button, for the UI tests.
  static let id = "toolbar-sidebar"
  /// Size of the glyph, in points: a toolbar glyph's size on macOS (Apple HIG).
  static let glyphSize: CGFloat = 16

  var body: some View {
    let hidden = columns == .detailOnly
    Button {
      // With Reduce Motion the sidebar goes or comes at once (design rule 5).
      withAnimation(reduceMotion ? nil : Tokens.Motion.standard) { columns = hidden ? .all : .detailOnly }
    } label: {
      Label {
        Text(hidden ? L10n.Toolbar.showSidebar : L10n.Toolbar.hideSidebar)
      } icon: {
        ShellIcon(kind: .sidebar, size: Self.glyphSize)
      }
    }
    .buttonStyle(.titleBar(square: true))
    .help(Text(hidden ? L10n.Toolbar.showSidebar : L10n.Toolbar.hideSidebar))
    .accessibilityIdentifier(Self.id)
  }
}

/// The title bar's line for the shown screen, from live data as the design boards word it:
/// Overview "tickr — sandbox — price-action-v1 v1 — up to 3 positions", Chart "tickr — sandbox —
/// chart — ABCD · Day · 1m", Trades & days "… — trades & days — 3 closed", Risk & account
/// "… — risk & account — 10:47:03 ET", Strategy lab "… — strategy lab — price-action-v1 v1".
/// A SwiftUI view in a toolbar item gets its ideal width and does not stretch or cut, so the line
/// is always whole: the window's least width holds the longest of the five sections' lines
/// (`TitleBarWidth`). Nothing here is measured during layout: the line's width was once computed
/// from the screen column's and the group's measured widths, which arrived a layout pass late, so
/// during a window resize the line and the date jumped after the window's edge on every step.
struct WindowLine: View {
  @Environment(AppModel.self) private var model
  @Environment(ChartModel.self) private var chart
  /// The line names the bot's code version; without it in a narrow window (`TitleBarFit.code`).
  var code = true

  var body: some View {
    Group {
      if model.section == .risk, model.status != nil {
        // The market clock ticks with the bot's clock, once a second.
        TimelineView(.periodic(from: .now, by: Tokens.Motion.clockTickSeconds)) { context in
          Text(line(now: model.botTime(context.date)))
        }
      } else {
        Text(line(now: nil))
      }
    }
    .font(Tokens.Typography.calloutMono)
    .foregroundStyle(Palette.textQuaternary)
  }

  private func line(now: Date?) -> LocalizedStringResource {
    Self.line(for: model.section, model: model, chart: chart, now: now, code: code)
  }

  /// The line `section`'s screen shows; `now` is the market clock of Risk & account; `code`
  /// names the bot's code version after the strategy.
  static func line(for section: AppSection, model: AppModel, chart: ChartModel, now: Date?, code: Bool = true)
    -> LocalizedStringResource {
    guard let status = model.status else { return L10n.Toolbar.windowLineEmpty }
    let environment = ApiText.environment(status.environment).localizedLowercase
    let strategy = code ? Format.strategy(status) : Format.strategy(status.strategy)
    let sectionTitle = String(localized: section.title).localizedLowercase
    switch section {
    case .overview:
      guard let limit = model.settings?.risk.maxOpenPositions else {
        return L10n.Toolbar.windowLine(environment, strategy)
      }
      return L10n.Toolbar.windowLineLimit(environment, strategy, limit)
    case .chart:
      guard let shown = chart.shown else { return L10n.Toolbar.windowLineSectionOnly(environment, sectionTitle) }
      let range = String(localized: ChartView.title(shown.range))
      let interval = String(localized: ChartView.title(shown.interval))
      let detail = [shown.symbol, range, interval].joined(separator: Format.itemSeparator)
      return L10n.Toolbar.windowLineSection(environment, sectionTitle, detail)
    case .trades:
      let closed = String(localized: L10n.Toolbar.closedTrades(model.shownTradeCount))
      return L10n.Toolbar.windowLineSection(environment, sectionTitle, closed)
    case .risk:
      guard let now else { return L10n.Toolbar.windowLineSectionOnly(environment, sectionTitle) }
      let clock = String(localized: L10n.Risk.clock(Format.marketTime(now)))
      return L10n.Toolbar.windowLineSection(environment, sectionTitle, clock)
    case .lab:
      return L10n.Toolbar.windowLineSection(environment, sectionTitle, strategy)
    }
  }
}

/// The right side of the title bar: the connection status, then ‹ day › with a menu of recorded
/// days, and Today (`DayControls`). In a window narrower than the title bar's comfortable width
/// the day controls sit in Overview's header instead, and in the narrowest the status is its dot
/// alone (`TitleBarFit`).
struct DayStepper: View {
  /// What the title bar holds (`TitleBarFit`).
  var fit = TitleBarFit.whole

  /// Gap between the connection status and the stepper, in points (added to the items' gap).
  static let connectionGap: CGFloat = 10

  var body: some View {
    HStack(spacing: Tokens.Space.s) {
      ConnectionStatus(compact: !fit.statusText)
        .padding(.trailing, fit.stepper ? Self.connectionGap : 0)
      if fit.stepper { DayControls() }
    }
  }

  /// The group's width, in points, with the day controls at the widest of their three forms
  /// (`DayControls.width`). Used for the window's least width.
  static func width(today: String, demoDay: String) -> CGFloat {
    ConnectionStatus.width + connectionGap + Tokens.Space.s + DayControls.width(today: today, demoDay: demoDay)
  }
}

/// ‹ day › with a menu of recorded days, and Today: in the title bar (`DayStepper`), or in
/// Overview's header in a narrow window.
struct DayControls: View {
  @Environment(AppModel.self) private var model

  /// Least width of the day label, in points, so the arrows keep their place from day to day:
  /// holds the widest live-day label in 11.5-point mono (`Typography.dayStepper`): 22 characters
  /// (157 points), more than the English "Wed Jan 28 · today" (128) and the Spanish
  /// "mié 30 sept · hoy" (at most 20 characters with the abbreviation dots).
  static let dayMinWidth: CGFloat = 158
  /// The stepper's arrows (‹ and ›), and its items `s` apart: ‹, the day, › and Today.
  static let arrowCount = 2
  static let stepperItems = 4

  var body: some View {
    Group {
      // On the demo day there is one day: no arrows, no day menu and no Today that would do
      // nothing (they also pushed the stepper into the toolbar's overflow in a narrow window).
      if model.dayLocked {
        Text(L10n.Toolbar.dayDemo(DayText.day(model.today)))
          .font(Tokens.Typography.dayStepper)
          .foregroundStyle(Palette.textPrimary)
          .fixedSize()
          .help(Text(L10n.Toolbar.demoHelp))
      } else if arrows.visible {
        stepper
      } else {
        // No other recorded day: no arrows, day menu or Today that would do nothing.
        Text(L10n.Toolbar.dayToday(DayText.day(model.today)))
          .font(Tokens.Typography.dayStepper)
          .foregroundStyle(Palette.textPrimary)
          .frame(minWidth: Self.dayMinWidth)
          .fixedSize()
      }
    }
  }

  /// The controls' width, in points, the widest of their three forms: ‹ day › and Today (`today`
  /// its title), the demo day (`demoDay`; its DEMO is the header's environment badge), or the day
  /// alone. The day label and the buttons have fixed widths; the texts are measured in the fonts
  /// they are drawn in (`TitleBarWidth.Fonts`).
  static func width(today: String, demoDay: String) -> CGFloat {
    let stepper = stepperWidth(today: today)
    let demo = TextMeasure.width(demoDay, font: TitleBarWidth.Fonts.day)
    return max(stepper, demo, dayMinWidth)
  }

  /// Width of ‹ day › and Today (`today` its title), in points.
  static func stepperWidth(today: String) -> CGFloat {
    let gap = Tokens.Space.s
    let edges = CardArrangement.paddedEdges
    let todayButton = max(TitleBarButtonStyle.width, TextMeasure.width(today, font: TitleBarWidth.Fonts.button) + gap * edges)
    let arrows = TitleBarButtonStyle.width * CGFloat(arrowCount)
    return arrows + dayMinWidth + todayButton + gap * CGFloat(stepperItems - 1)
  }

  /// Which of ‹ › step somewhere; neither while the day is locked or no other day is recorded.
  private var arrows: DayArrows {
    DayArrows(locked: model.dayLocked, canGoBack: model.previousDay != nil, canGoForward: !model.isLive)
  }

  /// ‹ day menu › and Today.
  @ViewBuilder private var stepper: some View {
    HStack(spacing: Tokens.Space.s) {
      Button { model.showPreviousDay() } label: {
        Label { Text(L10n.Toolbar.previousDay) } icon: { Image(systemName: Symbols.previous) }
      }
      .buttonStyle(.titleBar(square: true))
      .disabled(!arrows.canGoBack)
      .help(Text(L10n.Toolbar.previousDayHelp))
      Menu {
        Button(String(localized: L10n.Common.today)) { model.showToday() }
          .disabled(model.isLive)
        if !model.days.isEmpty { Divider() }
        ForEach(model.days.filter { $0.day != model.today }) { day in
          Button {
            model.selectedDay = day.day
          } label: {
            Text(L10n.Toolbar.dayRow(DayText.day(day.day), Money.signedUSD(day.resultUsd.value), day.trades))
          }
        }
      } label: {
        Group {
          if model.isLive {
            Text(L10n.Toolbar.dayToday(DayText.day(model.today)))
          } else {
            Text(verbatim: DayText.day(model.shownDay))
          }
        }
        .font(Tokens.Typography.dayStepper)
        .foregroundStyle(Palette.textPrimary)
        .frame(minWidth: Self.dayMinWidth)
      }
      .menuStyle(.button)
      .buttonStyle(.plain)
      .menuIndicator(.hidden)
      .fixedSize()
      .help(Text(L10n.Toolbar.pickDayHelp))
      Button { model.showNextDay() } label: {
        Label { Text(L10n.Toolbar.nextDay) } icon: { Image(systemName: Symbols.next) }
      }
      .buttonStyle(.titleBar(square: true))
      .disabled(!arrows.canGoForward)
      .help(Text(L10n.Toolbar.nextDayHelp))
      // Today is where the day already is while it is live: dimmed then, as ⌘T in the menu.
      TodayButton(L10n.Common.today) { model.showToday() }
        .disabled(model.isLive)
        .help(Text(L10n.Toolbar.todayHelp))
    }
  }
}

/// The bot's address and how old its status is ("127.0.0.1 · age 3 s"), with a dot in the
/// connection's colour (green while fresh statuses arrive); the tooltip says what the headline says.
struct ConnectionStatus: View {
  @Environment(AppModel.self) private var model
  /// The dot alone, its text in the tooltip and the accessibility label (the narrowest window,
  /// MainNarrow v110).
  var compact = false

  /// Accessibility id of the item, for the UI tests.
  static let id = "toolbar-connection"
  /// Width of the item, in points: fixed, so the age ticking from "9 s" to "10 s" or to "1 min"
  /// never changes the toolbar's width, which AppKit would answer with a new layout of the whole
  /// window every second. Holds 26 characters of 11-point mono with the dot, more than "127.0.0.1 · age 59
  /// min" in English and "127.0.0.1 · hace 59 min" in Spanish, right-aligned so the text keeps to the
  /// stepper; a longer address is shortened in the middle (the whole line is in the tooltip).
  static let width: CGFloat = 196
  /// Gap between the dot and the text, in points.
  static let dotGap: CGFloat = 6

  var body: some View {
    if compact {
      // The text as of the latest status read: no ticking clock redraws the title bar.
      dot
        .help(Text(verbatim: text(now: model.botTime(.now))))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: text(now: model.botTime(.now))))
        .accessibilityIdentifier(Self.id)
    } else {
      whole
    }
  }

  /// Pulses only while a fresh status keeps arriving; a down or silent bot's dot holds still.
  private var dot: some View {
    PulseDot(Self.color(hasStatus: model.status != nil, stale: model.response?.stale, failed: model.fetchError != nil),
      size: Tokens.Size.dot, pulsing: isFresh, event: model.headline.pulse)
  }

  private var whole: some View {
    TimelineView(.periodic(from: .now, by: Tokens.Motion.clockTickSeconds)) { context in
      HStack(spacing: Self.dotGap) {
        dot
        Text(verbatim: text(now: model.botTime(context.date)))
          .font(Tokens.Typography.subheadlineMono)
          .foregroundStyle(Palette.textQuaternary)
          .multilineTextAlignment(.trailing)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(width: Self.width, alignment: .trailing)
    }
    .help(Text(verbatim: model.headline.text))
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier(Self.id)
  }

  private var isFresh: Bool { model.response?.stale == false && model.fetchError == nil }

  /// The dot sits next to the status's age, so it tells the connection's health, not the
  /// headline's: green for a fresh status, amber for a stale one, quiet grey for a failed read
  /// (the connection banner says why), red for none.
  static func color(hasStatus: Bool, stale: Bool?, failed: Bool) -> Color {
    guard !failed else { return Palette.textQuaternary }
    guard hasStatus else { return Palette.loss }
    return stale == false ? Palette.profit : Palette.warning
  }

  private func text(now: Date) -> String {
    let host = model.baseURL.host() ?? model.baseURL.absoluteString
    guard let written = model.status?.writtenAt.date else { return host }
    let seconds = max(0, Int(now.timeIntervalSince(written)))
    let age = seconds < Format.secondsShownUpTo
      ? L10n.Toolbar.ageSeconds(seconds) : L10n.Toolbar.ageMinutes(seconds / Format.secondsPerMinute)
    return String(localized: L10n.Toolbar.connectionAge(host, String(localized: age)))
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

  /// Accessibility id of the toast, for the UI tests: a sent command always shows it.
  static let id = "command-toast"

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
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier(Self.id)
  }

  private var headline: String {
    if command.unknown { return String(localized: L10n.Toast.unknown(command.title)) }
    switch command.outcome {
    case nil: return String(localized: L10n.Toast.queued(command.title))
    case .done: return String(localized: L10n.Toast.done(command.title))
    case .refused: return String(localized: L10n.Toast.refused(command.title))
    }
  }

  private var detail: String? {
    if command.unknown { return String(localized: L10n.Toast.unknownDetail(command.cause ?? ApiText.missing)) }
    if let cause = command.cause { return cause }
    if let warning = command.warning { return String(localized: L10n.Toast.warning(warning)) }
    return command.outcome == nil ? String(localized: L10n.Toast.resultLater) : nil
  }

  /// SF Symbol of a queued command (a done one draws `Symbols.passed`, a refused one `Symbols.failed`).
  static let queuedSymbol = "clock.arrow.circlepath"

  /// SF Symbol of a send whose answer was lost.
  static let unknownSymbol = "questionmark.circle.fill"

  private var symbol: String {
    if command.unknown { return Self.unknownSymbol }
    switch command.outcome {
    case nil: return Self.queuedSymbol
    case .done: return Symbols.passed
    case .refused: return Symbols.failed
    }
  }

  private var color: Color {
    if command.unknown { return Palette.warningText }
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
