import AppKit
import ApertureKit
import SwiftUI

/// User-default keys of the app (Settings window).
enum Defaults {
    /// Base URL of the bot's local API.
    static let apiBaseURL = "apiBaseURL"
    /// Whether the menu-bar extra is shown.
    static let showMenuBarExtra = "showMenuBarExtra"
}

/// macOS shell: the main window with a sidebar, the standard Settings window (⌘,) and a
/// menu-bar extra. Appearance follows the system; there is no theme switch in the app.
@main
@MainActor
struct ApertureMacApp: App {
    @State private var model: AppModel
    @AppStorage(Defaults.showMenuBarExtra) private var showMenuBarExtra = true

    init() {
        let model = AppModel(baseURL: Self.baseURL())
        model.start()
        _model = State(initialValue: model)
        // Started with `swift run` there is no bundle: still show a Dock icon and the window.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    static func baseURL() -> URL {
        if let text = UserDefaults.standard.string(forKey: Defaults.apiBaseURL), let url = URL(string: text) {
            return url
        }
        return APIClient.defaultBaseURL
    }

    var body: some Scene {
        Window("Aperture", id: WindowID.main) {
            RootView()
                .environment(model)
                .frame(minWidth: 1080, minHeight: 700)
        }
        .defaultSize(width: 1440, height: 920)
        .commands { AppCommands(model: model) }

        Settings {
            SettingsView()
                .environment(model)
        }

        MenuBarExtra(isInserted: $showMenuBarExtra) {
            MenuBarPanel()
                .environment(model)
        } label: {
            Image(systemName: model.headline.severity.menuBarSymbol)
        }
        .menuBarExtraStyle(.window)
    }
}

enum WindowID {
    static let main = "main"
}

/// Menu commands: day navigation (⌘[ ⌘] ⌘T) next to the standard ones.
struct AppCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandMenu("Day") {
            Button("Previous Trading Day") { model.showPreviousDay() }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(model.previousDay == nil)
            Button("Next Trading Day") { model.showNextDay() }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(model.isLive)
            Button("Today") { model.showToday() }
                .keyboardShortcut("t", modifiers: .command)
                .disabled(model.isLive)
        }
    }
}
