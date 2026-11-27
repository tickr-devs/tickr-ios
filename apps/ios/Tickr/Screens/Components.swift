import SwiftUI
import TickrDesign
import TickrKit

extension Board.Event.Tone {
  var ticker: TickerItem.Tone {
    switch self {
    case .teal: return .teal
    case .green: return .green
    case .blue: return .blue
    case .amber: return .amber
    case .violet: return .violet
    case .red: return .red
    case .muted: return .muted
    }
  }

  /// The tone's fill (dots, bars), from the shared map (`Tone(_:)` in TickrDesign).
  var color: Color { TickrDesign.Tone(self).fill }

  /// The tone as a text colour, readable on `surface` (docs/design-system.md, colour roles).
  var textColor: Color { TickrDesign.Tone(self).text }
}

extension BotState {
  /// The bot's state as a person reads it.
  var title: LocalizedStringResource {
    switch self {
    case .starting: return L10n.BotState.starting
    case .running: return L10n.BotState.running
    case .stopping: return L10n.BotState.stopping
    case .stopped: return L10n.BotState.stopped
    }
  }
}

extension StreamHealth {
  /// The quote stream's health as a person reads it.
  var title: LocalizedStringResource {
    switch self {
    case .fresh: return L10n.Stream.fresh
    case .quiet: return L10n.Stream.quiet
    case .lost: return L10n.Stream.lost
    case .off: return L10n.Stream.off
    }
  }
}

extension StatusV1 {
  /// The bot may open a position now: no entry block, no operator pause, and the trading gate open.
  var entriesAllowed: Bool { entryBlock == nil && !entryStop && tradingGate.open }

  /// Entries are held only by an ordinary state the bot reports without attention (its own trade
  /// open, outside the regular session, after the last entry time, no session today): a calm
  /// "not now", grey, never a warning.
  var entriesCalm: Bool {
    guard let entryBlock, !entryBlock.attention else { return false }
    return !entryStop && tradingGate.open
  }
}

/// Money and time formatting used across screens.
enum Format {
  /// Shown where a value is missing.
  static let missing = ApiText.missing
  /// Between the two times of a trade.
  static let timeRange = "–"
  /// Between a trade's entry and its exit price.
  static let arrow = " → "
  /// Between two facts on one line.
  static let separator = " · "
  /// Between two figures of one tile, such as MAE and MFE.
  static let slash = " / "

  /// "14:06": the shared clock (TickrKit `ClockText`), 24-hour New York time.
  static func time(_ date: Date) -> String { ClockText.minutes(date) }

  /// "14:06:09", the same with seconds.
  static func clock(_ date: Date) -> String { ClockText.seconds(date) }

  static func timeOrDash(_ time: WireTime?) -> String {
    time.map { clock($0.date) } ?? missing
  }

  /// "updated 3 s ago" from the API's age of the status document.
  static func age(_ response: StatusResponseV1?) -> LocalizedStringResource {
    guard let response, let age = response.ageSeconds else { return L10n.Age.none }
    let seconds = NSDecimalNumber(decimal: age.value).intValue
    return response.stale ? L10n.Age.stale(seconds) : L10n.Age.updated(seconds)
  }
}

extension DynamicTypeSize {
  /// Rows of several parts (a symbol, figures, a tag) stack their parts from XXL up, so words and
  /// figures stay whole instead of breaking letter by letter (longer Spanish names need it from XXL).
  var stacksRows: Bool { self >= .xxLarge }
}

/// A row at ordinary text sizes that becomes a leading-aligned column when the text size
/// `stacksRows`; alignment and spacing as an `HStack`'s.
struct RowStack<Content: View>: View {
  @Environment(\.dynamicTypeSize) private var typeSize
  let alignment: VerticalAlignment
  let spacing: CGFloat?
  let content: Content

  init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
    self.alignment = alignment
    self.spacing = spacing
    self.content = content()
  }

  var body: some View {
    let layout = typeSize.stacksRows
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: spacing))
      : AnyLayout(HStackLayout(alignment: alignment, spacing: spacing))
    layout { content }
  }
}

