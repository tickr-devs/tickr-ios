import AppKit
import QuartzCore
import SwiftUI
import TickrDesign
import TickrKit

/// When the radar moves. It is ornament, but a turning radar reads as "the bot is scanning", so it
/// turns only while that is true: the bot runs and its status is live and fresh. Stopped, stale,
/// unreachable or on a recorded day it stands still, as with Reduce Motion.
enum RadarGate {
  static func turns(reduceMotion: Bool, current: Bool, botState: BotState?) -> Bool {
    !reduceMotion && current && botState == .running
  }
}

/// The radar's turning sweep, a conic gradient, and its two blips, dots that each send out a ring
/// in turn, as the design's empty-positions radar draws them. Core Animation runs both in the
/// render server: driven by a `TimelineView(.animation)` the sweep redrew every display frame on
/// the main thread while the Overview had no positions, which is most of the day. The blips are
/// ornament like the sweep: they mark no symbol.
struct RadarSweep: NSViewRepresentable {
  /// Colour where the sweep is brightest; it fades to clear over `width`.
  let color: Color
  /// Width of the sweep's tail.
  let width: Angle
  /// Colours of the two blips, first then second.
  let blips: [Color]
  /// Whether the sweep turns and the blips ping (`RadarGate`); still otherwise.
  let turning: Bool
  /// Whether the scene is in front; a change updates the view, which starts the turn again.
  let active: Bool

  func makeNSView(context: Context) -> RadarSweepView { RadarSweepView(frame: .zero) }

  func updateNSView(_ view: RadarSweepView, context: Context) {
    view.show(
      color: color.resolve(in: context.environment).cgColor, width: width,
      blips: blips.map { $0.resolve(in: context.environment).cgColor }, turning: turning)
  }
}

/// Holds the sweep layer, round, and its turn, and the blips with their rings.
final class RadarSweepView: NSView {
  /// Keys of the turn on the sweep layer and of the ping on a blip's ring.
  static let turnKey = "turn"
  static let pingKey = "ping"
  /// Key paths the turn and the pings drive.
  static let rotationPath = "transform.rotation.z"
  static let scalePath = "transform.scale"
  static let opacityPath = "opacity"
  /// Centres of the blips, as shares of the radar from its top left (the design's 150-point radar:
  /// a violet blip at 44, 50 and a teal one at 108, 96).
  static let blipCentres = [CGPoint(x: 0.293, y: 0.333), CGPoint(x: 0.72, y: 0.64)]
  /// How far a blip's ring sits outside its dot, in points, and the share of a ping in which the
  /// ring grows and fades (it then rests until the next one), as the design's ping.
  static let ringOutset: CGFloat = 3
  static let pingShare = 0.8
  /// Centre of the conic gradient and the point that sets where it starts (along +x), as shares
  /// of the layer.
  static let center = CGPoint(x: 0.5, y: 0.5)
  static let startEdge = CGPoint(x: 1, y: 0.5)

  private let sweep = CAGradientLayer()
  private var dots: [CAShapeLayer] = []
  private var rings: [CAShapeLayer] = []
  private var turning = false

