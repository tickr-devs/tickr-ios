import Foundation
import Observation

// The notification settings as both apps show and change them (GET /alerts, PUT /alerts/routing,
// backlog T14): the logic of the screen, so the Mac and the iPhone draw the same rows.

/// One cell of the routing: an alert kind on a channel.
public struct AlertCell: Hashable, Sendable {
  public let kind: String
  public let channel: AlertChannel

  public init(kind: String, channel: AlertChannel) {
    self.kind = kind
    self.channel = channel
  }
}

extension AlertsV1 {
  /// The groups of kinds the owner can switch, in the screen's order: what needs the owner now
  /// (none today: every such kind is locked), trading, the day and the bot, the model lab.
  public static let groupOrder: [AlertGroup] = [.critical, .trading, .day, .lab]

  /// The kinds always on everywhere, in the bot's order.
  public var lockedKinds: [AlertKindV1] { kinds.filter(\.locked) }

  /// Each group that has kinds the owner can switch, with them in the bot's order.
  public var switchableGroups: [(group: AlertGroup, kinds: [AlertKindV1])] {
    Self.groupOrder.compactMap { group in
      let found = kinds.filter { !$0.locked && $0.group == group }
      return found.isEmpty ? nil : (group, found)
    }
  }

  /// The channel's state as the latest morning check proved it.
  public func channel(_ channel: AlertChannel) -> AlertChannelV1? {
    channels.first { $0.channel == channel }
  }

  /// Whether the owner can change a channel's column: not while the routing file cannot be used,
  /// and not for a channel that is not built yet (its column is shown, never a choice today).
  public func canChange(_ channel: AlertChannel) -> Bool {
    routingCause == nil && self.channel(channel)?.cause != .notBuilt
  }
}

extension AlertRoutesV1 {
  /// Whether the kind goes to `channel`.
  public subscript(_ channel: AlertChannel) -> Bool {
    switch channel {
    case .mac: mac
    case .imessage: imessage
    case .push: push
    }
  }
}

/// The notification settings read from the bot, and the owner's changes on their way.
@MainActor
@Observable
public final class AlertRouting {
  /// The settings as last read or answered by a change; nil before the first read.
  public private(set) var alerts: AlertsV1?
  /// Why the settings could not be read, if they could not.
  public private(set) var readError: String?
  /// Why the last change did not happen, in words; cleared by the next change.
  public private(set) var changeError: String?
  /// Changes sent and not answered yet: their cells show the new value and wait.
  public private(set) var pending: [AlertCell: Bool] = [:]
  /// Bumped by `clear()`, so an answer from the old address is dropped.
  @ObservationIgnored private var generation = 0

  public init() {}

  /// Whether `kind` shows as on for `channel`: a change on its way first, else the bot's routing.
  public func isOn(_ kind: AlertKindV1, _ channel: AlertChannel) -> Bool {
    pending[AlertCell(kind: kind.kind, channel: channel)] ?? kind.channels[channel]
  }

  /// Forget everything read, as when the app's address changes.
  public func clear() {
    generation += 1
    alerts = nil
    readError = nil
    changeError = nil
    pending = [:]
  }

  /// Read the settings; a failed read clears them, so an old routing never reads as current.
  public func refresh(_ client: APIClient) async {
    let asked = generation
    do {
      let read = try await client.alerts()
      guard asked == generation else { return }
      alerts = read
      readError = nil
    } catch is CancellationError {
      return
    } catch {
      guard asked == generation else { return }
      alerts = nil
      readError = ErrorText.describe(error) ?? readError
    }
  }

  /// Turn one cell on or off: sent once; the answer replaces the settings. A refusal or a failed
  /// send is kept as `changeError` and the settings are read again, so the screen shows what the
  /// bot holds, never a guess.
  public func set(_ cell: AlertCell, on: Bool, client: APIClient) async {
    guard pending[cell] == nil else { return }
    let asked = generation
    pending[cell] = on
    changeError = nil
    do {
      let answer = try await client.setAlertRoute(kind: cell.kind, channel: cell.channel, on: on)
      guard asked == generation else { return }
      pending[cell] = nil
      alerts = answer
    } catch {
      guard asked == generation else { return }
      pending[cell] = nil
      changeError = ErrorText.cause(error)
      await refresh(client)
    }
  }
}
