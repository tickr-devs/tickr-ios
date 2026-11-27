import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Signing in with the owner's tickr.bot account on the app's own screens (owner, 2026-11-27: no
/// web sheet, the site's own ways in). tickr.bot's headless API for apps: a passkey, email and
/// password, or a code by email, then a second step (authenticator code, passkey or recovery code)
/// when the account asks for one. Once signed in, tickr.bot gives a one-minute grant for the bot
/// (only to a sign-in with a passkey or a second factor), the bot trades it for this device's
/// tokens (`APIClient.signIn`, `BotSession`), and the app signs out of tickr.bot at once, whatever
/// happened, so nothing that could mint another grant stays on the device.
///
/// One instance per sign-in attempt. tickr.bot's session token changes after each step, so the
/// newest one is kept; it lives in memory only and is never logged. Its error messages come in
/// the person's language (`Accept-Language`) and are shown as they are.
public actor AccountSignIn {
  /// tickr.bot's headless API for the app client, and the grant endpoint next to it.
  public static let site = URL(string: "https://tickr.bot")!
  static let headlessPath = "api/auth/app/v1"
  static let grantPath = "api/app/bot-grant"
  /// Paths under `headlessPath` (allauth headless, docs in the web repo's app sign-in notes).
  static let passwordLoginPath = "auth/login"
  static let codeRequestPath = "auth/code/request"
  static let codeConfirmPath = "auth/code/confirm"
  static let passkeyLoginPath = "auth/webauthn/login"
  static let secondFactorPath = "auth/2fa/authenticate"
  static let passkeySecondFactorPath = "auth/webauthn/authenticate"
  static let passwordResetPath = "auth/password/request"
  static let sessionPath = "auth/session"
  /// Header and body keys of the API.
  static let sessionHeader = "X-Session-Token"
  static let languageHeader = "Accept-Language"
  static let contentTypeHeader = "Content-Type"
  static let acceptHeader = "accept"
  static let json = "application/json"
  static let emailKey = "email"
  static let passwordKey = "password"
  static let codeKey = "code"
  static let credentialKey = "credential"
  static let clientKey = "client_id"
  static let resourceKey = "resource"
  static let get = "GET"
  static let post = "POST"
  static let delete = "DELETE"
  /// HTTP statuses the API answers with: done, a step still pending, a refused value.
  static let ok = 200
  static let pending = 401
  static let badRequest = 400
  static let forbidden = 403
  /// The flows a 401 names as pending.
  static let codeFlow = "login_by_code"
  static let secondFactorFlow = "mfa_authenticate"
  /// The grant endpoint's refusals the app tells apart.
  static let needsStrongFactor = "needs_passkey_or_authenticator"
  static let notAllowed = "not_allowed"

  /// Which app signs in: tickr.bot's client of that name.
  public enum Client: String, Sendable {
    case ios = "tickr-ios"
    case mac = "tickr-mac"
  }

  private let client: Client
  private let transport: any APITransport
  private var sessionToken: String?

  public init(client: Client, transport: any APITransport) {
    self.client = client
    self.transport = transport
  }

  // MARK: Ways in

  /// The challenge for a passkey sign-in, for the system's passkey sheet.
  public func passkeyChallenge() async throws(AccountError) -> PasskeyChallenge {
    try PasskeyChallenge(try await send(Self.passkeyLoginPath, body: nil).data)
  }

  /// Sign in with the passkey the system's sheet returned for `passkeyChallenge`.
  public func signIn(passkey: PasskeyAssertion) async throws(AccountError) -> AccountStep {
    try await step(Self.passkeyLoginPath, [Self.credentialKey: passkey.credential])
  }

  public func signIn(email: String, password: String) async throws(AccountError) -> AccountStep {
    try await step(Self.passwordLoginPath, [Self.emailKey: email, Self.passwordKey: password])
  }

  /// Email a one-time code to `email` (`AccountStep.codeSent`).
  public func requestCode(email: String) async throws(AccountError) -> AccountStep {
    try await step(Self.codeRequestPath, [Self.emailKey: email])
  }

  public func confirmCode(_ code: String) async throws(AccountError) -> AccountStep {
    try await step(Self.codeConfirmPath, [Self.codeKey: code])
  }

  /// The second step with an authenticator app's code or a recovery code.
  public func secondFactor(code: String) async throws(AccountError) -> AccountStep {
    try await step(Self.secondFactorPath, [Self.codeKey: code])
  }

  /// The challenge for a passkey as the second step.
  public func secondFactorPasskeyChallenge() async throws(AccountError) -> PasskeyChallenge {
    try PasskeyChallenge(try await send(Self.passkeySecondFactorPath, body: nil).data)
  }

  public func secondFactor(passkey: PasskeyAssertion) async throws(AccountError) -> AccountStep {
    try await step(Self.passkeySecondFactorPath, [Self.credentialKey: passkey.credential])
  }

  /// "Forgot password?": tickr.bot emails a link; the reset finishes on the site.
  public func requestPasswordReset(email: String) async throws(AccountError) {
    _ = try await step(Self.passwordResetPath, [Self.emailKey: email])
  }

  // MARK: The bot

  /// Once signed in: the grant, then this device's tokens from the bot under `name`. tickr.bot's
  /// session is deleted afterwards in every case, the bot's refusal included, before this returns.
  public func botSession(name: String) async throws -> SessionV1 {
    do {
      let grant = try await self.grant()
      let answer = try await APIClient(baseURL: BotAddress.url, transport: transport)
        .signIn(grant: grant, name: SignIn.deviceName(name))
      await signOutOfSite()
      return answer
    } catch {
      await signOutOfSite()
      throw error
    }
  }

  /// Delete tickr.bot's session (DELETE /auth/session). Its answer is not waited on for anything:
  /// the token is dropped here either way. Also for a sign-in left half way.
  public func signOutOfSite() async {
    guard sessionToken != nil else { return }
    var request = request(Self.sessionPath, body: nil)
    request.httpMethod = Self.delete
    _ = try? await transport.response(to: request)
    sessionToken = nil
  }

  private func grant() async throws(AccountError) -> String {
    let body = Self.encode([Self.clientKey: client.rawValue, Self.resourceKey: BotAddress.url.absoluteString])
    var request = URLRequest(url: Self.site.appendingPathComponent(Self.grantPath))
    request.httpMethod = Self.post
    request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    request.httpBody = body
    headers(&request)
    let (data, status) = try await exchange(request)
    guard status == Self.ok else {
      let refusal = (try? JSONDecoder().decode(GrantRefusal.self, from: data))?.error
      switch refusal {
      case Self.needsStrongFactor: throw .needsPasskeyOrAuthenticator
      case Self.notAllowed: throw .notAllowed
      default: throw .unreadable
      }
    }
    guard let answer = try? JSONDecoder().decode(GrantAnswer.self, from: data), !answer.grant.isEmpty else {
      throw .unreadable
    }
    return answer.grant
  }

  // MARK: Requests

  private func step(_ path: String, _ body: [String: Any]) async throws(AccountError) -> AccountStep {
    let answer = try await send(path, body: Self.encode(body))
    return try AccountStep(answer)
  }

  private func send(_ path: String, body: Data?) async throws(AccountError) -> Envelope {
    let (data, status) = try await exchange(request(path, body: body))
    guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else { throw .unreadable }
    if let token = envelope.meta?.sessionToken { sessionToken = token }
    if status == Self.ok || status == Self.pending { return envelope.with(status: status) }
    if let message = envelope.errors?.first?.message { throw .message(message) }
    throw .unreadable
  }

  private func exchange(_ request: URLRequest) async throws(AccountError) -> (Data, Int) {
    do {
      let (data, response) = try await transport.response(to: request)
      guard let http = response as? HTTPURLResponse else { throw AccountError.unreadable }
      return (data, http.statusCode)
    } catch let error as AccountError {
      throw error
    } catch {
      throw .unreachable(error.localizedDescription)
    }
  }

  private func request(_ path: String, body: Data?) -> URLRequest {
    var request = URLRequest(url: Self.site.appendingPathComponent(Self.headlessPath).appendingPathComponent(path))
    request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    request.httpMethod = body == nil ? Self.get : Self.post
    request.httpBody = body
    headers(&request)
    return request
  }

  private func headers(_ request: inout URLRequest) {
    request.setValue(Self.json, forHTTPHeaderField: Self.acceptHeader)
    if request.httpBody != nil { request.setValue(Self.json, forHTTPHeaderField: Self.contentTypeHeader) }
    if let sessionToken { request.setValue(sessionToken, forHTTPHeaderField: Self.sessionHeader) }
    if let language = Locale.preferredLanguages.first {
      request.setValue(language, forHTTPHeaderField: Self.languageHeader)
    }
  }

  static func encode(_ body: [String: Any]) -> Data {
    (try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])) ?? Data()
  }

  // MARK: Answers

  struct Envelope: Decodable {
    var status: Int?
    let data: HeadlessPayload?
    let meta: HeadlessMeta?
    let errors: [HeadlessFailure]?

    func with(status: Int) -> Envelope {
      var copy = self
      copy.status = status
      return copy
    }
  }

  struct GrantAnswer: Decodable { let grant: String }
  struct GrantRefusal: Decodable { let error: String }
}

