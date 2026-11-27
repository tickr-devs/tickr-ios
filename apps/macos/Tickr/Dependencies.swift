import Foundation
import TickrKit

/// What the macOS app resolves through Factory, next to the shared services in TickrKit
/// (Dependencies.swift there). Views read the model from the SwiftUI environment; the model gets
/// its services from the container.
extension Container {
  /// The one model behind every window and the menu bar, pointed at the bot with this Mac's
  /// sign-in (`SignInState`), or at the demo day the app carries when its switch was left on.
  @MainActor
  var appModel: Factory<AppModel> {
    self {
      AppModel(baseURL: Defaults.baseURL(), signedIn: self.signInState().signedIn,
        demoDay: UserDefaults.standard.bool(forKey: Defaults.demoDay))
    }
    .singleton
  }

  /// The Chart's bars and decisions, shared by the Chart screen and the window's decisions
  /// inspector.
  @MainActor
  var chartModel: Factory<ChartModel> {
    self { ChartModel() }.singleton
  }
}

extension Container {
  /// The system's passkey sheet for the sign-in (`SystemPasskeySheet`); tests answer it.
  @MainActor
  var passkeySheet: Factory<any PasskeySheet> {
    self { SystemPasskeySheet() }
  }
}
