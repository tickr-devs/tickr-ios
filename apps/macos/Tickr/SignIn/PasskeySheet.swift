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

  override public init() {}

  public func assertion(for challenge: PasskeyChallenge) async throws(PasskeyFailure) -> PasskeyAssertion {
    guard waiting == nil else { throw .closed }
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

  private func finish(_ result: Result<ASAuthorization, any Error>) {
    let continuation = waiting
    waiting = nil
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
    MainActor.assumeIsolated {
      #if os(macOS)
      NSApp.keyWindow ?? NSApp.windows.first ?? ASPresentationAnchor()
      #else
      UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first
        ?? ASPresentationAnchor()
      #endif
    }
  }
}
