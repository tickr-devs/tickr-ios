import ApertureDesign
import ApertureKit
import SwiftUI

@main
struct ApertureApp: App {
  @State private var model = Container.shared.appModel()
  @Environment(\.scenePhase) private var scenePhase
  /// Until the opening animation has handed the launch screen over to Home.
  @State private var opening = true

  var body: some Scene {
    WindowGroup {
      RootView()
        .overlay {
          if opening { LaunchHandoff { opening = false } }
        }
        .environment(model)
        .tint(Palette.info)
    }
    .onChange(of: scenePhase, initial: true) { _, phase in
      // Poll only while the app is on screen; the bot never depends on the phone.
      if phase == .active { model.start() } else { model.stop() }
    }
  }
}
