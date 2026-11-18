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
/// line, from `start` to `end` (now while live), each ending at the result the bot reports with a
/// dot. The time axis spans `domain`: the session the bot reports for that day, else the day's
/// recorded events, never assumed market hours. The money axis reads in whole dollars.
struct DayCurvesChart: View {
  let lines: [DayCurveLine]
  let start: Date
  let end: Date
  /// The time axis; nil spans `start` to `end`.
  var domain: ClosedRange<Date>?
  /// Draws the dashed "now" rule (the live day).
  let live: Bool

  /// Height of the plot, in points.
  static let height: CGFloat = 120
  /// Line widths: the active strategy's line is the thicker.
  static let activeWidth: CGFloat = 2.6
  static let observerWidth: CGFloat = 2
  /// Diameter of the end dot, in points.
  static let endDot: CGFloat = 3.5
  /// Minutes between labels on the time axis (09:30, 11:00, 12:30 ... as the design), and the
  /// least gap before the last label, which is the axis's end. The end label is drawn leftwards
  /// from its tick, so the gap is more than a step: at 45 minutes "20:00" and "21:32" (and
  /// "18:30" / "19:16") were drawn over each other; two hours still keep 14:00 before 16:00.
  static let labelStepMinutes: Double = 90
  static let lastLabelGapMinutes: Double = 120
  /// Seconds in a minute (unit factor).
  static let secondsPerMinute: Double = 60
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
    .chartXScale(domain: axis)
    // The lines draw themselves in on appear and again when a version's result changes; the
    // live "now" moving on does not redraw them.
    .chartPlotStyle { plot in plot.drawsIn(on: drawKey) }
    .chartXAxis {
      AxisMarks(values: timeLabels) { value in
        // The first and last labels are the axis's ends: drawn inside the plot, not cut at its
        // edges or under the money labels.
        AxisValueLabel(anchor: Self.anchor(value.index, of: value.count), collisionResolution: .disabled) {
          if let date = value.as(Date.self) {
            Text(verbatim: Format.marketMinute(date))
              .font(Tokens.Typography.annotation)
              .foregroundStyle(Palette.textQuaternary)
          }
        }
      }
    }
    .chartYAxis {
      AxisMarks(position: .leading, values: .automatic(desiredCount: Self.moneyLabels)) { value in
        AxisGridLine(stroke: StrokeStyle(lineWidth: Tokens.Stroke.hairline, dash: Tokens.Stroke.dashFine))
          .foregroundStyle(Palette.separator)
        AxisValueLabel {
          if let amount = value.as(Double.self) {
            Text(verbatim: Self.dollars(amount))
              .font(Tokens.Typography.annotation)
              .foregroundStyle(Palette.textQuaternary)
          }
        }
      }
    }
    .frame(height: Self.height)
    .accessibilityLabel(Text(L10n.Lab.curves))
    .accessibilityIdentifier(Self.id)
  }

  /// The step line (`DayCurve.line`): from the start, or from when an observer added at a
  /// restart started watching, to the end.
  private func points(_ name: String, _ curve: DayCurve) -> [Point] {
    curve.line(start: start, end: end).enumerated().map {
      Point(name: name, index: $0.offset, at: $0.element.at, value: double($0.element.total))
    }
  }

  /// What the lines show: each version's steps and end. A change redraws them.
  private struct DrawKey: Hashable {
    let name: String
    let totals: [Decimal]
    let end: Decimal?
  }

  private var drawKey: [DrawKey] {
    lines.map { DrawKey(name: $0.name, totals: $0.curve?.steps.map(\.total) ?? [], end: $0.curve?.end) }
  }

  private func double(_ value: Decimal) -> Double { NSDecimalNumber(decimal: value).doubleValue }

  /// Where a time label hangs from its tick: the ends inward, the rest centred.
  static func anchor(_ index: Int, of count: Int) -> UnitPoint {
    if index == 0 { return .topLeading }
    return index == count - 1 ? .topTrailing : .top
  }

  /// Labels on the money axis.
  static let moneyLabels = 4

  private var axis: ClosedRange<Date> { domain ?? start...max(end, start) }

  /// From the axis's start every `labelStepMinutes`, then its end: 09:30, 11:00, 12:30, 14:00,
  /// 16:00 over a regular session.
  private var timeLabels: [Date] {
    let step = Self.labelStepMinutes * Self.secondsPerMinute
    let last = axis.upperBound.addingTimeInterval(-Self.lastLabelGapMinutes * Self.secondsPerMinute)
    var dates = Array(stride(from: axis.lowerBound, through: last, by: step))
    dates.append(axis.upperBound)
    return dates
  }

  /// "+$12", "$0", "−$4": an axis amount in whole dollars.
  static func dollars(_ amount: Double) -> String {
    let whole = Decimal(Int(amount.rounded()))
    guard whole != 0 else { return Self.dollar + Money.plain(whole, fractionDigits: .zero) }
    // The sign first, then the dollar mark: "+12" becomes "+$12".
    let signed = Money.signed(whole, fractionDigits: .zero)
    return String(signed.prefix(1)) + Self.dollar + signed.dropFirst()
  }

  /// The currency mark on the money axis.
  static let dollar = "$"
}
