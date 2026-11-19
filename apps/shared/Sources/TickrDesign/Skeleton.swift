import QuartzCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Content loading (mockup v102, docs/design-system.md "Loading"): the shape of the real layout in
/// `SkeletonBlock`s, with a faint band of light sweeping across it. Never a radar and never the
/// system spinner; nothing real is shown until the data is ready.
///
/// Put the blocks (and grid lines, `SkeletonGridLine`) inside, laid out exactly as the content
/// they stand for. VoiceOver reads the skeleton once, by `label` ("Loading symbols").
///
/// Ornament (design-system rule 5): it marks no data, only that a read is in flight, and it is on
/// screen only while one is, so it moves whenever it shows. Core Animation sweeps the band in the
/// render server, like `ShineBand`. Under Reduce Motion nothing sweeps: the skeleton pulses from
/// full to `Loading.pulseLow` opacity and back instead.
public struct Skeleton<Content: View>: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase
  @State private var dimmed = false
  let label: Text?
  let content: Content

  /// - Parameters:
  ///   - label: what is loading, read by VoiceOver; nil where a caption beside it already says
  ///     so, or for a part of a screen whose other skeleton carries the name.
  public init(_ label: LocalizedStringResource?, @ViewBuilder content: () -> Content) {
    self.label = label.map { Text($0) }
    self.content = content()
  }

  /// How the skeleton moves under the person's Reduce Motion setting.
  public static func motion(reduceMotion: Bool) -> SkeletonMotion { reduceMotion ? .pulse : .sweep }

  public var body: some View {
    let motion = Self.motion(reduceMotion: reduceMotion)
    content
      .opacity(motion == .pulse && dimmed ? Tokens.Loading.pulseLow : 1)
      .overlay {
        if motion == .sweep {
          ShimmerBand(color: Palette.textPrimary, active: scenePhase == .active)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
      }
      .clipped()
      .onAppear { pulse(motion) }
      .onChange(of: motion) { _, new in pulse(new) }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(label ?? Text(verbatim: ""))
      .accessibilityHidden(label == nil)
      .accessibilityAddTraits(.updatesFrequently)
  }

  /// Starts the Reduce Motion pulse, or stops it.
  private func pulse(_ motion: SkeletonMotion) {
    guard motion == .pulse else {
      var still = Transaction()
      still.disablesAnimations = true
      withTransaction(still) { dimmed = false }
      return
    }
    withAnimation(Tokens.Loading.pulse) { dimmed = true }
  }
}

/// How a skeleton (and the button spinner) moves.
public enum SkeletonMotion: Equatable, Sendable {
  /// The band of light sweeps across; the spinner turns.
  case sweep
  /// Reduce Motion: nothing moves; the opacity pulses gently.
  case pulse
}

extension Tokens.Loading {
  /// The Reduce Motion pulse: full to `pulseLow` and back once every `pulseSeconds`.
  static let pulse = Animation.easeInOut(duration: pulseSeconds / 2)
    // decorative: the skeleton's Reduce Motion pulse while a read is in flight (mockup v102, design-system rule 5).
    .repeatForever(autoreverses: true)
}

/// One block of a skeleton, in the shape of what it stands for.
public struct SkeletonBlock: View {
  /// What the block stands for, which sets its height and corner radius.
  public enum Kind: Sendable, Hashable {
    /// A line of text (`Loading.lineHeight`).
    case line
    /// A value: a price, a figure (`Loading.valueHeight`).
    case value
    /// A pill: a badge, a chip (`Loading.pillHeight`).
    case pill
    /// A block of its own height (a glyph, a sparkline, a candle), radius `Loading.blockRadius`.
    case block(height: CGFloat)
    /// A block as tall as the view it stands for (a chip, a button), radius `Loading.pillRadius`;
    /// used with `View.skeleton(_:_:)`.
    case fill
  }

  let kind: Kind
  let width: CGFloat?

  /// - Parameter width: the block's width; nil fills the width it is offered.
  public init(_ kind: Kind = .line, width: CGFloat? = nil) {
    self.kind = kind
    self.width = width
  }

  /// The fill of every skeleton block: `separatorStrong` mixed into `surfaceSunken`.
  public static let fill = Palette.surfaceSunken.mix(with: Palette.separatorStrong, by: Tokens.Loading.blockMix)

