import Foundation

// Swift mirror of push-token-v1 (POST and DELETE /push-token) in src/tickr/api/contract.py: this
// device's APNs registration as the bot stored it. The device token itself is never echoed.

/// What an APNs token is for: alerts, or a Live Activity's push-to-start or update token.
public enum PushTokenKind: String, Codable, Sendable, CaseIterable {
  case alert
  case activityStart = "activity_start"
  case activityUpdate = "activity_update"
}

/// The platform of the app that registered a push token.
public enum PushPlatform: String, Codable, Sendable {
  case ios, macos

  /// The platform this build runs on; nil on any other (a test host), where nothing registers.
  public static var current: PushPlatform? {
    #if os(iOS)
    .ios
    #elseif os(macOS)
    .macos
    #else
    nil
    #endif
  }
}

/// This device's push registration of one kind. `registered` false (after DELETE) has every key
/// but `kind` null.
/// `environment` is the build's aps-environment ("development" or "production").
public struct PushTokenV1: Codable, Hashable, Sendable {
  public let registered: Bool
  public let kind: PushTokenKind
  public let environment: String?
  public let bundleId: String?
  public let platform: PushPlatform?
  public let registeredAt: WireTime?
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case registered, kind, environment, platform
    case bundleId = "bundle_id"
    case registeredAt = "registered_at"
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    registered = try c.decode(Bool.self, forKey: .registered)
    kind = try c.decode(PushTokenKind.self, forKey: .kind)
    environment = try c.decodeNullable(String.self, forKey: .environment)
    bundleId = try c.decodeNullable(String.self, forKey: .bundleId)
    platform = try c.decodeNullable(PushPlatform.self, forKey: .platform)
    registeredAt = try c.decodeNullable(WireTime.self, forKey: .registeredAt)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(registered, forKey: .registered)
    try c.encode(kind, forKey: .kind)
    try c.encodeNullable(environment, forKey: .environment)
    try c.encodeNullable(bundleId, forKey: .bundleId)
    try c.encodeNullable(platform, forKey: .platform)
    try c.encodeNullable(registeredAt, forKey: .registeredAt)
    try c.encode(apiVersion, forKey: .apiVersion)
  }
}

/// The APNs environment a build's tokens belong to: its `aps-environment` entitlement. Xcode's
/// Debug builds talk to APNs development; TestFlight and the App Store to production.
public enum ApsEnvironment: String, Sendable, CaseIterable {
  case development, production
}

/// What every registration of this build says besides the token: its APNs environment, bundle id
/// and platform.
public struct PushIdentity: Hashable, Sendable {
  /// Info.plist key of the build's APNs environment: `TICKR_APS_ENVIRONMENT` of
  /// apps/Config/Identity.xcconfig, set per configuration like the entitlement it matches.
  public static let environmentKey = "TickrApsEnvironment"

  public let environment: ApsEnvironment
  public let bundleId: String
  public let platform: PushPlatform

  public init(environment: ApsEnvironment, bundleId: String, platform: PushPlatform) {
    self.environment = environment
    self.bundleId = bundleId
    self.platform = platform
  }

  /// The identity `bundle` declares, or nil when it names no known environment (a build made
  /// without the Xcode settings, such as `swift build`), has no bundle id, or `platform` is nil:
  /// such a build never registers, rather than guess.
  public static func of(_ bundle: Bundle, platform: PushPlatform?) -> PushIdentity? {
    guard let raw = bundle.object(forInfoDictionaryKey: environmentKey) as? String,
      let environment = ApsEnvironment(rawValue: raw), let bundleId = bundle.bundleIdentifier,
      let platform else { return nil }
    return PushIdentity(environment: environment, bundleId: bundleId, platform: platform)
  }
}

/// One token to register: the body of POST /push-token.
public struct PushRegistration: Hashable, Sendable {
  /// Body keys of POST /push-token (docs/api.md, "Push tokens").
  static let tokenKey = "token"
  static let environmentKey = "environment"
  static let bundleIdKey = "bundle_id"
  static let platformKey = "platform"
  static let kindKey = "kind"

  /// The device token in lowercase hex (`hex(_:)`).
  public let token: String
  public let kind: PushTokenKind
  public let identity: PushIdentity

  public init(token: String, kind: PushTokenKind, identity: PushIdentity) {
    self.token = token
    self.kind = kind
    self.identity = identity
  }

  /// The exact JSON body the API requires.
  var body: [String: String] {
    [
      Self.tokenKey: token, Self.environmentKey: identity.environment.rawValue,
      Self.bundleIdKey: identity.bundleId, Self.platformKey: identity.platform.rawValue,
      Self.kindKey: kind.rawValue,
    ]
  }

  /// Base of a token's digits.
  static let hexRadix = 16
  /// Digits of one byte in hex.
  static let byteDigits = 2
  /// What pads a byte below 0x10 to two digits.
  static let pad: Character = "0"

  /// `token` as APNs and the bot write it: two lowercase hex digits per byte.
  public static func hex(_ token: Data) -> String {
    token.map { byte in
      let digits = String(byte, radix: hexRadix)
      return String(repeating: pad, count: byteDigits - digits.count) + digits
    }.joined()
  }
}
