import ApertureDesign
import SwiftUI

@main
struct ApertureApp: App {
  @State private var model = AppModel()
  @Environment(\.scenePhase) private var scenePhase

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(model)
        .tint(Palette.blue)
    }
    .onChange(of: scenePhase, initial: true) { _, phase in
      // Poll only while the app is on screen; the bot never depends on the phone.
      if phase == .active { model.start() } else { model.stop() }
    }
  }
}