  public var body: some View {
    RoundedRectangle(cornerRadius: radius, style: .continuous)
      .fill(Self.fill)
      .frame(width: width, height: height)
      .frame(maxWidth: width == nil ? .infinity : nil, maxHeight: height == nil ? .infinity : nil,
        alignment: .leading)
  }

  /// The block's height; nil fills the height it is offered (`fill`).
  var height: CGFloat? {
    switch kind {
    case .line: Tokens.Loading.lineHeight
    case .value: Tokens.Loading.valueHeight
    case .pill: Tokens.Loading.pillHeight
    case .block(let height): height
    case .fill: nil
    }
  }

  var radius: CGFloat {
    switch kind {
    case .line: Tokens.Loading.lineRadius
    case .value: Tokens.Loading.blockRadius
    case .pill, .fill: Tokens.Loading.pillRadius
    case .block(let height): min(Tokens.Loading.blockRadius, height / 2)
    }
  }
}

/// A grid line of a skeleton (an axis grid, a row divider): `separator` at `Loading.gridOpacity`.
public struct SkeletonGridLine: View {
  public enum Axis: Sendable { case horizontal, vertical }
  let axis: Axis

  public init(_ axis: Axis = .horizontal) {
    self.axis = axis
  }

  /// The colour of every skeleton grid line.
  public static let color = Palette.separator.opacity(Tokens.Loading.gridOpacity)

  public var body: some View {
    Rectangle()
      .fill(Self.color)
      .frame(width: axis == .vertical ? Tokens.Stroke.hairline : nil,
        height: axis == .horizontal ? Tokens.Stroke.hairline : nil)
  }
}

// MARK: - the shimmer band

/// The band of light that sweeps across a skeleton, in Core Animation (see `Skeleton`).
struct ShimmerBand {
  let color: Color
  /// Whether the scene is in front; a change updates the view, which starts the sweep again.
  let active: Bool
}

/// Holds the band layer and its sweep.
final class ShimmerBandView: PlatformView {
  /// Key of the sweep on the band layer, and the key path it drives.
  static let sweepKey = "sweep"
  static let translationPath = "transform.translation.x"
  /// Half (unit factor) and degrees in half a turn (unit factor).
  static let half = 0.5
  static let halfTurnDegrees = 180.0

  let band = CAGradientLayer()
  private var laidOut: CGSize?

