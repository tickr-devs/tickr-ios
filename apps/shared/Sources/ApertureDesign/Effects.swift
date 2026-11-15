import SwiftUI

// Small animated pieces shared by the operator apps. Motion is part of the design on every screen;
// each piece falls back to a still version when the person has Reduce Motion on.

/// A status dot. While `pulsing`, a ring expands and fades out once each time `event` changes (a new
/// status read, a fill, a state change): motion only on real events, never a loop. With no event it
/// stays still.
public struct PulseDot: View {
  let color: Color
  let size: CGFloat
  let pulsing: Bool
  let event: AnyHashable?

  public init(_ color: Color, size: CGFloat = Tokens.Size.dot, pulsing: Bool = true, event: AnyHashable? = nil) {
    self.color = color
    self.size = size
    self.pulsing = pulsing
    self.event = event
  }

  public var body: some View {
    Circle()
      .fill(color)
      .frame(width: size, height: size)
      .eventPulse(Circle(), color: color, scale: Tokens.Motion.pulseScale, event: pulsing ? event : nil)
      .accessibilityHidden(true)
  }
}

/// The steps of one event pulse: hidden, shown at the outline, grown and faded.
enum PulsePhase: CaseIterable {
  case rest, start, end
}

/// Draws `shape`'s outline around the view and plays one expanding, fading pulse each time `event`
/// changes. Nothing moves without a new event or with Reduce Motion on.
struct EventPulse<S: Shape>: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let shape: S
  let color: Color
  let scale: CGFloat
  let event: AnyHashable?

  func body(content: Content) -> some View {
    content.overlay {
      if let event, !reduceMotion {
        shape
          .stroke(color, lineWidth: Tokens.Stroke.bold)
          .phaseAnimator(PulsePhase.allCases, trigger: event) { ring, phase in
            ring
              .scaleEffect(phase == .end ? scale : 1)
              .opacity(phase == .start ? Tokens.Opacity.medium : 0)
          } animation: { phase in
            phase == .end ? .easeOut(duration: Tokens.Motion.pulseSeconds) : nil
          }
          .allowsHitTesting(false)
      }
    }
  }
}

extension View {
  /// One pulse of `shape`'s outline per change of `event`; still without one.
  func eventPulse<S: Shape>(_ shape: S, color: Color, scale: CGFloat, event: AnyHashable?) -> some View {
    modifier(EventPulse(shape: shape, color: color, scale: scale, event: event))
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

/// A ring that fills to `fraction` (0...1) with a soft halo behind it. When the fraction changes the
/// ring animates to it and the halo swells once; nothing moves between changes.
public struct ResultRing<Center: View>: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var drawn = false
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
        .phaseAnimator([false, true], trigger: reduceMotion ? 0 : fraction) { halo, swelled in
          halo
            .scaleEffect(swelled ? Tokens.Motion.breatheScale : 1)
            .opacity(swelled ? Tokens.Opacity.overlay : Tokens.Opacity.faint)
        } animation: { _ in
          .easeInOut(duration: Tokens.Motion.breatheSeconds)
        }
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
  let items: [TickerItem]
  let moving: Bool
  /// Points per second.
  let speed: Double

  public init(_ items: [TickerItem], moving: Bool = true, speed: Double = Tokens.Motion.tickerSpeed) {
    self.items = items
    self.moving = moving
    self.speed = speed
  }

  public var body: some View {
    Marquee(moving: moving && !items.isEmpty, content: items, speed: speed) { row }
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

}

/// A row that scrolls slowly to the left in a loop, faded at both ends, paused when `moving` is
/// false or Reduce Motion is on; then it is an ordinary horizontal scroll view.
///
/// The row is drawn into a picture once per change of `content` (or of appearance) and Core
/// Animation scrolls it (`MarqueeLayer`), so the scroll costs the app nothing per frame. Hover
/// help on the scrolling row is not shown; VoiceOver reads the live row.
public struct Marquee<Row: View>: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.displayScale) private var displayScale
  @Environment(\.locale) private var locale
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.colorSchemeContrast) private var contrast
  @State private var picture: CGImage?
  let moving: Bool
  /// What the row shows; a change draws the picture again.
  let content: AnyHashable
  /// Points per second.
  let speed: Double
  let row: Row

  public init(
    moving: Bool = true, content: AnyHashable, speed: Double = Tokens.Motion.tickerSpeed, @ViewBuilder row: () -> Row
  ) {
    self.moving = moving
    self.content = content
    self.speed = speed
    self.row = row()
  }

  /// Everything the picture depends on.
  private struct PictureKey: Hashable {
    let content: AnyHashable
    let scheme: ColorScheme
    let scale: CGFloat
    let locale: Locale
    let typeSize: DynamicTypeSize
    let contrast: ColorSchemeContrast
  }

  public var body: some View {
    Group {
      if moving && !reduceMotion {
        ZStack(alignment: .leading) {
          // The live row, invisible: it gives the strip its height.
          row.fixedSize().hidden()
          if let picture {
            MarqueeLayer(image: picture, scale: displayScale, speed: speed)
              .accessibilityRepresentation { row }
          }
        }
        // minWidth 0: the strip takes the width it is offered, never the width of its row
        // (else it widens the whole screen and pushes everything else off the sides).
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .clipped()
        .task(id: pictureKey) { draw() }
      } else {
        ScrollView(.horizontal, showsIndicators: false) { row }
      }
    }
    .mask(LinearGradient(
      stops: [.init(color: .clear, location: 0), .init(color: .black, location: MarqueeLayout.fadeEdge),
        .init(color: .black, location: 1 - MarqueeLayout.fadeEdge), .init(color: .clear, location: 1)],
      startPoint: .leading, endPoint: .trailing))
    .accessibilityElement(children: .combine)
  }

  private var pictureKey: PictureKey {
    PictureKey(
      content: content, scheme: colorScheme, scale: displayScale, locale: locale, typeSize: typeSize,
      contrast: contrast)
  }

  /// Draws the row into the picture the layer scrolls. A renderer does not inherit the screen's
  /// environment, so what the row's look depends on is passed in. Increased contrast cannot be
  /// set on a view (it is read-only), so a change of it only redraws; the palette has one value
  /// per appearance.
  private func draw() {
    let renderer = ImageRenderer(
      content: row.fixedSize()
        .environment(\.colorScheme, colorScheme)
        .environment(\.locale, locale)
        .environment(\.dynamicTypeSize, typeSize))
    renderer.scale = displayScale
    picture = renderer.cgImage
  }
}

private enum MarqueeLayout {
  /// Share of a marquee's width that fades out at each end.
  static let fadeEdge = 0.06
}
