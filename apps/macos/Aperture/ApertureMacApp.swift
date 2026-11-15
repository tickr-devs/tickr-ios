import AppKit
import ApertureDesign
import ApertureKit
import SwiftUI

/// User-default keys of the app (Settings window).
enum Defaults {
  /// Base URL of the bot's local API.
  static let apiBaseURL = "apiBaseURL"
  /// Whether the menu-bar extra is shown.
  static let showMenuBarExtra = "showMenuBarExtra"
  /// Appearance forced for every window, `light` or `dark`; unset follows the system. Not in
  /// Settings: the screen tour sets it as a launch argument (`-appearance light`).
  static let appearance = "appearance"
  static let light = "light"
  static let dark = "dark"
}

/// macOS shell: the main window with a sidebar, the standard Settings window (⌘,) and a
/// menu-bar extra. Appearance follows the system (Defaults.appearance can force one for the tour).
@main
@MainActor
struct ApertureMacApp: App {
  /// Smallest and first size of the main window, in points. The smallest fits a 1024-point-wide
  /// display (the CI runner's, where the UI tests zoom the window to the screen).
  static let minWidth: CGFloat = 1000
  static let minHeight: CGFloat = 700
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
    _model = State(initialValue: model)
    // Started with `swift run` there is no bundle: still show a Dock icon and the window.
    NSApplication.shared.setActivationPolicy(.regular)
    switch UserDefaults.standard.string(forKey: Defaults.appearance) {
    case Defaults.light: NSApplication.shared.appearance = NSAppearance(named: .aqua)
    case Defaults.dark: NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
    default: break
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
      RootView()
        .environment(model)
        // The design's accent for links, selection and controls (as on iOS), not the system blue.
        .tint(Palette.info)
        .frame(minWidth: Self.minWidth, minHeight: Self.minHeight)
    }
    .defaultSize(width: Self.defaultWidth, height: Self.defaultHeight)
    .commands {
      // The standard View > Show/Hide Sidebar item (Control-Command-S).
      SidebarCommands()
      AppCommands(model: model)
    }

    Settings {
      SettingsView()
        .environment(model)
        .tint(Palette.info)
    }

    MenuBarExtra(isInserted: $showMenuBarExtra) {
      MenuBarPanel()
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
  static let repository = URL(string: "https://github.com/valentyn-dymaretskyi/Aperture")
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
        .disabled(model.isLive)
      Button(String(localized: L10n.Common.today)) { model.showToday() }
        .keyboardShortcut(Self.todayKey, modifiers: .command)
        .disabled(model.isLive)
    }
  }
}
