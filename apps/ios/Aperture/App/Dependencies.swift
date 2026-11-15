import ApertureKit
import Foundation

/// What the iOS app resolves through Factory, next to the shared services in ApertureKit
/// (Dependencies.swift there). Views read the models from the SwiftUI environment; the models get
/// their services from the container.
extension Container {
  /// The one model behind every tab: polls the bot's status and queues commands.
  @MainActor
  var appModel: Factory<AppModel> {
    self { AppModel() }.singleton
  }

  /// The Chart tab's model: recorded days, bars and trades from the bot's API. A new one each time
  /// the tab builds its view, as before.
  @MainActor
  var chartModel: Factory<ChartModel> {
    self { ChartModel() }
  }

  /// The Activity tab's model: which day it shows and the recorded days of the calendar. A new one
  /// each time the tab builds its view.
  @MainActor
  var activityModel: Factory<ActivityModel> {
    self { ActivityModel() }
  }

  /// The Positions tab's marks from the bars of each open position. A new one each time the tab
  /// builds its view.
  @MainActor
  var positionsModel: Factory<PositionsModel> {
    self { PositionsModel() }
  }

  /// Where the paired API token lives: this phone's Keychain.
  var keychain: Factory<Keychain> {
    self { Keychain() }
  }
}
