import Foundation

/// What a failed call to the bot's API throws, each said in the person's language.
public enum APIError: Error, LocalizedError, Equatable {
  /// The API answered with a typed refusal (error-v1); `cause` in the person's language when the
  /// bot sent a code this app knows (`ErrorV1.causeText`), else the bot's own words.
  case refused(status: Int, error: String, cause: String)
  /// The answer does not match contract v1.
  case contract(String)
  /// The API could not be reached.
  case unreachable(String)
  /// A read the bot has no route for (404 `not_found` on a GET that names no record): a bot
  /// older than the app, or, for the demo day, a read its recording does not hold. Said in the
  /// person's language, never as "API refused (404 not_found): no resource '/movers'".
  case notServed(demo: Bool)

  public var errorDescription: String? {
    switch self {
    case .refused(let status, let error, let cause): return String(localized: L10n.apiRefused(status, error, cause))
    case .contract(let detail): return String(localized: L10n.apiContract(detail))
    case .unreachable(let detail): return String(localized: L10n.apiUnreachable(detail))
    case .notServed(let demo): return String(localized: demo ? L10n.apiNotRecordedDemo : L10n.apiNotServed)
    }
  }
}

/// Any error as the apps show it: its own description in the person's language when it has
/// one (APIError, ContractError), a plain "unexpected error" otherwise; never Swift's English
/// debug form of the error.
public enum ErrorText {
  /// What a failed read shows, or nil for a cancelled one: whoever cancelled it has moved on,
  /// so it shows nothing.
  public static func describe(_ error: Error) -> String? {
    error is CancellationError ? nil : text(error)
  }

  /// Always a sentence, for a failure the person must see even when it was cancelled (a
  /// command that may not have been sent).
  public static func text(_ error: Error) -> String {
    (error as? LocalizedError)?.errorDescription ?? String(localized: L10n.unexpectedError)
  }
}