/// Every screen draws on the same background. A tab's own screen (`tab` set) has the design's
/// compact title row at the top of its content, with its actions on the same row, and no navigation
/// bar; a screen pushed onto a tab draws the design's "‹ Home" over the same title row
/// (`PushedHeader`), with no navigation bar either.
struct Screen<Leading: View, Actions: View, Content: View>: View {
  let title: LocalizedStringResource
  let tab: AppTab?
  /// A pushed screen's way back: the name of the screen under it ("‹ Home").
  let back: LocalizedStringResource?
  let leading: Leading
  let actions: Actions
  let content: Content
  @Environment(AppModel.self) private var model
  /// How far the window's controls reach into the screen's top leading corner, in points.
  @State private var windowControls: CGFloat = 0

  init(
    _ title: LocalizedStringResource, tab: AppTab? = nil, back: LocalizedStringResource? = nil,
    @ViewBuilder leading: () -> Leading, @ViewBuilder actions: () -> Actions, @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.tab = tab
    self.back = back
    self.leading = leading()
    self.actions = actions()
    self.content = content()
  }

  var body: some View {
    let scroll = ScrollView {
      VStack(alignment: .leading, spacing: Tokens.Space.m) {
        Group {
          if tab != nil {
            TitleRow(title: title) { leading } actions: { actions }
          } else {
            PushedHeader(title: title, back: back) { leading } actions: { actions }
          }
        }
        // In an iPad window (Stage Manager, a narrow window shows this layout) the window controls
        // sit in the top leading corner: the header starts past them and narrows to fit. Measured
        // on the scroll view, outside the scrolled content, which knows no window corner. On
        // iPhone the corner is empty and nothing moves.
        .padding(.leading, max(windowControls - Tokens.Space.l, 0))
        // The link to the bot, said the same on every screen: a banner over the last known
        // data (drawn dimmer), or an empty state in the card area when nothing was read.
        ConnectionPrompt()
        content.lastKnown(model.connectionState.isLastKnown)
      }
      .padding(.horizontal, Tokens.Space.l)
      .padding(.bottom, Tokens.Space.xl)
    }
    .scrollEdgeHints()
    .scrollContentBackground(.hidden)
    .background(TickrBackground())
    .onGeometryChange(for: CGFloat.self, of: { $0.containerCornerInsets.topLeading.width }, action: { windowControls = $0 })
    if let tab {
      scroll.tabRoot(tab)
    } else {
      scroll.pushedScreen(title)
    }
  }
}

/// A pushed screen's top: the app's own back button ("‹ Home", `BackButton`), then the screen's
/// title row, as on the tabs. The one way every pushed screen draws its way back.
struct PushedHeader<Leading: View, Actions: View>: View {
  let title: LocalizedStringResource
  /// The screen under this one; nil reads "Back".
  let back: LocalizedStringResource?
  var action: DismissAction?
  let leading: Leading
  let actions: Actions

  init(
    title: LocalizedStringResource, back: LocalizedStringResource?, action: DismissAction? = nil,
    @ViewBuilder leading: () -> Leading, @ViewBuilder actions: () -> Actions
  ) {
    self.title = title
    self.back = back
    self.action = action
    self.leading = leading()
    self.actions = actions()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      BackButton(title: back ?? L10n.Common.back, action: action)
      TitleRow(title: title) { leading } actions: { actions }
    }
  }
}

extension PushedHeader {
  /// A pushed header at the top of a form (Settings, Configuration): the header of the form's first
  /// section, whose view is not cut at its edges as a row is, so the back button's shadow shows
  /// whole; in the form's own text case and side margins.
  func formHeaderRow() -> some View {
    textCase(nil)
      .listRowInsets(EdgeInsets())
  }
}

extension PushedHeader where Leading == EmptyView, Actions == EmptyView {
  init(title: LocalizedStringResource, back: LocalizedStringResource?, action: DismissAction? = nil) {
    self.init(title: title, back: back, action: action, leading: { EmptyView() }, actions: { EmptyView() })
  }
}

