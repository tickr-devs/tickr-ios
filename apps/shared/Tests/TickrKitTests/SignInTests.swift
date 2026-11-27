import Foundation
import Testing
@testable import TickrKit

/// The tickr.bot sign-in's pieces (SignIn.swift): the page it opens, the answer it accepts and the
/// grant request, with a fixed verifier and state.
@Suite struct SignInTests {
  /// RFC 7636 appendix B: this verifier's S256 challenge.
  static let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
  static let challenge = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
  static let state = "state-1"

  private var signIn: SignIn { SignIn(client: .ios, verifier: Self.verifier, state: Self.state) }

  private func items(_ url: URL) -> [String: String] {
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
  }

  @Test func theChallengeIsRFC7636s() {
    #expect(SignIn.challenge(Self.verifier) == Self.challenge)
  }

  @Test func theSignInPageAsksForTheBotWithPKCE() {
    let url = signIn.authorizeURL
    #expect(url.absoluteString.hasPrefix("https://tickr.bot/identity/o/authorize?"))
    #expect(items(url) == [
      "response_type": "code", "client_id": "tickr-ios", "redirect_uri": "tickr://signin", "scope": "bot",
      "state": Self.state, "code_challenge": Self.challenge, "code_challenge_method": "S256",
      "resource": "https://api.tickr.bot",
    ])
  }

  @Test func eachSignInHasItsOwnVerifierAndState() {
    let first = SignIn(client: .mac)
    let second = SignIn(client: .mac)
    #expect(first.verifier != second.verifier && first.state != second.state)
    #expect(first.verifier.count == 43)
  }

  @Test func theAnswerGivesTheCodeOnlyForThisSignIn() throws {
    let answer = try #require(URL(string: "tickr://signin?code=abc&state=\(Self.state)"))
    #expect(try signIn.code(from: answer) == "abc")
    for other in ["tickr://signin?code=abc&state=other", "tickr://pair?code=abc&state=\(Self.state)",
      "https://signin?code=abc&state=\(Self.state)", "tickr://signin?state=\(Self.state)"] {
      #expect(throws: SignInError.notThisSignIn) { try signIn.code(from: try #require(URL(string: other))) }
    }
  }

  @Test func aDeniedAccountIsARefusal() throws {
    let answer = try #require(URL(string: "tickr://signin?error=access_denied&state=\(Self.state)"))
    #expect(throws: SignInError.refused("access_denied")) { try signIn.code(from: answer) }
  }

  @Test func theGrantRequestSendsTheCodeAndVerifierAsAForm() throws {
    let request = signIn.grantRequest(code: "a+b&c")
    #expect(request.httpMethod == "POST")
    #expect(request.url?.absoluteString == "https://tickr.bot/identity/o/api/token")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
    let body = try #require(String(bytes: try #require(request.httpBody), encoding: .utf8))
    var form = URLComponents()
    form.percentEncodedQuery = body
    let sent = Dictionary(uniqueKeysWithValues: (form.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    #expect(sent == [
      "grant_type": "authorization_code", "code": "a+b&c", "redirect_uri": "tickr://signin",
      "client_id": "tickr-ios", "code_verifier": Self.verifier, "resource": "https://api.tickr.bot",
    ])
  }

  @Test func theGrantIsTheAccessToken() throws {
    let answer = Data(#"{"access_token":"g","expires_in":60,"token_type":"Bearer","scope":"bot"}"#.utf8)
    #expect(try SignIn.grant(from: answer, status: 200) == "g")
    #expect(throws: SignInError.tokenRefused(400)) { try SignIn.grant(from: answer, status: 400) }
    #expect(throws: SignInError.unreadable) { try SignIn.grant(from: Data("{}".utf8), status: 200) }
  }

  @Test func theDeviceNameKeepsWhatTheBotTakes() {
    #expect(SignIn.deviceName("Valentyn\u{2019}s iPhone") == "Valentyns iPhone")
    #expect(SignIn.deviceName(" -MacBook Pro (2) ") == "MacBook Pro 2")
    #expect(SignIn.deviceName("\u{1F4F1}") == "device")
  }
}
