import Foundation
import Observation
import TickrKit

/// The numbers of tickr.bot's sign-in the screen shows (the web app's settings, docs in the web
/// repo's app sign-in notes): the emailed code's digits, lifetime and tries.
enum SignInLimits {
  /// Digits of an emailed code and of an authenticator code.
  static let codeLength = 6
  /// Seconds an emailed code lasts (tickr.bot's `ACCOUNT_LOGIN_BY_CODE_TIMEOUT`).
  static let codeLifetime: TimeInterval = 900
  /// Wrong codes tickr.bot takes before the code is spent (`ACCOUNT_LOGIN_BY_CODE_MAX_ATTEMPTS`).
  static let codeAttempts = 3
  /// Seconds between the code pill's countdown ticks.
  static let tick: Duration = .seconds(1)
}

/// The sign-in screens' state and steps (mockup v174): a passkey, email and password, or an
/// emailed code; then a second step when the account asks for one; then the bot's tokens for this
/// device (`AccountSignIn.botSession`, kept by `BotSession`), and `SignInState` turns the app to
/// its screens. "Forgot password?" sends tickr.bot's reset email; the reset finishes on the site.
/// Each way in starts a new tickr.bot sign-in; going back drops the one half done.
@MainActor
@Observable
final class SignInModel {
  enum Step: Equatable { case main, code, twoStep, recovery, forgot, sent }
  /// What is being sent: its button shows the spinner and the others wait.
  enum Action: Equatable { case passkey, password, requestCode, confirmCode, verify, reset }

  let device: SignInDevice
  private(set) var step: Step = .main
  var email = ""
  var password = ""
  var code = ""
  var recoveryCode = ""
  var showsPassword = false
  private(set) var busy: Action?
  private(set) var problem: SignInProblem?
  /// When the emailed code was sent, for its expiry pill.
  private(set) var codeSentAt: Date?
  private(set) var attemptsLeft = SignInLimits.codeAttempts
  /// The second steps the account offers.
  private(set) var factors: [SecondFactor] = []

  @ObservationIgnored private var account: AccountSignIn?
  @ObservationIgnored @Injected(\.botSession) private var session
  @ObservationIgnored @Injected(\.now) private var now
  @ObservationIgnored @Injected(\.passkeySheet) private var passkeys

  init(device: SignInDevice, ended: SignInEnd?) {
    self.device = device
    problem = ended.map(SignInProblem.ended)
  }

