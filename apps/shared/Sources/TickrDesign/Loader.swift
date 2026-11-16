import QuartzCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// How the loader moves.
public enum LoaderMotion: Equatable, Sendable {
  /// A teal beam turns over the rings, its dot pinging at the top on each turn.
  case sweep
  /// Reduce Motion: no beam and no dot; the rings pulse gently, outer to inner (owner, 2026-11-16).
  case pulse
}

/// Tickr's loader, in place of the system's spinner, as on the Controls board: a small radar of
/// three rings in `separatorStrong` with a teal beam turning once every `Motion.loaderTurnSeconds`
/// and a teal dot pinging at its top on each turn. Under Reduce Motion the beam stands down and the
/// rings pulse gently instead. `.compact` (`Size.loader`) inside a card, `.large`
/// (`Size.loaderLarge`) for a whole pane (the Chart). An optional caption under it, which wraps
/// rather than being cut; VoiceOver reads the label once, as one element.
///
/// Ornament (design-system rule 5): it marks no data, only that a read is in flight, and it is on
/// screen only while one is. Core Animation runs it in the render server, like the brand halo and
/// the advisor title's shine (`ShineBand`), so it costs the main thread nothing while it turns.
public struct TickrLoader: View {
  /// The loader's size.
  public enum Size: Sendable {
    /// Inside a card or beside a button.
    case compact
    /// For a whole pane (the Chart).
    case large

    var side: CGFloat { self == .compact ? Tokens.Size.loader : Tokens.Size.loaderLarge }
    var dot: CGFloat { self == .compact ? Tokens.Size.loaderDot : Tokens.Size.loaderDotLarge }
  }

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase
  let label: Text
  let size: Size
  let showsCaption: Bool

  /// `label` is what is loading ("Loading ABCD · 1m bars"): VoiceOver's name for the loader, and
  /// its caption when `caption` is true.
  public init(_ label: LocalizedStringResource, size: Size = .compact, caption: Bool = false) {
    self.label = Text(label)
    self.size = size
    self.showsCaption = caption
  }

  /// How the loader moves under the person's Reduce Motion setting.
  public static func motion(reduceMotion: Bool) -> LoaderMotion { reduceMotion ? .pulse : .sweep }

  public var body: some View {
    VStack(spacing: Tokens.Space.s) {
      RadarLoader(
        motion: Self.motion(reduceMotion: reduceMotion), dot: size.dot, beam: Palette.accent,
        rings: Palette.separatorStrong, active: scenePhase == .active)
        .frame(width: size.side, height: size.side)
        .accessibilityHidden(true)
      if showsCaption {
        label
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label)
    .accessibilityAddTraits(.updatesFrequently)
  }
}

/// The loader's layers: the three rings, the beam and the dot.
struct RadarLoader {
  let motion: LoaderMotion
  /// Diameter of the ping dot.
  let dot: CGFloat
  let beam: Color
  let rings: Color
  /// Whether the scene is in front; a change updates the view, which starts the motion again.
  let active: Bool
}

/// Holds the loader's layers and their motion.
final class RadarLoaderView: PlatformView {
  /// Keys of the beam's turn, the dot's ping and a ring's pulse.
  static let turnKey = "turn"
  static let pingKey = "ping"
  static let pulseKey = "pulse"
  /// Key paths the motion drives.
  static let rotationPath = "transform.rotation.z"
  static let scalePath = "transform.scale"
  static let opacityPath = "opacity"
  /// The inner rings' insets, as shares of the loader's side (the board's 22% and 41%); the
  /// innermost is filled.
  static let ringInsets: [CGFloat] = [0, 0.22, 0.41]
  /// Centre of the beam's conic gradient, and the point that sets where it starts: the top, where
  /// the dot sits.
  static let center = CGPoint(x: 0.5, y: 0.5)
  static let top = CGPoint(x: 0.5, y: 0)
  /// One full turn, in radians.
  static let fullTurn = Double.pi * 2

  private(set) var ringLayers: [CAShapeLayer] = []
  let beamLayer = CAGradientLayer()
  let dotLayer = CAShapeLayer()
  private(set) var motion: LoaderMotion?
  private var dot: CGFloat = 0
  private var laidOutSide: CGFloat?

  override init(frame: CGRect) {
    super.init(frame: frame)
    ringLayers = Self.ringInsets.map { _ in CAShapeLayer() }
    for ring in ringLayers { ring.lineWidth = Tokens.Stroke.regular }
    beamLayer.type = .conic
    beamLayer.startPoint = Self.center
    beamLayer.endPoint = Self.top
    beamLayer.locations = [0, NSNumber(value: 1 - Tokens.Motion.loaderTail), 1]
    #if canImport(UIKit)
    isUserInteractionEnabled = false
    let host = layer
    #else
    // A layer-hosting view, its y axis downward as on iOS, so both turn the same way.
    let host = CALayer()
    host.isGeometryFlipped = true
    layer = host
    wantsLayer = true
    #endif
    for ring in ringLayers { host.addSublayer(ring) }
    host.addSublayer(beamLayer)
    host.addSublayer(dotLayer)
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
    if window != nil { start() }
  }
  #else
  override func hitTest(_ point: NSPoint) -> NSView? { nil }
  override func layout() {
    super.layout()
    place()
  }
  // Core Animation drops a layer's animations when its window goes away; start them again.
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if window != nil { start() }
  }
  #endif

