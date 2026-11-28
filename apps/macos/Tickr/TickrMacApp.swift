#if os(macOS)
import AppKit
#endif
import SwiftUI
import TickrDesign
import TickrKit

#if os(macOS)
/// macOS shell: the main window with a sidebar, the standard Settings window (⌘,) and a
/// menu-bar extra. Appearance follows the system (Defaults.appearance can force one for the tour).
/// Started by `Launcher` (Launcher.swift).
@MainActor
struct TickrMacApp: App {
  /// Narrowest window at which no screen breaks, in points: the sidebar at its widest (the person
  /// can drag it there) beside the widest least screen (`RootView.screenMinWidth`, Trades & days'
  /// table). Derived, not set: a set 1000 cut the trades table at the card's edge.
  static let screensMinWidth: CGFloat = RootView.sidebarMax + RootView.screenMinWidth

  /// Comfortable least width of the main window, in points: the screens' need or the title bar's
  /// (`TitleBarWidth`), whichever is wider, so neither a card nor the title bar's line is cut. On
  /// a display narrower than this the window's least width is the display's (`WindowFit`).
  static func leastWidth(model: AppModel, chart: ChartModel) -> CGFloat {
    max(screensMinWidth, TitleBarWidth.need(model: model, chart: chart))
  }

  /// Comfortable least height of the main window's content (under the title bar), capped to the
  /// display like the width (`WindowFit`), in points: the event strip
  /// above every screen but the Overview and the tallest least screen (`RootView.screenMinHeight`,
  /// the Chart with every study pane), so no card is cut or scrolls inside.
  static let minHeight: CGFloat = EventStrip.height + RootView.screenMinHeight
  /// First size of the main window, in points.
  static let defaultWidth: CGFloat = 1440
  static let defaultHeight: CGFloat = 920

  /// Receives the push token the system gives this Mac (MacAppDelegate.swift).
  @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var appDelegate
  @State private var model: AppModel
  @AppStorage(Defaults.showMenuBarExtra) private var showMenuBarExtra = true

  init() {
    #if DEBUG
    PreviewAPI.serveFixturesIfAsked()
    #endif
    let model = Container.shared.appModel()
    model.start()
    #if DEBUG
    LayoutSweep.startIfAsked(model: model)
    LayoutSweep.smallestIfAsked(model: model)
    #endif
    // Ask once, here, where the question can be seen, to show the bot's push (APNs). Not in the
    // UI tests' fixture mode, where nobody could answer, nor without an app bundle (`swift run`).
    var asksForNotifications = MacAppDelegate.isBundled
    #if DEBUG
    asksForNotifications = asksForNotifications && !PreviewAPI.servesFixtures
    #endif
    if asksForNotifications { Task { await MacAppDelegate.registerForPushIfAllowed() } }
    _model = State(initialValue: model)
    // Started with `swift run` there is no bundle: still show a Dock icon and the window.
    NSApplication.shared.setActivationPolicy(.regular)
    NSApplication.shared.appearance = Self.appearance(UserDefaults.standard.string(forKey: Defaults.appearance))
  }

  /// The appearance every window takes for a stored choice (Defaults.appearance); nil follows
  /// the system.
  static func appearance(_ choice: String?) -> NSAppearance? {
    switch choice {
    case Defaults.light: NSAppearance(named: .aqua)
    case Defaults.dark: NSAppearance(named: .darkAqua)
    default: nil
    }
  }

  var body: some Scene {
    Window(String(localized: L10n.App.name), id: WindowID.main) {
      MainWindow(model: model, chart: Container.shared.chartModel())
        .withoutScrollIndicators()
    }
    .defaultSize(width: Self.defaultWidth, height: Self.defaultHeight)
    // The design's low title bar (about 40 points) with one line in it.
    .windowToolbarStyle(.unifiedCompact)
    .windowResizability(.contentMinSize)
    .commands {
      // The standard View > Show/Hide Sidebar item (Control-Command-S).
      SidebarCommands()
      AppCommands(model: model)
    }

    Settings {
      SettingsView()
        .withoutScrollIndicators()
        .hintHost()
        .readFailureContext(model)
        .environment(model)
        .tint(Palette.info)
    }

    MenuBarExtra(isInserted: $showMenuBarExtra) {
      MenuBarPanel()
        .withoutScrollIndicators()
        .hintHost()
        .readFailureContext(model)
        .environment(model)
        .tint(Palette.info)
    } label: {
      model.headline.severity.menuBarImage
    }
    .menuBarExtraStyle(.window)
  }
}

/// The standard About panel (app icon, name and version from the bundle) with a one-line
/// description and a link to the source code.
enum AboutPanel {
  /// Where the source code lives.
  static let repository = URL(string: "https://github.com/valentyn-dymaretskyi/Tickr")
  /// Separates the description from the link.
  static let lineBreak = "\n"

