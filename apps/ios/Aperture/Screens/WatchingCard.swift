import ApertureDesign
import ApertureKit
import SwiftUI

/// "Watching closely": the symbols the strategy is nearest to entering, each with its verdict, the
/// check that decided it and how close that check is to passing.
struct WatchingCard: View {
  let watching: WatchingV1?
  let failure: String?

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      HStack {
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
          WatchingRow(row: row)
        }
      } else if failure == nil {
        ProgressView().frame(maxWidth: .infinity)
      }
    }
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, alignment: .leading)
    .apertureCard()
  }
}

private struct WatchingRow: View {
  let row: WatchingRowV1

  /// How close the decisive check is to passing, 0 to 1, when the bot measured it.
  private var closeness: Double? {
    row.closeness.map { NSDecimalNumber(decimal: $0.value).doubleValue }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
        Text(verbatim: row.symbol)
          .font(Tokens.Typography.calloutMono.bold())
          .foregroundStyle(Palette.textPrimary)
        Text(row.verdict.title)
          .font(Tokens.Typography.annotationBold)
          .foregroundStyle(row.verdict.color)
        Spacer()
        Text(verbatim: Format.time(row.at.date))
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      }
      if let check = row.decisiveCheck {
        Text(verbatim: [check.rule, check.measured?.text ?? Format.missing, check.operator,
          check.threshold?.text ?? Format.missing].joined(separator: ChartFormat.space))
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textTertiary)
          .lineLimit(1)
          .minimumScaleFactor(StatTile.minimumScale)
      }
      if let closeness {
        ProgressView(value: min(max(closeness, 0), 1))
          .tint(Palette.accent)
          .accessibilityLabel(Text(L10n.Watching.closeness))
      } else if let cause = row.closenessCause {
        Text(verbatim: cause)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      }
    }
    .accessibilityElement(children: .combine)
  }
}
