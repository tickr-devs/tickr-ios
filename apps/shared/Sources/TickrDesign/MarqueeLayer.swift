import QuartzCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// How fast a `Marquee` scrolls.
public enum MarqueePace: Hashable, Sendable {
  /// Points per second.
  case speed(Double)
  /// The whole row passes once in this many seconds, however long it is.
  case loop(seconds: Double)
}

/// A picture of a marquee's row, drawn twice side by side and scrolled left in a loop by Core
/// Animation. The render server moves it: the app's main thread and SwiftUI do no work per frame,
/// where a SwiftUI-driven offset (or a TimelineView) recomputed the strip, and with it the screen
/// around it, on every display frame (Instruments, 2026-11-15).
///
/// The picture comes in tiles laid left to right (`MarqueeTiles`): one picture of a long row is
/// wider than a renderer can draw, and comes out blank.
struct MarqueeLayer {
  /// The row as images laid side by side, at `scale` pixels per point.
  let tiles: [CGImage]
  let scale: CGFloat
  /// Points per second.
  let speed: Double

  /// Size of the row in points.
  var size: CGSize {
    CGSize(
      width: tiles.reduce(0) { $0 + CGFloat($1.width) } / scale,
      height: CGFloat(tiles.map(\.height).max() ?? 0) / scale)
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
      copy.frame = CGRect(x: size.width * CGFloat(index), y: 0, width: size.width, height: size.height)
      copy.sublayers = Self.tileLayers(marquee)
    }
    strip.frame = CGRect(x: 0, y: 0, width: size.width + size.width, height: size.height)
    CATransaction.commit()
    let restart = shown.map { $0.size.width != size.width || $0.speed != marquee.speed } ?? true
    shown = marquee
    if restart || strip.animation(forKey: Self.animationKey) == nil { scroll(width: size.width, speed: marquee.speed) }
  }

  /// One layer per tile, each at its place in the row.
  private static func tileLayers(_ marquee: MarqueeLayer) -> [CALayer] {
    var x: CGFloat = 0
    return marquee.tiles.map { image in
      let tile = CALayer()
      tile.contents = image
      tile.contentsScale = marquee.scale
      tile.contentsGravity = .resize
      let width = CGFloat(image.width) / marquee.scale
      tile.frame = CGRect(x: x, y: 0, width: width, height: CGFloat(image.height) / marquee.scale)
      x += width
      return tile
    }
  }

  private func scroll(width: CGFloat, speed: Double) {
    let current = (strip.presentation()?.value(forKeyPath: Self.keyPath) as? CGFloat) ?? 0
    strip.removeAnimation(forKey: Self.animationKey)
    guard width > 0, speed > 0 else { return }
    let animation = CABasicAnimation(keyPath: Self.keyPath)
    animation.fromValue = 0
    animation.toValue = -width
    animation.duration = Double(width) / speed
    // decorative: the ticker scrolls as an ornament; its items change only on real events (owner, 2026-11-15).
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
