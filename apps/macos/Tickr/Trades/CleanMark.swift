import SwiftUI
import TickrDesign
import TickrKit

/// A recorded day's clean-day verdict as a small mark: a seal for clean, a warning for not clean,
/// nothing while unknown. The verdict is the bot's, from its journal.
struct CleanMark: View {
  let clean: CleanDay

  var body: some View {
    Group {
      switch clean.verdict {
      case .clean:
        Image(systemName: Symbols.cleanDay).foregroundStyle(Palette.profitText)
      case .notClean:
        Image(systemName: Symbols.notCleanDay).foregroundStyle(Palette.warningText)
      case .unknown:
        EmptyView()
      }
    }
    .font(Tokens.Typography.caption)
    .tip(Text(verbatim: Self.text(clean)))
    .accessibilityLabel(Text(verbatim: Self.text(clean)))
  }

  /// The verdict in words: what made a day not clean, or why the verdict is unknown.
  static func text(_ clean: CleanDay) -> String {
    switch clean.verdict {
    case .clean:
      return String(localized: L10n.Trades.cleanDay)
    case .notClean:
      return String(localized: L10n.Trades.notCleanDay(
        clean.causes.map { ApiText.prose($0.textCodes, text: $0.text) }.joined(separator: Format.listSeparator)))
    case .unknown:
      return String(localized: L10n.Trades.cleanUnknown(ApiText.prose(clean.causeCodes, text: clean.cause) ?? Format.missing))
    }
  }
}

/// The shown day's verdict in its header, as the boards draw it: the shared `Badge` saying a clean
/// day or one that needs a look, with what made it so in the tooltip; nothing while the verdict is
/// unknown. Trades & days follows it with the records' agreement in words (`showsNote`), as
/// MacTrades does; the Overview header draws the badge alone.
struct CleanBadge: View {
  let clean: CleanDay
  /// The note after the badge ("records agree", "records differ").
  var showsNote = false

  /// Accessibility id of the badge, for the UI tests.
  static let id = "trades-clean-badge"

  var body: some View {
    switch clean.verdict {
    case .clean: badge(L10n.Trades.cleanBadge, note: L10n.Trades.recordsAgree, color: Palette.profitText)
    case .notClean: badge(L10n.Trades.needsLookBadge, note: L10n.Trades.recordsDiffer, color: Palette.warningText)
    case .unknown: EmptyView()
    }
  }

  private func badge(_ title: LocalizedStringResource, note: LocalizedStringResource, color: Color) -> some View {
    HStack(spacing: Tokens.Space.s) {
      Badge(title, color: color)
      if showsNote {
        Text(note)
          .font(Tokens.Typography.captionMono)
          .foregroundStyle(Palette.textQuaternary)
      }
    }
    .tip(Text(verbatim: CleanMark.text(clean)))
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier(Self.id)
  }
}
