import Foundation
import Testing
@testable import TickrKit

/// Signing in with tickr.bot on the app's own screens (AccountSignIn.swift), against answers
/// recorded from tickr.bot's test suite (the web repo's app sign-in samples).
@Suite struct AccountSignInTests {
  static let passkeyOptions = #"{"status":200,"data":{"request_options":{"publicKey":{"challenge":"#
    + #""rx8Mbze0LVeLtgUaFhsF_U4mUHaqkW-IasCsUjXWFmw","rpId":"tickr.bot","allowCredentials":[],"#
    + #""userVerification":"required"}}},"meta":{"session_token":"s-passkey"}}"#
  static let wrongPassword = #"{"status":400,"errors":[{"message":"The email address and/or password you "#
    + #"specified are not correct.","code":"email_password_mismatch","param":"password"}]}"#
  static let needsAuthenticator = #"{"status":401,"data":{"flows":[{"id":"login"},{"id":"login_by_code"},"#
    + #"{"id":"mfa_login_webauthn"},{"id":"mfa_authenticate","is_pending":true,"types":["totp"]}]},"#
    + #""meta":{"is_authenticated":false,"session_token":"s-1"}}"#
  static let signedIn = #"{"status":200,"data":{"user":{"id":1}},"#
    + #""meta":{"is_authenticated":true,"session_token":"s-2"}}"#
  static let codeSent = #"{"status":401,"data":{"flows":[{"id":"login"},{"id":"login_by_code","is_pending":true}]},"#
    + #""meta":{"is_authenticated":false,"session_token":"s-code"}}"#
  static let signedOut = #"{"status":401,"data":{"flows":[{"id":"login"}]},"meta":{"is_authenticated":false}}"#
  static let grant = #"{"grant":"g.r.ant","expires_in":60,"email":"owner@example.com"}"#

