import Foundation

// The notification settings (GET /alerts, PUT /alerts/routing, backlog T14).
extension APIClient {
  /// Path of the notification settings read.
  static let alertsPath = "/alerts"
  /// Path of one routing change.
  static let alertRoutingPath = "/alerts/routing"
  /// Body keys of PUT /alerts/routing.
  static let alertKindField = "kind"
  static let alertChannelField = "channel"
  static let alertOnField = "on"

  /// The notification settings: each alert channel, and which alert kinds go to which channel.
  public func alerts() async throws -> AlertsV1 {
    try await perform(request(path: Self.alertsPath, body: nil), expect: Self.ok)
  }

  /// Turn one alert kind on or off on one channel. Answers the settings as they now stand; a
  /// locked kind turned off, or a routing file that cannot be used, is 409 and an unknown kind or
  /// channel 400, both thrown as `APIError.refused`. Not a bot command: nothing is queued.
  public func setAlertRoute(kind: String, channel: AlertChannel, on: Bool) async throws -> AlertsV1 {
    let body = try JSONSerialization.data(withJSONObject: [
      Self.alertKindField: kind, Self.alertChannelField: channel.rawValue, Self.alertOnField: on,
    ] as [String: Any], options: [.sortedKeys])
    return try await perform(request(path: Self.alertRoutingPath, method: Self.put, body: body), expect: Self.ok)
  }
}