  override init(frame: CGRect) {
    super.init(frame: frame)
    // A layer-hosting view.
    let host = CALayer()
    host.isGeometryFlipped = true
    layer = host
    wantsLayer = true
    sweep.type = .conic
    sweep.startPoint = Self.center
    sweep.endPoint = Self.startEdge
    sweep.masksToBounds = true
    host.addSublayer(sweep)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  // An ornament: clicks go through to what is under it.
  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  override func layout() {
    super.layout()
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    sweep.frame = bounds
    sweep.cornerRadius = min(bounds.width, bounds.height) / 2
    let dot = Tokens.Size.dot
    let ring = Self.ringOutset + dot + Self.ringOutset
    for (index, centre) in Self.blipCentres.enumerated() where index < dots.count {
      let x = centre.x * bounds.width
      let y = centre.y * bounds.height
      dots[index].frame = CGRect(x: x - dot / 2, y: y - dot / 2, width: dot, height: dot)
      dots[index].path = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: dot, height: dot), transform: nil)
      rings[index].frame = CGRect(x: x - ring / 2, y: y - ring / 2, width: ring, height: ring)
      rings[index].path = CGPath(
        ellipseIn: CGRect(x: 0, y: 0, width: ring, height: ring).insetBy(dx: Tokens.Stroke.bold / 2, dy: Tokens.Stroke.bold / 2),
        transform: nil)
    }
    CATransaction.commit()
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if window != nil { turn() }
  }

  /// Colours the sweep and the blips and starts or stops their motion.
  func show(color: CGColor, width: Angle, blips: [CGColor], turning: Bool) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    sweep.colors = [color, color.copy(alpha: 0) ?? color, color.copy(alpha: 0) ?? color]
    sweep.locations = [0, NSNumber(value: width.radians / Geometry.fullTurn), 1]
    if dots.count != blips.count { makeBlips(blips.count) }
    for (index, blip) in blips.enumerated() {
      dots[index].fillColor = blip
      rings[index].strokeColor = blip
    }
    CATransaction.commit()
    self.turning = turning
    turn()
  }

  private func makeBlips(_ count: Int) {
    (dots + rings).forEach { $0.removeFromSuperlayer() }
    dots = (0..<count).map { _ in CAShapeLayer() }
    rings = (0..<count).map { _ in
      let ring = CAShapeLayer()
      ring.fillColor = nil
      ring.lineWidth = Tokens.Stroke.bold
      ring.opacity = 0
      return ring
    }
    (rings + dots).forEach { layer?.addSublayer($0) }
    needsLayout = true
  }

  private func turn() {
    guard turning else {
      sweep.removeAnimation(forKey: Self.turnKey)
      rings.forEach { $0.removeAnimation(forKey: Self.pingKey) }
      return
    }
    ping()
    guard sweep.animation(forKey: Self.turnKey) == nil else { return }
    let turn = CABasicAnimation(keyPath: Self.rotationPath)
    // Clockwise on screen, so the bright edge leads and the fade trails behind it, like a radar.
    turn.fromValue = 0
    turn.toValue = -Geometry.fullTurn
    turn.duration = Tokens.Motion.rotationSeconds
    turn.timingFunction = CAMediaTimingFunction(name: .linear)
    // decorative: the empty-positions radar is an ornament; it shows no data (owner, 2026-11-15).
    turn.repeatCount = .infinity
    turn.isRemovedOnCompletion = false
    sweep.add(turn, forKey: Self.turnKey)
  }

  /// Each blip's ring grows to `Tokens.Motion.blipScale` and fades out, easing out, then rests
  /// until its next ping; the second blip trails the first by `Tokens.Motion.blipLagSeconds`.
  private func ping() {
    for (index, ring) in rings.enumerated() where ring.animation(forKey: Self.pingKey) == nil {
      let rest = NSNumber(value: Self.pingShare)
      let grow = CAKeyframeAnimation(keyPath: Self.scalePath)
      grow.values = [1, Tokens.Motion.blipScale, Tokens.Motion.blipScale]
      grow.keyTimes = [0, rest, 1]
      let fade = CAKeyframeAnimation(keyPath: Self.opacityPath)
      fade.values = [Tokens.Opacity.medium, 0, 0]
      fade.keyTimes = [0, rest, 1]
      let ping = CAAnimationGroup()
      ping.animations = [grow, fade]
      ping.duration = Tokens.Motion.pulseSeconds
      ping.timingFunction = CAMediaTimingFunction(name: .easeOut)
      ping.beginTime = ring.convertTime(CACurrentMediaTime(), from: nil) + Double(index) * Tokens.Motion.blipLagSeconds
      ping.fillMode = .backwards
      // decorative: the empty-positions radar's blips are an ornament; they mark no symbol (owner, 2026-11-15).
      ping.repeatCount = .infinity
      ping.isRemovedOnCompletion = false
      ring.add(ping, forKey: Self.pingKey)
    }
  }
}
