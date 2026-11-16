import Charts
import SwiftUI

/// A small Swift Charts line through `values`, without axes, that draws itself in from the left on
/// appear and whenever the values change (still with Reduce Motion). Fewer than two values draw a
/// flat line.
public struct DrawnSparkline: View {
  /// Plot keys of the two axes (Charts names its values with them; the chart is hidden from
  /// VoiceOver, so they are never read).
  static let indexKey = "index"
  static let valueKey = "value"

  let values: [Double]
  let color: Color

  public init(values: [Double], color: Color) {
    self.values = values
    self.color = color
  }

  public var body: some View {
    let shown = values.count > 1 ? values : [values.first ?? 0, values.first ?? 0]
    Chart(Array(shown.enumerated()), id: \.offset) { point in
      LineMark(x: .value(Self.indexKey, point.offset), y: .value(Self.valueKey, point.element))
        .foregroundStyle(color)
        .lineStyle(StrokeStyle(lineWidth: Tokens.Stroke.bold, lineCap: .round, lineJoin: .round))
    }
    .chartXAxis(.hidden)
    .chartYAxis(.hidden)
    .chartLegend(.hidden)
    .chartXScale(domain: 0...(shown.count - 1))
    .chartYScale(domain: .automatic(includesZero: false))
    .drawsIn(on: values)
    .accessibilityHidden(true)
  }
}

/// Draws its view in from the left once as it appears (`Motion.draw`); shows it whole at once with
/// Reduce Motion.
struct DrawIn: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var progress: CGFloat = 0

  func body(content: Content) -> some View {
    content
      .reveal(reduceMotion ? 1 : progress)
      .onAppear { withAnimation(Tokens.Motion.draw) { progress = 1 } }
  }
}

public extension View {
  /// Draws the view (a line, a chart) in from the left as it appears and again each time `trigger`
  /// changes: one draw per change of its data, still in between.
  func drawsIn(on trigger: some Hashable) -> some View {
    // A new identity per change starts the draw from nothing: setting the progress back to 0 and
    // animating it to 1 in one update would show no motion at all.
    modifier(DrawIn()).id(trigger)
  }

  /// Shows the leading `progress` (0...1) of the view's width: how charts draw themselves in.
  func reveal(_ progress: CGFloat) -> some View {
    mask(alignment: .leading) {
      GeometryReader { proxy in
        Rectangle().frame(width: proxy.size.width * progress)
      }
    }
  }
}