/// "‹ Home": the way back from a pushed screen, the app's own control rather than the system's, as
/// on the design: the shared glass `BackCapsule` (chevron and name in the label's colour) with the
/// name of the screen under it. Its touch target covers `Size.touchTarget` (Apple HIG). VoiceOver
/// reads "Back, Home"; the edge swipe still goes back (`EdgeSwipeBack`). Every pushed screen draws
/// it through `PushedHeader`.
struct BackButton: View {
  @Environment(\.dismiss) private var dismiss
  let title: LocalizedStringResource
  /// The screen's own dismiss, for a header inside a form, whose rows see another one.
  var action: DismissAction?

  var body: some View {
    Button {
      (action ?? dismiss)()
    } label: {
      BackCapsule(title)
    }
    .buttonStyle(.backCapsule)
    .accessibilityLabel(Text(L10n.Common.back))
    .accessibilityValue(Text(title))
    .accessibilityIdentifier(AccessibilityID.back)
  }
}

/// A header's icon button face, the same on every screen, as on the design (the boards' `.gbtn`):
/// a round glass button, 40 points across, with the glyph (the design's own or a symbol) at the
/// size of the system's bar-button glyphs, both growing with the text size, inside a touch target
/// of at least `Size.touchTarget` (Apple HIG). `glass: false` leaves the glyph bare (the calendar's
/// month arrows, inside a card). Wrap it in a `Button` or a `NavigationLink`.
struct HeaderIcon: View {
  /// What the button shows.
  enum Glyph {
    case design(DesignGlyph)
    case symbol(String)
  }

  /// Diameter of the glass circle at the default text size, in points (the boards' `.gbtn`).
  static let glassSide: CGFloat = 40

  /// The glyph and the glass grow with the text, as the system's own bar buttons do.
  @ScaledMetric(relativeTo: .title3) private var side = Tokens.Size.headerGlyph
  @ScaledMetric(relativeTo: .title3) private var circle = HeaderIcon.glassSide
  let glyph: Glyph
  var glass = true

  init(_ glyph: DesignGlyph) {
    self.glyph = .design(glyph)
  }

  init(symbol: String, glass: Bool = true) {
    self.glyph = .symbol(symbol)
    self.glass = glass
  }

  var body: some View {
    Group {
      switch glyph {
      case .design(let glyph): DesignGlyphView(glyph, side: side)
      case .symbol(let name): Image(systemName: name).font(Tokens.Typography.headerSymbol)
      }
    }
    .frame(width: glass ? circle : nil, height: glass ? circle : nil)
    .background {
      if glass {
        Circle().fill(.clear)
          .glassSurface(in: Circle())
      }
    }
    .frame(minWidth: Tokens.Size.touchTarget, minHeight: Tokens.Size.touchTarget)
    .contentShape(Rectangle())
  }
}

/// The screen's own background over the status bar, so scrolled content never draws under the
/// clock. The app hides the navigation bar on every screen (each draws its own title row), and with
/// it goes the system's scroll edge effect that would cover the status bar: without this, cards,
/// chart tags and candles scrolled up ran under "9:41". The same `TickrBackground` the screen
/// stands on, cut to the top safe area and fading out over `fade` below it, so the seam is not
/// seen. It covers the whole top safe area of the content it modifies: under the Chart tab's
/// symbol bar (`safeAreaBar`) that is the status bar and the bar, so nothing shows through the
/// bar's glass either. Draws only; touches go to the content.
struct StatusBarBackdrop: ViewModifier {
  /// Height of the fade under the covered strip, in points.
  static let fade = Tokens.Space.s

  func body(content: Content) -> some View {
    content.overlay {
      GeometryReader { proxy in
        TickrBackground()
          .mask {
            VStack(spacing: 0) {
              Rectangle().frame(height: proxy.safeAreaInsets.top)
              LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: Self.fade)
              Spacer(minLength: 0)
            }
            .ignoresSafeArea()
          }
      }
      .allowsHitTesting(false)
      .accessibilityHidden(true)
    }
  }
}

