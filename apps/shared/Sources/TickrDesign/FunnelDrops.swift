import QuartzCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Ticker dots falling through the funnel sheet's bars, as on the IOSFunnel board (mockup v159):
/// an overlay over the bars' column, `Size.funnelFlowInset` in from each side, as tall as the
/// bars. Four white dots with a dark rim and a soft glow fall from the top to the bottom one after
/// another, fading in at the top and out at the bottom; the second and the fourth drop out at the
/// middle stages (they stop near the middle, slide aside and fade). While `moving` (the caller's
/// `OrnamentGate`) and Reduce Motion is off they fall; otherwise none shows. An ornament: it shows
/// no data, takes no touch and VoiceOver skips it.
///
/// Core Animation plays the fall in the render server, so the app does no work per frame (as
/// `Hatch` and `MarqueeLayer` do).
public struct FunnelDrops: View {
  let moving: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  public init(moving: Bool) {
    self.moving = moving
  }

  public var body: some View {
    FunnelDropsLayer(dot: Palette.funnelDrop, rim: Palette.funnelDropRim.opacity(Tokens.Opacity.funnelDropRim),
      moving: moving && !reduceMotion)
      .padding(.horizontal, Tokens.Size.funnelFlowInset)
      .allowsHitTesting(false)
      .accessibilityHidden(true)
  }
}

struct FunnelDropsLayer {
  let dot: Color
  let rim: Color
  let moving: Bool
}

/// Holds the dots' layers and their falls.
final class FunnelDropsLayerView: PlatformView {
  /// Key of a dot's fall on its layer, and the key paths the fall drives.
  static let fallKey = "fall"
  static let downPath = "position.y"
  static let asidePath = "position.x"
  static let opacityPath = "opacity"

  /// One layer per dot, in `Tokens.Motion.funnelDropDelays` order; each transparent while still.
  private let dots: [CALayer] = Tokens.Motion.funnelDropDelays.map { _ in CALayer() }
  private var moving = false
  /// The size the running falls were made for: a new height restarts them.
  private var fallSize = CGSize.zero

  /// Whether the dots fall now (their falls are on the layers).
  var isFalling: Bool { dots.first?.animation(forKey: Self.fallKey) != nil }

  override init(frame: CGRect) {
    super.init(frame: frame)
    #if canImport(UIKit)
    isUserInteractionEnabled = false
    for dot in dots { layer.addSublayer(dot) }
    #else
    // A layer-hosting view: set our own layer before asking for one, as AppKit documents for
    // views that add sublayers.
    let host = CALayer()
    host.isGeometryFlipped = true
    layer = host
    wantsLayer = true
    for dot in dots { host.addSublayer(dot) }
    #endif
    for dot in dots { dot.opacity = 0 }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  // An ornament: touches go through to the stage bars under it.
  #if canImport(UIKit)
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }

  override func layoutSubviews() {
    super.layoutSubviews()
    place()
  }

