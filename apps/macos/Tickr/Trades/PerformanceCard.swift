import Charts
import SwiftUI
import TickrDesign
import TickrKit

/// Gross performance in R over the days that end on the shown day: expectancy, win rate, profit
/// factor, max drawdown and total, the cumulative R curve, and the trades left out with why.
struct PerformanceCard: View {
  @Environment(AppModel.self) private var model

  /// Accessibility id of the card, for the UI tests.
  static let id = "trades-performance"
  /// Height of the cumulative R curve, in points.
  static let curveHeight: CGFloat = 90
  /// A win rate of 1 is 100 percent.
  static let percentFactor: Decimal = 100
  /// Narrowest a figure gets before the figures wrap to another row, in points (the card sits in
  /// the Trades side column).
  static let figureMinWidth: CGFloat = 80

  var body: some View {
    Card(L10n.Trades.performance(AppModel.performanceDays)) {
      if let performance = model.performance {
        if performance.trades == 0 && performance.exclusions.isEmpty {
          Footnote(L10n.Trades.noPerformance)
        } else {
          content(performance)
        }
      } else if let error = model.performanceError {
        Footnote(L10n.Trades.performanceUnavailable(error))
      } else {
        ProgressView().controlSize(.small)
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(Self.id)
  }

  private func content(_ performance: PerformanceV1) -> some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      LazyVGrid(
        columns: [GridItem(.adaptive(minimum: Self.figureMinWidth), spacing: Tokens.Space.m, alignment: .topLeading)],
        alignment: .leading, spacing: Tokens.Space.m
      ) {
        Figure(L10n.Trades.expectancy, performance.expectancyGrossR, color: true) { Risk.text($0) }
        Figure(L10n.Trades.winRate, performance.winRate) {
          String(localized: L10n.Trades.percent(Money.plain($0 * Self.percentFactor, fractionDigits: StatDigits.percent)))
        }
        Figure(L10n.Trades.profitFactor, performance.profitFactorGross) {
          Money.plain($0, fractionDigits: StatDigits.factor)
        }
        Figure(L10n.Trades.maxDrawdown, CausedDecimal(value: performance.maxDrawdownGrossR, cause: nil)) {
          Risk.text(-$0)
        }
        Figure(L10n.Trades.totalR, CausedDecimal(value: performance.resultGrossR, cause: nil), color: true) {
          Risk.text($0)
        }
      }
      if performance.days.count > 1 {
        Curve(days: performance.days)
          .frame(height: Self.curveHeight)
      }
      Text(L10n.Trades.performanceCounts(performance.trades, performance.wins, performance.losses,
        performance.scratches))
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(Palette.textSecondary)
      ForEach(Array(performance.exclusions.enumerated()), id: \.offset) { _, exclusion in
        Footnote(L10n.Trades.excluded(exclusion.trades, exclusion.cause), color: Palette.warningText)
      }
      Footnote(L10n.Trades.grossNote)
    }
  }
}

/// One performance figure: its value, or a dash with the bot's cause as the tooltip.
private struct Figure: View {
  let title: LocalizedStringResource
  let figure: CausedDecimal
  let color: Bool
  let format: (Decimal) -> String

  init(
    _ title: LocalizedStringResource, _ figure: CausedDecimal, color: Bool = false, format: @escaping (Decimal) -> String
  ) {
    self.title = title
    self.figure = figure
    self.color = color
    self.format = format
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
      Text(title)
        .font(Tokens.Typography.caption)
        .foregroundStyle(Palette.textTertiary)
      if let value = figure.value?.value {
        Text(verbatim: format(value))
          .font(Tokens.Typography.metric)
          .foregroundStyle(color ? Palette.result(value) : Palette.textPrimary)
      } else {
        Text(verbatim: Format.missing)
          .font(Tokens.Typography.metric)
          .foregroundStyle(Palette.textQuaternary)
          .help(figure.cause.map { Text(verbatim: $0) } ?? Text(verbatim: Format.missing))
      }
    }
    .lineLimit(1)
    .accessibilityElement(children: .combine)
  }
}

/// Cumulative R at the end of each day with trades, from 0 before the first.
private struct Curve: View {
  let days: [PerformanceDayV1]

  var body: some View {
    Chart {
      RuleMark(y: .value(String(localized: L10n.Trades.cumulativeR), 0))
        .foregroundStyle(Palette.textQuaternary)
      ForEach(days, id: \.day) { day in
        LineMark(
          x: .value(String(localized: L10n.Trades.day), day.day.noonInNewYork),
          y: .value(String(localized: L10n.Trades.cumulativeR), NSDecimalNumber(decimal: day.cumulativeGrossR.value).doubleValue))
          .foregroundStyle(Palette.accentText)
        PointMark(
          x: .value(String(localized: L10n.Trades.day), day.day.noonInNewYork),
          y: .value(String(localized: L10n.Trades.cumulativeR), NSDecimalNumber(decimal: day.cumulativeGrossR.value).doubleValue))
          .foregroundStyle(Palette.result(day.resultGrossR.value))
      }
    }
    .chartXAxis(.hidden)
  }
}
