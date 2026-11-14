import AppKit
import ApertureKit
import ApertureUI
import SwiftUI

/// macOS shell: a menu-bar item that is always visible plus a status window.
/// The API address comes from the `apiBaseURL` user default (see apps/macos/README.md).
@main
@MainActor
struct ApertureMacApp: App {
    @StateObject private var model: StatusModel

    init() {
        let model = StatusModel(client: APIClient(baseURL: Self.baseURL()))
        model.start()
        _model = StateObject(wrappedValue: model)
        // Run from `swift run` without a bundle: still show a Dock icon and a window.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    static func baseURL() -> URL {
        if let text = UserDefaults.standard.string(forKey: "apiBaseURL"), let url = URL(string: text) {
            return url
        }
        return APIClient.defaultBaseURL
    }

    var body: some Scene {
        Window("Aperture", id: "status") {
            StatusView(model: model)
                .frame(minWidth: 560, minHeight: 560)
        }
        MenuBarExtra {
            MenuBarPanel(model: model)
        } label: {
            Image(systemName: model.headline.severity.symbolName)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarPanel: View {
    @ObservedObject var model: StatusModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        MenuContent(model: model) {
            openWindow(id: "status")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
}
