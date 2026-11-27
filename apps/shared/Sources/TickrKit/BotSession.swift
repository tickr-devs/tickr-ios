import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// POST /session and POST /session/refresh on the remote port: a signed-in device's token pair,
/// answered once. The access token is the bearer token until `accessExpiresIn` seconds from the
/// answer; the refresh token buys the next pair until `refreshExpiresIn` (docs/api.md).
public struct SessionV1: Codable, Hashable, Sendable {
  public let accessToken: String
  public let accessExpiresIn: Int
  public let refreshToken: String
  public let refreshExpiresIn: Int
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case accessToken = "access_token"
    case accessExpiresIn = "access_expires_in"
    case refreshToken = "refresh_token"
    case refreshExpiresIn = "refresh_expires_in"
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    accessToken = try c.decode(String.self, forKey: .accessToken)
    accessExpiresIn = try c.decode(Int.self, forKey: .accessExpiresIn)
    refreshToken = try c.decode(String.self, forKey: .refreshToken)
    refreshExpiresIn = try c.decode(Int.self, forKey: .refreshExpiresIn)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(accessToken, forKey: .accessToken)
    try c.encode(accessExpiresIn, forKey: .accessExpiresIn)
    try c.encode(refreshToken, forKey: .refreshToken)
    try c.encode(refreshExpiresIn, forKey: .refreshExpiresIn)
    try c.encode(apiVersion, forKey: .apiVersion)
  }
}

/// A signed-in device's two bot tokens (docs/api.md, POST /session and /session/refresh), as the
/// Keychain keeps them. Expiries are this device's clock at the answer plus the seconds the bot
/// gave, so a skew between the two clocks never matters, only the answer's travel time.
public struct BotTokens: Codable, Hashable, Sendable {
  public let accessToken: String
  public let accessExpiresAt: Date
  public let refreshToken: String
  public let refreshExpiresAt: Date

  public init(_ answer: SessionV1, receivedAt now: Date) {
    accessToken = answer.accessToken
    accessExpiresAt = now.addingTimeInterval(TimeInterval(answer.accessExpiresIn))
    refreshToken = answer.refreshToken
    refreshExpiresAt = now.addingTimeInterval(TimeInterval(answer.refreshExpiresIn))
  }
}

/// Why the device has no usable access token.
public enum BotSessionError: Error, Equatable, Sendable {
  /// Not signed in, or the sign-in ended (expired, revoked, or a renewal whose answer was lost):
  /// the owner signs in again.
  case signInAgain
  /// The renewal could not leave this device (no network): the tokens are kept, try later.
  case offline(String)
}

/// This device's sign-in with the bot: its tokens in the Keychain, the access token handed to
/// every request (`APIClient`) and renewed once it has run out. One per app run
/// (`Container.botSession`), so two screens never renew at once: a refresh token sent twice is
/// reuse to the bot, which signs the device out. A renewal is sent once and never resent; when its
/// answer may have been lost, the refresh token may already be retired, so the device signs in
/// again (docs/api.md) instead of guessing.
public actor BotSession {
  private let keychain: Keychain
  private let transport: any APITransport
  private let now: @Sendable () -> Date
  private var tokens: BotTokens?
  private var loaded = false
  private var renewing: Task<BotTokens, any Error>?

  public init(keychain: Keychain, transport: any APITransport, now: @escaping @Sendable () -> Date) {
    self.keychain = keychain
    self.transport = transport
    self.now = now
  }

  /// Whether a sign-in is kept (it may still have run out; `accessToken` says).
  public var isSignedIn: Bool { current() != nil }

  /// The access token for the next request, renewed first when it has run out.
  public func accessToken() async throws -> String {
    guard let held = current() else { throw BotSessionError.signInAgain }
    if now() < held.accessExpiresAt { return held.accessToken }
    if let renewing { return try await renewing.value.accessToken }
    guard now() < held.refreshExpiresAt else {
      forget()
      throw BotSessionError.signInAgain
    }
    let task = Task { try await self.renew(held) }
    renewing = task
    defer { renewing = nil }
    return try await task.value.accessToken
  }

  /// Keep the pair the bot answered to POST /session. False when the Keychain did not keep it.
  @discardableResult
  public func signedIn(_ answer: SessionV1) -> Bool {
    store(BotTokens(answer, receivedAt: now()))
  }

  /// Forget the tokens on this device (after DELETE /session, or when the bot ended the sign-in).
  public func forget() {
    tokens = nil
    loaded = true
    keychain.deleteToken()
  }

  private func current() -> BotTokens? {
    if !loaded {
      loaded = true
      tokens = keychain.readToken().flatMap { try? JSONDecoder().decode(BotTokens.self, from: Data($0.utf8)) }
    }
    return tokens
  }

  @discardableResult
  private func store(_ new: BotTokens) -> Bool {
    tokens = new
    loaded = true
    guard let data = try? JSONEncoder().encode(new), let text = String(bytes: data, encoding: .utf8) else {
      return false
    }
    return keychain.saveToken(text)
  }

  private func renew(_ held: BotTokens) async throws -> BotTokens {
    let request = try APIClient(baseURL: BotAddress.url, transport: transport)
      .refreshRequest(refreshToken: held.refreshToken)
    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await transport.response(to: request)
    } catch {
      if let code = (error as? URLError)?.code, Self.neverSent.contains(code) {
        throw BotSessionError.offline(error.localizedDescription)
      }
      // The request may have reached the bot and retired the refresh token: never resent.
      forget()
      throw BotSessionError.signInAgain
    }
    guard (response as? HTTPURLResponse)?.statusCode == APIClient.ok,
      let answer = try? Wire.decoder().decode(SessionV1.self, from: data) else {
      forget()
      throw BotSessionError.signInAgain
    }
    let renewed = BotTokens(answer, receivedAt: now())
    store(renewed)
    return renewed
  }

  /// Failures where the request never left this device, so the refresh token is still live.
  static let neverSent: Set<URLError.Code> = [
    .notConnectedToInternet, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed,
    .internationalRoamingOff, .dataNotAllowed, .callIsActive,
  ]
}
