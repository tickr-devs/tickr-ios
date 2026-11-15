import Charts
import SwiftUI
import TickrDesign
import TickrKit

/// One line of the Lab chart: a version, its colour and its curve (nil: no line, the row says why).
struct DayCurveLine: Identifiable {
  let name: String
  let color: Color
  let curve: DayCurve?
  let active: Bool
  var id: String { name }

  /// Line colours in the observers' order, after the active strategy's.
  static let observerColors = [Palette.highlight, Palette.warning, Palette.info]

  static func color(observerIndex: Int) -> Color { observerColors[observerIndex % observerColors.count] }
}

/// "Today if each version traded": each version's gross result through the shown day as a step
/// line, from the first event of the day to now (live) or the last event; each line ends at the
/// result the bot reports. The axis spans the day's recorded events, not assumed market hours.
struct DayCurvesChart: View {
  let lines: [DayCurveLine]
  let start: Date
  let end: Date
  /// Draws the dashed "now" rule (the live day).
  let live: Bool

  /// Height of the plot, in points.
  static let height: CGFloat = 120
  /// Line widths: the active strategy's line is the thicker.
  static let activeWidth: CGFloat = 2.6
  static let observerWidth: CGFloat = 2
  /// Diameter of the end dot, in points.
  static let endDot: CGFloat = 3.5
  /// Labels on the time axis.
  static let timeLabels = 5
  /// Accessibility id of the chart, for the UI tests.
  static let id = "lab-day-curves"

  private struct Point: Identifiable {
    let name: String
    let index: Int
    let at: Date
    let value: Double
    var id: String { "\(name) \(index)" }
  }

  var body: some View {
    Chart {
      RuleMark(y: .value(String(localized: L10n.Lab.curveResult), 0))
        .foregroundStyle(Palette.separatorStrong)
        .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.thin))
      if live {
        RuleMark(x: .value(String(localized: L10n.Lab.curveTime), end))
          .foregroundStyle(Palette.textQuaternary)
          .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.thin, dash: Tokens.Stroke.dash))
      }
      ForEach(lines) { line in
        if let curve = line.curve {
          let style = StrokeStyle(lineWidth: line.active ? Self.activeWidth : Self.observerWidth,
            dash: curve.complete ? [] : Tokens.Stroke.dash)
          ForEach(points(line.name, curve)) { point in
            LineMark(
              x: .value(String(localized: L10n.Lab.curveTime), point.at),
              y: .value(String(localized: L10n.Lab.curveResult), point.value),
              series: .value(String(localized: L10n.Lab.curveVersion), line.name))
              .interpolationMethod(.stepEnd)
              .foregroundStyle(line.color)
              .lineStyle(style)
          }
          PointMark(
            x: .value(String(localized: L10n.Lab.curveTime), end),
            y: .value(String(localized: L10n.Lab.curveResult), double(curve.end)))
            .symbolSize(Self.endDot * Self.endDot)
            .foregroundStyle(line.color)
        }
      }
    }
    .chartXScale(domain: start...max(end, start))
    .chartXAxis {
      AxisMarks(values: .automatic(desiredCount: Self.timeLabels)) { value in
        AxisGridLine(stroke: StrokeStyle(lineWidth: Tokens.Stroke.hairline, dash: Tokens.Stroke.dashFine))
        AxisValueLabel {
          if let date = value.as(Date.self) {
            Text(verbatim: Format.marketMinute(date)).font(Tokens.Typography.annotation)
          }
        }
      }
    }
    .chartYAxis {
      AxisMarks(position: .leading) { value in
        AxisGridLine(stroke: StrokeStyle(lineWidth: Tokens.Stroke.hairline, dash: Tokens.Stroke.dashFine))
        AxisValueLabel {
          if let amount = value.as(Double.self) {
            Text(verbatim: Money.signedUSD(Decimal(amount))).font(Tokens.Typography.annotation)
          }
        }
      }
    }
    .frame(height: Self.height)
    .accessibilityLabel(Text(L10n.Lab.curves))
    .accessibilityIdentifier(Self.id)
  }

  /// The step line: flat at zero from the start, a step at each close, flat to the end, and a
  /// last step to the reported result when it differs from the running sum.
  private func points(_ name: String, _ curve: DayCurve) -> [Point] {
    var values: [(Date, Decimal)] = [(start, 0)]
    values += curve.steps.map { ($0.at, $0.total) }
    let last = curve.steps.last?.total ?? 0
    values.append((end, last))
    if curve.end != last { values.append((end, curve.end)) }
    return values.enumerated().map { Point(name: name, index: $0.offset, at: $0.element.0, value: double($0.element.1)) }
  }

  private func double(_ value: Decimal) -> Double { NSDecimalNumber(decimal: value).doubleValue }
}
