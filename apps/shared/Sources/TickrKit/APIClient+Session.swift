import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Signing a device in and out at the bot (docs/api.md, POST/DELETE /session, POST /session/refresh).
extension APIClient {
  /// Trade a tickr.bot grant (`AccountSignIn`) for this device's own token pair (`BotSession`).
  /// Sent without a token; a grant works once, for a minute, and a refused one is thrown as
  /// `APIError.refused` (401 `unauthorized`, with the check that failed as its cause).
  public func signIn(grant: String, name: String) async throws -> SessionV1 {
    let body = try JSONSerialization.data(withJSONObject: [Self.grantKey: grant, Self.nameKey: name],
      options: [.sortedKeys])
    return try await perform(request(path: Self.sessionPath, body: body), expect: Self.ok)
  }

  /// Sign this device out: the bot revokes the token this client carries.
  public func signOut() async throws {
    var signOut = request(path: Self.sessionPath, body: nil)
    signOut.httpMethod = Self.delete
    let _: Empty = try await perform(signOut, expect: Self.noContent)
  }

  /// POST /session/refresh: the refresh token buys a new pair and is retired. Sent without a
  /// bearer token and never resent (`BotSession` decides what a failure means).
  func refreshRequest(refreshToken: String) throws -> URLRequest {
    let body = try JSONSerialization.data(withJSONObject: [Self.refreshTokenKey: refreshToken])
    return request(path: Self.refreshPath, body: body)
  }
}
