import Foundation

/// The sign-in's banners and the Connection card's texts (L10n+SignIn.swift has the screens').
extension L10n.SignIn {
  /// Banner: tickr.bot refused the password.
  static var wrongTitle: LocalizedStringResource {
    LocalizedStringResource("signIn.wrongTitle", defaultValue: "Wrong email or password.", bundle: L10n.bundle)
  }
  static var wrongDetail: LocalizedStringResource {
    LocalizedStringResource("signIn.wrongDetail",
      defaultValue: "Check both and try again, or email yourself a code.",
      bundle: L10n.bundle)
  }
  /// Banner: tickr.bot's rate limit.
  static var manyTitle: LocalizedStringResource {
    LocalizedStringResource("signIn.manyTitle", defaultValue: "Too many attempts.", bundle: L10n.bundle)
  }
  /// `wait`: the time the server named, formatted ("15 min").
  static func manyWait(_ wait: String) -> LocalizedStringResource {
    LocalizedStringResource("signIn.manyWait", defaultValue: "Try again in \(wait).", bundle: L10n.bundle)
  }
  /// When the server named no time.
  static var manyLater: LocalizedStringResource {
    LocalizedStringResource("signIn.manyLater", defaultValue: "Try again later.", bundle: L10n.bundle)
  }
  /// Banner: the grant or the bot refused the account.
  static var noAccountTitle: LocalizedStringResource {
    LocalizedStringResource("signIn.noAccountTitle", defaultValue: "This account can't reach the bot.", bundle: L10n.bundle)
  }
  static var noAccountDetail: LocalizedStringResource {
    LocalizedStringResource("signIn.noAccountDetail",
      defaultValue: "Sign in with the account from your invite.",
      bundle: L10n.bundle)
  }
  /// Banner: a password or code alone is not enough for the bot.
  static var strongTitle: LocalizedStringResource {
    LocalizedStringResource("signIn.strongTitle", defaultValue: "This sign-in can't reach the bot.", bundle: L10n.bundle)
  }
  static var strongDetail: LocalizedStringResource {
    LocalizedStringResource("signIn.strongDetail",
      defaultValue: "Sign in with your passkey, or add an authenticator app on tickr.bot.",
      bundle: L10n.bundle)
  }
  /// Banner: tickr.bot or the bot could not be reached.
  static var offlineTitle: LocalizedStringResource {
    LocalizedStringResource("signIn.offlineTitle", defaultValue: "No network connection.", bundle: L10n.bundle)
  }
  static var offlineMac: LocalizedStringResource {
    LocalizedStringResource("signIn.offlineMac",
      defaultValue: "Check this Mac's Wi‑Fi or network, then try again.",
      bundle: L10n.bundle)
  }
  static var offlineIPhone: LocalizedStringResource {
    LocalizedStringResource("signIn.offlineIPhone",
      defaultValue: "Check Wi‑Fi or mobile data, then try again.",
      bundle: L10n.bundle)
  }
  static var offlineIPad: LocalizedStringResource {
    LocalizedStringResource("signIn.offlineIPad", defaultValue: "Check this iPad's Wi‑Fi, then try again.", bundle: L10n.bundle)
  }
  /// Banner: the kept sign-in ran out.
  static var sessionTitle: LocalizedStringResource {
    LocalizedStringResource("signIn.sessionTitle", defaultValue: "Your session expired.", bundle: L10n.bundle)
  }
  /// Banner: the bot revoked this device.
  static var revokedTitle: LocalizedStringResource {
    LocalizedStringResource("signIn.revokedTitle", defaultValue: "This device was signed out.", bundle: L10n.bundle)
  }
  /// Detail of the session and revoked banners.
  static var signInAgain: LocalizedStringResource {
    LocalizedStringResource("signIn.signInAgain", defaultValue: "Sign in again.", bundle: L10n.bundle)
  }
  /// Banner: the passkey sheet found none.
  static var noPasskeyTitle: LocalizedStringResource {
    LocalizedStringResource("signIn.noPasskeyTitle",
      defaultValue: "No passkey for tickr.bot on this device.",
      bundle: L10n.bundle)
  }
  static var noPasskeyDetail: LocalizedStringResource {
    LocalizedStringResource("signIn.noPasskeyDetail",
      defaultValue: "Use email and password, or create a passkey on tickr.bot from your invite on another device.",
      bundle: L10n.bundle)
  }
  /// Banner: a wrong code.
  static var codeWrongTitle: LocalizedStringResource {
    LocalizedStringResource("signIn.codeWrongTitle", defaultValue: "That code didn't work.", bundle: L10n.bundle)
  }
  static var codeWrongDetail: LocalizedStringResource {
    LocalizedStringResource("signIn.codeWrongDetail",
      defaultValue: "Check the latest email and enter its code.",
      bundle: L10n.bundle)
  }
  static var authWrongDetail: LocalizedStringResource {
    LocalizedStringResource("signIn.authWrongDetail",
      defaultValue: "Enter the code your authenticator app shows now.",
      bundle: L10n.bundle)
  }
  /// Banner: the emailed code ran out or its tries are spent.
  static var codeExpiredTitle: LocalizedStringResource {
    LocalizedStringResource("signIn.codeExpiredTitle", defaultValue: "This code expired.", bundle: L10n.bundle)
  }
  static var codeExpiredDetail: LocalizedStringResource {
    LocalizedStringResource("signIn.codeExpiredDetail",
      defaultValue: "Send a new one; each code lasts 15 min.",
      bundle: L10n.bundle)
  }
  /// Banner: another refusal, with tickr.bot's own words as the detail.
  static var refusedTitle: LocalizedStringResource {
    LocalizedStringResource("signIn.refusedTitle", defaultValue: "tickr.bot didn't accept that.", bundle: L10n.bundle)
  }
  /// Banner: an answer the app does not expect.
  static var unreadableTitle: LocalizedStringResource {
    LocalizedStringResource("signIn.unreadableTitle",
      defaultValue: "tickr.bot sent an answer this app can't read.",
      bundle: L10n.bundle)
  }
  static var tryAgain: LocalizedStringResource {
    LocalizedStringResource("signIn.tryAgain", defaultValue: "Try again.", bundle: L10n.bundle)
  }
  /// Banner: the Keychain refused the tokens.
  static var keychainTitle: LocalizedStringResource {
    LocalizedStringResource("signIn.keychainTitle", defaultValue: "This device couldn't keep the sign-in.", bundle: L10n.bundle)
  }
  static var keychainDetail: LocalizedStringResource {
    LocalizedStringResource("signIn.keychainDetail", defaultValue: "Unlock the device and sign in again.", bundle: L10n.bundle)
  }
  /// Settings' card of the sign-in.
  static var connection: LocalizedStringResource {
    LocalizedStringResource("signIn.connection", defaultValue: "Connection", bundle: L10n.bundle)
  }
  static func signedInMac(_ email: String) -> LocalizedStringResource {
    LocalizedStringResource("signIn.signedInMac", defaultValue: "Signed in as \(email) on this Mac", bundle: L10n.bundle)
  }
  static func signedInIPhone(_ email: String) -> LocalizedStringResource {
    LocalizedStringResource("signIn.signedInIPhone", defaultValue: "Signed in as \(email) on this iPhone", bundle: L10n.bundle)
  }
  static func signedInIPad(_ email: String) -> LocalizedStringResource {
    LocalizedStringResource("signIn.signedInIPad", defaultValue: "Signed in as \(email) on this iPad", bundle: L10n.bundle)
  }
  /// When the account's email was not kept.
  static var signedInNoEmail: LocalizedStringResource {
    LocalizedStringResource("signIn.signedInNoEmail", defaultValue: "Signed in on this device", bundle: L10n.bundle)
  }
  /// Settings row: the bot's address.
  static var bot: LocalizedStringResource {
    LocalizedStringResource("signIn.bot", defaultValue: "Bot", bundle: L10n.bundle)
  }
  /// Settings row: the link's state.
  static var statusRow: LocalizedStringResource {
    LocalizedStringResource("signIn.statusRow", defaultValue: "Status", bundle: L10n.bundle)
  }
  /// Settings' button.
  static var signOut: LocalizedStringResource {
    LocalizedStringResource("signIn.signOut", defaultValue: "Sign Out", bundle: L10n.bundle)
  }
  static var outHintMac: LocalizedStringResource {
    LocalizedStringResource("signIn.outHintMac",
      defaultValue: "Signs out this Mac only. Other devices stay signed in.",
      bundle: L10n.bundle)
  }
  static var outHintIPhone: LocalizedStringResource {
    LocalizedStringResource("signIn.outHintIPhone",
      defaultValue: "Signs out this iPhone only. Other devices stay signed in.",
      bundle: L10n.bundle)
  }
  static var outHintIPad: LocalizedStringResource {
    LocalizedStringResource("signIn.outHintIPad",
      defaultValue: "Signs out this iPad only. Other devices stay signed in.",
      bundle: L10n.bundle)
  }
  static var outQuestionMac: LocalizedStringResource {
    LocalizedStringResource("signIn.outQuestionMac", defaultValue: "Sign out of tickr.bot on this Mac?", bundle: L10n.bundle)
  }
  static var outQuestionIPhone: LocalizedStringResource {
    LocalizedStringResource("signIn.outQuestionIPhone",
      defaultValue: "Sign out of tickr.bot on this iPhone?",
      bundle: L10n.bundle)
  }
  static var outQuestionIPad: LocalizedStringResource {
    LocalizedStringResource("signIn.outQuestionIPad", defaultValue: "Sign out of tickr.bot on this iPad?", bundle: L10n.bundle)
  }
  static var outBody: LocalizedStringResource {
    LocalizedStringResource("signIn.outBody",
      defaultValue: "The bot revokes this device's key. Other devices stay signed in, and the bot keeps running.",
      bundle: L10n.bundle)
  }
  static var cancel: LocalizedStringResource {
    LocalizedStringResource("signIn.cancel", defaultValue: "Cancel", bundle: L10n.bundle)
  }
}
