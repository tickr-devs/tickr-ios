import SwiftUI
import TickrDesign
import TickrKit

/// "Watching closely": the symbols the strategy is nearest to entering, each with its verdict, the
/// check that decided it and how close that check is to passing. The closest few here; the card's
/// footer link "Show all N ›" (`CardFooterLink`, as on the Mac) opens every row the bot sent in a
/// sheet (`WatchingSheet`).
struct WatchingCard: View {
  let watching: WatchingV1?
  let failure: String?
  @State private var showsAll = false

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      CardLabel(L10n.Watching.title)
      if let failure {
        ReadFailureNote(watching == nil ? L10n.Watching.failed : L10n.Watching.stale, detail: failure)
      }
      if let watching {
        if watching.rows.isEmpty {
          Text(L10n.Watching.none)
            .font(Tokens.Typography.callout)
            .foregroundStyle(Palette.textTertiary)
        }
        let rows = WatchingList.top(watching.rows)
        ForEach(rows, id: \.symbol) { row in
          WatchingRow(row: row, current: failure == nil)
        }
        if WatchingList.hasMore(watching.rows) {
          CardFooterLink(L10n.Watching.showAll, count: watching.rows.count,
            hint: watching.total > rows.count ? L10n.Watching.closestOf(rows.count, watching.total) : nil) {
            showsAll = true
          }
        }
      } else if failure == nil {
        TickrLoader(L10n.Common.loading).frame(maxWidth: .infinity)
      }
    }
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, alignment: .leading)
    .tickrCard()
    .sheet(isPresented: $showsAll) {
      // The card's own rows, so the sheet follows each new read while it is open.
      WatchingSheet(watching: watching, current: failure == nil)
    }
  }
}

struct WatchingRow: View {
  let row: WatchingRowV1
  /// False while a refresh failed and the row is the last read: its bar is dimmed.
  let current: Bool

  /// How close the decisive check is to passing, 0 to 1, when the bot measured it.
  private var closeness: Double? {
    row.closeness.map { NSDecimalNumber(decimal: $0.value).doubleValue }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      RowStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
        Text(verbatim: row.symbol)
          .font(Tokens.Typography.calloutMono.bold())
          .foregroundStyle(Palette.textPrimary)
          .fixedSize()
        Text(row.verdict.title)
          .font(Tokens.Typography.annotationBold)
          .foregroundStyle(row.verdict.color)
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
          // Wraps rather than cutting the figures.
          .fixedSize(horizontal: false, vertical: true)
      }
      if let closeness {
        // As on the board: a thin bar that grows in, and to each new closeness the bot measures.
        let share = min(max(closeness, 0), 1)
        GeometryReader { proxy in
          ZStack(alignment: .leading) {
            Capsule().fill(Palette.separator)
            Capsule()
              .fill(current ? row.verdict.color : Palette.textQuaternary)
              .frame(width: proxy.size.width * share)
              .grows(with: share)
          }
        }
        .frame(height: Tokens.Size.barThin)
        .accessibilityElement()
        .accessibilityLabel(Text(L10n.Watching.closeness))
        .accessibilityValue(Text(share, format: .percent.precision(.fractionLength(0))))
      } else if let cause = row.closenessCauseText {
        Text(verbatim: cause)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      }
    }
    .accessibilityElement(children: .combine)
  }
}