  // Core Animation drops a layer's animation when its window goes away (or the app goes to the
  // background); start the falls again when the view is back on screen.
  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window != nil { fall() }
  }
  #else
  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  override func layout() {
    super.layout()
    place()
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if window != nil { fall() }
  }
  #endif

  /// Shows `drops` with its colours resolved for `environment`, and starts or stops the falls.
  func show(_ drops: FunnelDropsLayer, environment: EnvironmentValues) {
    let white = drops.dot.resolve(in: environment).cgColor
    let rim = drops.rim.resolve(in: environment).cgColor
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    for dot in dots {
      dot.backgroundColor = white
      dot.borderColor = rim
      dot.shadowColor = white
    }
    CATransaction.commit()
    moving = drops.moving
    fall()
  }

  /// A dot's side with its rim, outside the white as the board's ring shadow draws it.
  private static var side: CGFloat { Tokens.Size.funnelDrop + Tokens.Size.funnelDropRim + Tokens.Size.funnelDropRim }

  /// Puts each dot at the top middle with its rim and glow; a new size restarts the falls.
  private func place() {
    let side = Self.side
    let glow = CGRect(x: 0, y: 0, width: side, height: side)
      .insetBy(dx: -Tokens.Size.funnelDropGlowSpread, dy: -Tokens.Size.funnelDropGlowSpread)
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    for dot in dots {
      dot.bounds = CGRect(x: 0, y: 0, width: side, height: side)
      dot.position = CGPoint(x: bounds.midX, y: bounds.minY)
      dot.cornerRadius = side / 2
      dot.borderWidth = Tokens.Size.funnelDropRim
      dot.shadowOffset = .zero
      dot.shadowRadius = Tokens.Size.funnelDropGlow / 2
      dot.shadowOpacity = Float(Tokens.Opacity.funnelDropGlow)
      dot.shadowPath = CGPath(ellipseIn: glow, transform: nil)
    }
    CATransaction.commit()
    guard bounds.size != fallSize else { return }
    stop()
    fall()
  }

  private func stop() {
    for dot in dots { dot.removeAnimation(forKey: Self.fallKey) }
  }

  /// Starts the falls while `moving` and laid out (unless they run already), removes them otherwise.
  private func fall() {
    guard moving, !bounds.isEmpty else {
      stop()
      return
    }
    guard !isFalling else { return }
    fallSize = bounds.size
    for (index, dot) in dots.enumerated() {
      let falls = Tokens.Motion.funnelDropOuts.contains(index) ? dropOut() : drop()
      let group = CAAnimationGroup()
      group.animations = falls
      group.duration = Tokens.Motion.funnelDropSeconds
      group.beginTime = dot.convertTime(CACurrentMediaTime(), from: nil) + Tokens.Motion.funnelDropDelays[index]
      // decorative: owner-approved funnel sheet dots (mockup v159, 2026-11-26)
      group.repeatCount = .infinity
      group.isRemovedOnCompletion = false
      dot.add(group, forKey: Self.fallKey)
    }
  }

  /// The board's `fndrop`: top to bottom, in over the first `funnelDropFade` and out over the last.
  private func drop() -> [CAAnimation] {
    let fade = Tokens.Motion.funnelDropFade
    return [
      Self.keyframes(Self.downPath, [bounds.minY, bounds.maxY], at: [0, 1]),
      Self.keyframes(Self.opacityPath, [0, 1, 1, 0], at: [0, fade, 1 - fade, 1]),
    ]
  }

  /// The board's `fnout`: down to `funnelDropOutFall` of the height, then from `funnelDropOutStart`
  /// to `funnelDropOutEnd` of the cycle aside by `funnelDropShift` and down to `funnelDropOutRest`,
  /// fading out; gone for the rest of the cycle.
  private func dropOut() -> [CAAnimation] {
    let motion = Tokens.Motion.self
    let times = [0, motion.funnelDropOutStart, motion.funnelDropOutEnd, 1]
    let height = bounds.height
    let fall = bounds.minY + height * motion.funnelDropOutFall
    let rest = bounds.minY + height * motion.funnelDropOutRest
    let aside = bounds.midX + Tokens.Size.funnelDropShift
    return [
      Self.keyframes(Self.downPath, [bounds.minY, fall, rest, rest], at: times),
      Self.keyframes(Self.asidePath, [bounds.midX, bounds.midX, aside, aside], at: times),
      Self.keyframes(Self.opacityPath, [0, 1, 1, 0, 0],
        at: [0, motion.funnelDropFade, motion.funnelDropOutStart, motion.funnelDropOutEnd, 1]),
    ]
  }

  /// A linear keyframe animation of `path` through `values` at `times` (shares of the cycle).
  private static func keyframes(_ path: String, _ values: [CGFloat], at times: [Double]) -> CAKeyframeAnimation {
    let animation = CAKeyframeAnimation(keyPath: path)
    animation.values = values.map { NSNumber(value: Double($0)) }
    animation.keyTimes = times.map { NSNumber(value: $0) }
    animation.calculationMode = .linear
    return animation
  }
}

#if canImport(UIKit)
extension FunnelDropsLayer: UIViewRepresentable {
  func makeUIView(context: Context) -> FunnelDropsLayerView { FunnelDropsLayerView(frame: .zero) }
  func updateUIView(_ view: FunnelDropsLayerView, context: Context) { view.show(self, environment: context.environment) }
}
#elseif canImport(AppKit)
extension FunnelDropsLayer: NSViewRepresentable {
  func makeNSView(context: Context) -> FunnelDropsLayerView { FunnelDropsLayerView(frame: .zero) }
  func updateNSView(_ view: FunnelDropsLayerView, context: Context) { view.show(self, environment: context.environment) }
}
#endif
