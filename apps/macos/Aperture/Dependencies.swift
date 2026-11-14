import ApertureKit
import Foundation

/// What the macOS app resolves through Factory, next to the shared services in ApertureKit
/// (Dependencies.swift there). Views read the model from the SwiftUI environment; the model gets
/// its services from the container.
extension Container {
  /// The one model behind every window and the menu bar, pointed at the saved API address.
  @MainActor
  var appModel: Factory<AppModel> {
    self { AppModel(baseURL: ApertureMacApp.baseURL()) }.singleton
  }
}
