import Foundation
import Observation

/// Whether this device is signed in with the bot, for the screens: the sign-in screen while it is
/// not, with why a kept sign-in ended (`SignInEnd`) and the account's email for "Signed in as".
/// One per app run (`Container.signInState`); the tokens themselves are `BotSession`'s.
@MainActor
@Observable
public final class SignInState {
  /// UserDefaults key of the signed-in account's email (shown in Settings; not a credential).
  static let emailKey = "signedInEmail"

  public private(set) var signedIn: Bool
  public private(set) var email: String?
  /// Why the last sign-in ended on its own; nil after signing out here or signing in.
  public private(set) var ended: SignInEnd?
  @ObservationIgnored private let defaults: UserDefaults

  public init(signedIn: Bool, defaults: UserDefaults = .standard) {
    self.signedIn = signedIn
    self.defaults = defaults
    email = signedIn ? defaults.string(forKey: Self.emailKey) : nil
  }

  /// The bot gave this device its tokens (kept by `BotSession`) for the account `email`. The bot
  /// holds no push token of a new sign-in, so `PushRegistrar` sends them all again.
  public func signedIn(email: String) {
    Container.shared.pushRegistrar().signedIn()
    self.email = email
    defaults.set(email, forKey: Self.emailKey)
    ended = nil
    signedIn = true
  }

  /// Signed out here, on purpose.
  public func signedOut() {
    forgetEmail()
    ended = nil
    signedIn = false
  }

  /// The sign-in ended without the owner asking (`BotSession`).
  public func end(_ why: SignInEnd) {
    guard signedIn else { return }
    forgetEmail()
    ended = why
    signedIn = false
  }

  private func forgetEmail() {
    email = nil
    defaults.removeObject(forKey: Self.emailKey)
  }
}
