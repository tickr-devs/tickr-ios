import SwiftUI
import TickrDesign
import TickrKit

/// "Which version trades" (MacLab board, mockup v159): the active version's name with the Active
/// badge, the shown day's result big with its trades under it and the day's curve beside it, then
/// the version's latest replay over past days when the Lab has one. On a card edged in the accent.
struct ActiveVersionCard: View {
  @Environment(AppModel.self) private var model

  /// Size of the day's curve, in points (the board's 140 × 40).
  static let curveWidth: CGFloat = 140
  static let curveHeight: CGFloat = 40

  private var name: String { model.status?.strategy.name ?? model.settings?.activeStrategy ?? Format.missing }

  var body: some View {
    Card(L10n.Lab.active, tint: Palette.accent) {
      VStack(alignment: .leading, spacing: Tokens.Space.m) {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
          HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(verbatim: name)
            if let version = model.status?.strategy.version {
              Text(L10n.Lab.versionSuffix(version))
            }
          }
          .font(Tokens.Typography.quote)
          .foregroundStyle(Palette.textPrimary)
          .fixedSize(horizontal: false, vertical: true)
          Badge(L10n.Lab.tagActive, tone: .accent)
          Spacer(minLength: 0)
        }
        HStack(alignment: .bottom, spacing: Tokens.Space.l) {
          VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            MoneyText(value: model.shownResult, font: Tokens.Typography.hero)
              .contentTransition(.numericText())
            Text(verbatim: summary)
              .font(Tokens.Typography.caption)
              .foregroundStyle(Palette.textTertiary)
              .fixedSize(horizontal: false, vertical: true)
          }
          .layoutPriority(1)
          Spacer(minLength: 0)
          DrawnSparkline(values: model.cumulativeResults, color: Palette.result(model.shownResult))
            .frame(width: Self.curveWidth, height: Self.curveHeight)
            .accessibilityHidden(true)
        }
        if let test = LabFigures.activeTest(model.labReplay) {
          Divider()
          HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
            Text(L10n.Lab.testedOn(test.sessions))
              .font(Tokens.Typography.callout)
              .foregroundStyle(Palette.textTertiary)
              .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Tokens.Space.s)
            MoneyText(value: test.botTotalUsd.value, font: Tokens.Typography.calloutMono.bold())
          }
          .accessibilityElement(children: .combine)
        }
      }
    }
  }

  /// "Today · 3 closed, 2 won, 1 lost", or a recorded day's "Nov 13 · …", then "before broker fees"
  /// while the result does not count them yet.
  private var summary: String {
    let day = model.isLive ? String(localized: L10n.Common.today) : DayText.day(model.shownDay)
    let line = String(localized: L10n.Lab.daySummary(day, model.shownTradeCount, model.shownWins, model.shownLosses))
    guard model.shownResultBeforeFees else { return line }
    return [line, String(localized: L10n.Overview.beforeFees)].joined(separator: Format.itemSeparator)
  }
}

/// A card title's "i" (the boards' `.info`): a click opens what the card counts or how it runs in
/// a popover; its tooltip names it.
struct LabInfoButton: View {
  let label: LocalizedStringResource
  let texts: [LocalizedStringResource]
  @State private var open = false

  var body: some View {
    Button { open = true } label: {
      Image(systemName: InfoCaption.infoSymbol)
        .font(Tokens.Typography.caption)
        .foregroundStyle(Palette.textTertiary)
        .frame(minWidth: Tokens.Size.headerLink, minHeight: Tokens.Size.headerLink)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .linkPointer()
    .tip(Text(label))
    .accessibilityLabel(Text(label))
    .popover(isPresented: $open, arrowEdge: .bottom) {
      VStack(alignment: .leading, spacing: Tokens.Space.s) {
        CardLabel(label)
        ForEach(texts.indices, id: \.self) { index in
          Text(texts[index])
            .font(Tokens.Typography.callout)
            .foregroundStyle(Palette.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .padding(Tokens.Space.l)
      .frame(idealWidth: Tokens.Size.popover, maxWidth: Tokens.Size.popover, alignment: .leading)
      .background(Palette.surface)
    }
  }
}
