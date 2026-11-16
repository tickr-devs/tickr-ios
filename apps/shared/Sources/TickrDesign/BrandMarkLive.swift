import QuartzCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// The live part of the brand mark: the halo ring the spark sends out, as on the design's boards
/// (from the spark's own size to `Tokens.Motion.pulseScale` times it, fading out). Core Animation
/// runs it in the render server. As a SwiftUI `repeatForever` animation it moved every display
/// frame inside the Overview's header, and each frame laid out the whole Overview again, texts
/// included: about a full CPU core at idle (Instruments, 2026-11-15).
struct BrandMarkLive {
  /// Side of the mark, in points.
  let size: CGFloat
  let lineColor: Color
  /// Whether the scene is in front. Core Animation drops a layer's loops when the app goes to the
  /// background; a change here updates the view, which starts them again.
  let active: Bool
}

/// Holds the ring layer and its loop.
final class BrandMarkLiveView: PlatformView {
  /// Key of the loop on the ring layer.
  static let ringKey = "ring"
  /// Key paths the loop drives.
  static let scalePath = "transform.scale"
  static let opacityPath = "opacity"

  private let root = CALayer()
  private let ring = CAShapeLayer()
  private var laidOutSize: CGFloat?

  override init(frame: CGRect) {
    super.init(frame: frame)
    #if canImport(UIKit)
    layer.addSublayer(root)
    #else
    // A layer-hosting view: set our own layer before asking for one, as AppKit documents for
    // views that add sublayers.
    let host = CALayer()
    layer = host
    wantsLayer = true
    host.addSublayer(root)
    #endif
    root.addSublayer(ring)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  // An ornament: clicks go through to what is under it (on the Mac, dragging the window).
  #if canImport(UIKit)
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }
  #else
  override func hitTest(_ point: NSPoint) -> NSView? { nil }
  #endif

  // Core Animation drops a layer's animation when its window goes away (or the app goes to the
  // background on iOS); start them again when the view is back on screen.
  #if canImport(UIKit)
  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window != nil, laidOutSize != nil { startLoop() }
  }
  #else
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if window != nil, laidOutSize != nil { startLoop() }
  }
  #endif

  /// Shows `mark` with its colour resolved for `environment`; lays out and starts the loop on the
  /// first show and when the size changes.
  func show(_ mark: BrandMarkLive, environment: EnvironmentValues) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    ring.fillColor = mark.lineColor.resolve(in: environment).cgColor
    if laidOutSize != mark.size { layOut(size: mark.size) }
    CATransaction.commit()
    if ring.animation(forKey: Self.ringKey) == nil { startLoop() }
  }

  private func layOut(size: CGFloat) {
    laidOutSize = size
    let bounds = CGRect(x: 0, y: 0, width: size, height: size)
    root.frame = bounds
    let diameter = size * BrandMark.sparkDiameter
    let spark = Self.upright(BrandMark.breakout)
    ring.frame = CGRect(
      x: spark.x * size - diameter / 2, y: spark.y * size - diameter / 2, width: diameter, height: diameter)
    ring.path = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: diameter, height: diameter), transform: nil)
    startLoop()
  }

  /// A point of the mark (shares from the top left) in this view's layer, whose origin is at the
  /// bottom left on macOS.
  private static func upright(_ point: CGPoint) -> CGPoint {
    #if canImport(UIKit)
    point
    #else
    CGPoint(x: point.x, y: 1 - point.y)
    #endif
  }

  /// The ring grows from the spark and fades, easing out, once every pulse.
  private func startLoop() {
    let grow = CABasicAnimation(keyPath: Self.scalePath)
    grow.fromValue = 1
    grow.toValue = Tokens.Motion.pulseScale
    let fade = CABasicAnimation(keyPath: Self.opacityPath)
    fade.fromValue = Tokens.Opacity.muted
    fade.toValue = 0
    let pulse = CAAnimationGroup()
    pulse.animations = [grow, fade]
    pulse.duration = Tokens.Motion.pulseSeconds
    pulse.timingFunction = CAMediaTimingFunction(name: .easeOut)
    // decorative: the brand mark's spark is an ornament (owner, 2026-11-15).
    pulse.repeatCount = .infinity
    pulse.isRemovedOnCompletion = false
    ring.opacity = 0
    ring.add(pulse, forKey: Self.ringKey)
  }
}

#if canImport(UIKit)
extension BrandMarkLive: UIViewRepresentable {
  func makeUIView(context: Context) -> BrandMarkLiveView { BrandMarkLiveView(frame: .zero) }
  func updateUIView(_ view: BrandMarkLiveView, context: Context) { view.show(self, environment: context.environment) }
}
#elseif canImport(AppKit)
extension BrandMarkLive: NSViewRepresentable {
  func makeNSView(context: Context) -> BrandMarkLiveView { BrandMarkLiveView(frame: .zero) }
  func updateNSView(_ view: BrandMarkLiveView, context: Context) { view.show(self, environment: context.environment) }
}
#endif