extension View {
  /// A pushed screen draws its own top (`PushedHeader`): no navigation bar and no tab bar; the
  /// title stays the screen's name for VoiceOver and the app switcher.
  func pushedScreen(_ title: LocalizedStringResource) -> some View {
    modifier(StatusBarBackdrop())
      .toolbarVisibility(.hidden, for: .navigationBar)
      .navigationTitle(Text(title))
      .background { EdgeSwipeBack() }
  }
}

extension Screen where Leading == EmptyView {
  init(
    _ title: LocalizedStringResource, tab: AppTab? = nil, back: LocalizedStringResource? = nil,
    @ViewBuilder actions: () -> Actions, @ViewBuilder content: () -> Content
  ) {
    self.init(title, tab: tab, back: back, leading: { EmptyView() }, actions: actions, content: content)
  }
}

extension Screen where Leading == EmptyView, Actions == EmptyView {
  init(
    _ title: LocalizedStringResource, tab: AppTab? = nil, back: LocalizedStringResource? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.init(title, tab: tab, back: back, leading: { EmptyView() }, actions: { EmptyView() }, content: content)
  }
}

/// A tab screen's title row as on the design: the title in `Typography.title`, the screen's
/// actions as plain icons at the end of the same row. At large text sizes the actions take the line
/// under the title, which shrinks to fit its one line.
struct TitleRow<Leading: View, Actions: View>: View {
  @Environment(\.dynamicTypeSize) private var typeSize
  let title: LocalizedStringResource
  let leading: Leading
  let actions: Actions

  init(title: LocalizedStringResource, @ViewBuilder leading: () -> Leading, @ViewBuilder actions: () -> Actions) {
    self.title = title
    self.leading = leading()
    self.actions = actions()
  }

  var body: some View {
    let stacked = typeSize.stacksRows
    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      HStack(spacing: Tokens.Space.s) {
        leading
        // One line when it fits; otherwise it wraps (at large text sizes), never cut with "…".
        ViewThatFits(in: .horizontal) {
          Text(title).fixedSize()
          Text(title).fixedSize(horizontal: false, vertical: true)
        }
        .font(Tokens.Typography.title)
        .foregroundStyle(Palette.textPrimary)
        .accessibilityAddTraits(.isHeader)
        Spacer(minLength: Tokens.Space.s)
        if !stacked { actionRow }
      }
      if stacked { actionRow }
    }
    .padding(.top, Tokens.Space.s)
  }

  /// The actions' touch targets (`HeaderIcon`) carry their own room, so they sit close; a glyph
  /// without its own colour takes `infoText`, the apps' link colour.
  private var actionRow: some View {
    HStack(spacing: Tokens.Space.xs) { actions }
      .buttonStyle(.glyph)
      .foregroundStyle(Palette.infoText)
  }
}

extension View {
  /// A tab's own screen: no navigation bar (the screen draws its title row), the tab's name as the
  /// title a pushed screen's back button shows ("‹ Home"), and the design's tab bar under it. Pushed
  /// screens have no tab bar, as on the design's Settings.
  func tabRoot(_ tab: AppTab) -> some View {
    modifier(StatusBarBackdrop())
      .toolbarVisibility(.hidden, for: .navigationBar)
      .navigationTitle(Text(tab.title))
      .safeAreaInset(edge: .bottom, spacing: 0) { TickrTabBar() }
      // The bar sits lower than the space it reserves (it reaches into the home indicator's
      // strip): a gap more, so the last card ends clear of the bar instead of under its edge.
      .contentMargins(.bottom, Tokens.Space.l, for: .scrollContent)
  }
}

extension AppTab {
  /// All tabs, in the order of the tab bar.
  static var ordered: [AppTab] { [.home, .positions, .chart, .activity, .lab] }

  /// The tab's name in the tab bar.
  var title: LocalizedStringResource {
    switch self {
    case .home: return L10n.App.home
    case .positions: return L10n.App.positions
    case .chart: return L10n.App.chart
    case .activity: return L10n.App.activity
    case .lab: return L10n.App.lab
    }
  }

