import SwiftUI

// Small animated pieces shared by the operator apps. Motion is part of the design on every screen;
// each piece falls back to a still version when the person has Reduce Motion on.

/// A status dot with a ring that keeps expanding and fading out, meaning "live".
public struct PulseDot: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var expanded = false
  let color: Color
  let size: CGFloat
  let pulsing: Bool

  public init(_ color: Color, size: CGFloat = Tokens.Size.dot, pulsing: Bool = true) {
    self.color = color
    self.size = size
    self.pulsing = pulsing
  }

  public var body: some View {
    Circle()
      .fill(color)
      .frame(width: size, height: size)
      .overlay {
        if pulsing && !reduceMotion {
          Circle()
            .stroke(color, lineWidth: Tokens.Stroke.bold)
            .scaleEffect(expanded ? Tokens.Motion.pulseScale : 1)
            .opacity(expanded ? 0 : Tokens.Opacity.medium)
            .animation(.easeOut(duration: Tokens.Motion.pulseSeconds).repeatForever(autoreverses: false),
              value: expanded)
        }
      }
      .onAppear { expanded = true }
      .accessibilityHidden(true)
  }
}

/// Fades a view in while it rises a few points, after `delay`; staggered delays make a screen
/// assemble itself on appear.
public struct Rise: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var shown = false
  let delay: Double

  public func body(content: Content) -> some View {
    content
      .opacity(shown ? 1 : 0)
      .offset(y: shown || reduceMotion ? 0 : Tokens.Size.riseOffset)
      .onAppear {
        withAnimation(Tokens.Motion.entrance.delay(delay)) { shown = true }
      }
  }
}

public extension View {
  /// Rises in as the `step`-th card of a screen: 0 first, then `Tokens.Motion.stagger` apart.
  func rise(step: Int) -> some View { modifier(Rise(delay: Double(step) * Tokens.Motion.stagger)) }

  /// Rises in after `delay` seconds. Prefer `rise(step:)`, which keeps one rhythm on every screen.
  func rise(_ delay: Double = 0) -> some View { modifier(Rise(delay: delay)) }
}

/// A ring that fills to `fraction` (0...1) with a soft breathing halo behind it.
public struct ResultRing<Center: View>: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var drawn = false
  @State private var breathing = false
  let fraction: Double
  let color: Color
  let lineWidth: CGFloat
  let center: Center

  public init(fraction: Double, color: Color, lineWidth: CGFloat = Tokens.Stroke.ring, @ViewBuilder center: () -> Center) {
    self.fraction = min(max(fraction, 0), 1)
    self.color = color
    self.lineWidth = lineWidth
    self.center = center()
  }

  public var body: some View {
    ZStack {
      Circle()
        .fill(RadialGradient(colors: [color.opacity(Tokens.Opacity.border), .clear], center: .center,
          startRadius: 0, endRadius: Tokens.Size.ringHalo))
        .padding(lineWidth)
        .scaleEffect(breathing ? Tokens.Motion.breatheScale : 1)
        .opacity(breathing ? Tokens.Opacity.overlay : Tokens.Opacity.faint)
      Circle().stroke(Palette.separator, lineWidth: lineWidth)
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
      if !reduceMotion {
        withAnimation(.easeInOut(duration: Tokens.Motion.breatheSeconds).repeatForever(autoreverses: true)) {
          breathing = true
        }
      }
    }
  }
}

/// Fixed geometry of `ResultRing` (kept outside the generic type, which cannot hold statics).
enum RingGeometry {
  /// The ring starts at twelve o'clock.
  static let startAngle = Angle.degrees(-90)
}

/// A line through `values`, scaled to fill its frame. Animates when the values change.
public struct Sparkline: Shape {
  public var values: [Double]

  public init(_ values: [Double]) { self.values = values }

  public func path(in rect: CGRect) -> Path {
    var path = Path()
    guard values.count > 1, let low = values.min(), let high = values.max() else {
      path.move(to: CGPoint(x: rect.minX, y: rect.midY))
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
      return path
    }
    let span = high - low == 0 ? 1 : high - low
    for (index, value) in values.enumerated() {
      let point = CGPoint(
        x: rect.minX + rect.width * CGFloat(index) / CGFloat(values.count - 1),
        y: rect.maxY - rect.height * CGFloat((value - low) / span))
      if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
    }
    return path
  }
}

/// One entry of the scrolling event ticker.
public struct TickerItem: Identifiable, Hashable, Sendable {
  public let id: String
  public let tag: String
  public let text: String
  public let tone: Tone

  public enum Tone: Sendable { case teal, green, blue, amber, violet, red, muted }

  public init(id: String, tag: String, text: String, tone: Tone) {
    self.id = id
    self.tag = tag
    self.text = text
    self.tone = tone
  }
}

extension TickerItem.Tone {
  var color: Color {
    switch self {
    case .teal: return Palette.accentText
    case .green: return Palette.profitText
    case .blue: return Palette.infoText
    case .amber: return Palette.warningText
    case .violet: return Palette.highlightText
    case .red: return Palette.lossText
    case .muted: return Palette.textTertiary
    }
  }
}

/// A slowly scrolling strip of recent events (a marquee), paused when `moving` is false or Reduce
/// Motion is on; then it is an ordinary horizontal scroll view.
public struct Ticker: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var contentWidth: CGFloat = 0
  let items: [TickerItem]
  let moving: Bool
  /// Points per second.
  let speed: Double

  /// Share of the strip's width that fades out at each end.
  static let fadeEdge = 0.06

  public init(_ items: [TickerItem], moving: Bool = true, speed: Double = Tokens.Motion.tickerSpeed) {
    self.items = items
    self.moving = moving
    self.speed = speed
  }

  public var body: some View {
    Group {
      if moving && !reduceMotion && !items.isEmpty {
        TimelineView(.animation) { context in
          let t = context.date.timeIntervalSinceReferenceDate
          let offset = contentWidth > 0 ? -CGFloat((t * speed).truncatingRemainder(dividingBy: Double(contentWidth))) : 0
          HStack(spacing: 0) {
            row.background(GeometryReader { proxy in
              Color.clear.preference(key: WidthKey.self, value: proxy.size.width)
            })
            row
          }
          .offset(x: offset)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onPreferenceChange(WidthKey.self) { contentWidth = $0 }
        .clipped()
      } else {
        ScrollView(.horizontal, showsIndicators: false) { row }
      }
    }
    .mask(LinearGradient(
      stops: [.init(color: .clear, location: 0), .init(color: .black, location: Self.fadeEdge),
        .init(color: .black, location: 1 - Self.fadeEdge), .init(color: .clear, location: 1)],
      startPoint: .leading, endPoint: .trailing))
    .accessibilityElement(children: .combine)
  }

  private var row: some View {
    HStack(spacing: Tokens.Space.xl) {
      ForEach(items) { item in
        HStack(spacing: Tokens.Space.s) {
          Text(item.tag).fontWeight(.bold).foregroundStyle(item.tone.color)
          Text(item.text).foregroundStyle(Palette.textTertiary)
        }
        .font(Tokens.Typography.annotation)
        .lineLimit(1)
        .fixedSize()
      }
    }
    .padding(.trailing, Tokens.Space.xl)
  }

  private struct WidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
  }
}
