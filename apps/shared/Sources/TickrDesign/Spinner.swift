import QuartzCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// A command in flight (mockup v102, docs/design-system.md "Loading"): a neutral ring with a
/// quarter arc turning once every `Loading.spinnerTurnSeconds`, in the button's glyph place while
/// the bot or the broker answers. Mac 16 pt, iOS 20 pt. Under Reduce Motion the arc stands still
/// and the ring pulses gently in opacity instead.
///
/// Never on its own for content loading (that is a `Skeleton`): the command styles show it when
/// the button is marked `.inFlight(_:)`.
///
/// Ornament (design-system rule 5): it marks only that a command is in flight and is on screen
/// only while one is. Core Animation turns it in the render server.
public struct Spinner: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase
  @ScaledMetric(relativeTo: .callout) private var side = Tokens.Loading.spinner

  public init() {}

  public var body: some View {
    SpinnerRing(
      motion: Skeleton<EmptyView>.motion(reduceMotion: reduceMotion), color: Palette.textTertiary,
      active: scenePhase == .active)
      .frame(width: side, height: side)
      .accessibilityHidden(true)
  }
}

/// The spinner's layers: the track and the arc.
struct SpinnerRing {
  let motion: SkeletonMotion
  let color: Color
  /// Whether the scene is in front; a change updates the view, which starts the motion again.
  let active: Bool
}

/// Holds the spinner's layers and their motion.
final class SpinnerRingView: PlatformView {
  /// Keys of the arc's turn and the ring's Reduce Motion pulse, and the key paths they drive.
  static let turnKey = "turn"
  static let pulseKey = "pulse"
  static let rotationPath = "transform.rotation.z"
  static let opacityPath = "opacity"
  /// One full turn, in radians, and the top of the ring (where the arc starts), a quarter turn
  /// back from the right.
  static let fullTurn = Double.pi * 2
  static let quarterTurns = 4.0

  let track = CAShapeLayer()
  let arc = CAShapeLayer()
  private(set) var motion: SkeletonMotion?
  private var laidOutSide: CGFloat?
  private let host: CALayer

