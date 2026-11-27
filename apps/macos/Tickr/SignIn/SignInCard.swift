import SwiftUI
import TickrDesign
import TickrKit

/// The step's card, built from the screens' card, rows and commands (mockup v174): the sign-in's
/// ways in; an emailed code; the second step; a recovery code; the reset email; the reset sent.
struct SignInCard: View {
  @Environment(SignInModel.self) private var model

  /// SF Symbols of the card's commands and fields.
  static let passkeySymbol = "person.badge.key"
  static let signInSymbol = "arrow.right"
  static let emailSymbol = "envelope"
  static let passwordSymbol = "lock"
  static let recoverySymbol = "key"
  static let shownSymbol = "eye"
  static let hiddenSymbol = "eye.slash"
  static let sentSymbol = "checkmark"

  var body: some View {
    Card(title, tone: .accent) {
      VStack(alignment: .leading, spacing: Tokens.Space.m) {
        switch model.step {
        case .main: ways
        case .code: emailedCode
        case .twoStep: secondStep
        case .recovery: recovery
        case .forgot: forgot
        case .sent: sent
        }
      }
    }
  }

  private var title: LocalizedStringResource {
    switch model.step {
    case .main: L10n.SignIn.card
    case .code: L10n.SignIn.codeCard
    case .twoStep: L10n.SignIn.twoCard
    case .recovery: L10n.SignIn.recoveryCard
    case .forgot: L10n.SignIn.forgotCard
    case .sent: L10n.SignIn.sentCard
    }
  }

  // MARK: Steps

  @ViewBuilder private var ways: some View {
    @Bindable var model = model
    command(L10n.SignIn.passkey, symbol: Self.passkeySymbol, tier: .primary, action: .passkey) {
      await model.signInWithPasskey()
    }
    OrDivider()
    SignInField(symbol: Self.emailSymbol, tone: .info) {
      TextField(text: $model.email) { Text(L10n.SignIn.email) }
        .signInEmail()
    }
    SignInField(symbol: Self.passwordSymbol, tone: .highlight) {
      Group {
        if model.showsPassword {
          TextField(text: $model.password) { Text(L10n.SignIn.password) }
        } else {
          SecureField(text: $model.password) { Text(L10n.SignIn.password) }
        }
      }
      .textContentType(.password)
      .onSubmit { Task { await model.signInWithPassword() } }
      Button { model.showsPassword.toggle() } label: {
        Image(systemName: model.showsPassword ? Self.hiddenSymbol : Self.shownSymbol)
          .foregroundStyle(Palette.textTertiary)
          .frame(minWidth: SignInLayout.control, minHeight: SignInLayout.control)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(Text(model.showsPassword ? L10n.SignIn.hidePassword : L10n.SignIn.showPassword))
    }
    command(L10n.SignIn.signIn, symbol: Self.signInSymbol, tier: .secondary(.accent), action: .password) {
      await model.signInWithPassword()
    }
    .disabled(!model.canSignIn)
    footer {
      CardFooterLink(L10n.SignIn.codeLink) { Task { await model.requestCode() } }
        .disabled(!model.canRequestCode)
      CardFooterLink(L10n.SignIn.forgot) { model.show(.forgot) }
    }
  }

  @ViewBuilder private var emailedCode: some View {
    @Bindable var model = model
    CodeCells(code: $model.code) { Task { await model.confirmCode() } }
    CodeFacts()
    command(L10n.SignIn.signIn, symbol: Self.signInSymbol, tier: .primary, action: .confirmCode) {
      await model.confirmCode()
    }
    .disabled(!model.canConfirmCode)
    footer {
      CardFooterLink(L10n.SignIn.resend) { Task { await model.requestCode() } }
        .disabled(!model.canRequestCode)
    }
  }

  @ViewBuilder private var secondStep: some View {
    @Bindable var model = model
    CodeCells(code: $model.code) { Task { await model.verify() } }
    command(L10n.SignIn.verify, symbol: Self.signInSymbol, tier: .primary, action: .verify) {
      await model.verify()
    }
    .disabled(!model.canVerify)
    footer {
      if model.factors.contains(.passkey) {
        CardFooterLink(L10n.SignIn.usePasskey) { Task { await model.verifyWithPasskey() } }
      }
      if model.factors.contains(.recoveryCode) {
        CardFooterLink(L10n.SignIn.useRecovery) { model.show(.recovery) }
      }
    }
  }

  @ViewBuilder private var recovery: some View {
    @Bindable var model = model
    SignInField(symbol: Self.recoverySymbol, tone: .warning) {
      TextField(text: $model.recoveryCode) { Text(L10n.SignIn.recoveryCard) }
        .textContentType(.oneTimeCode)
        .font(Tokens.Typography.bodyMono)
        .onSubmit { Task { await model.verify() } }
    }
    command(L10n.SignIn.verify, symbol: Self.signInSymbol, tier: .primary, action: .verify) {
      await model.verify()
    }
    .disabled(!model.canVerify)
    if model.factors.contains(.authenticator) {
      footer {
        CardFooterLink(L10n.SignIn.useAuthenticator) { model.show(.twoStep) }
      }
    }
  }

  @ViewBuilder private var forgot: some View {
    @Bindable var model = model
    SignInField(symbol: Self.emailSymbol, tone: .info) {
      TextField(text: $model.email) { Text(L10n.SignIn.email) }
        .signInEmail()
        .onSubmit { Task { await model.sendReset() } }
    }
    command(L10n.SignIn.sendReset, symbol: Self.emailSymbol, tier: .primary, action: .reset) {
      await model.sendReset()
    }
    .disabled(!model.canRequestCode)
  }

  @ViewBuilder private var sent: some View {
    SignInField(symbol: Self.emailSymbol, tone: .info) {
      Text(verbatim: model.email)
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textPrimary)
      Spacer(minLength: Tokens.Space.s)
      StatusPill(L10n.SignIn.sent, systemImage: Self.sentSymbol, tone: .profit)
    }
    Button { model.show(.main) } label: {
      Label { Text(L10n.SignIn.backToSignIn) } icon: { Image(systemName: Self.signInSymbol) }
    }
    .buttonStyle(.command(.primary))
  }

