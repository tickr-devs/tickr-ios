import SwiftUI
import TickrDesign
import TickrKit

/// What a live-flow stage did on the shown day (`StageDetail`, the same model the iPhone draws):
/// the popover a click on a stage opens. Its facts as label and value, then each group's symbols,
/// each a link that opens the Chart on it. An empty stage says so in one line.
struct StageDetailView: View {
  let name: LocalizedStringResource
  /// The stage's ring colour, for the title's tick.
  let color: Color
  let detail: StageDetail

  /// Tallest the popover grows before its content scrolls, in points.
  static let maxHeight: CGFloat = 460

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      HStack(spacing: Tokens.Space.s) {
        Circle().fill(color).frame(width: Tokens.Size.dotSmall, height: Tokens.Size.dotSmall)
        CardLabel(name)
      }
      if let empty = detail.empty {
        Footnote(verbatim: empty)
      } else {
        ScrollView {
          content
        }
        .scrollEdgeHints()
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxHeight: Self.maxHeight)
        .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(Tokens.Space.l)
    .frame(idealWidth: Tokens.Size.popover, maxWidth: Tokens.Size.popover, alignment: .leading)
    .background(Palette.surface)
  }

  private var content: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      facts(detail.facts)
      ForEach(detail.groups) { group in
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
          CardLabel(group.title)
          ForEach(group.rows) { row in
            StageDetailRow(row: row)
          }
          if group.more > 0 {
            Text(L10n.Watching.more(group.more))
              .font(Tokens.Typography.captionMono)
              .foregroundStyle(Palette.textQuaternary)
          }
        }
      }
      facts(detail.footer)
    }
  }

  /// Facts as label and value, the value in its tone.
  @ViewBuilder
  private func facts(_ facts: [StageDetail.Fact]) -> some View {
    if !facts.isEmpty {
      VStack(spacing: Tokens.Space.s) {
        ForEach(facts) { fact in
          HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.m) {
            Text(verbatim: fact.label)
              .font(Tokens.Typography.callout)
              .foregroundStyle(Palette.textTertiary)
            Spacer(minLength: Tokens.Space.s)
            Text(verbatim: fact.value)
              .font(Tokens.Typography.calloutMono)
              .foregroundStyle(fact.tone == .muted ? Palette.textPrimary : fact.tone.color)
              .multilineTextAlignment(.trailing)
              .fixedSize(horizontal: false, vertical: true)
          }
          .accessibilityElement(children: .combine)
        }
      }
    }
  }
}

/// One symbol of a stage's detail: the symbol, then what the stage did with it in its tone. A row
/// about a symbol opens the Chart on it, as the Watching rows do.
private struct StageDetailRow: View {
  let row: StageDetail.Row

  var body: some View {
    if let symbol = row.symbol {
      ChartLink(symbol) { line(symbol) }
    } else {
      line(nil)
    }
  }

  private func line(_ symbol: String?) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
      if let symbol {
        SymbolText(symbol)
          .font(Tokens.Typography.calloutMono)
          .fontWeight(.semibold)
          .foregroundStyle(Palette.textPrimary)
      }
      if let text = row.text {
        Text(verbatim: text)
          .font(Tokens.Typography.captionMono)
          .foregroundStyle(row.tone == .muted ? Palette.textTertiary : row.tone.color)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, Tokens.Space.s)
    .padding(.vertical, Tokens.Space.xs)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Palette.surfaceSunken, in: RoundedRectangle(cornerRadius: Tokens.Radius.medium))
    .accessibilityElement(children: .combine)
  }
}