/// The parts of a tickr.bot headless answer the app reads.
struct HeadlessMeta: Decodable {
  let sessionToken: String?
  enum CodingKeys: String, CodingKey { case sessionToken = "session_token" }
}

struct HeadlessFailure: Decodable { let message: String }

struct HeadlessFlow: Decodable {
  let id: String
  let isPending: Bool?
  let types: [String]?
  enum CodingKeys: String, CodingKey {
    case id, types
    case isPending = "is_pending"
  }
}

struct HeadlessPayload: Decodable {
  let flows: [HeadlessFlow]?
  let requestOptions: HeadlessRequestOptions?
  enum CodingKeys: String, CodingKey {
    case flows
    case requestOptions = "request_options"
  }
}

struct HeadlessRequestOptions: Decodable { let publicKey: HeadlessPublicKey }

struct HeadlessPublicKey: Decodable {
  let challenge: String
  let rpId: String
}

/// Where a sign-in stands after a step.
public enum AccountStep: Equatable, Sendable {
  /// Signed in at tickr.bot: next, `AccountSignIn.botSession`.
  case signedIn
  /// The account asks for a second step, by one of these.
  case secondFactor([SecondFactor])
  /// A code is on its way to the email address.
  case codeSent

  init(_ answer: AccountSignIn.Envelope) throws(AccountError) {
    if answer.status == AccountSignIn.ok {
      self = .signedIn
      return
    }
    let pending = answer.data?.flows?.first { $0.isPending == true }
    switch pending?.id {
    case AccountSignIn.secondFactorFlow:
      self = .secondFactor((pending?.types ?? []).compactMap(SecondFactor.init(rawValue:)))
    case AccountSignIn.codeFlow:
      self = .codeSent
    default:
      throw .unreadable
    }
  }
}

/// A second step tickr.bot accepts (its own names).
public enum SecondFactor: String, Equatable, Sendable {
  case authenticator = "totp"
  case passkey = "webauthn"
  case recoveryCode = "recovery_codes"
}

/// Why a sign-in step did not go through.
public enum AccountError: Error, Equatable, Sendable {
  /// tickr.bot's own words, already in the person's language (a wrong password, a wrong code).
  case message(String)
  /// The sign-in used a password or a code only: the bot needs a passkey or an authenticator.
  case needsPasskeyOrAuthenticator
  /// This account may not reach the bot.
  case notAllowed
  /// tickr.bot could not be reached.
  case unreachable(String)
  /// An answer this app cannot read.
  case unreadable
}

extension AccountError {
  /// What the person reads.
  public var text: String {
    switch self {
    case .message(let words): words
    case .needsPasskeyOrAuthenticator: String(localized: L10n.accountNeedsStrongFactor)
    case .notAllowed: String(localized: L10n.signInAccountRefused)
    case .unreachable: String(localized: L10n.accountUnreachable)
    case .unreadable: String(localized: L10n.signInBadAnswer)
    }
  }
}