  override init(frame: CGRect) {
    super.init(frame: frame)
    band.locations = Tokens.Loading.shimmerStops.map { NSNumber(value: $0) }
    #if canImport(UIKit)
    isUserInteractionEnabled = false
    layer.masksToBounds = true
    layer.addSublayer(band)
    #else
    // A layer-hosting view, its y axis downward as on iOS, so the band leans the same way.
    let host = CALayer()
    host.isGeometryFlipped = true
    host.masksToBounds = true
    layer = host
    wantsLayer = true
    host.addSublayer(band)
    #endif
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  // An ornament: clicks and touches go through to what is under it.
  #if canImport(UIKit)
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }
  override func layoutSubviews() {
    super.layoutSubviews()
    place()
  }
  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window != nil { startSweep() }
  }
  #else
  override func hitTest(_ point: NSPoint) -> NSView? { nil }
  override func layout() {
    super.layout()
    place()
  }
  // Core Animation drops a layer's animation when its window goes away; start it again.
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if window != nil { startSweep() }
  }
  #endif

  /// Shows `shimmer` with its colour resolved for `environment`; starts the sweep if it is not
  /// running.
  func show(_ shimmer: ShimmerBand, environment: EnvironmentValues) {
    let light = shimmer.color.resolve(in: environment).cgColor
    let clear = light.copy(alpha: 0) ?? light
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    band.colors = [clear, light.copy(alpha: Tokens.Loading.shimmerOpacity) ?? light, clear]
    CATransaction.commit()
    if band.animation(forKey: Self.sweepKey) == nil { startSweep() }
  }

  /// The band image is `shimmerWidth` times the skeleton's width, its gradient at `shimmerAngle`.
  private func place() {
    let size = bounds.size
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    band.frame = CGRect(x: 0, y: 0, width: size.width * Tokens.Loading.shimmerWidth, height: size.height)
    let points = Self.gradientPoints(size: band.bounds.size, degrees: Tokens.Loading.shimmerAngle)
    band.startPoint = points.start
    band.endPoint = points.end
    CATransaction.commit()
    if laidOut != size {
      laidOut = size
      startSweep()
    }
  }

  /// How far into its current sweep the shared clock is at media time `now`, in seconds.
  static func sweepPhase(at now: CFTimeInterval) -> CFTimeInterval {
    now.truncatingRemainder(dividingBy: Tokens.Loading.shimmerSeconds)
  }

  /// Start and end of a CSS linear gradient at `degrees` over a box of `size`, in the layer's
  /// unit coordinates (y downward): the gradient line runs through the centre, as long as the
  /// box's extent along it.
  static func gradientPoints(size: CGSize, degrees: Double) -> (start: CGPoint, end: CGPoint) {
    guard size.width > 0, size.height > 0 else { return (CGPoint(x: 0, y: half), CGPoint(x: 1, y: half)) }
    let angle = degrees * .pi / halfTurnDegrees
    let dx = sin(angle)
    let dy = -cos(angle)
    let length = abs(size.width * dx) + abs(size.height * dy)
    let reach = length * half
    func unit(_ sign: Double) -> CGPoint {
      CGPoint(x: half + sign * dx * reach / size.width, y: half + sign * dy * reach / size.height)
    }
    return (unit(-1), unit(1))
  }

  /// Where the band starts and ends its sweep, as translations of the band image (which is
  /// `shimmerWidth` times the skeleton's width): its light, the gradient between its outer stops,
  /// leaning at `shimmerAngle`, wholly off the skeleton on the left at the start and on the right
  /// at the end, whatever the skeleton's height. The board's fixed 120% → −20% left the leaning
  /// light's corners on a tall skeleton (the Chart's), so every sweep ended with light still at
  /// the right edge that then jumped back to the left: the "boom" the owner saw (2026-11-19).
  static func travel(size: CGSize) -> (from: CGFloat, to: CGFloat) {
    let bandWidth = size.width * Tokens.Loading.shimmerWidth
    let angle = Tokens.Loading.shimmerAngle * .pi / halfTurnDegrees
    let across = abs(sin(angle))
    let down = abs(cos(angle))
    guard across > 0, let first = Tokens.Loading.shimmerStops.first, let last = Tokens.Loading.shimmerStops.last else {
      return (-bandWidth, size.width)
    }
    // The gradient line's length over the band box, and the light's half-width along it.
    let length = bandWidth * across + size.height * down
    let light = length * (last - first) * half
    // How far right of the band's centre line the light reaches, at the skeleton's top or bottom
    // edge, where the lean carries it furthest.
    let reach = (light + size.height * half * down) / across
    let centre = bandWidth * half
    return (-(centre + reach), size.width - centre + reach)
  }

  /// The band sweeps left to right, ease-in-out, again and again, its light off the skeleton at
  /// both ends (`travel`), so a new sweep never shows the light jumping back. Every skeleton
  /// sweeps on one clock (`sweepPhase`): the cards of a screen shimmer together, and a skeleton
  /// laid out again (another size) goes on where the sweep is instead of jumping back to its
  /// start, which read as a jerky loader (owner report 2026-11-17).
  private func startSweep() {
    guard bounds.width > 0 else { return }
    let now = CACurrentMediaTime()
    let travel = Self.travel(size: bounds.size)
    let sweep = CABasicAnimation(keyPath: Self.translationPath)
    sweep.beginTime = band.convertTime(now, from: nil) - Self.sweepPhase(at: now)
    sweep.fromValue = travel.from
    sweep.toValue = travel.to
    sweep.duration = Tokens.Loading.shimmerSeconds
    sweep.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    // decorative: the skeleton's shimmer while a read is in flight, only while it shows (mockup v102, rule 5).
    sweep.repeatCount = .infinity
    sweep.isRemovedOnCompletion = false
    band.add(sweep, forKey: Self.sweepKey)
  }
}

#if canImport(UIKit)
extension ShimmerBand: UIViewRepresentable {
  func makeUIView(context: Context) -> ShimmerBandView { ShimmerBandView(frame: .zero) }
  func updateUIView(_ view: ShimmerBandView, context: Context) { view.show(self, environment: context.environment) }
}
#elseif canImport(AppKit)
extension ShimmerBand: NSViewRepresentable {
  func makeNSView(context: Context) -> ShimmerBandView { ShimmerBandView(frame: .zero) }
  func updateNSView(_ view: ShimmerBandView, context: Context) { view.show(self, environment: context.environment) }
}
#endif