  /// Shows `loader` with its colours resolved for `environment`; starts its motion when it changed
  /// or is not running.
  func show(_ loader: RadarLoader, environment: EnvironmentValues) {
    let beam = loader.beam.resolve(in: environment).cgColor
    let rings = loader.rings.resolve(in: environment).cgColor
    let clear = beam.copy(alpha: 0) ?? beam
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    beamLayer.colors = [clear, clear, beam.copy(alpha: Tokens.Opacity.muted) ?? beam]
    dotLayer.fillColor = beam
    for (index, ring) in ringLayers.enumerated() {
      ring.strokeColor = rings
      ring.fillColor = index == ringLayers.count - 1 ? rings : nil
    }
    CATransaction.commit()
    let changed = motion != loader.motion || dot != loader.dot
    motion = loader.motion
    dot = loader.dot
    place()
    if changed || !running { start() }
  }

  /// Whether the motion for the current mode is on its layers.
  private var running: Bool {
    switch motion {
    case .sweep: beamLayer.animation(forKey: Self.turnKey) != nil
    case .pulse: ringLayers.allSatisfy { $0.animation(forKey: Self.pulseKey) != nil }
    case nil: false
    }
  }

  /// Sizes the rings, the beam and the dot to the view.
  private func place() {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    let side = min(bounds.width, bounds.height)
    let half = Tokens.Stroke.regular / 2
    for (index, ring) in ringLayers.enumerated() {
      let inset = Self.ringInsets[index] * side
      ring.frame = bounds
      ring.path = CGPath(ellipseIn: bounds.insetBy(dx: inset + half, dy: inset + half), transform: nil)
    }
    beamLayer.frame = bounds
    beamLayer.cornerRadius = side / 2
    beamLayer.masksToBounds = true
    dotLayer.frame = CGRect(x: bounds.midX - dot / 2, y: bounds.minY - dot / 2, width: dot, height: dot)
    dotLayer.path = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: dot, height: dot), transform: nil)
    CATransaction.commit()
    // The first layout with a size starts the motion that `show` could not start without one.
    if laidOutSide != side {
      laidOutSide = side
      start()
    }
  }

  /// Puts the motion of the current mode on the layers and takes the other one off.
  private func start() {
    guard let motion, bounds.width > 0 else { return }
    for ring in ringLayers { ring.removeAnimation(forKey: Self.pulseKey) }
    beamLayer.removeAnimation(forKey: Self.turnKey)
    dotLayer.removeAnimation(forKey: Self.pingKey)
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    switch motion {
    case .sweep:
      beamLayer.opacity = 1
      dotLayer.opacity = 1
      for ring in ringLayers { ring.opacity = 1 }
      beamLayer.add(Self.turn(), forKey: Self.turnKey)
      dotLayer.add(Self.ping(), forKey: Self.pingKey)
    case .pulse:
      beamLayer.opacity = 0
      dotLayer.opacity = 0
      let now = CACurrentMediaTime()
      for (index, ring) in ringLayers.enumerated() {
        ring.add(Self.pulse(from: now, lag: Double(index) * Tokens.Motion.loaderPulseLagSeconds), forKey: Self.pulseKey)
      }
    }
    CATransaction.commit()
  }

  /// One turn of the beam, at an even pace, again and again.
  static func turn() -> CABasicAnimation {
    let turn = CABasicAnimation(keyPath: rotationPath)
    turn.fromValue = 0
    turn.toValue = fullTurn
    turn.duration = Tokens.Motion.loaderTurnSeconds
    turn.timingFunction = CAMediaTimingFunction(name: .linear)
    // decorative: the loader is ornament while a read is in flight (design-system rule 5).
    turn.repeatCount = .infinity
    turn.isRemovedOnCompletion = false
    return turn
  }

  /// The dot's ping as the beam passes it: grown and bright, settling to its size and fading a
  /// little, once a turn.
  static func ping() -> CAAnimationGroup {
    let shrink = CABasicAnimation(keyPath: scalePath)
    shrink.fromValue = Tokens.Motion.loaderPingScale
    shrink.toValue = 1
    let fade = CABasicAnimation(keyPath: opacityPath)
    fade.fromValue = 1
    fade.toValue = Tokens.Opacity.border
    let ping = CAAnimationGroup()
    ping.animations = [shrink, fade]
    ping.duration = Tokens.Motion.loaderTurnSeconds
    ping.timingFunction = CAMediaTimingFunction(name: .easeOut)
    // decorative: the loader is ornament while a read is in flight (design-system rule 5).
    ping.repeatCount = .infinity
    ping.isRemovedOnCompletion = false
    return ping
  }

  /// A ring's gentle pulse under Reduce Motion: faint, full and faint again, `lag` seconds after
  /// the ring around it; the opacity alone changes, nothing moves.
  static func pulse(from now: CFTimeInterval, lag: Double) -> CABasicAnimation {
    let pulse = CABasicAnimation(keyPath: opacityPath)
    pulse.fromValue = Tokens.Motion.loaderPulseLow
    pulse.toValue = 1
    pulse.duration = Tokens.Motion.loaderPulseSeconds / 2
    pulse.autoreverses = true
    pulse.beginTime = now + lag
    pulse.fillMode = .backwards
    pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    // decorative: the loader's Reduce Motion pulse, owner's choice (2026-11-16, design-system rule 5).
    pulse.repeatCount = .infinity
    pulse.isRemovedOnCompletion = false
    return pulse
  }
}

#if canImport(UIKit)
extension RadarLoader: UIViewRepresentable {
  func makeUIView(context: Context) -> RadarLoaderView { RadarLoaderView(frame: .zero) }
  func updateUIView(_ view: RadarLoaderView, context: Context) { view.show(self, environment: context.environment) }
}
#elseif canImport(AppKit)
extension RadarLoader: NSViewRepresentable {
  func makeNSView(context: Context) -> RadarLoaderView { RadarLoaderView(frame: .zero) }
  func updateNSView(_ view: RadarLoaderView, context: Context) { view.show(self, environment: context.environment) }
}
#endif
