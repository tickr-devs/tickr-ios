import SwiftUI
import TickrKit

/// How the app words a refused entry: its detail in the person's language, which names the end
/// of a cooldown itself; else the bot's message with the end of the refusal's window when it has
/// one ("… · until 10:44"). Without the structured refusal, the recorded "CAUSE: detail" text
/// read by `recorded(_:)`, so the code itself never shows.
enum RefusalText {
  static func text(_ refusal: RefusalV1?, cause: String?) -> String? {
    guard let refusal else { return cause.map(recorded) }
    if let detail = ApiText.refusalDetail(code: refusal.code, params: refusal.params) { return detail }
    guard let until = refusal.until else {
      // A refusal without values to name ("operator entry-stop is set") reads as its rule's
      // title in the person's language, never as the bot's English.
      if let known = RefusalCode(rawValue: refusal.code) { return String(localized: L10n.Cause.title(known)) }
      return refusal.message
    }
    return String(localized: L10n.Trades.refusedUntil(refusal.message, Format.marketMinute(until.date)))
  }

  /// A recorded "CODE: detail" in words: the rule's title and the detail with its times in New
  /// York; "Other reason" for a code this app does not know; prose without a code as written.
  static func recorded(_ text: String) -> String {
    let cause = RefusalCause(text)
    guard cause.hasCode else { return text }
    let title = String(localized: cause.known.map(L10n.Cause.title) ?? L10n.Cause.other)
    guard !cause.detail.isEmpty else { return title }
    return title + RefusalCause.separator + cause.readable(time: Format.marketMinute)
  }
}
