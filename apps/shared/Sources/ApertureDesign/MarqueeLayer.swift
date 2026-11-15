import QuartzCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// A picture of a marquee's row, drawn twice side by side and scrolled left in a loop by Core
/// Animation. The render server moves it: the app's main thread and SwiftUI do no work per frame,
/// where a SwiftUI-driven offset (or a TimelineView) recomputed the strip, and with it the screen
/// around it, on every display frame (Instruments, 2026-11-15).
struct MarqueeLayer {
  /// The row as an image, at `scale` pixels per point.
  let image: CGImage
  let scale: CGFloat
  /// Points per second.
  let speed: Double

  /// Size of the row in points.
  var size: CGSize {
    CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
  }
}

/// The view that holds the two copies of the row and their animation.
final class MarqueeLayerView: PlatformView {
  /// Key of the scroll animation on the strip layer.
  static let animationKey = "marquee"
  /// Key path the animation drives: the strip's horizontal shift.
  static let keyPath = "transform.translation.x"

  private let strip = CALayer()
  private let first = CALayer()
  private let second = CALayer()
  private var shown: MarqueeLayer?

  override init(frame: CGRect) {
    super.init(frame: frame)
    #if canImport(AppKit) && !canImport(UIKit)
    wantsLayer = true
    #endif
    for copy in [first, second] {
      copy.contentsGravity = .resize
      strip.addSublayer(copy)
    }
    hostLayer.addSublayer(strip)
    hostLayer.masksToBounds = true
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  private var hostLayer: CALayer {
    #if canImport(UIKit)
    layer
    #else
    layer ?? CALayer()
    #endif
  }

  /// Shows `marquee`: a new picture of the same width swaps in place; a new width keeps the scroll
  /// where it is (no jump back to the start) and loops over the new width.
  func show(_ marquee: MarqueeLayer) {
    let size = marquee.size
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    for (index, copy) in [first, second].enumerated() {
      copy.contents = marquee.image
      copy.contentsScale = marquee.scale
      copy.frame = CGRect(x: size.width * CGFloat(index), y: 0, width: size.width, height: size.height)
    }
    strip.frame = CGRect(x: 0, y: 0, width: size.width + size.width, height: size.height)
    CATransaction.commit()
    let restart = shown.map { $0.size.width != size.width || $0.speed != marquee.speed } ?? true
    shown = marquee
    if restart || strip.animation(forKey: Self.animationKey) == nil { scroll(width: size.width, speed: marquee.speed) }
  }

  private func scroll(width: CGFloat, speed: Double) {
    let current = (strip.presentation()?.value(forKeyPath: Self.keyPath) as? CGFloat) ?? 0
    strip.removeAnimation(forKey: Self.animationKey)
    guard width > 0, speed > 0 else { return }
    let animation = CABasicAnimation(keyPath: Self.keyPath)
    animation.fromValue = 0
    animation.toValue = -width
    animation.duration = Double(width) / speed
    animation.repeatCount = .infinity
    // Kept while the app is in the background or the view leaves its window, so it resumes.
    animation.isRemovedOnCompletion = false
    // Carry on from where the old loop was, within the new width.
    animation.timeOffset = Double(min(-current, width)) / speed
    // decorative: the ticker scrolls as an ornament; its items change only on real events (owner, 2026-11-15).
    strip.add(animation, forKey: Self.animationKey)
  }
}

#if canImport(UIKit)
typealias PlatformView = UIView

extension MarqueeLayer: UIViewRepresentable {
  func makeUIView(context: Context) -> MarqueeLayerView { MarqueeLayerView(frame: .zero) }
  func updateUIView(_ view: MarqueeLayerView, context: Context) { view.show(self) }
  func sizeThatFits(_ proposal: ProposedViewSize, uiView: MarqueeLayerView, context: Context) -> CGSize? {
    CGSize(width: proposal.width ?? size.width, height: size.height)
  }
}
#elseif canImport(AppKit)
typealias PlatformView = NSView

extension MarqueeLayer: NSViewRepresentable {
  func makeNSView(context: Context) -> MarqueeLayerView { MarqueeLayerView(frame: .zero) }
  func updateNSView(_ view: MarqueeLayerView, context: Context) { view.show(self) }
  func sizeThatFits(_ proposal: ProposedViewSize, nsView: MarqueeLayerView, context: Context) -> CGSize? {
    CGSize(width: proposal.width ?? size.width, height: size.height)
  }
}
#endif