  @Test func passwordThenAuthenticatorThenTheBotThenSignedOutOfTheSite() async throws {
    let transport = ScriptedTransport([
      .http(401, Self.needsAuthenticator), .http(200, Self.signedIn), .http(200, Self.grant),
      .http(200, sessionJSON("a1", "r1")), .http(401, Self.signedOut),
    ])
    let account = AccountSignIn(client: .ios, transport: transport)
    #expect(try await account.signIn(email: "owner@example.com", password: "pw") == .secondFactor([.authenticator]))
    #expect(try await account.secondFactor(code: "123456") == .signedIn)
    let answer = try await account.botSession(name: "iPhone 3F2A1B7C")
    #expect(answer.session.accessToken == "a1" && answer.session.refreshToken == "r1")
    #expect(answer.email == "owner@example.com")

    let sent = transport.sent
    #expect(sent.map { $0.url?.absoluteString ?? "" } == [
      "https://tickr.bot/api/auth/app/v1/auth/login",
      "https://tickr.bot/api/auth/app/v1/auth/2fa/authenticate",
      "https://tickr.bot/api/app/bot-grant",
      "https://api.tickr.bot/session",
      "https://tickr.bot/api/auth/app/v1/auth/session",
    ])
    #expect(sent.map { $0.httpMethod ?? "" } == ["POST", "POST", "POST", "POST", "DELETE"])
    // The newest session token goes with each step; none goes to the bot.
    #expect(sent.map { $0.value(forHTTPHeaderField: "X-Session-Token") } == [nil, "s-1", "s-2", nil, "s-2"])
    #expect(transport.body(0)?["password"] as? String == "pw")
    #expect(transport.body(2)?["client_id"] as? String == "tickr-ios")
    #expect(transport.body(2)?["resource"] as? String == "https://api.tickr.bot")
    #expect(transport.body(3)?["grant"] as? String == "g.r.ant")
    #expect(transport.body(3)?["name"] as? String == "iPhone 3F2A1B7C")
  }

  @Test func theSiteSessionIsDeletedWhenTheBotRefuses() async throws {
    let refusal = #"{"error":"unauthorized","cause":"this tickr.bot account may not reach the bot","api_version":1}"#
    let transport = ScriptedTransport([
      .http(200, Self.signedIn), .http(200, Self.grant), .http(401, refusal), .http(401, Self.signedOut),
    ])
    let account = AccountSignIn(client: .mac, transport: transport)
    _ = try await account.signIn(email: "owner@example.com", password: "pw")
    await #expect(throws: APIError.self) { try await account.botSession(name: "Mac") }
    #expect(transport.sent.last?.httpMethod == "DELETE")
    #expect(transport.sent.last?.value(forHTTPHeaderField: "X-Session-Token") == "s-2")
  }

  @Test func theSiteSessionIsDeletedWhenTheGrantIsRefused() async throws {
    let transport = ScriptedTransport([
      .http(200, Self.signedIn), .http(403, #"{"error":"needs_passkey_or_authenticator"}"#), .http(401, Self.signedOut),
    ])
    let account = AccountSignIn(client: .ios, transport: transport)
    _ = try await account.confirmCode("ABCD-EFGH")
    await #expect(throws: AccountError.needsPasskeyOrAuthenticator) { try await account.botSession(name: "iPhone") }
    #expect(transport.sent.count == 3 && transport.sent.last?.httpMethod == "DELETE")
  }

  @Test func aWrongPasswordShowsTickrBotsOwnWords() async {
    let account = AccountSignIn(client: .ios, transport: ScriptedTransport([.http(400, Self.wrongPassword)]))
    let words = "The email address and/or password you specified are not correct."
    await #expect(throws: AccountError.refused(code: "email_password_mismatch", message: words)) {
      try await account.signIn(email: "owner@example.com", password: "no")
    }
    #expect(AccountError.refused(code: "email_password_mismatch", message: words).refusal == .wrongPassword)
    #expect(AccountError.refused(code: "too_many_login_attempts", message: "").refusal == .tooMany)
    #expect(AccountError.refused(code: nil, message: "").refusal == .other)
  }

  @Test func aRateLimitCarriesTheWaitTickrBotNamed() async {
    let body = #"{"status":429,"errors":[{"message":"Too many failed login attempts.","#
      + #""code":"too_many_login_attempts"}]}"#
    let named = AccountSignIn(client: .ios, transport: ScriptedTransport([.headed(429, body, ["Retry-After": "900"])]))
    await #expect(throws: AccountError.refused(code: "too_many_login_attempts",
      message: "Too many failed login attempts.", retryAfter: 900)) {
      try await named.signIn(email: "owner@example.com", password: "no")
    }
    let unnamed = AccountSignIn(client: .ios, transport: ScriptedTransport([.http(429, body)]))
    await #expect(throws: AccountError.refused(code: "too_many_login_attempts",
      message: "Too many failed login attempts.", retryAfter: nil)) {
      try await unnamed.signIn(email: "owner@example.com", password: "no")
    }
  }

  @Test func aSpentCodeAsksForANewOne() async throws {
    let transport = ScriptedTransport([.http(401, Self.codeSent), .http(409, #"{"status":409}"#)])
    let account = AccountSignIn(client: .ios, transport: transport)
    _ = try await account.requestCode(email: "owner@example.com")
    await #expect(throws: AccountError.codeSpent) { try await account.confirmCode("123456") }
  }

  @Test func anEmailedCodeIsRequestedThenConfirmed() async throws {
    let transport = ScriptedTransport([.http(401, Self.codeSent), .http(401, Self.needsAuthenticator)])
    let account = AccountSignIn(client: .ios, transport: transport)
    #expect(try await account.requestCode(email: "owner@example.com") == .codeSent)
    #expect(try await account.confirmCode("ABCD-EFGH") == .secondFactor([.authenticator]))
    #expect(transport.sent[1].value(forHTTPHeaderField: "X-Session-Token") == "s-code")
  }

  @Test func aPasskeyChallengeAndItsAssertion() async throws {
    let transport = ScriptedTransport([.http(200, Self.passkeyOptions), .http(200, Self.signedIn)])
    let account = AccountSignIn(client: .ios, transport: transport)
    let challenge = try await account.passkeyChallenge()
    #expect(challenge.relyingParty == "tickr.bot")
    #expect(Base64URL.encode(challenge.challenge) == "rx8Mbze0LVeLtgUaFhsF_U4mUHaqkW-IasCsUjXWFmw")
    #expect(transport.sent[0].httpMethod == "GET")
    let assertion = PasskeyAssertion(credentialID: Data([0xFB, 0xFF]), clientDataJSON: Data("c".utf8),
      authenticatorData: Data("a".utf8), signature: Data("s".utf8), userID: nil)
    #expect(try await account.signIn(passkey: assertion) == .signedIn)
    let credential = try #require(transport.body(1)?["credential"] as? [String: Any])
    #expect(credential["id"] as? String == "-_8" && credential["type"] as? String == "public-key")
    let response = try #require(credential["response"] as? [String: String])
    #expect(response == ["clientDataJSON": "Yw", "authenticatorData": "YQ", "signature": "cw"])
    #expect(transport.sent[1].value(forHTTPHeaderField: "X-Session-Token") == "s-passkey")
  }

  @Test func nothingIsDeletedWithoutASiteSession() async {
    let transport = ScriptedTransport([])
    await AccountSignIn(client: .ios, transport: transport).signOutOfSite()
    #expect(transport.sent.isEmpty)
  }

  @Test func base64URLRoundTripsWithoutPadding() {
    for bytes in [Data(), Data([0]), Data([0, 1]), Data([0xFB, 0xFF, 0xBF])] {
      #expect(Base64URL.decode(Base64URL.encode(bytes)) == bytes)
      #expect(!Base64URL.encode(bytes).contains("="))
    }
  }
}