  override init(frame: CGRect) {
    #if canImport(UIKit)
    host = CALayer()
    super.init(frame: frame)
    isUserInteractionEnabled = false
    layer.addSublayer(host)
    #else
    // A layer-hosting view, its y axis downward as on iOS, so both turn the same way.
    host = CALayer()
    super.init(frame: frame)
    host.isGeometryFlipped = true
    layer = host
    wantsLayer = true
    #endif
    for shape in [track, arc] {
      shape.fillColor = nil
      shape.lineWidth = Tokens.Loading.spinnerStroke
      host.addSublayer(shape)
    }
    arc.lineCap = .butt
    arc.strokeStart = 0
    arc.strokeEnd = Tokens.Loading.spinnerArc
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  #if canImport(UIKit)
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }
  override func layoutSubviews() {
    super.layoutSubviews()
    host.frame = bounds
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

  /// Shows `ring` with its colours resolved for `environment`; starts its motion when it changed
  /// or is not running.
  func show(_ ring: SpinnerRing, environment: EnvironmentValues) {
    let color = ring.color.resolve(in: environment).cgColor
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    track.strokeColor = color.copy(alpha: Tokens.Loading.spinnerTrackOpacity) ?? color
    arc.strokeColor = color
    CATransaction.commit()
    let changed = motion != ring.motion
    motion = ring.motion
    if changed || !running { start() }
  }

  /// Whether the motion for the current mode is on its layers.
  private var running: Bool {
    switch motion {
    case .sweep: arc.animation(forKey: Self.turnKey) != nil
    case .pulse: host.animation(forKey: Self.pulseKey) != nil
    case nil: false
    }
  }

  /// Sizes the ring to the view: a circle inside its stroke, the arc starting at the top.
  private func place() {
    let side = min(bounds.width, bounds.height)
    let inset = Tokens.Loading.spinnerStroke / 2
    let box = CGRect(x: 0, y: 0, width: side, height: side)
    // Starting at the top and running clockwise on screen (y downward).
    let top = -Self.fullTurn / Self.quarterTurns
    let path = CGMutablePath()
    path.addArc(center: CGPoint(x: box.midX, y: box.midY), radius: max(side / 2 - inset, 0),
      startAngle: top, endAngle: top + Self.fullTurn, clockwise: false)
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    for shape in [track, arc] {
      shape.frame = box
      shape.path = path
    }
    CATransaction.commit()
    if laidOutSide != side {
      laidOutSide = side
      start()
    }
  }

  /// Puts the motion of the current mode on the layers and takes the other one off.
  private func start() {
    guard let motion, bounds.width > 0 else { return }
    arc.removeAnimation(forKey: Self.turnKey)
    host.removeAnimation(forKey: Self.pulseKey)
    switch motion {
    case .sweep: arc.add(Self.turn(), forKey: Self.turnKey)
    case .pulse: host.add(Self.pulse(), forKey: Self.pulseKey)
    }
  }

  /// One turn of the arc, at an even pace, again and again.
  static func turn() -> CABasicAnimation {
    let turn = CABasicAnimation(keyPath: rotationPath)
    turn.fromValue = 0
    turn.toValue = fullTurn
    turn.duration = Tokens.Loading.spinnerTurnSeconds
    turn.timingFunction = CAMediaTimingFunction(name: .linear)
    // decorative: the spinner turns only while a command is in flight (mockup v102, design-system rule 5).
    turn.repeatCount = .infinity
    turn.isRemovedOnCompletion = false
    return turn
  }

  /// The ring's Reduce Motion pulse: full, `pulseLow` and full again; nothing moves.
  static func pulse() -> CABasicAnimation {
    let pulse = CABasicAnimation(keyPath: opacityPath)
    pulse.fromValue = 1
    pulse.toValue = Tokens.Loading.pulseLow
    pulse.duration = Tokens.Loading.pulseSeconds / 2
    pulse.autoreverses = true
    pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    // decorative: the spinner's Reduce Motion pulse while a command is in flight (mockup v102, rule 5).
    pulse.repeatCount = .infinity
    pulse.isRemovedOnCompletion = false
    return pulse
  }
}

#if canImport(UIKit)
extension SpinnerRing: UIViewRepresentable {
  func makeUIView(context: Context) -> SpinnerRingView { SpinnerRingView(frame: .zero) }
  func updateUIView(_ view: SpinnerRingView, context: Context) { view.show(self, environment: context.environment) }
}
#elseif canImport(AppKit)
extension SpinnerRing: NSViewRepresentable {
  func makeNSView(context: Context) -> SpinnerRingView { SpinnerRingView(frame: .zero) }
  func updateNSView(_ view: SpinnerRingView, context: Context) { view.show(self, environment: context.environment) }
}
#endif

// MARK: - a command in flight

public extension EnvironmentValues {
  /// What a command button says while its command is in flight ("Closing ABCD position"); nil
  /// while it is not. Set with `.inFlight(_:)`.
  @Entry var commandInFlight: Text?
}

public extension View {
  /// Marks the command button (`.command`, `.action`) as in flight while `progress` is set: the
  /// spinner takes its glyph's place, `progress` its title's, VoiceOver reads `progress`, and a
  /// second click or tap does nothing. Not dimmed though the command is off meanwhile.
  func inFlight(_ progress: Text?) -> some View { environment(\.commandInFlight, progress) }
}

// MARK: - an operation of known length

/// An operation of known length (mockup v102, docs/design-system.md "Loading"): a 2 pt line,
/// `info` over its 18% track, its fill growing to `fraction` (0...1) in `Loading.progressSeconds`
/// (at once under Reduce Motion). Its caption ("Replay · 12 of 30 days · 40%") is the caller's.
public struct ProgressLine: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let fraction: Double
  let label: Text

  /// - Parameters:
  ///   - fraction: how much is done, 0...1.
  ///   - label: what is in progress, read by VoiceOver with the percentage.
  public init(fraction: Double, label: LocalizedStringResource) {
    self.fraction = min(max(fraction, 0), 1)
    self.label = Text(label)
  }

  public var body: some View {
    let shape = RoundedRectangle(cornerRadius: Tokens.Loading.progressRadius, style: .continuous)
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        shape.fill(Palette.info.opacity(Tokens.Loading.progressTrackOpacity))
        shape.fill(Palette.info).frame(width: proxy.size.width * fraction)
      }
    }
    .frame(height: Tokens.Loading.progressHeight)
    .animation(reduceMotion ? nil : Tokens.Loading.progressCurve, value: fraction)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label)
    .accessibilityValue(Text(fraction, format: .percent.precision(.fractionLength(0))))
    .accessibilityAddTraits(.updatesFrequently)
  }
}