  /// The email as tickr.bot takes it.
  private var address: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }
  var canSignIn: Bool { !address.isEmpty && !password.isEmpty && busy == nil }
  var canRequestCode: Bool { !address.isEmpty && busy == nil }
  /// The code with the spaces and dashes a paste brings dropped.
  var digits: String { code.filter(\.isNumber) }
  var canConfirmCode: Bool { digits.count == SignInLimits.codeLength && busy == nil && attemptsLeft > .zero }
  var canVerify: Bool {
    busy == nil && (step == .recovery ? !recoveryCode.trimmingCharacters(in: .whitespaces).isEmpty
      : digits.count == SignInLimits.codeLength)
  }

  /// Seconds the emailed code has left at `moment`; zero once it ran out.
  func codeSecondsLeft(at moment: Date) -> Int {
    guard let codeSentAt else { return .zero }
    return max(.zero, Int((SignInLimits.codeLifetime - moment.timeIntervalSince(codeSentAt)).rounded(.up)))
  }

  // MARK: Ways in

  func signInWithPasskey() async {
    await run(.passkey) { account in
      let challenge = try await account.passkeyChallenge()
      let assertion = try await self.passkeys.assertion(for: challenge)
      return try await account.signIn(passkey: assertion)
    }
  }

  func signInWithPassword() async {
    guard canSignIn else { return }
    let email = address
    let password = password
    await run(.password) { account in try await account.signIn(email: email, password: password) }
  }

  /// "Email me a sign-in code" and "Resend code": a new code, a new count of tries.
  func requestCode() async {
    guard canRequestCode else { return }
    let email = address
    await run(.requestCode) { account in try await account.requestCode(email: email) }
  }

  func confirmCode() async {
    guard canConfirmCode, let account else { return }
    guard codeSecondsLeft(at: now()) > .zero else {
      problem = .codeExpired
      return
    }
    let digits = digits
    await send(.confirmCode, on: account) { try await account.confirmCode(digits) }
    if problem == .codeWrong {
      attemptsLeft -= 1
      code = ""
      if attemptsLeft == .zero { problem = .codeExpired }
    } else if problem == .codeExpired {
      attemptsLeft = .zero
    }
  }

  /// The second step with the authenticator's code, or a recovery code on that step.
  func verify() async {
    guard canVerify, let account else { return }
    let value = step == .recovery ? recoveryCode.trimmingCharacters(in: .whitespaces) : digits
    await send(.verify, on: account, secondStep: true) { try await account.secondFactor(code: value) }
    if problem == .authenticatorWrong { code = "" }
  }

  func verifyWithPasskey() async {
    guard busy == nil, let account else { return }
    await send(.passkey, on: account, secondStep: true) {
      let challenge = try await account.secondFactorPasskeyChallenge()
      let assertion = try await self.passkeys.assertion(for: challenge)
      return try await account.secondFactor(passkey: assertion)
    }
  }

  func sendReset() async {
    guard canRequestCode else { return }
    let email = address
    let account = Container.shared.accountSignIn(device.client)
    busy = .reset
    defer { busy = nil }
    do {
      try await account.requestPasswordReset(email: email)
      problem = nil
      step = .sent
    } catch {
      problem = SignInProblem.of(error)
    }
  }

  // MARK: Moving between steps

  func show(_ next: Step) {
    problem = nil
    if next == .twoStep || next == .recovery { code = "" }
    step = next
  }

  /// The back capsule: the recovery step goes back to the second step, every other step to the
  /// sign-in, dropping a half-done tickr.bot sign-in.
  func back() {
    if step == .recovery {
      show(.twoStep)
      return
    }
    dropAccount()
    code = ""
    show(.main)
  }

  private func dropAccount() {
    guard let account else { return }
    self.account = nil
    Task { await account.signOutOfSite() }
  }

  // MARK: Steps

  /// A first step: a new tickr.bot sign-in.
  private func run(_ action: Action, _ first: @escaping (AccountSignIn) async throws -> AccountStep) async {
    guard busy == nil else { return }
    dropAccount()
    let account = Container.shared.accountSignIn(device.client)
    self.account = account
    await send(action, on: account) { try await first(account) }
  }

  private func send(
    _ action: Action, on account: AccountSignIn, secondStep: Bool = false,
    _ step: @escaping () async throws -> AccountStep
  ) async {
    busy = action
    defer { busy = nil }
    do {
      let next = try await step()
      problem = nil
      try await advance(next, on: account)
    } catch {
      problem = SignInProblem.of(error, secondStep: secondStep)
    }
  }

  private func advance(_ next: AccountStep, on account: AccountSignIn) async throws {
    switch next {
    case .codeSent:
      codeSentAt = now()
      attemptsLeft = SignInLimits.codeAttempts
      code = ""
      step = .code
    case .secondFactor(let offered):
      factors = offered
      code = ""
      recoveryCode = ""
      if offered.contains(.authenticator) {
        step = .twoStep
      } else if offered.contains(.passkey) {
        step = .twoStep
        await verifyWithPasskey()
      } else {
        step = .recovery
      }
    case .signedIn:
      try await finish(on: account)
    }
  }

  /// tickr.bot signed in: the bot's tokens for this device, kept; tickr.bot's session is gone.
  private func finish(on account: AccountSignIn) async throws {
    self.account = nil
    let answer = try await account.botSession(name: device.botName)
    guard await session.signedIn(answer.session) else {
      problem = .keychain
      return
    }
    password = ""
    Container.shared.signInState().signedIn(email: answer.email)
  }
}
