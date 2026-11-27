import Foundation

/// The sign-in screens and the Connection card (mockup v174, boards MacSignIn, IOSSignIn,
/// IPadSignIn, MacSystem and IOSSystem): every text in English, Spanish in Localizable.xcstrings.
extension L10n {
  enum SignIn {
    /// The sign-in screen's title.
    static var title: LocalizedStringResource {
      LocalizedStringResource("signIn.title", defaultValue: "Sign in to tickr.bot", bundle: L10n.bundle)
    }
    /// Under the title: there is no sign-up.
    static var line: LocalizedStringResource {
      LocalizedStringResource("signIn.line",
        defaultValue: "Accounts are by invite. Use the email from your invite.",
        bundle: L10n.bundle)
    }
    /// The card's header.
    static var card: LocalizedStringResource {
      LocalizedStringResource("signIn.card", defaultValue: "Sign in", bundle: L10n.bundle)
    }
    /// The primary way in.
    static var passkey: LocalizedStringResource {
      LocalizedStringResource("signIn.passkey", defaultValue: "Sign in with passkey", bundle: L10n.bundle)
    }
    /// The divider between the passkey and email and password.
    static var or: LocalizedStringResource {
      LocalizedStringResource("signIn.or", defaultValue: "or", bundle: L10n.bundle)
    }
    /// The email field.
    static var email: LocalizedStringResource {
      LocalizedStringResource("signIn.email", defaultValue: "Email", bundle: L10n.bundle)
    }
    /// The password field.
    static var password: LocalizedStringResource {
      LocalizedStringResource("signIn.password", defaultValue: "Password", bundle: L10n.bundle)
    }
    /// The eye button, password hidden.
    static var showPassword: LocalizedStringResource {
      LocalizedStringResource("signIn.showPassword", defaultValue: "Show password", bundle: L10n.bundle)
    }
    /// The eye button, password shown.
    static var hidePassword: LocalizedStringResource {
      LocalizedStringResource("signIn.hidePassword", defaultValue: "Hide password", bundle: L10n.bundle)
    }
    /// Sends email and password, or the emailed code.
    static var signIn: LocalizedStringResource {
      LocalizedStringResource("signIn.signIn", defaultValue: "Sign In", bundle: L10n.bundle)
    }
    /// VoiceOver, while a step is sent.
    static var signing: LocalizedStringResource {
      LocalizedStringResource("signIn.signing", defaultValue: "Signing in…", bundle: L10n.bundle)
    }
    /// Footer row: sign in with an emailed code.
    static var codeLink: LocalizedStringResource {
      LocalizedStringResource("signIn.codeLink", defaultValue: "Email me a sign-in code", bundle: L10n.bundle)
    }
    /// Footer row: the reset by email.
    static var forgot: LocalizedStringResource {
      LocalizedStringResource("signIn.forgot", defaultValue: "Forgot password?", bundle: L10n.bundle)
    }
    /// The code step's title.
    static var codeTitle: LocalizedStringResource {
      LocalizedStringResource("signIn.codeTitle", defaultValue: "Check your email", bundle: L10n.bundle)
    }
    /// The code step's line.
    static func codePrompt(_ email: String) -> LocalizedStringResource {
      LocalizedStringResource("signIn.codePrompt",
        defaultValue: "Enter the 6-digit code we sent to \(email).",
        bundle: L10n.bundle)
    }
    /// The code step's card.
    static var codeCard: LocalizedStringResource {
      LocalizedStringResource("signIn.codeCard", defaultValue: "Email code", bundle: L10n.bundle)
    }
    /// The code cells, for VoiceOver.
    static var codeField: LocalizedStringResource {
      LocalizedStringResource("signIn.codeField", defaultValue: "Code", bundle: L10n.bundle)
    }
    /// Footer row of the code step.
    static var resend: LocalizedStringResource {
      LocalizedStringResource("signIn.resend", defaultValue: "Resend code", bundle: L10n.bundle)
    }
    /// The code's expiry pill (m:ss).
    static func expiresIn(_ left: String) -> LocalizedStringResource {
      LocalizedStringResource("signIn.expiresIn", defaultValue: "Expires in \(left)", bundle: L10n.bundle)
    }
    /// The code's expiry pill once it ran out.
    static var expired: LocalizedStringResource {
      LocalizedStringResource("signIn.expired", defaultValue: "Expired", bundle: L10n.bundle)
    }
    /// The code's attempts badge.
    static func attemptsLeft(_ count: Int) -> LocalizedStringResource {
      LocalizedStringResource("signIn.attemptsLeft", defaultValue: "\(count) attempts left", bundle: L10n.bundle)
    }
    /// The reset step's title.
    static var forgotTitle: LocalizedStringResource {
      LocalizedStringResource("signIn.forgotTitle", defaultValue: "Reset password", bundle: L10n.bundle)
    }
    /// The reset step's line.
    static var forgotPrompt: LocalizedStringResource {
      LocalizedStringResource("signIn.forgotPrompt",
        defaultValue: "Enter your account email. We'll email you a link; you set the new password on tickr.bot in your browser.",
        bundle: L10n.bundle)
    }
    /// The reset step's card.
    static var forgotCard: LocalizedStringResource {
      LocalizedStringResource("signIn.forgotCard", defaultValue: "Account email", bundle: L10n.bundle)
    }
    /// Sends the reset email.
    static var sendReset: LocalizedStringResource {
      LocalizedStringResource("signIn.sendReset", defaultValue: "Send Reset Link", bundle: L10n.bundle)
    }
    /// The sent step's line.
    static func sentPrompt(_ email: String) -> LocalizedStringResource {
      LocalizedStringResource("signIn.sentPrompt",
        // swiftlint:disable:next line_length
        defaultValue: "If \(email) has an account, a reset link is on its way. Open it in your browser, set the new password on tickr.bot, then sign in here.",
        bundle: L10n.bundle)
    }
    /// The sent step's card.
    static var sentCard: LocalizedStringResource {
      LocalizedStringResource("signIn.sentCard", defaultValue: "Reset link", bundle: L10n.bundle)
    }
    /// The sent step's mark next to the email.
    static var sent: LocalizedStringResource {
      LocalizedStringResource("signIn.sent", defaultValue: "Sent", bundle: L10n.bundle)
    }
    /// The sent step's button.
    static var backToSignIn: LocalizedStringResource {
      LocalizedStringResource("signIn.backToSignIn", defaultValue: "Back to Sign In", bundle: L10n.bundle)
    }
    /// The second step's title.
    static var twoTitle: LocalizedStringResource {
      LocalizedStringResource("signIn.twoTitle", defaultValue: "Two-step verification", bundle: L10n.bundle)
    }
    /// The second step's line.
    static var twoPrompt: LocalizedStringResource {
      LocalizedStringResource("signIn.twoPrompt",
        defaultValue: "Enter the 6-digit code from your authenticator app.",
        bundle: L10n.bundle)
    }
    /// The second step's card.
    static var twoCard: LocalizedStringResource {
      LocalizedStringResource("signIn.twoCard", defaultValue: "Authenticator app", bundle: L10n.bundle)
    }
    /// Sends the second step's code.
    static var verify: LocalizedStringResource {
      LocalizedStringResource("signIn.verify", defaultValue: "Verify", bundle: L10n.bundle)
    }
    /// Footer row: the passkey as the second step.
    static var usePasskey: LocalizedStringResource {
      LocalizedStringResource("signIn.usePasskey", defaultValue: "Use passkey instead", bundle: L10n.bundle)
    }
    /// Footer row: a recovery code as the second step.
    static var useRecovery: LocalizedStringResource {
      LocalizedStringResource("signIn.useRecovery", defaultValue: "Use a recovery code", bundle: L10n.bundle)
    }
    /// The recovery step's line.
    static var recoveryPrompt: LocalizedStringResource {
      LocalizedStringResource("signIn.recoveryPrompt",
        defaultValue: "Enter one of your recovery codes. Each code works once.",
        bundle: L10n.bundle)
    }
    /// The recovery step's card and field.
    static var recoveryCard: LocalizedStringResource {
      LocalizedStringResource("signIn.recoveryCard", defaultValue: "Recovery code", bundle: L10n.bundle)
    }
    /// Footer row: back to the authenticator code.
    static var useAuthenticator: LocalizedStringResource {
      LocalizedStringResource("signIn.useAuthenticator", defaultValue: "Use authenticator code", bundle: L10n.bundle)
    }
    /// The back capsule's title on a step under the sign-in.
    static var backSignIn: LocalizedStringResource {
      LocalizedStringResource("signIn.backSignIn", defaultValue: "Sign In", bundle: L10n.bundle)
    }
    /// The back capsule's title on the recovery step.
    static var backTwoStep: LocalizedStringResource {
      LocalizedStringResource("signIn.backTwoStep", defaultValue: "Two-step", bundle: L10n.bundle)
    }
    /// The status pill: this device has a network path.
    static var online: LocalizedStringResource {
      LocalizedStringResource("signIn.online", defaultValue: "ONLINE", bundle: L10n.bundle)
    }
    /// The status pill: this device has no network path.
    static var offline: LocalizedStringResource {
      LocalizedStringResource("signIn.offline", defaultValue: "OFFLINE", bundle: L10n.bundle)
    }
    /// The status pill: the bot's host and the state.
    static func status(_ host: String, _ state: String) -> LocalizedStringResource {
      LocalizedStringResource("signIn.status", defaultValue: "\(host) · \(state)", bundle: L10n.bundle)
    }
    /// The Mac's brand column under the mark.
    static var operatorName: LocalizedStringResource {
      LocalizedStringResource("signIn.operatorName", defaultValue: "Tickr Operator", bundle: L10n.bundle)
    }
  }
}
