import CryptoKit
import Foundation

/// Where the apps reach the bot: its API behind TLS on the cloud server, the same for every build
/// (owner, 2026-11-27: no address to type, no pairing link). The owner signs in once with his
/// tickr.bot account (`SignIn`) and the bot gives this device its own token.
public enum BotAddress {
  /// The bot's API.
  public static let url = URL(string: "https://bot.tickr.bot")!
}

/// Signing a device in with the owner's tickr.bot account (docs/api.md, POST /session): OAuth 2.0
/// for native apps (RFC 8252), authorization code with PKCE (RFC 7636). The system's sign-in sheet
/// opens `authorizeURL`; tickr.bot signs the owner in with his passkey and sends the code back to
/// `redirect`; `grantRequest` turns the code into a 60-second grant for the bot (RFC 8707
/// `resource`), and `APIClient.signIn` trades the grant for this device's token. The verifier, the
/// code and the grant live in memory for this one sign-in and are never logged or stored.
public struct SignIn: Sendable {
  /// tickr.bot's OpenID provider (web thread, 2026-11-27).
  public static let issuer = URL(string: "https://tickr.bot")!
  static let authorizePath = "/identity/o/authorize"
  static let tokenPath = "/identity/o/api/token"
  /// The app's own scheme and the redirect tickr.bot sends the code to (registered on both apps).
  public static let callbackScheme = "tickr"
  static let redirect = "tickr://signin"
  static let callbackHost = "signin"
  /// What the grant may do: reach the bot.
  static let scope = "bot"
  /// The OAuth parameter names and values used here (RFC 6749, 7636, 8707).
  static let responseTypeField = "response_type"
  static let codeValue = "code"
  static let clientField = "client_id"
  static let redirectField = "redirect_uri"
  static let scopeField = "scope"
  static let stateField = "state"
  static let challengeField = "code_challenge"
  static let challengeMethodField = "code_challenge_method"
  static let challengeMethod = "S256"
  static let resourceField = "resource"
  static let grantTypeField = "grant_type"
  static let grantType = "authorization_code"
  static let codeField = "code"
  static let verifierField = "code_verifier"
  static let errorField = "error"
  static let formType = "application/x-www-form-urlencoded"
  static let contentTypeHeader = "Content-Type"
  static let post = "POST"
  /// "+" in a form value, which form decoding would read as a space.
  static let plusEscape = "%2B"
  /// Random bytes behind the verifier and the state: 32 gives a 43-character verifier, the shortest
  /// RFC 7636 allows, and 256 bits of state.
  static let randomBytes = 32

  /// Which app signs in: tickr.bot's client of that name.
  public enum Client: String, Sendable {
    case ios = "tickr-ios"
    case mac = "tickr-mac"
  }

  public let client: Client
  let verifier: String
  let state: String

  public init(client: Client) {
    self.init(client: client, verifier: Self.random(), state: Self.random())
  }

  init(client: Client, verifier: String, state: String) {
    self.client = client
    self.verifier = verifier
    self.state = state
  }

  /// The page the sign-in sheet opens.
  public var authorizeURL: URL {
    var parts = URLComponents(url: Self.issuer.appendingPathComponent(String(Self.authorizePath.dropFirst())),
      resolvingAgainstBaseURL: false) ?? URLComponents()
    parts.queryItems = [
      URLQueryItem(name: Self.responseTypeField, value: Self.codeValue),
      URLQueryItem(name: Self.clientField, value: client.rawValue),
      URLQueryItem(name: Self.redirectField, value: Self.redirect),
      URLQueryItem(name: Self.scopeField, value: Self.scope),
      URLQueryItem(name: Self.stateField, value: state),
      URLQueryItem(name: Self.challengeField, value: Self.challenge(verifier)),
      URLQueryItem(name: Self.challengeMethodField, value: Self.challengeMethod),
      URLQueryItem(name: Self.resourceField, value: BotAddress.url.absoluteString),
    ]
    return parts.url ?? Self.issuer
  }

  /// The code tickr.bot sent back to `redirect`, or why there is none: the owner turned the sign-in
  /// down, the account may not reach the bot (`access_denied`), or the answer is not this
  /// sign-in's (another state, another address).
  public func code(from callback: URL) throws(SignInError) -> String {
    guard let parts = URLComponents(url: callback, resolvingAgainstBaseURL: false),
      parts.scheme?.lowercased() == Self.callbackScheme, parts.host?.lowercased() == Self.callbackHost,
      parts.path.isEmpty else { throw .notThisSignIn }
    let items = parts.queryItems ?? []
    func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
    guard value(Self.stateField) == state else { throw .notThisSignIn }
    if let error = value(Self.errorField) { throw .refused(error) }
    guard let code = value(Self.codeField), !code.isEmpty else { throw .notThisSignIn }
    return code
  }