  @MainActor
  static func show() {
    let credits = NSMutableAttributedString(string: String(localized: L10n.About.tagline) + lineBreak)
    var link: [NSAttributedString.Key: Any] = [:]
    if let repository { link[.link] = repository }
    credits.append(NSAttributedString(string: String(localized: L10n.About.source), attributes: link))
    let centred = NSMutableParagraphStyle()
    centred.alignment = .center
    let whole = NSRange(location: 0, length: credits.length)
    credits.addAttribute(.paragraphStyle, value: centred, range: whole)
    credits.addAttribute(.font, value: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize), range: whole)
    NSApp.activate()
    NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
  }
}

enum WindowID {
  /// Id of the main window (SwiftUI scene identity).
  static let main = "main"
}

/// Menu commands: day navigation (⌘[ ⌘] ⌘T) next to the standard ones.
struct AppCommands: Commands {
  let model: AppModel

  /// Key of the Today command (⌘T).
  static let todayKey: KeyEquivalent = "t"

  var body: some Commands {
    CommandGroup(replacing: .appInfo) {
      Button(String(localized: L10n.App.about)) { AboutPanel.show() }
    }
    CommandMenu(String(localized: L10n.App.dayMenu)) {
      Button(String(localized: L10n.App.previousTradingDay)) { model.showPreviousDay() }
        .keyboardShortcut("[", modifiers: .command)
        .disabled(model.previousDay == nil)
      Button(String(localized: L10n.App.nextTradingDay)) { model.showNextDay() }
        .keyboardShortcut("]", modifiers: .command)
        .disabled(model.isLive || model.dayLocked)
      Button(String(localized: L10n.Common.today)) { model.showToday() }
        .keyboardShortcut(Self.todayKey, modifiers: .command)
        .disabled(model.isLive || model.dayLocked)
    }
  }
}

/// The launch's opening over the first window. Its own view, so the header mark's moves while the
/// window settles re-render only the opening, never the scene, whose rebuild would cut it short.
private struct OpeningOverlay: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    if !model.openingPlayed {
      BrandOpening(
        target: model.overviewMarkCentre,
        targetHeight: model.showsSignIn ? SignInScreen.markHeight(on: .mac) : Tokens.Size.wordmark,
        flying: { model.openingFlying = true },
        finished: { model.openingPlayed = true })
    }
  }
}

/// The screens once this Mac is signed in with the bot, the sign-in until then (mockup v174,
/// board MacSignIn). A development address and the demo day need no sign-in. The launch's opening
/// lands on the sign-in's mark when there is no sign-in, else on the Overview's.
private struct MacSignInGate: View {
  @Environment(AppModel.self) private var model
  @State private var state = Container.shared.signInState()

  var body: some View {
    Group {
      if !model.showsSignIn {
        RootView()
      } else {
        SignInScreen(device: .mac, ended: state.ended, markShown: model.openingPlayed) { centre in
          model.overviewMarkCentre = centre
        }
      }
    }
    .onChange(of: state.signedIn, initial: true) { _, signedIn in model.use(signedIn: signedIn) }
  }
}

/// The main window's content at its least size or larger.
///
/// The least size comes from data and constants only (`TickrMacApp.leastWidth`, `minHeight`),
/// capped to the room the window's screen leaves it (`WindowFit`, owner decision 2026-11-16), and
/// never from the screens' layout, so a screen that changes its layout while the window is
/// resized (a card arrangement picked by width, a chart's panes) can never move the window's
/// minimum and start AppKit's "Update Constraints in Window" loop. Screens fit themselves into
/// the window instead. The width follows the title bar's line, so it changes only when that
/// line's data does (the strategy, the chart's symbol), never during a resize.
private struct MainWindow: View {
  let model: AppModel
  let chart: ChartModel
  /// The room the window's screen leaves its content (`ScreenRoomReader`); nil until the window
  /// is on a screen.
  @State private var room: CGSize?

  var body: some View {
    let comfortable = CGSize(width: TickrMacApp.leastWidth(model: model, chart: chart), height: TickrMacApp.minHeight)
    WindowFrame(minSize: WindowFit.least(comfortable: comfortable, room: room)) {
      MacSignInGate()
        .background(ScreenRoomReader { if room != $0 { room = $0 } })
        .overlay { OpeningOverlay() }
        .readFailureContext(model)
        .environment(model)
        .environment(chart)
        // The design's accent for links, selection and controls (as on iOS), not the system blue.
        .tint(Palette.info)
    }
  }
}

#endif

/// The main window's content at the window's size, never smaller than `minSize`.
///
/// It answers every size question from those numbers alone and never asks its content. The
/// window's hosting view asks for its least size on every layout pass (each display frame of a
/// scroll or an animation): through a `.frame(minWidth:maxWidth:minHeight:maxHeight:)` that
/// question laid out the whole screen a second time at another size, its scroll view and every
/// text included (Instruments on the installed app, 2026-11-16: 8% of the main thread while
/// scrolling the Overview).
struct WindowFrame: Layout {
  let minSize: CGSize

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    CGSize(
      width: max(proposal.width ?? minSize.width, minSize.width),
      height: max(proposal.height ?? minSize.height, minSize.height))
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    for subview in subviews {
      subview.place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(bounds.size))
    }
  }
}
