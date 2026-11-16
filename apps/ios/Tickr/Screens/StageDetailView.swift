import SwiftUI
import TickrDesign
import TickrKit

/// What a live-flow stage did today (`StageDetail`, the same model the Mac draws): the popover a
/// tap on a stage opens. Its facts as label and value, then each group's symbols, each opening the
/// Chart on it. The strategy and risk stages read the watching rows (GET /watching) when opened,
/// as Home does not follow them. An empty stage says so in one line.
struct StageDetailView: View {
  let name: LocalizedStringResource
  /// The stage's dot colour, beside its name.
  let color: Color
  let stage: PipelineStage
  /// Everything but the watching rows, which this view reads itself.
  let sources: StageSources

  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @State private var watching = Container.shared.watchingModel()

  private var detail: StageDetail {
    StageDetail.make(stage, from: StageSources(flow: sources.flow, skipped: sources.skipped,
      watching: watching.watching, status: sources.status, settings: sources.settings))
  }

  var body: some View {
    // Text at reading size, never the card's redacted style; content too tall for the
    // popover (a long day, large Dynamic Type) scrolls.
    ViewThatFits(in: .vertical) {
      content
      ScrollView { content }
    }
    // Its content's width up to the token, narrower where the screen is: it wraps, never clips.
    .frame(idealWidth: Tokens.Size.popover, maxWidth: Tokens.Size.popover)
    .unredacted()
    .task {
      guard stage == .strategy || stage == .risk, let url = model.connection.url else { return }
      await watching.load(url, day: model.today)
    }
  }

  private var content: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      HStack(spacing: Tokens.Space.s) {
        Circle().fill(color).frame(width: Tokens.Size.dotSmall, height: Tokens.Size.dotSmall)
        CardLabel(name)
      }
      let detail = detail
      if let empty = detail.empty {
        Text(verbatim: empty)
          .font(Tokens.Typography.callout)
          .foregroundStyle(Palette.textTertiary)
      }
      ForEach(detail.facts) { fact in factRow(fact) }
      ForEach(detail.groups) { group in
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
          CardLabel(group.title)
          ForEach(group.rows) { row in
            rowView(row)
          }
          if group.more > 0 {
            Text(L10n.Flow.moreRows(group.more))
              .font(Tokens.Typography.annotation)
              .foregroundStyle(Palette.textQuaternary)
          }
        }
      }
      ForEach(detail.footer) { fact in factRow(fact) }
    }
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// A fact as label and value, the value in its tone.
  private func factRow(_ fact: StageDetail.Fact) -> some View {
    RowStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
      Text(verbatim: fact.label)
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textTertiary)
      Spacer(minLength: Tokens.Space.s)
      Text(verbatim: fact.value)
        .font(Tokens.Typography.calloutMono)
        .foregroundStyle(fact.tone == .muted ? Palette.textPrimary : fact.tone.textColor)
        .multilineTextAlignment(.trailing)
        .fixedSize(horizontal: false, vertical: true)
    }
    .accessibilityElement(children: .combine)
  }

  /// A row about a symbol opens the Chart on it; one about no symbol (a fence) is text only.
  @ViewBuilder
  private func rowView(_ row: StageDetail.Row) -> some View {
    if let symbol = row.symbol {
      Button {
        model.selectedSymbol = symbol
        model.selectedTab = .chart
        dismiss()
      } label: {
        line(row, symbol: symbol)
      }
      .buttonStyle(.plain)
      .accessibilityHint(Text(L10n.Flow.openOnChart))
    } else {
      line(row, symbol: nil)
    }
  }

  private func line(_ row: StageDetail.Row, symbol: String?) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
      if let symbol {
        Text(verbatim: symbol)
          .font(Tokens.Typography.calloutMono)
          .fontWeight(.semibold)
          .foregroundStyle(Palette.textPrimary)
      }
      if let text = row.text {
        Text(verbatim: text)
          .font(Tokens.Typography.captionMono)
          .foregroundStyle(row.tone == .muted ? Palette.textTertiary : row.tone.textColor)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, Tokens.Space.s)
    .padding(.vertical, Tokens.Space.xs)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Palette.surfaceSunken, in: RoundedRectangle(cornerRadius: Tokens.Radius.medium))
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
  }
}

/// A live-flow stage while a finger is on it: the stage's colour as a wash behind it and the
/// design's press scale, so a tap reads before its popover opens.
struct StagePressStyle: ButtonStyle {
  let color: Color
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .background {
        RoundedRectangle(cornerRadius: Tokens.Radius.medium)
          .fill(color.opacity(configuration.isPressed ? Tokens.Opacity.wash : 0))
      }
      .scaleEffect(configuration.isPressed && !reduceMotion ? Tokens.Motion.pressScale : 1)
      .animation(reduceMotion ? nil : Tokens.Motion.quick, value: configuration.isPressed)
  }
}
