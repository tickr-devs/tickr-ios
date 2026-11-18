import SwiftUI

/// A ring that fills to `fraction` (0...1) with a soft halo behind it, and then on by `trailing`
/// in `trailingColor` (a day's losses after its wins). When a fraction changes the ring animates
/// to it and the halo swells once; nothing moves between changes.
public struct ResultRing<Center: View>: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var drawn = false
  let fraction: Double
  let color: Color
  let trailing: Double
  let trailingColor: Color
  /// The halo's colour; the ring's own when nil.
  let halo: Color?
  let lineWidth: CGFloat
  let center: Center

  public init(
    fraction: Double, color: Color, trailing: Double = 0, trailingColor: Color = .clear,
    halo: Color? = nil, lineWidth: CGFloat = Tokens.Stroke.ring, @ViewBuilder center: () -> Center
  ) {
    self.fraction = min(max(fraction, 0), 1)
    self.color = color
    self.trailing = min(max(trailing, 0), 1 - self.fraction)
    self.trailingColor = trailingColor
    self.halo = halo
    self.lineWidth = lineWidth
    self.center = center()
  }

  public var body: some View {
    ZStack {
      Circle()
        .fill(RadialGradient(colors: [(halo ?? color).opacity(Tokens.Opacity.border), .clear], center: .center,
          startRadius: 0, endRadius: Tokens.Size.ringHalo))
        .padding(lineWidth)
        .phaseAnimator([false, true], trigger: reduceMotion ? 0 : fraction) { halo, swelled in
          halo
            .scaleEffect(swelled ? Tokens.Motion.breatheScale : 1)
            .opacity(swelled ? Tokens.Opacity.overlay : Tokens.Opacity.faint)
        } animation: { _ in
          .easeInOut(duration: Tokens.Motion.breatheSeconds)
        }
      Circle().stroke(Palette.separator, lineWidth: lineWidth)
      Circle()
        .trim(from: drawn ? fraction : 0, to: drawn ? fraction + trailing : 0)
        .stroke(trailingColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        .rotationEffect(RingGeometry.startAngle)
        .animation(Tokens.Motion.fill, value: [fraction, trailing])
      Circle()
        .trim(from: 0, to: drawn ? fraction : 0)
        .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        .rotationEffect(RingGeometry.startAngle)
        .animation(Tokens.Motion.fill, value: fraction)
      center
    }
    .padding(lineWidth / 2)
    .onAppear {
      withAnimation(reduceMotion ? nil : Tokens.Motion.fill) { drawn = true }
    }
  }
}

/// Fixed geometry of `ResultRing` (kept outside the generic type, which cannot hold statics).
enum RingGeometry {
  /// The ring starts at twelve o'clock.
  static let startAngle = Angle.degrees(-90)
}
