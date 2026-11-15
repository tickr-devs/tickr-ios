import SwiftUI

/// The Tickr mark: a price line drawn as a tick that breaks upward, with a spark at its end. The
/// app icon and the iOS launch screen draw the same line (apps/scripts/make_brand_assets.py).
///
/// On appear the line draws itself and the area under it fades in. While `live` (the bot's data is
/// current) the spark then keeps pulsing; otherwise, and with Reduce Motion, the mark stands still.
///
/// Empty screens show it as their illustration (`BrandMark.empty`): in brand colours when there is
/// simply nothing yet, muted when the bot cannot be reached.
public struct BrandMark: View {
  /// How the mark is coloured.
  public enum Tone: Sendable {
    /// Brand colours: profit line, accent area.
    case brand
    /// One quiet colour: nothing can be known right now (bot unreachable).
    case muted
  }

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorScheme) private var colorScheme
  @State private var drawn: CGFloat = 0
  @State private var breathing = false
  /// Where the live shine is along the line (0 to 1 plus its length, so it leaves at the end).
  @State private var shine: CGFloat = 0
  @State private var settled = false
  let size: CGFloat
  let live: Bool
  let tone: Tone
  /// How the line draws itself on appear; nil shows it drawn at once.
  let drawing: Animation?

  /// Points of the line as shares of the mark's side, left to right (POINTS in make_brand_assets.py).
  static let start = CGPoint(x: 0.205, y: 0.51)
  static let dip = CGPoint(x: 0.39, y: 0.7)
  static let bounce = CGPoint(x: 0.5, y: 0.575)
  static let retest = CGPoint(x: 0.565, y: 0.625)
  public static let breakout = CGPoint(x: 0.81, y: 0.285)
  static let points = [start, dip, bounce, retest, breakout]
  /// Line width, spark diameter and the bottom of the fading area, as shares of the side.
  static let lineWidth = 0.084
  public static let sparkDiameter = 0.09
  static let areaBottom = 0.86
  /// The live ring: its diameter as a multiple of the spark's at the start, and how far it grows.
  static let ringStart: CGFloat = 1.6
  static let ringGrowth: CGFloat = 2.4
  /// Radius of the soft glow behind the line, as a share of the side (the canvas header's glow).
  static let glowRadius = 0.18
  /// Seconds before the line starts drawing, so a window is on screen before it moves.
  static let drawDelay = 0.35
  /// Length of the live shine running along the line, as a share of the line.
  static let shineLength: CGFloat = 0.28
  /// The area's side fade, from the line's start to its end: fully in at `areaIn`, fading out
  /// again from `areaOut` (shares of that run), so neither side has an edge.
  static let areaIn = 0.45
  static let areaOut = 0.6

  /// `drawsIn` false shows the mark already drawn: where an opening animation has just put it.
  public init(size: CGFloat = Tokens.Size.logo, live: Bool, tone: Tone = .brand, drawsIn: Bool = true) {
    self.init(size: size, live: live, tone: tone, drawing: drawsIn ? Tokens.Motion.draw.delay(Self.drawDelay) : nil)
  }

  init(size: CGFloat, live: Bool, tone: Tone, drawing: Animation?) {
    self.size = size
    self.live = live
    self.tone = tone
    self.drawing = drawing
  }

  /// The illustration of an empty screen: large and still.
  public static func empty(_ tone: Tone = .brand) -> BrandMark {
    BrandMark(size: Tokens.Size.emptyMark, live: false, tone: tone)
  }

  private var lineColor: Color { tone == .brand ? Palette.profit : Palette.textQuaternary }
  private var areaColor: Color { tone == .brand ? Palette.accent : Palette.textQuaternary }
  /// A green halo on dark; on light a halo turns muddy, so only a trace of it.
  private var glowColor: Color {
    guard tone == .brand else { return .clear }
    return lineColor.opacity(colorScheme == .dark ? Tokens.Opacity.border : Tokens.Opacity.wash)
  }
  private var lineEnd: Color { tone == .brand ? Palette.accent : Palette.textQuaternary }

  public var body: some View {
    let spark = Self.breakout
    let diameter = size * Self.sparkDiameter
    ZStack(alignment: .topLeading) {
      TickArea(points: Self.points, bottom: Self.areaBottom)
        // Fades out downwards and in from the left, so it reads as a glow under the line, not a box.
        .fill(LinearGradient(colors: [areaColor.opacity(Tokens.Opacity.border), .clear],
          startPoint: UnitPoint(x: Self.breakout.x, y: Self.breakout.y),
          endPoint: UnitPoint(x: Self.breakout.x, y: Self.areaBottom)))
        .mask(LinearGradient(
          stops: [.init(color: .clear, location: 0), .init(color: .black, location: Self.areaIn),
            .init(color: .black, location: Self.areaOut), .init(color: .clear, location: 1)],
          startPoint: UnitPoint(x: Self.start.x, y: Self.start.y),
          endPoint: UnitPoint(x: Self.breakout.x, y: Self.start.y)))
        .opacity(drawn)
      TickLine(points: Self.points)
        .trim(from: 0, to: drawn)
        .stroke(
          LinearGradient(colors: [lineColor, lineEnd], startPoint: .topTrailing, endPoint: .bottomLeading),
          style: StrokeStyle(lineWidth: size * Self.lineWidth, lineCap: .round, lineJoin: .round))
      if live && settled && !reduceMotion {
        // While live a highlight runs up the line to the spark, and the spark sends out a ring.
        TickShine(points: Self.points, phase: shine, length: Self.shineLength)
          .stroke(Palette.shine.opacity(Tokens.Opacity.medium),
            style: StrokeStyle(lineWidth: size * Self.lineWidth, lineCap: .round, lineJoin: .round))
          .blendMode(.plusLighter)
        Circle()
          .fill(lineColor.opacity(Tokens.Opacity.medium))
          .frame(width: diameter * Self.ringStart, height: diameter * Self.ringStart)
          .scaleEffect(breathing ? Self.ringGrowth : 1)
          .opacity(breathing ? 0 : 1)
          .position(x: spark.x * size, y: spark.y * size)
          .onAppear(perform: pulse)
          .onDisappear {
            breathing = false
            shine = 0
          }
      }
      Circle()
        .fill(lineColor)
        .frame(width: diameter, height: diameter)
        .scaleEffect(drawn)
        .position(x: spark.x * size, y: spark.y * size)
    }
    .frame(width: size, height: size)
    .shadow(color: glowColor, radius: size * Self.glowRadius)
    .onAppear(perform: appear)
    .accessibilityHidden(true)
  }

  private func appear() {
    guard !reduceMotion, let drawing else {
      drawn = 1
      settled = true
      return
    }
    withAnimation(drawing) {
      drawn = 1
    } completion: {
      settled = true
    }
  }

  private func pulse() {
    // decorative: the brand mark's spark is an ornament (owner, 2026-11-15).
    withAnimation(.easeOut(duration: Tokens.Motion.pulseSeconds).repeatForever(autoreverses: false)) {
      breathing = true
    }
    // decorative: the shine across the brand mark is an ornament (owner, 2026-11-15).
    withAnimation(.easeInOut(duration: Tokens.Motion.pulseSeconds).repeatForever(autoreverses: false)) {
      shine = 1 + Self.shineLength
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

/// A piece of the tick's line `length` long that ends at `phase` (shares of the line), animatable
/// so it can run along the line.
struct TickShine: Shape {
  let points: [CGPoint]
  var phase: CGFloat
  let length: CGFloat

  var animatableData: CGFloat {
    get { phase }
    set { phase = newValue }
  }

  func path(in rect: CGRect) -> Path {
    TickLine(points: points).path(in: rect).trimmedPath(from: max(0, phase - length), to: min(1, phase))
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
  HStack {
    BrandMark(live: true)
    BrandMark.empty()
    BrandMark.empty(.muted)
  }
    .padding()
    .background(Palette.background)
}
