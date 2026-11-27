import FactoryTesting
import Foundation
import Synchronization
import Testing
import TickrKit
@testable import TickrScreens

/// tickr.bot's answers by path for the sign-in tests, each path's answers in turn.
final class SignInRoutes: URLProtocol {
  static let answers = Mutex<[String: [(Int, String)]]>([:])

  static func session(_ answers: [String: [(Int, String)]]) -> URLSession {
    Self.answers.withLock { $0 = answers }
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [SignInRoutes.self]
    return URLSession(configuration: configuration)
  }

  override static func canInit(with request: URLRequest) -> Bool { true }
  override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func stopLoading() {}

  override func startLoading() {
    guard let url = request.url else { return }
    let path = url.path()
    let answer = Self.answers.withLock { answers -> (Int, String)? in
      guard var list = answers[path], !list.isEmpty else { return nil }
      let first = list.removeFirst()
      answers[path] = list
      return first
    }
    guard let (status, body) = answer,
      let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)
    else {
      client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
      return
    }
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Data(body.utf8))
    client?.urlProtocolDidFinishLoading(self)
  }
}

/// A passkey sheet the owner closes.
@MainActor
struct ClosedSheet: PasskeySheet {
  func assertion(for challenge: PasskeyChallenge) async throws(PasskeyFailure) -> PasskeyAssertion {
    throw .closed
  }
}

/// The sign-in screens' steps (SignInModel.swift) against tickr.bot's recorded answers.
@MainActor
@Suite("Sign-in model", .container, .serialized)
struct SignInModelTests {
  static let login = "/api/auth/app/v1/auth/login"
  static let codeRequest = "/api/auth/app/v1/auth/code/request"
  static let codeConfirm = "/api/auth/app/v1/auth/code/confirm"
  static let passkeyLogin = "/api/auth/app/v1/auth/webauthn/login"
  static let wrongPassword = #"{"status":400,"errors":[{"message":"No.","code":"email_password_mismatch"}]}"#
  static let wrongCode = #"{"status":400,"errors":[{"message":"No.","code":"incorrect_code"}]}"#
  static let codeSent = #"{"status":401,"data":{"flows":[{"id":"login_by_code","is_pending":true}]},"#
    + #""meta":{"session_token":"s-1"}}"#
  static let passkeyOptions = #"{"status":200,"data":{"request_options":{"publicKey":{"#
    + #""challenge":"rx8Mbze0LVeLtgUaFhsF_U4mUHaqkW-IasCsUjXWFmw","rpId":"tickr.bot"}}}}"#

  func model(_ answers: [String: [(Int, String)]]) -> SignInModel {
    let session = SignInRoutes.session(answers)
    Container.shared.urlSession.register { session }
    return SignInModel(device: .mac, ended: nil)
  }

  @Test("A wrong password shows its banner and stays on the sign-in")
  func wrongPassword() async {
    let model = model([Self.login: [(400, Self.wrongPassword)]])
    model.email = "owner@example.com"
    model.password = "no"
    await model.signInWithPassword()
    #expect(model.problem == .wrongPassword && model.step == .main && model.busy == nil)
  }

  @Test("An emailed code takes three wrong tries, then asks for a new one")
  func codeTries() async {
    let wrong = Array(repeating: (400, Self.wrongCode), count: SignInLimits.codeAttempts)
    let model = model([Self.codeRequest: [(401, Self.codeSent)], Self.codeConfirm: wrong])
    model.email = "owner@example.com"
    await model.requestCode()
    #expect(model.step == .code && model.attemptsLeft == SignInLimits.codeAttempts)
    for left in (0..<SignInLimits.codeAttempts).reversed() {
      model.code = "123-456"
      await model.confirmCode()
      #expect(model.attemptsLeft == left && model.code.isEmpty)
    }
    #expect(model.problem == .codeExpired && !model.canConfirmCode)
  }

  @Test("Closing the passkey sheet says nothing")
  func closedPasskeySheet() async {
    Container.shared.passkeySheet.register { ClosedSheet() }
    let model = model([Self.passkeyLogin: [(200, Self.passkeyOptions)]])
    await model.signInWithPasskey()
    #expect(model.problem == nil && model.step == .main)
  }

  @Test("A kept sign-in that ended says why, in blue")
  func endedSignIn() {
    let model = SignInModel(device: .iPad, ended: .revoked)
    #expect(model.problem == .ended(.revoked) && model.problem?.tone == .info)
  }
}