  /// The tab's outline glyph, the design's own drawing.
  var glyph: DesignGlyph {
    switch self {
    case .home: return .home
    case .positions: return .positions
    case .chart: return .chart
    case .activity: return .activity
    case .lab: return .lab
    }
  }

  /// The tab button's accessibility identifier (`AccessibilityID`).
  var identifier: String {
    switch self {
    case .home: return AccessibilityID.tabHome
    case .positions: return AccessibilityID.tabPositions
    case .chart: return AccessibilityID.tabChart
    case .activity: return AccessibilityID.tabActivity
    case .lab: return AccessibilityID.tabLab
    }
  }
}

/// The phone's bottom safe-area inset (the home indicator's strip), read once at the root: the tab
/// bar floats at the design's distance from the screen's edge rather than from the safe area.
extension EnvironmentValues {
  @Entry var screenBottomInset: CGFloat = 0
}

/// The design's tab bar: a floating capsule on a blurred surface with a hairline and a soft shadow;
/// each tab an outline symbol over its name, the selected one in `textPrimary` on a quiet grey pill
/// that spans the tab's width, stays inside the bar and slides to the tab chosen next.
struct TickrTabBar: View {
  /// Height of the capsule, its distance from the screen's sides and bottom edge, in points.
  static let height: CGFloat = 58
  static let sideInset: CGFloat = 20
  static let bottomGap: CGFloat = 22
  /// Largest text size of the tab names.
  static let largestText = DynamicTypeSize.xLarge
  /// Least width of one tab, in points.
  static let tabWidth: CGFloat = 56
  /// The selected tab's pill: a share of `textPrimary`, a neutral grey in light and dark.
  static let selectedWash = 0.08
  /// The pill's identity in `pill`.
  static let pillID = "selected"
  /// At a compact height (an iPhone in landscape, IOS2Landscape board): the capsule's height and
  /// width, its distance from the screen's bottom edge, in points; each glyph beside its name.
  static let compactHeight: CGFloat = 46
  static let compactWidth: CGFloat = 440
  static let compactBottomGap: CGFloat = 4

  @Environment(AppModel.self) private var model
  @Environment(\.screenBottomInset) private var bottomInset
  @Environment(\.verticalSizeClass) private var verticalSizeClass
  /// The pill's one identity across the tabs, so a switch slides it instead of fading.
  @Namespace private var pill

  /// An iPhone in landscape: a shorter capsule in the middle, each glyph beside its name.
  private var compact: Bool { verticalSizeClass == .compact }

  var body: some View {
    HStack(spacing: 0) {
      ForEach(AppTab.ordered, id: \.self) { tab in
        button(tab).frame(maxWidth: .infinity)
      }
    }
    // The bar is as tall as its tallest tab, never taller: each tab's pill fills that height
    // (`maxHeight: .infinity` below), but the bar takes its own height, not the height
    // `safeAreaInset` offers. Without this the bar grew to the whole screen at large text sizes,
    // and the screen above it went wide, pushing the first tab off the left edge (layout sweep).
    .fixedSize(horizontal: false, vertical: true)
    // Only the bar animates a switch (the pill springs across, overshooting a little as the
    // system's does); the screens change at once.
    .animation(Tokens.Motion.pill, value: model.selectedTab)
    // The pill keeps this margin from the bar's edge on every side.
    .padding(Tokens.Space.xxs)
    .frame(minHeight: compact ? Self.compactHeight : Self.height)
    // In landscape a capsule in the middle, as on the board; a name that needs more than its
    // tab's width wraps to a second line beside its glyph, never cut.
    .frame(maxWidth: compact ? Self.compactWidth : .infinity)
    // The system's Liquid Glass, as the system tab bar: it bends and lights the screen under it.
    .glassEffect(.regular, in: Capsule())
    .padding(.horizontal, Self.sideInset)
    // From the screen's bottom edge, not from the top of the home indicator's strip.
    .padding(.bottom, (compact ? Self.compactBottomGap : Self.bottomGap) - bottomInset)
    // As the system tab bar: its names keep the tab label's fixed size (`Typography.tabLabel`),
    // and a long press shows a tab's name in the large-content viewer at accessibility sizes.
    .dynamicTypeSize(...Self.largestText)
    .accessibilityElement(children: .contain)
    .accessibilityAddTraits(.isTabBar)
  }