  /// The request that trades `code` for the bot grant at tickr.bot's token endpoint.
  public func grantRequest(code: String) -> URLRequest {
    var request = URLRequest(url: Self.issuer.appendingPathComponent(String(Self.tokenPath.dropFirst())))
    request.httpMethod = Self.post
    request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    request.setValue(Self.formType, forHTTPHeaderField: Self.contentTypeHeader)
    var form = URLComponents()
    form.queryItems = [
      URLQueryItem(name: Self.grantTypeField, value: Self.grantType),
      URLQueryItem(name: Self.codeField, value: code),
      URLQueryItem(name: Self.redirectField, value: Self.redirect),
      URLQueryItem(name: Self.clientField, value: client.rawValue),
      URLQueryItem(name: Self.verifierField, value: verifier),
      URLQueryItem(name: Self.resourceField, value: BotAddress.url.absoluteString),
    ]
    // Form encoding: URLComponents leaves "+" and "&" in values as they are, so they are escaped here.
    request.httpBody = Data((form.percentEncodedQuery ?? "").replacing("+", with: Self.plusEscape).utf8)
    return request
  }

  /// The grant in tickr.bot's token answer (`access_token`), or why there is none.
  public static func grant(from data: Data, status: Int) throws(SignInError) -> String {
    guard status == APIClient.ok else { throw .tokenRefused(status) }
    guard let answer = try? JSONDecoder().decode(TokenAnswer.self, from: data), !answer.accessToken.isEmpty else {
      throw .unreadable
    }
    return answer.accessToken
  }

  /// The rest of the sign-in once the sheet came back with `callback`: the code, the grant from
  /// tickr.bot, then this device's token from the bot (POST /session) under `name`. Throws
  /// `SignInError`, or the bot's refusal (`APIError`); nothing is stored here.
  public func deviceToken(callback: URL, name: String) async throws -> String {
    let answer = try code(from: callback)
    let (data, response) = try await Container.shared.urlSession().data(for: grantRequest(code: answer))
    let grant = try Self.grant(from: data, status: (response as? HTTPURLResponse)?.statusCode ?? .zero)
    return try await Container.shared.apiClient(APIClient.Endpoint(baseURL: BotAddress.url))
      .signIn(grant: grant, name: Self.deviceName(name)).token
  }

  /// The name the bot lists this device under: `raw` (the system's name for the device) with only
  /// what a bot device name may hold (letters, digits, space, dot, dash, underscore; a letter or
  /// digit at each end), or `fallbackName` when nothing is left.
  public static func deviceName(_ raw: String) -> String {
    let kept = String(String.UnicodeScalarView(raw.unicodeScalars.filter { nameCharacters.contains($0) }))
    let trimmed = kept.trimmingCharacters(in: nameEnds)
    return trimmed.isEmpty ? fallbackName : trimmed
  }

  /// The letters and digits a bot device name may hold (src/tickr/api/devices.py NAME): ASCII only.
  static let nameLettersAndDigits = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
  /// The marks a bot device name may hold between them.
  static let nameMarks = " ._-"
  static let nameCharacters = CharacterSet(charactersIn: nameLettersAndDigits + nameMarks)
  /// What a device name may not start or end with.
  static let nameEnds = CharacterSet(charactersIn: nameMarks)
  /// The device name when the system's name has no character a bot device name may hold.
  static let fallbackName = "device"

  /// RFC 7636 S256: base64url of the SHA-256 of the verifier, without padding.
  static func challenge(_ verifier: String) -> String {
    base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
  }

  static func random() -> String {
    var generator = SystemRandomNumberGenerator()
    return base64URL(Data((0..<randomBytes).map { _ in UInt8.random(in: .min ... .max, using: &generator) }))
  }

  static func base64URL(_ data: Data) -> String {
    data.base64EncodedString().replacing("+", with: "-").replacing("/", with: "_").replacing("=", with: "")
  }

  struct TokenAnswer: Decodable {
    let accessToken: String
    enum CodingKeys: String, CodingKey { case accessToken = "access_token" }
  }
}

/// Why a sign-in ended without a token.
public enum SignInError: Error, Equatable, Sendable {
  /// tickr.bot answered with an error: `access_denied` when the account may not reach the bot.
  case refused(String)
  /// The sign-in sheet came back with something that is not this sign-in's answer.
  case notThisSignIn
  /// tickr.bot's token endpoint answered with this HTTP status instead of a grant.
  case tokenRefused(Int)
  /// tickr.bot's answer has no grant in it.
  case unreadable
}

extension SignInError {
  /// What the owner reads when a sign-in ends this way: tickr.bot's own error code is never shown.
  public var reason: LocalizedStringResource {
    switch self {
    case .refused: L10n.signInAccountRefused
    case .notThisSignIn, .unreadable: L10n.signInBadAnswer
    case .tokenRefused: L10n.signInCodeRefused
    }
  }
}
