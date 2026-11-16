import QuartzCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Diagonal stripes filling the view, as the design draws a planned (BACKLOG) stretch: bands
/// `HatchLayerView.stripe` wide with gaps as wide, running down to the right (the boards'
/// `repeating-linear-gradient(45deg, …)`), in `color` at `Hatch.opacity`. While `moving` they drift right at
/// `HatchLayerView.speed`, as the boards' `stripes` keyframes do; still otherwise.
///
/// Core Animation drifts them in the render server, so the app does no work per frame (as
/// `MarqueeLayer` and the radar do).
public struct Hatch: View {
  #if os(iOS)
  /// Opacity of the stripes over their colour: the iPhone design's 25%.
  public static let opacity = 0.25
  #else
  /// Opacity of the stripes over their colour: the Mac design's 18%.
  public static let opacity = 0.18
  #endif

  let color: Color
  let moving: Bool

  public init(_ color: Color, moving: Bool) {
    self.color = color
    self.moving = moving
  }

  public var body: some View {
    HatchLayer(color: color.opacity(Self.opacity), moving: moving)
      // The bands reach a period past the view's edge (for the drift); never shown outside it.
      .clipped()
      .allowsHitTesting(false)
      .accessibilityHidden(true)
  }
}

struct HatchLayer {
  let color: Color
  let moving: Bool
}

/// Holds the stripes layer and its drift.
final class HatchLayerView: PlatformView {
  /// Key of the drift on the stripes layer, and the key path it drives.
  static let driftKey = "drift"
  static let driftPath = "transform.translation.x"
  /// A band and its gap measured across the stripes, as a share of their width along a row:
  /// at 45° a row crosses each one √2 times wider.
  static let diagonal = 2.0.squareRoot()
  #if os(iOS)
  /// Width of a stripe, and of the gap after it, measured across them: the iPhone design's 4 px.
  static let stripe: CGFloat = 4
  #else
  /// Width of a stripe, and of the gap after it, measured across them: the Mac design's 6 px.
  static let stripe: CGFloat = 6
  #endif

  private let stripes = CAShapeLayer()
  private var moving = false

  /// Points per second the stripes drift right: the design's 34 px every 1.2 s.
  static let speed: CGFloat = 28.3

  /// One band and one gap along a row, in points: the distance the pattern repeats over.
  static var period: CGFloat { (stripe + stripe) * diagonal }

  /// Whether the stripes drift now (their drift is on the layer).
  var isDrifting: Bool { stripes.animation(forKey: Self.driftKey) != nil }

  override init(frame: CGRect) {
    super.init(frame: frame)
    #if canImport(UIKit)
    isUserInteractionEnabled = false
    layer.masksToBounds = true
    layer.addSublayer(stripes)
    #else
    // A layer-hosting view: set our own layer before asking for one, as AppKit documents for
    // views that add sublayers.
    let host = CALayer()
    host.isGeometryFlipped = true
    host.masksToBounds = true
    layer = host
    wantsLayer = true
    host.addSublayer(stripes)
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

  // Core Animation drops a layer's animation when its window goes away (or the app goes to the
  // background); start the drift again when the view is back on screen.
  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window != nil { drift() }
  }
  #else
  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  override func layout() {
    super.layout()
    place()
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if window != nil { drift() }
  }
  #endif

  /// Shows `hatch` with its colour resolved for `environment`, and starts or stops its drift.
  func show(_ hatch: HatchLayer, environment: EnvironmentValues) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    stripes.fillColor = hatch.color.resolve(in: environment).cgColor
    CATransaction.commit()
    moving = hatch.moving
    drift()
  }

  /// Draws the bands over the view and one period more to the left, so a drift of one period
  /// shows no edge.
  private func place() {
    let size = bounds.size
    let period = Self.period
    let band = period / 2
    let path = CGMutablePath()
    // A band runs down to the right: it leans one height over its run.
    var x = -period - size.height
    while x < size.width {
      path.addLines(between: [
        CGPoint(x: x, y: 0), CGPoint(x: x + band, y: 0),
        CGPoint(x: x + band + size.height, y: size.height), CGPoint(x: x + size.height, y: size.height),
      ])
      path.closeSubpath()
      x += period
    }
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    stripes.frame = bounds
    stripes.path = path
    CATransaction.commit()
  }

  /// Starts the drift while `moving` (unless it runs already), removes it otherwise.
  private func drift() {
    guard moving else {
      stripes.removeAnimation(forKey: Self.driftKey)
      return
    }
    guard !isDrifting else { return }
    let drift = CABasicAnimation(keyPath: Self.driftPath)
    drift.fromValue = 0
    drift.toValue = Self.period
    drift.duration = Self.period / Self.speed
    drift.timingFunction = CAMediaTimingFunction(name: .linear)
    // decorative: owner-requested session stripes (2026-11-16); gated like the radar, they show no data.
    drift.repeatCount = .infinity
    drift.isRemovedOnCompletion = false
    stripes.add(drift, forKey: Self.driftKey)
  }
}

#if canImport(UIKit)
extension HatchLayer: UIViewRepresentable {
  func makeUIView(context: Context) -> HatchLayerView { HatchLayerView(frame: .zero) }
  func updateUIView(_ view: HatchLayerView, context: Context) { view.show(self, environment: context.environment) }
}
#elseif canImport(AppKit)
extension HatchLayer: NSViewRepresentable {
  func makeNSView(context: Context) -> HatchLayerView { HatchLayerView(frame: .zero) }
  func updateNSView(_ view: HatchLayerView, context: Context) { view.show(self, environment: context.environment) }
}
#endif
