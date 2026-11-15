import AppKit
import ApertureDesign
import QuartzCore
import SwiftUI

/// The radar's turning sweep: a conic gradient that Core Animation turns in the render server.
/// Driven by a `TimelineView(.animation)` it redrew every display frame on the main thread while
/// the Overview had no positions, which is most of the day.
struct RadarSweep: NSViewRepresentable {
  /// Colour where the sweep is brightest; it fades to clear over `width`.
  let color: Color
  /// Width of the sweep's tail.
  let width: Angle
  /// Whether it turns (off with Reduce Motion).
  let turning: Bool
  /// Whether the scene is in front; a change updates the view, which starts the turn again.
  let active: Bool

  func makeNSView(context: Context) -> RadarSweepView { RadarSweepView(frame: .zero) }

  func updateNSView(_ view: RadarSweepView, context: Context) {
    view.show(color: color.resolve(in: context.environment).cgColor, width: width, turning: turning)
  }
}

/// Holds the sweep layer, round, and its turn.
final class RadarSweepView: NSView {
  /// Key of the turn on the sweep layer.
  static let turnKey = "turn"
  /// Key path the turn drives.
  static let rotationPath = "transform.rotation.z"
  /// Centre of the conic gradient and the point that sets where it starts (along +x), as shares
  /// of the layer.
  static let center = CGPoint(x: 0.5, y: 0.5)
  static let startEdge = CGPoint(x: 1, y: 0.5)

  private let sweep = CAGradientLayer()
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
    CATransaction.commit()
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if window != nil { turn() }
  }

  /// Colours the sweep and starts or stops its turn.
  func show(color: CGColor, width: Angle, turning: Bool) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    sweep.colors = [color, color.copy(alpha: 0) ?? color, color.copy(alpha: 0) ?? color]
    sweep.locations = [0, NSNumber(value: width.radians / Geometry.fullTurn), 1]
    CATransaction.commit()
    self.turning = turning
    turn()
  }

  private func turn() {
    guard turning else {
      sweep.removeAnimation(forKey: Self.turnKey)
      return
    }
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
}
