import SwiftUI
import TickrDesign
import TickrKit

/// The rail's explain card: what the strategy (or an observer) decided about the shown symbol at
/// the pointed candle, or its latest decision while the pointer is off the chart, with every check
/// that led to it.
struct ChartExplainCard: View {
  let symbol: String?
  /// The day's candles, to find the pointed candle's decision; nil over a longer range.
  let plot: ChartPlot?
  let pointer: ChartPointer
  let decisions: DecisionsV1?
  let error: String?
  /// The chart shows one day: decisions are recorded per day, so a longer range has none to read.
  let showsDay: Bool

  /// Lines a check's name may take: the rail is narrow, and a name cut short no longer read.
  static let ruleLines = 3
  /// Accessibility id of the card's content, for the UI tests.
  static let contentID = "chart-decisions-list"
  /// SF Symbols of a passed and a failed check.
  static let passedSymbol = "checkmark.circle.fill"
  static let failedSymbol = "xmark.circle.fill"

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      content
    }
    .padding(Tokens.Space.m)
    .frame(maxWidth: .infinity, alignment: .leading)
    .tickrCard(radius: Tokens.Radius.large)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(Self.contentID)
  }

  @ViewBuilder private var content: some View {
    if let decision = shown {
      HStack(spacing: Tokens.Space.s) {
        CardLabel(L10n.Chart.explain(symbol ?? Format.missing, Format.marketMinute(decision.at.date)))
          .lineLimit(1)
          .minimumScaleFactor(Tokens.Shrink.standard)
        Spacer(minLength: 0)
        if decision.observer {
          Badge(L10n.Chart.observerTag, color: Palette.highlightText)
        }
        Badge(decision.action.title, color: decision.action.color)
      }
      summary(decision)
      ForEach(Array(decision.checks.enumerated()), id: \.offset) { _, check in
        CheckRow(check: check)
      }
      Text(L10n.Chart.explainHint)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
    } else {
      CardLabel(L10n.Chart.explainSymbol(symbol ?? Format.missing))
      if !showsDay {
        note(L10n.Chart.decisionsDayOnly)
      } else if let error {
        note(L10n.Chart.decisionsUnavailable(error))
      } else if decisions != nil || symbol == nil {
        note(L10n.Chart.noDecisions)
      } else {
        ProgressView().controlSize(.small)
      }
    }
  }

  /// The decision at the pointed candle (the last made before it closed), else the latest; the
  /// trading strategy's own before an observer's made at the same time or earlier.
  private var shown: DecisionV1? {
    guard showsDay, let all = decisions?.decisions, !all.isEmpty else { return nil }
    var made = all
    if let plot, let index = pointer.index, plot.candles.indices.contains(index) {
      let end = plot.candles[index].end
      made = all.filter { $0.at.date < end }
    }
    return made.last { !$0.observer } ?? made.last
  }

  /// One line on what the decision came to: the refusal, the entry and stop, or the strategy.
  @ViewBuilder private func summary(_ decision: DecisionV1) -> some View {
    if let reason = RefusalText.text(decision.refusal, cause: decision.refusalCause) {
      Text(verbatim: reason)
        .font(Tokens.Typography.caption)
        .foregroundStyle(Palette.warningText)
        .fixedSize(horizontal: false, vertical: true)
    } else if let entry = decision.entryPrice, let stop = decision.stopPrice {
      Text(L10n.Chart.entryStop(Format.price(entry.value), Format.price(stop.value)))
        .font(Tokens.Typography.caption)
        .foregroundStyle(Palette.textTertiary)
    } else {
      Text(L10n.Chart.strategyVersion(decision.strategy.name, decision.strategy.version))
        .font(Tokens.Typography.caption)
        .foregroundStyle(Palette.textTertiary)
    }
  }

  private func note(_ text: LocalizedStringResource) -> some View {
    Text(text)
      .font(Tokens.Typography.caption)
      .foregroundStyle(Palette.textTertiary)
      .fixedSize(horizontal: false, vertical: true)
  }
}

/// One rule the strategy checked: passed or not, the rule in words, and the measured value (the
/// comparison with its threshold, and the bot's note, in the tooltip).
private struct CheckRow: View {
  let check: CheckV1

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
      Image(systemName: check.passed ? ChartExplainCard.passedSymbol : ChartExplainCard.failedSymbol)
        .foregroundStyle(check.passed ? Palette.profit : Palette.textQuaternary)
        .accessibilityLabel(Text(check.passed ? L10n.Chart.checkPassed : L10n.Chart.checkFailed))
      // The rule in words (ApiText), wrapped over a few lines rather than cut mid-word.
      Text(verbatim: ApiText.rule(check.rule))
        .font(Tokens.Typography.caption)
        .foregroundStyle(Palette.textSecondary)
        .lineLimit(ChartExplainCard.ruleLines)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: Tokens.Space.xs)
      Text(verbatim: check.measured?.text ?? Format.missing)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
    }
    .help(Text(verbatim: help))
    .accessibilityElement(children: .combine)
  }

  /// "measured operator threshold" as the bot recorded them (a missing side shows as a dash),
  /// then the bot's note.
  private var help: String {
    let comparison = "\(check.measured?.text ?? Format.missing) \(check.operator) \(check.threshold?.text ?? Format.missing)"
    return ([comparison] + (check.note.isEmpty ? [] : [check.note])).joined(separator: Format.lineSeparator)
  }
}

extension Verdict {
  /// The role colour of the decision's badge.
  var color: Color {
    switch self {
    case .enter: Palette.accentText
    case .exit: Palette.warningText
    case .watch: Palette.infoText
    case .hold: Palette.highlightText
    case .ignore: Palette.textTertiary
    }
  }
}
