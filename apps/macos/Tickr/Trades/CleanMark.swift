import SwiftUI
import TickrDesign
import TickrKit

/// A recorded day's clean-day verdict as a small mark: a seal for clean, a warning for not clean,
/// nothing while unknown. The verdict is the bot's, from its journal.
struct CleanMark: View {
  let clean: CleanDay

  /// SF Symbol of a clean day.
  static let cleanSymbol = "checkmark.seal.fill"
  /// SF Symbol of a day that was not clean.
  static let notCleanSymbol = "exclamationmark.triangle.fill"

  var body: some View {
    Group {
      switch clean.verdict {
      case .clean:
        Image(systemName: Self.cleanSymbol).foregroundStyle(Palette.profitText)
      case .notClean:
        Image(systemName: Self.notCleanSymbol).foregroundStyle(Palette.warningText)
      case .unknown:
        EmptyView()
      }
    }
    .font(Tokens.Typography.caption)
    .help(Text(verbatim: Self.text(clean)))
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

/// The shown day's verdict in its header: a clean day, or one that needs a look, with what made
/// it so in the tooltip; nothing while the verdict is unknown.
struct CleanBadge: View {
  let clean: CleanDay
  /// The verdict's symbol before the badge; the Overview header draws the badge alone.
  var showsSymbol = true

  /// Accessibility id of the badge, for the UI tests.
  static let id = "trades-clean-badge"

  var body: some View {
    switch clean.verdict {
    case .clean: badge(L10n.Trades.cleanBadge, symbol: CleanMark.cleanSymbol, color: Palette.profitText)
    case .notClean: badge(L10n.Trades.needsLookBadge, symbol: CleanMark.notCleanSymbol, color: Palette.warningText)
    case .unknown: EmptyView()
    }
  }

  private func badge(_ title: LocalizedStringResource, symbol: String, color: Color) -> some View {
    HStack(spacing: Tokens.Space.xs) {
      if showsSymbol {
        Image(systemName: symbol).foregroundStyle(color)
      }
      Badge(title, color: color)
    }
    .help(Text(verbatim: CleanMark.text(clean)))
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier(Self.id)
  }
}
