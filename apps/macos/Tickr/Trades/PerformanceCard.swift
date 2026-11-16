import Charts
import SwiftUI
import TickrDesign
import TickrKit

/// Gross performance in R over the days that end on the shown day: expectancy, win rate, profit
/// factor and max drawdown in one row, the cumulative R curve, the trade counts and the trades
/// left out with why.
struct PerformanceCard: View {
  @Environment(AppModel.self) private var model

  /// Accessibility id of the card, for the UI tests.
  static let id = "trades-performance"
  /// Height of the cumulative R curve, in points.
  static let curveHeight: CGFloat = 90

  /// A figure with its cause in the person's language (the bot's words for an unknown code).
  static func worded(_ figure: CausedDecimal, _ codes: [ReasonV1]) -> CausedDecimal {
    CausedDecimal(value: figure.value, cause: ApiText.prose(codes, text: figure.cause))
  }

  var body: some View {
    Card(L10n.Trades.performance(AppModel.performanceDays), trailing: {
      Text(L10n.Trades.oneRNote)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
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
        TickrLoader(L10n.Common.loading)
      }
    })
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(Self.id)
  }

  private func content(_ performance: PerformanceV1) -> some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      // One row of four, each a quarter of the card: a figure shrinks to fit rather than cut
      // ("−3.8…").
      HStack(alignment: .top, spacing: Tokens.Space.s) {
        Figure(L10n.Trades.expectancy, Self.worded(performance.expectancyGrossR, performance.expectancyGrossRCauseCodes),
          color: true) { Risk.text($0) }
        Figure(L10n.Trades.winRate, Self.worded(performance.winRate, performance.winRateCauseCodes)) {
          Percent.plain(fraction: $0)
        }
        Figure(L10n.Trades.profitFactor, Self.worded(performance.profitFactorGross,
          performance.profitFactorGrossCauseCodes)) {
          Money.plain($0, fractionDigits: StatDigits.factor)
        }
        Figure(L10n.Trades.maxDrawdown, CausedDecimal(value: performance.maxDrawdownGrossR, cause: nil), loss: true) {
          Risk.text(-$0)
        }
      }
      if performance.days.count > 1 {
        Curve(days: performance.days)
          .frame(height: Self.curveHeight)
          // Draws itself in on appear and again when a new day's result changes the curve.
          .drawsIn(on: performance.days.map(\.cumulativeGrossR))
      }
      Text(L10n.Trades.performanceLine(performance.trades, performance.wins, performance.losses,
        performance.scratches))
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(Palette.textTertiary)
      ForEach(Array(performance.exclusions.enumerated()), id: \.offset) { _, exclusion in
        Footnote(L10n.Trades.excluded(exclusion.trades, ApiText.prose(exclusion.causeCodes, text: exclusion.cause)),
          color: Palette.warningText)
      }
    }
  }
}

/// One performance figure: its value over its name, or a dash with the bot's cause as the tooltip.
private struct Figure: View {
  let title: LocalizedStringResource
  let figure: CausedDecimal
  /// Coloured by sign (a result), or as a loss (a drawdown).
  let color: Bool
  let loss: Bool
  let format: (Decimal) -> String

  init(
    _ title: LocalizedStringResource, _ figure: CausedDecimal, color: Bool = false, loss: Bool = false,
    format: @escaping (Decimal) -> String
  ) {
    self.title = title
    self.figure = figure
    self.color = color
    self.loss = loss
    self.format = format
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
      if let value = figure.value?.value {
        // Counts up as it appears and on to each new value, as the design's figures do.
        CountingText(NSDecimalNumber(decimal: value).doubleValue) { format(Decimal($0)) }
          .font(Tokens.Typography.figure)
          .foregroundStyle(loss && value != 0 ? Tone.series.text : color ? Palette.result(value) : Palette.textPrimary)
      } else {
        Text(verbatim: Format.missing)
          .font(Tokens.Typography.figure)
          .foregroundStyle(Palette.textQuaternary)
          .help(figure.cause.map { Text(verbatim: $0) } ?? Text(verbatim: Format.missing))
      }
      // A name longer than its quarter ("Доля прибыльных") wraps onto a second line, never cut.
      Text(title)
        .font(Tokens.Typography.caption)
        .foregroundStyle(Palette.textQuaternary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

/// Cumulative R at the end of each day with trades, as a filled area without axes.
private struct Curve: View {
  let days: [PerformanceDayV1]

  var body: some View {
    let name = String(localized: L10n.Trades.cumulativeR)
    let day = String(localized: L10n.Trades.day)
    Chart {
      ForEach(days, id: \.day) { item in
        let value = NSDecimalNumber(decimal: item.cumulativeGrossR.value).doubleValue
        AreaMark(x: .value(day, item.day.noonInNewYork), y: .value(name, value))
          .foregroundStyle(
            LinearGradient(
              colors: [Palette.accent.opacity(Tokens.Opacity.faint), Palette.accent.opacity(Tokens.Opacity.wash)],
              startPoint: .top, endPoint: .bottom))
        LineMark(x: .value(day, item.day.noonInNewYork), y: .value(name, value))
          .foregroundStyle(Palette.accent)
          .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.bold))
      }
    }
    .chartXAxis(.hidden)
    .chartYAxis(.hidden)
  }
}
