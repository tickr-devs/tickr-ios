import AuthenticationServices
import TickrKit
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Why the system's passkey sheet came back without a passkey.
public enum PasskeyFailure: Error, Equatable, Sendable {
  /// The owner closed the sheet: nothing is said.
  case closed
  /// The sheet found no passkey for tickr.bot here, or could not use one.
  case noPasskey
}

/// The system's passkey sheet for a tickr.bot challenge. A protocol so tests answer it.
@MainActor
public protocol PasskeySheet {
  func assertion(for challenge: PasskeyChallenge) async throws(PasskeyFailure) -> PasskeyAssertion
}

/// The real sheet: `ASAuthorizationController` with the platform's passkeys for tickr.bot (the
/// app's associated domain `webcredentials:tickr.bot`). One request at a time.
@MainActor
public final class SystemPasskeySheet: NSObject, PasskeySheet {
  private var waiting: CheckedContinuation<ASAuthorization, any Error>?
  /// The window the sheet shows over, found as a request starts.
  private var anchor: ASPresentationAnchor?

  override public init() {}

  public func assertion(for challenge: PasskeyChallenge) async throws(PasskeyFailure) -> PasskeyAssertion {
    guard waiting == nil else { throw .closed }
    // No window to show the sheet over: no passkey can be used here.
    guard let window = Self.keyWindow() else { throw .noPasskey }
    anchor = window
    let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: challenge.relyingParty)
    let request = provider.createCredentialAssertionRequest(challenge: challenge.challenge)
    let controller = ASAuthorizationController(authorizationRequests: [request])
    controller.delegate = self
    controller.presentationContextProvider = self
    let authorization: ASAuthorization
    do {
      authorization = try await withCheckedThrowingContinuation { continuation in
        waiting = continuation
        controller.performRequests()
      }
    } catch let error as ASAuthorizationError where error.code == .canceled {
      throw .closed
    } catch {
      throw .noPasskey
    }
    guard let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion else {
      throw .noPasskey
    }
    return PasskeyAssertion(credentialID: credential.credentialID, clientDataJSON: credential.rawClientDataJSON,
      authenticatorData: credential.rawAuthenticatorData, signature: credential.signature,
      userID: credential.userID)
  }

  /// The app's key window, or its first one.
  private static func keyWindow() -> ASPresentationAnchor? {
    #if os(macOS)
    NSApp.keyWindow ?? NSApp.windows.first
    #else
    let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    return windows.compactMap(\.keyWindow).first ?? windows.flatMap(\.windows).first
    #endif
  }

  private func finish(_ result: Result<ASAuthorization, any Error>) {
    let continuation = waiting
    waiting = nil
    anchor = nil
    continuation?.resume(with: result)
  }
}

extension SystemPasskeySheet: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
  nonisolated public func authorizationController(
    controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization
  ) {
    MainActor.assumeIsolated { finish(.success(authorization)) }
  }

  nonisolated public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: any Error) {
    MainActor.assumeIsolated { finish(.failure(error)) }
  }

  nonisolated public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    // Asked only while a request runs, and a request starts only with a window (`assertion(for:)`).
    MainActor.assumeIsolated {
      guard let anchor else { preconditionFailure() }
      return anchor
    }
  }
}
