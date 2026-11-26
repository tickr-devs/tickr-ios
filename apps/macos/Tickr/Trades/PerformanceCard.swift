import Charts
import SwiftUI
import TickrDesign
import TickrKit

/// Gross performance in R over the days that end on the shown day (MacTrades v134): the result per
/// trade big, the trades and win rate beside the title, one line with the profit factor, the max
/// drawdown and the counts, the cumulative R curve, and the trades left out with why.
struct PerformanceCard: View {
  @Environment(AppModel.self) private var model

  /// Accessibility id of the card, for the UI tests.
  static let id = "trades-performance"
  /// Height of the cumulative R curve, in points (MacTrades v134: 54).
  static let curveHeight: CGFloat = 54

  /// A figure with its cause in the person's language (the bot's words for an unknown code).
  static func worded(_ figure: CausedDecimal, _ codes: [ReasonV1]) -> CausedDecimal {
    CausedDecimal(value: figure.value, cause: ApiText.prose(codes, text: figure.cause))
  }

  var body: some View {
    Card(L10n.Trades.performance(AppModel.performanceDays), trailing: {
      if let performance = model.performance, performance.trades > 0 {
        Text(L10n.Trades.performanceSub(performance.trades,
          Self.worded(performance.winRate, performance.winRateCauseCodes).value.map { Percent.plain(fraction: $0.value) }
            ?? Format.missing))
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      }
    }, content: {
      if let performance = model.performance {
        if performance.trades == 0 && performance.exclusions.isEmpty {
          Footnote(L10n.Trades.noPerformance)
        } else {
          content(performance)
        }
      } else if let error = model.performanceError {
        ReadFailureNote(L10n.Trades.performanceUnavailable, detail: error)
      } else {
        Skeleton(L10n.Common.loading) {
          VStack(alignment: .leading, spacing: Tokens.Space.m) {
            SkeletonTiles(Tokens.Loading.tiles)
            SkeletonLines(Tokens.Loading.fewLines)
          }
        }
      }
    })
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(Self.id)
  }

  private func content(_ performance: PerformanceV1) -> some View {
    let expectancy = Self.worded(performance.expectancyGrossR, performance.expectancyGrossRCauseCodes)
    let factor = performance.profitFactorGross.value.map { Money.plain($0.value, fractionDigits: StatDigits.factor) }
    return VStack(alignment: .leading, spacing: Tokens.Space.s) {
      HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
        if let value = expectancy.value?.value {
          // Counts up as it appears and on to each new value, as the design's figure does.
          CountingText(NSDecimalNumber(decimal: value).doubleValue) { Risk.text(Decimal($0)) }
            .font(Tokens.Typography.metric)
            .foregroundStyle(Palette.result(value))
        } else {
          Text(verbatim: Format.missing)
            .font(Tokens.Typography.metric)
            .foregroundStyle(Palette.textQuaternary)
            .tip(expectancy.cause.map { Text(verbatim: $0) } ?? Text(verbatim: Format.missing))
        }
        Text(L10n.Trades.perTrade)
          .font(Tokens.Typography.caption)
          .foregroundStyle(Palette.textTertiary)
      }
      .tip(Text(L10n.Trades.oneRNote))
      Text(L10n.Trades.performanceLine(factor ?? Format.missing, Risk.text(-performance.maxDrawdownGrossR.value),
        performance.wins, performance.losses, performance.scratches))
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(Palette.textTertiary)
        .fixedSize(horizontal: false, vertical: true)
        .tip(Text(verbatim: ApiText.prose(performance.profitFactorGrossCauseCodes,
          text: performance.profitFactorGross.cause) ?? String()))
      if performance.days.count > 1 {
        Curve(days: performance.days)
          .frame(height: Self.curveHeight)
          // Draws itself in on appear and again when a new day's result changes the curve.
          .drawsIn(on: performance.days.map(\.cumulativeGrossR))
      }
      ForEach(Array(performance.exclusions.enumerated()), id: \.offset) { _, exclusion in
        Footnote(L10n.Trades.excluded(exclusion.trades, ApiText.prose(exclusion.causeCodes, text: exclusion.cause)),
          color: Palette.warningText)
      }
    }
  }
}

/// Cumulative R at the end of each day with trades, as a filled area without axes: the area
/// fills from the chart's floor (the lowest value) up to the line, as the Chart screen's line
/// does, so a run below zero never fills upward from a zero line; green while the latest total is
/// a gain, pink for a loss.
private struct Curve: View {
  let days: [PerformanceDayV1]

  var body: some View {
    let name = String(localized: L10n.Trades.cumulativeR)
    let day = String(localized: L10n.Trades.day)
    let values = days.map { NSDecimalNumber(decimal: $0.cumulativeGrossR.value).doubleValue }
    let floor = values.min() ?? 0
    let top = values.max() ?? 0
    let tint = (days.last?.cumulativeGrossR.value ?? 0) < 0 ? Palette.seriesATR : Palette.accent
    Chart {
      ForEach(Array(zip(days, values)), id: \.0.day) { item, value in
        AreaMark(x: .value(day, item.day.noonInNewYork), yStart: .value(name, floor), yEnd: .value(name, value))
          .foregroundStyle(
            LinearGradient(
              colors: [tint.opacity(Tokens.Opacity.faint), tint.opacity(Tokens.Opacity.wash)],
              startPoint: .top, endPoint: .bottom))
        LineMark(x: .value(day, item.day.noonInNewYork), y: .value(name, value))
          .foregroundStyle(tint)
          .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.bold))
      }
    }
    // The values' own range: the floor is the chart's bottom edge, never a zero it does not reach.
    .chartYScale(domain: floor...max(top, floor + 1))
    .chartXAxis(.hidden)
    .chartYAxis(.hidden)
  }
}
