import QuartzCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// The live part of the brand mark: a highlight that runs up the line to the spark, and a ring the
/// spark sends out. Core Animation runs both in the render server. As SwiftUI `repeatForever`
/// animations they moved every display frame inside the Overview's header, and each frame laid
/// out the whole Overview again, texts included: about a full CPU core at idle (Instruments,
/// 2026-11-15).
struct BrandMarkLive {
  /// Side of the mark, in points.
  let size: CGFloat
  let lineColor: Color
  let shineColor: Color
  /// Whether the scene is in front. Core Animation drops a layer's loops when the app goes to the
  /// background; a change here updates the view, which starts them again.
  let active: Bool
}

/// Holds the shine and ring layers and their loops.
final class BrandMarkLiveView: PlatformView {
  /// Keys of the two loops on their layers.
  static let shineKey = "shine"
  static let ringKey = "ring"
  /// Key paths the loops drive.
  static let strokeStartPath = "strokeStart"
  static let strokeEndPath = "strokeEnd"
  static let scalePath = "transform.scale"
  static let opacityPath = "opacity"

  private let root = CALayer()
  private let shine = CAShapeLayer()
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
    shine.fillColor = nil
    shine.lineCap = .round
    shine.lineJoin = .round
    root.addSublayer(shine)
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

  // Core Animation drops a layer's animations when its window goes away (or the app goes to the
  // background on iOS); start them again when the view is back on screen.
  #if canImport(UIKit)
  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window != nil, laidOutSize != nil { startLoops() }
  }
  #else
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if window != nil, laidOutSize != nil { startLoops() }
  }
  #endif

  /// Shows `mark` with colours resolved for `environment`; lays out and starts the loops on the
  /// first show and when the size changes.
  func show(_ mark: BrandMarkLive, environment: EnvironmentValues) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    shine.strokeColor = mark.shineColor.resolve(in: environment).cgColor
    ring.fillColor = mark.lineColor.resolve(in: environment).cgColor
    if laidOutSize != mark.size { layOut(size: mark.size) }
    CATransaction.commit()
    if shine.animation(forKey: Self.shineKey) == nil || ring.animation(forKey: Self.ringKey) == nil {
      startLoops()
    }
  }

  private func layOut(size: CGFloat) {
    laidOutSize = size
    let bounds = CGRect(x: 0, y: 0, width: size, height: size)
    root.frame = bounds
    shine.frame = bounds
    shine.lineWidth = size * BrandMark.lineWidth
    shine.path = TickLine(points: BrandMark.points.map(Self.upright)).path(in: bounds).cgPath
    let diameter = size * BrandMark.sparkDiameter * BrandMark.ringStart
    let spark = Self.upright(BrandMark.breakout)
    ring.frame = CGRect(
      x: spark.x * size - diameter / 2, y: spark.y * size - diameter / 2, width: diameter, height: diameter)
    ring.path = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: diameter, height: diameter), transform: nil)
    startLoops()
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

  /// The highlight runs from the line's start to past the spark, `BrandMark.shineLength` long,
  /// easing in and out; the ring grows and fades, easing out. Both repeat every pulse.
  private func startLoops() {
    let length = BrandMark.shineLength
    let trip = 1 + length
    let end = CAKeyframeAnimation(keyPath: Self.strokeEndPath)
    end.values = [0, 1, 1]
    end.keyTimes = [0, NSNumber(value: Double(1 / trip)), 1]
    let start = CAKeyframeAnimation(keyPath: Self.strokeStartPath)
    start.values = [0, 0, 1]
    start.keyTimes = [0, NSNumber(value: Double(length / trip)), 1]
    let run = CAAnimationGroup()
    run.animations = [start, end]
    run.duration = Tokens.Motion.pulseSeconds
    run.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    // decorative: the shine across the brand mark is an ornament (owner, 2026-11-15).
    run.repeatCount = .infinity
    run.isRemovedOnCompletion = false
    shine.strokeStart = 0
    shine.strokeEnd = 0
    shine.add(run, forKey: Self.shineKey)

    let grow = CABasicAnimation(keyPath: Self.scalePath)
    grow.fromValue = 1
    grow.toValue = BrandMark.ringGrowth
    let fade = CABasicAnimation(keyPath: Self.opacityPath)
    fade.fromValue = 1
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