  // MARK: Pieces

  /// A command of the card: full width, its spinner while its step is sent.
  private func command(
    _ title: LocalizedStringResource, symbol: String, tier: CommandButtonStyle.Tier, action: SignInModel.Action,
    run: @escaping () async -> Void
  ) -> some View {
    Button { Task { await run() } } label: {
      Label { Text(title) } icon: { Image(systemName: symbol) }
        .frame(maxWidth: .infinity, minHeight: SignInLayout.control)
    }
    .buttonStyle(.command(tier))
    .inFlight(model.busy == action ? Text(L10n.SignIn.signing) : nil)
    .disabled(model.busy != nil && model.busy != action)
  }

  /// The footer rows reach the card's edges, as every card's footer links do.
  private func footer(@ViewBuilder _ rows: () -> some View) -> some View {
    VStack(spacing: .zero) { rows() }
  }
}

/// "— or —" between the passkey and email and password.
struct OrDivider: View {
  var body: some View {
    HStack(spacing: Tokens.Space.s) {
      line
      Text(L10n.SignIn.or)
        .font(Tokens.Typography.label)
        .foregroundStyle(Palette.textLabel)
        .fixedSize()
      line
    }
    .accessibilityHidden(true)
  }

  private var line: some View {
    Rectangle().fill(Palette.separator).frame(height: Tokens.Stroke.thin)
  }
}

/// A field row: a tile with the field's symbol in its tone, then the field.
struct SignInField<Content: View>: View {
  let symbol: String
  let tone: Tone
  let content: Content

  init(symbol: String, tone: Tone, @ViewBuilder content: () -> Content) {
    self.symbol = symbol
    self.tone = tone
    self.content = content()
  }

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
    HStack(spacing: Tokens.Space.m) {
      Image(systemName: symbol)
        .font(Tokens.Typography.symbol)
        .foregroundStyle(tone.text)
        .frame(width: Tokens.Size.iconButtonCompact, height: Tokens.Size.iconButtonCompact)
        .background(tone.fill.opacity(Tokens.Opacity.glow), in: RoundedRectangle(cornerRadius: Tokens.Radius.small))
        .accessibilityHidden(true)
      content
        .textFieldStyle(.plain)
        .font(Tokens.Typography.body)
    }
    .padding(.horizontal, Tokens.Space.m)
    .frame(minHeight: SignInLayout.control)
    .background(Palette.surfaceSunken, in: shape)
    .overlay(shape.strokeBorder(Palette.separator, lineWidth: Tokens.Stroke.thin))
  }
}

extension View {
  /// An email field: the account's address, no capitals or corrections.
  func signInEmail() -> some View {
    #if os(iOS)
    textContentType(.username)
      .keyboardType(.emailAddress)
      .textInputAutocapitalization(.never)
      .autocorrectionDisabled()
    #else
    textContentType(.username)
      .autocorrectionDisabled()
    #endif
  }
}
