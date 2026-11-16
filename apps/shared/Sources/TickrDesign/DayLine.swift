import Charts
import SwiftUI

/// A symbol's price line today in the Symbols detail (mockup v101): the closes as one line,
/// teal at or above the previous close and pink below it, and the previous close as a dashed
/// hairline. Draws itself in like `DrawnSparkline`; hidden from VoiceOver (the price and change
/// beside it say the same).
public struct DayLine: View {
  /// Plot keys of the two axes (Charts names its values with them; never read aloud).
  static let indexKey = "index"
  static let valueKey = "value"

  let closes: [Double]
  let previousClose: Double?

  public init(closes: [Double], previousClose: Double?) {
    self.closes = closes
    self.previousClose = previousClose
  }

  private var color: Color {
    guard let last = closes.last, let previousClose, last < previousClose else { return Palette.accent }
    return Palette.dropped
  }

  public var body: some View {
    let shown = closes.count > 1 ? closes : [closes.first ?? 0, closes.first ?? 0]
    Chart {
      ForEach(Array(shown.enumerated()), id: \.offset) { point in
        LineMark(x: .value(Self.indexKey, point.offset), y: .value(Self.valueKey, point.element))
          .foregroundStyle(color)
          .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.bold, lineCap: .round, lineJoin: .round))
      }
      if let previousClose {
        RuleMark(y: .value(Self.valueKey, previousClose))
          .foregroundStyle(Palette.separatorStrong)
          .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.thin, dash: Tokens.Stroke.dashFine))
      }
    }
    .chartXAxis(.hidden)
    .chartYAxis(.hidden)
    .chartLegend(.hidden)
    .chartXScale(domain: 0...(shown.count - 1))
    .chartYScale(domain: .automatic(includesZero: false))
    .frame(height: Tokens.Size.dayLine)
    .drawsIn(on: closes)
    .accessibilityHidden(true)
  }
}
