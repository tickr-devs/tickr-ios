import SwiftUI
import TickrDesign
import TickrKit

/// "Watching closely": the symbols the strategy is nearest to entering, each with its verdict, the
/// check that decided it and how close that check is to passing.
struct WatchingCard: View {
  let watching: WatchingV1?
  let failure: String?

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      // The label, then its note; the note goes under it at large text sizes.
      RowStack {
        CardLabel(L10n.Watching.title)
        Spacer()
        if let watching, watching.total > watching.rows.count {
          Text(L10n.Watching.shown(watching.rows.count, watching.total))
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textQuaternary)
        }
      }
      if let failure {
        Text(watching == nil ? L10n.Watching.failed(failure) : L10n.Watching.stale(failure))
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.warningText)
      }
      if let watching {
        if watching.rows.isEmpty {
          Text(L10n.Watching.none)
            .font(Tokens.Typography.callout)
            .foregroundStyle(Palette.textTertiary)
        }
        ForEach(watching.rows, id: \.symbol) { row in
          WatchingRow(row: row, current: failure == nil)
        }
      } else if failure == nil {
        ProgressView().frame(maxWidth: .infinity)
      }
    }
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, alignment: .leading)
    .tickrCard()
  }
}

private struct WatchingRow: View {
  @Environment(\.dynamicTypeSize) private var typeSize
  let row: WatchingRowV1
  /// False while a refresh failed and the row is the last read: its bar is dimmed.
  let current: Bool

  /// How close the decisive check is to passing, 0 to 1, when the bot measured it.
  private var closeness: Double? {
    row.closeness.map { NSDecimalNumber(decimal: $0.value).doubleValue }
  }

  /// A verdict's colour here, as on the design: watching in blue, ignored in the stocks stage's
  /// pink, the rest as everywhere else.
  static func color(_ verdict: Verdict) -> Color {
    switch verdict {
    case .watch: return Palette.infoText
    case .ignore: return Palette.seriesATRText
    case .enter, .exit, .hold: return verdict.color
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      RowStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
        Text(verbatim: row.symbol)
          .font(Tokens.Typography.calloutMono.bold())
          .foregroundStyle(Palette.textPrimary)
          .lineLimit(1)
          .fixedSize()
        Text(row.verdict.title)
          .font(Tokens.Typography.annotationBold)
          .foregroundStyle(Self.color(row.verdict))
        Spacer(minLength: 0)
        Text(verbatim: Format.time(row.at.date))
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      }
      if let check = row.decisiveCheck {
        Text(verbatim: [ApiText.rule(check.rule), check.measured?.text ?? Format.missing, check.operator,
          check.threshold?.text ?? Format.missing].joined(separator: ChartFormat.space))
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textTertiary)
          // One line at ordinary sizes; at large ones it wraps rather than cutting the figures.
          .lineLimit(typeSize.stacksRows ? nil : 1)
          .minimumScaleFactor(Tokens.Shrink.standard)
      }
      if let closeness {
        ProgressView(value: min(max(closeness, 0), 1))
          .tint(current ? Self.color(row.verdict) : Palette.textQuaternary)
          .accessibilityLabel(Text(L10n.Watching.closeness))
      } else if let cause = row.closenessCause {
        Text(verbatim: ApiText.prose(row.closenessCauseCodes, text: cause))
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      }
    }
    .accessibilityElement(children: .combine)
  }
}
