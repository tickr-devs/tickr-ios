import Foundation

// Swift mirror of alerts-v1 (GET /alerts, PUT /alerts/routing) in src/tickr/api/contract.py: the
// notification settings. Which alert kinds go to which channel; critical kinds are locked on.

/// An owner-facing alert channel the routing switches.
public enum AlertChannel: String, Codable, Sendable, CaseIterable {
  case mac, imessage, telegram, push
}

/// How the apps group alert kinds.
public enum AlertGroup: String, Codable, Sendable {
  case critical, trading, day, lab
}

/// Why a channel is not known to work on the bot's machine.
public enum AlertChannelCause: String, Codable, Sendable {
  case noPreflight = "no-preflight"
  case preflightUnreadable = "preflight-unreadable"
  case checkFailed = "check-failed"
  case notBuilt = "not-built"
  case notConfigured = "not-configured"
}

/// One channel: whether the latest preflight proved it works, else why not.
public struct AlertChannelV1: Codable, Hashable, Sendable {
  public let channel: AlertChannel
  public let configured: Bool
  public let cause: AlertChannelCause?

  enum CodingKeys: String, CodingKey { case channel, configured, cause }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    channel = try c.decode(AlertChannel.self, forKey: .channel)
    configured = try c.decode(Bool.self, forKey: .configured)
    cause = try c.decodeNullable(AlertChannelCause.self, forKey: .cause)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(channel, forKey: .channel)
    try c.encode(configured, forKey: .configured)
    try c.encodeNullable(cause, forKey: .cause)
  }
}

/// Whether one kind goes to each channel (a locked kind: true everywhere).
public struct AlertRoutesV1: Codable, Hashable, Sendable {
  public let mac: Bool
  public let imessage: Bool
  public let telegram: Bool
  public let push: Bool
}

/// One alert kind and where it goes. `locked`: it needs the owner now and cannot be turned off.
public struct AlertKindV1: Codable, Hashable, Sendable {
  public let kind: String
  public let group: AlertGroup
  public let locked: Bool
  public let channels: AlertRoutesV1
}

/// The notification settings. `routingCause` is set when the routing file cannot be used: every
/// kind then goes to every channel and changes are refused until the file is deleted.
public struct AlertsV1: Codable, Hashable, Sendable {
  public let channels: [AlertChannelV1]
  public let kinds: [AlertKindV1]
  public let routingCause: String?
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case channels, kinds
    case routingCause = "routing_cause"
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    channels = try c.decode([AlertChannelV1].self, forKey: .channels)
    kinds = try c.decode([AlertKindV1].self, forKey: .kinds)
    routingCause = try c.decodeNullable(String.self, forKey: .routingCause)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(channels, forKey: .channels)
    try c.encode(kinds, forKey: .kinds)
    try c.encodeNullable(routingCause, forKey: .routingCause)
    try c.encode(apiVersion, forKey: .apiVersion)
  }
}

// Swift mirror of push-token-v1 (POST and DELETE /push-token) in src/tickr/api/contract.py: this
// device's APNs registration as the bot stored it. The device token itself is never echoed.

/// The platform of the app that registered a push token.
public enum PushPlatform: String, Codable, Sendable {
  case ios, macos
}

/// This device's push registration. `registered` false (after DELETE) has every other key null.
/// `environment` is the build's aps-environment ("development" or "production").
public struct PushTokenV1: Codable, Hashable, Sendable {
  public let registered: Bool
  public let environment: String?
  public let bundleId: String?
  public let platform: PushPlatform?
  public let registeredAt: WireTime?
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case registered, environment, platform
    case bundleId = "bundle_id"
    case registeredAt = "registered_at"
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    registered = try c.decode(Bool.self, forKey: .registered)
    environment = try c.decodeNullable(String.self, forKey: .environment)
    bundleId = try c.decodeNullable(String.self, forKey: .bundleId)
    platform = try c.decodeNullable(PushPlatform.self, forKey: .platform)
    registeredAt = try c.decodeNullable(WireTime.self, forKey: .registeredAt)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(registered, forKey: .registered)
    try c.encodeNullable(environment, forKey: .environment)
    try c.encodeNullable(bundleId, forKey: .bundleId)
    try c.encodeNullable(platform, forKey: .platform)
    try c.encodeNullable(registeredAt, forKey: .registeredAt)
    try c.encode(apiVersion, forKey: .apiVersion)
  }
}
