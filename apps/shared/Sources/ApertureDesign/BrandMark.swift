import SwiftUI

/// The Tickr mark: a price line drawn as a tick that breaks upward, with a spark at its end. The
/// app icon and the iOS launch screen draw the same line (apps/scripts/make_brand_assets.py).
///
/// On appear the line draws itself and the area under it fades in. While `live` (the bot's data is
/// current) the spark then keeps pulsing; otherwise, and with Reduce Motion, the mark stands still.
public struct BrandMark: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var drawn: CGFloat = 0
  @State private var breathing = false
  @State private var settled = false
  let size: CGFloat
  let live: Bool

  /// Points of the line as shares of the mark's side, left to right (POINTS in make_brand_assets.py).
  static let start = CGPoint(x: 0.205, y: 0.51)
  static let dip = CGPoint(x: 0.39, y: 0.7)
  static let bounce = CGPoint(x: 0.5, y: 0.575)
  static let retest = CGPoint(x: 0.565, y: 0.625)
  static let breakout = CGPoint(x: 0.81, y: 0.285)
  static let points = [start, dip, bounce, retest, breakout]
  /// Line width, spark diameter and the bottom of the fading area, as shares of the side.
  static let lineWidth = 0.084
  static let sparkDiameter = 0.09
  static let areaBottom = 0.86

  public init(size: CGFloat = Tokens.Size.logo, live: Bool) {
    self.size = size
    self.live = live
  }

  public var body: some View {
    let spark = Self.breakout
    let diameter = size * Self.sparkDiameter
    ZStack(alignment: .topLeading) {
      TickArea(points: Self.points, bottom: Self.areaBottom)
        .fill(LinearGradient(colors: [Palette.accent.opacity(Tokens.Opacity.border), Palette.accent.opacity(0)],
          startPoint: .top, endPoint: .bottom))
        .opacity(drawn)
      TickLine(points: Self.points)
        .trim(from: 0, to: drawn)
        .stroke(
          LinearGradient(colors: [Palette.profit, Palette.accent], startPoint: .topTrailing, endPoint: .bottomLeading),
          style: StrokeStyle(lineWidth: size * Self.lineWidth, lineCap: .round, lineJoin: .round))
      if live && settled && !reduceMotion {
        Circle()
          .fill(Palette.profit.opacity(Tokens.Opacity.faint))
          .frame(width: diameter, height: diameter)
          .scaleEffect(breathing ? Tokens.Motion.pulseScale : 1)
          .opacity(breathing ? 0 : 1)
          .position(x: spark.x * size, y: spark.y * size)
          .onAppear(perform: pulse)
          .onDisappear { breathing = false }
      }
      Circle()
        .fill(Palette.profit)
        .frame(width: diameter, height: diameter)
        .scaleEffect(drawn)
        .position(x: spark.x * size, y: spark.y * size)
    }
    .frame(width: size, height: size)
    .onAppear(perform: appear)
    .accessibilityHidden(true)
  }

  private func appear() {
    guard !reduceMotion else {
      drawn = 1
      return
    }
    withAnimation(Tokens.Motion.draw) {
      drawn = 1
    } completion: {
      settled = true
    }
  }

  private func pulse() {
    withAnimation(.easeOut(duration: Tokens.Motion.pulseSeconds).repeatForever(autoreverses: false)) {
      breathing = true
    }
  }
}

/// The tick's price line through `points` (shares of the rect).
struct TickLine: Shape {
  let points: [CGPoint]

  func path(in rect: CGRect) -> Path {
    Path { path in
      path.addLines(points.map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height) })
    }
  }
}

/// The area under the tick's line, down to `bottom` (a share of the rect's height).
struct TickArea: Shape {
  let points: [CGPoint]
  let bottom: CGFloat

  func path(in rect: CGRect) -> Path {
    guard let first = points.first, let last = points.last else { return Path() }
    var path = TickLine(points: points).path(in: rect)
    path.addLine(to: CGPoint(x: rect.minX + last.x * rect.width, y: rect.minY + bottom * rect.height))
    path.addLine(to: CGPoint(x: rect.minX + first.x * rect.width, y: rect.minY + bottom * rect.height))
    path.closeSubpath()
    return path
  }
}

#Preview {
  BrandMark(live: true)
    .padding()
    .background(Palette.background)
}
