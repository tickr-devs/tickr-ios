import SwiftUI
import TickrDesign
import TickrKit

/// The rail's explain card: what the trading strategy decided about the shown symbol at
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

  /// Accessibility id of the card's content, for the UI tests.
  static let contentID = "chart-decisions-list"

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      content.offlineOutline(lines: Tokens.Loading.fewLines)
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
        CardLabel(label(decision))
        Spacer(minLength: 0)
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
      if let candle = pointed, decisions?.decisions.isEmpty == false {
        note(L10n.Chart.noDecisionInCandle(Format.marketMinute(candle.start)))
      } else if !showsDay {
        note(L10n.Chart.decisionsDayOnly)
      } else if let error {
        ReadFailureNote(L10n.Chart.decisionsUnavailable, detail: error)
      } else if decisions != nil || symbol == nil {
        note(L10n.Chart.noDecisions)
      } else {
        Skeleton(L10n.Common.loading) { SkeletonLines(Tokens.Loading.lines) }
      }
    }
  }

  /// The candle under the pointer, on a chart of one day.
  private var pointed: Candle? {
    guard showsDay, let plot, let index = pointer.index, plot.candles.indices.contains(index) else { return nil }
    return plot.real[index]
  }

  /// The decision made inside the pointed candle (the last one, when a candle of several minutes
  /// holds several), else with the pointer off the chart the latest; a shadow strategy's are left
  /// out. A pointed candle without a decision shows none, never an older one.
  private var shown: DecisionV1? {
    guard showsDay, let all = decisions?.decisions, !all.isEmpty else { return nil }
    var made = all
    if let candle = pointed {
      made = all.filter { $0.at.date >= candle.start && $0.at.date < candle.end }
    }
    return made.last { !$0.observer }
  }

  /// "Explain ABCD · 12:54", and in a candle of several minutes which candle it is the last
  /// decision of ("· last in the 12:50 candle"), so the time never reads as a different candle.
  private func label(_ decision: DecisionV1) -> LocalizedStringResource {
    let symbol = symbol ?? Format.missing
    let time = Format.marketMinute(decision.at.date)
    guard let candle = pointed, Format.marketMinute(candle.start) != time else {
      return L10n.Chart.explain(symbol, time)
    }
    return L10n.Chart.explainInCandle(symbol, time, Format.marketMinute(candle.start))
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
      Image(systemName: check.passed ? Symbols.passed : Symbols.failed)
        .foregroundStyle(check.passed ? Palette.profit : Palette.textQuaternary)
        .accessibilityLabel(Text(check.passed ? L10n.Chart.checkPassed : L10n.Chart.checkFailed))
      // The rule in words (ApiText), wrapped over a few lines rather than cut mid-word.
      Text(verbatim: ApiText.rule(check.rule))
        .font(Tokens.Typography.caption)
        .foregroundStyle(Palette.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: Tokens.Space.xs)
      // A number is never broken over two lines ("120,226,776.1" / "3"): the rule's words wrap.
      Text(verbatim: check.measured.map { CheckValue.text($0.value) } ?? Format.missing)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
        .fixedSize()
    }
    .help(Text(verbatim: help))
    .accessibilityElement(children: .combine)
  }

  /// The measured value against what it needs, in words that stay true for a failed check
  /// (`CheckV1.valueText`), then the bot's note.
  private var help: String {
    ([check.valueText] + (check.note.isEmpty ? [] : [check.note])).joined(separator: Format.lineSeparator)
  }
}
