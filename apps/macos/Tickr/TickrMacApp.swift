import AppKit
import SwiftUI
import TickrDesign
import TickrKit

/// User-default keys of the app (Settings window).
enum Defaults {
  /// Base URL of the bot's local API.
  static let apiBaseURL = "apiBaseURL"
  /// Whether the demo day is shown instead of the bot (Settings › General, `AppModel.demoDay`).
  static let demoDay = "demoDay"
  /// Whether the menu-bar extra is shown.
  static let showMenuBarExtra = "showMenuBarExtra"
  /// Appearance forced for every window, `light` or `dark`; unset or empty follows the system.
  /// Chosen in Settings › General (Appearance · theme); the screen tour sets it as a launch
  /// argument (`-appearance light`), which wins over the stored choice.
  static let appearance = "appearance"
  static let light = "light"
  static let dark = "dark"
}

/// macOS shell: the main window with a sidebar, the standard Settings window (⌘,) and a
/// menu-bar extra. Appearance follows the system (Defaults.appearance can force one for the tour).
/// Started by `Launcher` (AlertCommand.swift), which first handles the bot's notify mode.
@MainActor
struct TickrMacApp: App {
  /// Smallest size of the main window, in points. The width is the narrowest at which no screen
  /// breaks: the sidebar at its widest (the person can drag it there) beside the widest least
  /// screen (`RootView.screenMinWidth`, Trades & days' table). Derived, not set: a set 1000 cut
  /// the trades table at the card's edge.
  static let minWidth: CGFloat = RootView.sidebarMax + RootView.screenMinWidth
  /// Smallest height of the main window, in points.
  static let minHeight: CGFloat = 700
  /// First size of the main window, in points.
  static let defaultWidth: CGFloat = 1440
  static let defaultHeight: CGFloat = 920

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
    LayoutSweep.smallestIfAsked()
    #endif
    // The bot shows its alerts through this app (AlertCommand.swift): ask once, here, where the
    // question can be seen. Not in the UI tests' fixture mode, where nobody could answer.
    var asksForNotifications = AlertPoster.available
    #if DEBUG
    asksForNotifications = asksForNotifications && !PreviewAPI.servesFixtures
    #endif
    if asksForNotifications {
      Task { await AlertPoster().requestPermission() }
    }
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

  static func baseURL() -> URL {
    if let text = UserDefaults.standard.string(forKey: Defaults.apiBaseURL), let url = URL(string: text) {
      return url
    }
    return APIClient.defaultBaseURL
  }

  var body: some Scene {
    Window(String(localized: L10n.App.name), id: WindowID.main) {
      // The window's least size is these numbers and nothing else, so a screen that changes its
      // layout while the window is resized (a ViewThatFits picking another arrangement, a chart's
      // panes) can never move the window's minimum and start AppKit's "Update Constraints in
      // Window" loop. Screens fit themselves into the window instead.
      WindowFrame(minSize: CGSize(width: Self.minWidth, height: Self.minHeight)) {
        RootView()
          .overlay { OpeningOverlay() }
          .environment(model)
          .environment(Container.shared.chartModel())
          .environment(Container.shared.advisorModel())
          // The design's accent for links, selection and controls (as on iOS), not the system blue.
          .tint(Palette.info)
      }
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
        .hintHost()
        .environment(model)
        .tint(Palette.info)
    }

    MenuBarExtra(isInserted: $showMenuBarExtra) {
      MenuBarPanel()
        .hintHost()
        .environment(model)
        .tint(Palette.info)
    } label: {
      Image(systemName: model.headline.severity.menuBarSymbol)
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
        target: model.overviewMarkCentre, flying: { model.openingFlying = true },
        finished: { model.openingPlayed = true })
    }
  }
}

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
