import SwiftUI
import TickrDesign
import TickrKit

@main
struct TickrApp: App {
  @State private var model = Container.shared.appModel()
  @Environment(\.scenePhase) private var scenePhase
  /// Until the opening animation has handed the launch screen over to Home.
  @State private var opening = true
  /// Until the flying mark has landed in Home's title: Home's cards wait to rise until then.
  @State private var landed = false

  var body: some Scene {
    WindowGroup {
      RootView()
        .withoutScrollIndicators()
        .environment(\.risesHeld, !landed)
        .overlay {
          if opening { LaunchHandoff { landed = true } finished: { opening = false } }
        }
        .readFailureContext(model)
        .environment(model)
        .tint(Palette.info)
    }
    .onChange(of: scenePhase, initial: true) { _, phase in
      // Poll only while the app is on screen; the bot never depends on the phone.
      if phase == .active { model.start() } else { model.stop() }
    }
  }
}
