import ApertureKit
import SwiftUI

/// How the app words a refused entry: the bot's message, with the end of the refusal's window
/// when it has one ("… · until 10:44"); the code is the tooltip. Without the structured refusal,
/// the recorded "CAUSE: detail" text as it is.
enum RefusalText {
  static func text(_ refusal: RefusalV1?, cause: String?) -> String? {
    guard let refusal else { return cause }
    guard let until = refusal.until else { return refusal.message }
    return String(localized: L10n.Trades.refusedUntil(refusal.message, Format.marketMinute(until.date)))
  }
}