  private func button(_ tab: AppTab) -> some View {
    let selected = model.selectedTab == tab
    return Button {
      model.selectedTab = tab
    } label: {
      let layout = compact ? AnyLayout(HStackLayout(spacing: Tokens.Space.xs))
        : AnyLayout(VStackLayout(spacing: Tokens.Space.xs))
      layout {
        DesignGlyphView(tab.glyph, side: Tokens.Size.tabGlyph)
        Text(tab.title)
          .font(Tokens.Typography.tabLabel)
      }
      .foregroundStyle(selected ? Palette.textPrimary : Palette.textSecondary)
      .padding(.vertical, Tokens.Space.xs)
      // The name gets the tab's whole width (no side padding inside it), so the longest name
      // ("Posiciones" in Spanish) stays on one line; the pill spans the tab, at least `tabWidth` wide,
      // and the bar's own padding keeps it inside the bar.
      .frame(minWidth: Self.tabWidth, maxWidth: .infinity, maxHeight: .infinity)
      .background {
        if selected {
          Capsule().fill(Palette.textPrimary.opacity(Self.selectedWash))
            .matchedGeometryEffect(id: Self.pillID, in: pill)
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityShowsLargeContentViewer {
      Label { Text(tab.title) } icon: { DesignGlyphView(tab.glyph, side: Tokens.Size.tabGlyph) }
    }
    .accessibilityAddTraits(selected ? [.isSelected] : [])
    .accessibilityIdentifier(tab.identifier)
  }
}

/// What every screen says about the link to the bot (TickrKit `ConnectionState`), at the top of
/// its content (`Screen`, the Chart tab): the mockup's calm banner over the last known data when a
/// read fails, an empty state in the card area when there is no data yet, nothing while the link
/// is fine. The technical cause (address, port, the API's own words) is behind "Details"; commands
/// stay off while it shows (`canCommand`), and its line says so.
struct ConnectionPrompt: View {
  @Environment(AppModel.self) private var model
  /// A Retry is on its way: the button waits for it.
  @State private var retrying = false

  var body: some View {
    let state = model.connectionState
    if let message = model.connectionMessage {
      // A lost link is a banner over the cards (drawn as quiet outlines when nothing was read,
      // mockup "no connection" v2); only a bot not set up or silent fills the card area.
      ConnectionNotice(state.hasNoData && !state.isNeverConnected ? .empty : .banner,
        title: message.title, subtitle: message.subtitle,
        detailsLabel: ConnectionMessage.detailsLabel, details: details(message)) {
        // A refused address is fixed in Settings; reading it again never helps.
        if state != .notConfigured && !message.refused {
          Button {
            Task {
              retrying = true
              await model.refreshAll()
              retrying = false
            }
          } label: { Text(ConnectionMessage.retry) }
            .buttonStyle(.action(.secondary, size: .compact))
            .disabled(retrying)
        }
        NavigationLink { SettingsView() } label: { Text(ConnectionMessage.settings) }
          .buttonStyle(.action(state == .notConfigured || message.refused ? .primary : .ghost, size: .compact))
      }
      .rise()
    }
  }

  /// The technical lines under "Details": the address read from, then the failure as the API
  /// client describes it.
  private func details(_ message: ConnectionMessage) -> [String] {
    guard let detail = message.details else { return [] }
    let address = model.connection.url.map { String(localized: ConnectionMessage.address($0.absoluteString)) }
    return [address, detail].compactMap(\.self)
  }
}

/// The command notice floating at the top of the screen, with haptics. A success or an info leaves
/// by itself after a few seconds; a failure stays until it is dismissed. A swipe up dismisses it,
/// following the finger (and resisting a pull down); a touch holds it while the finger is on it; a
/// tap dismisses it too.
struct NoticeOverlay: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  /// Seconds a success or an info stays on screen once nobody touches it.
  static let seconds = 4.0
  /// Points of upward travel that dismiss the notice when the finger lifts.
  static let dismissDistance: CGFloat = 24
  /// Upward speed, in points per second, that dismisses it even after a short swipe (a flick).
  static let dismissVelocity: CGFloat = 300
  /// Points a pull down can stretch the notice at most (rubber band).
  static let stretchLimit: CGFloat = 40
  /// Points a touch may move and still count as a tap.
  static let tapSlop: CGFloat = 4

  @Environment(AppModel.self) private var model
  /// Vertical offset of the notice while the finger drags it.
  @State private var offset: CGFloat = 0
  /// Whether a finger is on the notice (its timer waits meanwhile).
  @State private var touching = false

  func body(content: Content) -> some View {
    content
      .overlay(alignment: .top) {
        if let notice = model.notice {
          Text(verbatim: notice.text)
            .font(Tokens.Typography.subheadlineStrong)
            .foregroundStyle(color(notice.tone))
            .multilineTextAlignment(.center)
            .padding(.horizontal, Tokens.Space.l)
            .padding(.vertical, Tokens.Space.m)
            .glassEffect(.regular, in: Capsule())
            .padding(.horizontal, Tokens.Space.xl)
            .padding(.top, Tokens.Space.s)
            .offset(y: offset)
            .gesture(drag)
            .transition(.moving(from: .top, reduceMotion: reduceMotion))
            .id(notice.id)
            .task(id: touching) {
              guard notice.tone != .failure, !touching else { return }
              try? await Task.sleep(for: .seconds(Self.seconds))
              if !Task.isCancelled, model.notice?.id == notice.id { model.notice = nil }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { model.notice = nil }
            .accessibilityIdentifier(AccessibilityID.notice)
        }
      }
      .animation(Tokens.Motion.standard, value: model.notice)
      .sensoryFeedback(trigger: model.notice) { _, new in
        switch new?.tone {
        case .success: return .success
        case .failure: return .error
        case .info: return .impact(weight: .light)
        case nil: return nil
        }
      }
  }

  /// Follows the finger 1:1 upward and stretches less and less downward; on release a far enough
  /// or fast enough swipe up (or a tap) dismisses, anything else springs back.
  private var drag: some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { value in
        touching = true
        let dy = value.translation.height
        offset = dy < 0 ? dy : Self.stretchLimit * dy / (dy + Self.stretchLimit)
      }
      .onEnded { value in
        touching = false
        let dy = value.translation.height
        let tapped = abs(dy) < Self.tapSlop && abs(value.translation.width) < Self.tapSlop
        if tapped || dy < -Self.dismissDistance || value.velocity.height < -Self.dismissVelocity {
          model.notice = nil
          offset = 0
        } else {
          withAnimation(Tokens.Motion.quick) { offset = 0 }
        }
      }
  }

  private func color(_ tone: Notice.Tone) -> Color {
    switch tone {
    case .info: return Palette.infoText
    case .success: return Palette.profitText
    case .failure: return Palette.lossText
    }
  }
}

/// A settings row's leading icon, as iOS settings draw them: a white symbol on a small solid tile
/// in the row's tone. Decorative: the row's own label carries the meaning.
struct SettingsIcon: View {
  let systemImage: String
  let tone: Tone

  init(_ systemImage: String, tone: Tone) {
    self.systemImage = systemImage
    self.tone = tone
  }

  var body: some View {
    Image(systemName: systemImage)
      .font(Tokens.Typography.caption.weight(.semibold))
      .foregroundStyle(Palette.sheen)
      .frame(width: Tokens.Size.iconButtonCompact, height: Tokens.Size.iconButtonCompact)
      .background(tone.fill, in: RoundedRectangle(cornerRadius: Tokens.Radius.small, style: .continuous))
      .accessibilityHidden(true)
  }
}

/// A settings section as the design's card: the section's label inside the card with its glowing
/// tick (and an accessory at the end, such as a state pill), the rows, and its note last. With a
/// `cardRise` step the whole card (rows and background) rises in as the screen's `step`-th block.
struct SettingsCard<Accessory: View, Content: View>: View {
  @Environment(\.cardRiseStep) private var step
  let title: LocalizedStringResource
  var note: LocalizedStringResource?
  let accessory: Accessory
  let content: Content

  init(
    _ title: LocalizedStringResource, note: LocalizedStringResource? = nil,
    @ViewBuilder accessory: () -> Accessory, @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.note = note
    self.accessory = accessory()
    self.content = content()
  }

  var body: some View {
    Section {
      Group {
        SectionHeader(title) { accessory }
        content
        if let note {
          InfoCaption(note)
        }
      }
      .modifier(RiseStep(step: step))
    }
    .listRowBackground(Palette.surface.modifier(RiseStep(step: step)))
  }
}

extension EnvironmentValues {
  /// Which block of its screen a `SettingsCard` rises in as (`rise(step:)`); nil stays still.
  @Entry var cardRiseStep: Int?
}

extension View {
  /// Makes the `SettingsCard` inside rise in as the screen's `step`-th block, rows and background
  /// together (a form's rows are separate views, so each row and its background rise alike).
  func cardRise(step: Int) -> some View { environment(\.cardRiseStep, step) }
}

/// `rise(step:)` when there is a step; still otherwise.
private struct RiseStep: ViewModifier {
  let step: Int?

  func body(content: Content) -> some View {
    if let step { content.rise(step: step) } else { content }
  }
}

extension SettingsCard where Accessory == EmptyView {
  init(_ title: LocalizedStringResource, note: LocalizedStringResource? = nil, @ViewBuilder content: () -> Content) {
    self.init(title, note: note, accessory: { EmptyView() }, content: content)
  }
}

/// A form row with a `SettingsIcon` in front of its label, an optional line under the label, and
/// any value view after it.
struct SettingsRow<Value: View, Subtitle: View>: View {
  let label: Text
  let systemImage: String
  let tone: Tone
  let value: Value
  let subtitle: Subtitle

  init(
    _ label: LocalizedStringResource, systemImage: String, tone: Tone, @ViewBuilder value: () -> Value,
    @ViewBuilder subtitle: () -> Subtitle
  ) {
    self.init(Text(label), systemImage: systemImage, tone: tone, value: value, subtitle: subtitle)
  }

  /// A row whose label is already localized (a state written in sentence case).
  init(
    _ label: Text, systemImage: String, tone: Tone, @ViewBuilder value: () -> Value,
    @ViewBuilder subtitle: () -> Subtitle
  ) {
    self.label = label
    self.systemImage = systemImage
    self.tone = tone
    self.value = value()
    self.subtitle = subtitle()
  }

  var body: some View {
    LabeledContent {
      value
    } label: {
      Label {
        VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
          label
          subtitle
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textQuaternary)
        }
      } icon: {
        SettingsIcon(systemImage, tone: tone)
      }
    }
  }
}

extension SettingsRow where Subtitle == EmptyView {
  init(_ label: LocalizedStringResource, systemImage: String, tone: Tone, @ViewBuilder value: () -> Value) {
    self.init(label, systemImage: systemImage, tone: tone, value: value) { EmptyView() }
  }
}

extension View {
  /// Sets what every `ReadFailureNote` below says: while the link to the bot is down, cards wait
  /// calmly and leave the failure to the connection banner.
  func readFailureContext(_ model: AppModel) -> some View {
    environment(\.readFailureContext, ReadFailureContext(
      connectionDown: model.connectionState.failure != nil,
      noData: model.connectionState.isNeverConnected,
      detailsLabel: ConnectionMessage.detailsLabel, waiting: ConnectionMessage.waiting))
  }
}
