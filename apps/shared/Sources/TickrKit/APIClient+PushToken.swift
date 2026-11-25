import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// This device's APNs tokens at the bot (docs/api.md, POST and DELETE /push-token), apart from
// APIClient.swift to keep that file within SwiftLint's length limit.
extension APIClient {
  /// Path of the push token registration.
  static let pushTokenPath = "/push-token"
  /// Query item name of the kind a DELETE removes.
  static let kindQuery = "kind"
  /// HTTP method that removes a registration.
  static let delete = "DELETE"

  /// Store this device's token of one kind at the bot, replacing only that kind's earlier one.
  /// The bot refuses a token that is not hex, an unknown environment, bundle id or kind with 400
  /// `bad_request`, thrown as `APIError.refused`.
  public func registerPushToken(_ registration: PushRegistration) async throws -> PushTokenV1 {
    let body = try JSONSerialization.data(withJSONObject: registration.body, options: [.sortedKeys])
    return try await perform(request(path: Self.pushTokenPath, body: body), expect: Self.ok)
  }

  /// Remove this device's token of `kind` at the bot (none stored is fine): the answer says
  /// `registered` false.
  public func removePushToken(kind: PushTokenKind) async throws -> PushTokenV1 {
    var removal = request(path: Self.pushTokenPath, query: [(Self.kindQuery, kind.rawValue)], body: nil)
    removal.httpMethod = Self.delete
    return try await perform(removal, expect: Self.ok)
  }
}
