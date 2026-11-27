import SwiftUI
import TickrDesign
import TickrKit

/// Why a sign-in step did not go through, as the screen's banner says it: its title, detail,
/// glyph and tone by cause (mockup v174): pink for a refused value, amber for something to wait
/// out or fix on the device, blue for a sign-in that ended on its own.
enum SignInProblem: Equatable {
  case wrongPassword, tooMany, noAccount, needsStrongFactor, offline, noPasskey, unreadable, keychain
  case codeWrong, authenticatorWrong, codeExpired
  /// A kept sign-in ended on its own (`SignInEnd`).
  case ended(SignInEnd)
  /// Another refusal: tickr.bot's or the bot's own words.
  case refused(String)

  /// The bot's statuses the screen tells apart: it does not accept this sign-in, or it limits tries.
  static let unauthorized = 401
  static let rateLimited = 429

  /// What an error of a step means for the screen; nil when nothing is said (the owner closed
  /// the passkey sheet). `secondStep`: a wrong code there is the authenticator's.
  static func of(_ error: any Error, secondStep: Bool = false) -> SignInProblem? {
    switch error {
    case let account as AccountError: return ofAccount(account, secondStep: secondStep)
    case let passkey as PasskeyFailure: return passkey == .closed ? nil : .noPasskey
    case let api as APIError:
      switch api {
      case .refused(let status, _, let cause):
        if status == unauthorized { return .noAccount }
        return status == rateLimited ? .tooMany : .refused(cause)
      case .unreachable: return .offline
      default: return .unreadable
      }
    case is URLError: return .offline
    default: return .unreadable
    }
  }

  /// What one of tickr.bot's account errors means; its own name, so `of` can never call itself.
  private static func ofAccount(_ error: AccountError, secondStep: Bool) -> SignInProblem {
    switch error {
    case .refused(_, let words):
      switch error.refusal {
      case .wrongPassword: .wrongPassword
      case .tooMany: .tooMany
      case .wrongCode: secondStep ? .authenticatorWrong : .codeWrong
      case .other, nil: .refused(words)
      }
    case .codeSpent: .codeExpired
    case .needsPasskeyOrAuthenticator: .needsStrongFactor
    case .notAllowed: .noAccount
    case .unreachable: .offline
    case .unreadable: .unreadable
    }
  }

  var title: LocalizedStringResource {
    switch self {
    case .wrongPassword: L10n.SignIn.wrongTitle
    case .tooMany: L10n.SignIn.manyTitle
    case .noAccount: L10n.SignIn.noAccountTitle
    case .needsStrongFactor: L10n.SignIn.strongTitle
    case .offline: L10n.SignIn.offlineTitle
    case .noPasskey: L10n.SignIn.noPasskeyTitle
    case .unreadable: L10n.SignIn.unreadableTitle
    case .keychain: L10n.SignIn.keychainTitle
    case .codeWrong, .authenticatorWrong: L10n.SignIn.codeWrongTitle
    case .codeExpired: L10n.SignIn.codeExpiredTitle
    case .ended(.expired): L10n.SignIn.sessionTitle
    case .ended(.revoked): L10n.SignIn.revokedTitle
    case .refused: L10n.SignIn.refusedTitle
    }
  }

  func detail(on device: SignInDevice) -> Text {
    switch self {
    case .wrongPassword: Text(L10n.SignIn.wrongDetail)
    case .tooMany: Text(L10n.SignIn.manyDetail)
    case .noAccount: Text(L10n.SignIn.noAccountDetail)
    case .needsStrongFactor: Text(L10n.SignIn.strongDetail)
    case .offline:
      switch device {
      case .mac: Text(L10n.SignIn.offlineMac)
      case .iPhone: Text(L10n.SignIn.offlineIPhone)
      case .iPad: Text(L10n.SignIn.offlineIPad)
      }
    case .noPasskey: Text(L10n.SignIn.noPasskeyDetail)
    case .unreadable: Text(L10n.SignIn.tryAgain)
    case .keychain: Text(L10n.SignIn.keychainDetail)
    case .codeWrong: Text(L10n.SignIn.codeWrongDetail)
    case .authenticatorWrong: Text(L10n.SignIn.authWrongDetail)
    case .codeExpired: Text(L10n.SignIn.codeExpiredDetail)
    case .ended: Text(L10n.SignIn.signInAgain)
    case .refused(let words): Text(words)
    }
  }

  var tone: Tone {
    switch self {
    case .wrongPassword, .noAccount, .needsStrongFactor, .noPasskey, .codeWrong, .authenticatorWrong, .refused,
      .unreadable:
      .loss
    case .tooMany, .offline, .codeExpired, .keychain: .warning
    case .ended: .info
    }
  }

  /// SF Symbols of the banner by cause.
  static let offlineSymbol = "wifi.slash"
  static let lockedSymbol = "lock"
  static let waitSymbol = "clock"
  static let endedSymbol = "info.circle"
  static let refusedSymbol = "exclamationmark.circle"

  var symbol: String {
    switch self {
    case .offline: Self.offlineSymbol
    case .noAccount, .needsStrongFactor, .noPasskey: Self.lockedSymbol
    case .tooMany, .codeExpired: Self.waitSymbol
    case .ended: Self.endedSymbol
    default: Self.refusedSymbol
    }
  }
}
