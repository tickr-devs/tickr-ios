import Foundation
import TickrKit

/// What the macOS app resolves through Factory, next to the shared services in TickrKit
/// (Dependencies.swift there). Views read the model from the SwiftUI environment; the model gets
/// its services from the container.
extension Container {
  /// The one model behind every window and the menu bar, pointed at the saved API address.
  @MainActor
  var appModel: Factory<AppModel> {
    self { AppModel(baseURL: TickrMacApp.baseURL()) }.singleton
  }

  /// The Chart's bars and decisions, shared by the Chart screen and the window's decisions
  /// inspector.
  @MainActor
  var chartModel: Factory<ChartModel> {
    self { ChartModel() }.singleton
  }
}
