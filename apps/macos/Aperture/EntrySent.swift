import ApertureDesign
import ApertureKit
import SwiftUI

/// "One send per decision", as the app shows it: an entry sent exactly once reads quietly, any
/// other count is an alarm, and a missing record is a warning with the bot's cause.
enum EntrySent {
  /// One entry's line: "Once · acknowledged", "2 sends · outcome unknown", "Not recorded". The
  /// help is the bot's cause of a missing record; the client order id is never shown.
  static func line(_ entry: EntrySend, cause: String?) -> (text: String, color: Color, help: String?) {
    guard let sends = entry.sends else {
      return (String(localized: L10n.EntrySent.notRecorded), Palette.warningText, cause)
    }
    let sent = String(localized: sends == 1 ? L10n.EntrySent.once : L10n.EntrySent.times(sends))
    let outcome = (entry.latestOutcome ?? entry.sendOutcome).map { String(localized: $0.title) }
    let text = outcome.map { String(localized: L10n.EntrySent.withOutcome(sent, $0)) } ?? sent
    let color = entry.sentOtherThanOnce ? Palette.lossText : awaitsBroker(entry) ? Palette.warningText : Palette.textPrimary
    return (text, color, nil)
  }

  /// The send's latest state is not a broker answer yet: not sent, no answer, or unknown.
  static func awaitsBroker(_ entry: EntrySend) -> Bool {
    switch entry.latestOutcome ?? entry.sendOutcome {
    case .intent, .attempted, .unknown: true
    case .acknowledged, .refused, .absent, nil: false
    }
  }

  /// The Safety card's row over today's entries (open positions and closed trades): the first
  /// entry sent other than once, else how many have no record, else how many await the broker's
  /// answer, else all once; nil without entries.
  static func summary(_ entries: [(symbol: String, entry: EntrySend)]) -> (text: String, tone: Tone)? {
    guard !entries.isEmpty else { return nil }
    if let breach = entries.first(where: { $0.entry.sentOtherThanOnce }), let sends = breach.entry.sends {
      return (String(localized: L10n.EntrySent.breach(breach.symbol, sends)), .loss)
    }
    let unrecorded = entries.filter { $0.entry.sends == nil }.count
    if unrecorded > 0 {
      return (String(localized: L10n.EntrySent.unrecorded(unrecorded)), .warning)
    }
    let awaiting = entries.filter { awaitsBroker($0.entry) }.count
    if awaiting > 0 {
      return (String(localized: L10n.EntrySent.awaiting(awaiting)), .warning)
    }
    return (String(localized: L10n.EntrySent.allOnce(entries.count)), .profit)
  }
}

extension SendOutcome {
  var title: LocalizedStringResource {
    switch self {
    case .intent: L10n.EntrySent.intent
    case .attempted: L10n.EntrySent.attempted
    case .acknowledged: L10n.EntrySent.acknowledged
    case .refused: L10n.EntrySent.refused
    case .unknown: L10n.EntrySent.unknown
    case .absent: L10n.EntrySent.absent
    }
  }
}
