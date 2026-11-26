import SwiftUI
import TickrDesign
import TickrKit

@main
struct TickrApp: App {
  @State private var model = Container.shared.appModel()
  /// Until the opening animation has handed the launch screen over to Home.
  @State private var opening = true
  /// Until the flying mark has landed in Home's title: Home's cards wait to rise until then.
  @State private var landed = false

  var body: some Scene {
    WindowGroup {
      AdaptiveRoot()
        .withoutScrollIndicators()
        .environment(\.risesHeld, !landed)
        .overlay {
          if opening { LaunchHandoff { landed = true } finished: { opening = false } }
        }
        .readFailureContext(model)
        .environment(model)
        .tint(Palette.info)
    }
  }
}
