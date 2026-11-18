import QuartzCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// An open position's live price line (mockup v116 "Live sparkline"): the last closes and the live
/// price, right-aligned, ending in a dot. It draws itself in once, as it appears; after that a new
/// price never redraws it. A new price glides only the last point and the dot; a closed bar fixes
/// the live point and the line slides left one point. While `live`, each new price sends a ring
/// out of the dot; two rings alternate, so a running ring always finishes and a still price rests.
/// A stale price turns the line, fill and dot dim and still. With Reduce Motion it jumps straight.
///
/// Core Animation plays all of it in the render server (as PulseLayer does): a SwiftUI animation
/// keyed to every price re-lays out the whole screen on every frame of it. One component for the
/// position cards of both apps.
public struct LiveSparkline: View {
  /// Small: the iPhone's position cards (thinner line, no fill, fewer points). Large: bigger
  /// charts (Mac Overview), with a fill under the line.
  public enum Scale: Sendable {
    case small, large

    var gaps: Int { self == .small ? Tokens.Sparkline.gapsSmall : Tokens.Sparkline.gapsLarge }
    var line: CGFloat { self == .small ? Tokens.Sparkline.lineSmall : Tokens.Sparkline.lineLarge }
    var filled: Bool { self == .large }
  }

  let values: [Double]
  let live: Bool
  let scale: Scale
  let domain: ClosedRange<Double>?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// `values` is the whole line since the fill, oldest first, ending at the latest price; only its
  /// last points show (`window`). `domain` is the price range shown; nil spans those points.
  public init(values: [Double], live: Bool, scale: Scale, domain: ClosedRange<Double>? = nil) {
    self.values = values
    self.live = live
    self.scale = scale
    self.domain = domain
  }

  public var body: some View {
    let shown = Self.window(values, scale)
    LiveSparkLayer(shown: shown, total: values.count, domain: domain ?? Self.span(shown), live: live,
      scale: scale, still: reduceMotion)
      .accessibilityHidden(true)
  }

  /// The points shown: the last `gaps + 1` values (two equal ones for a single value).
  public static func window(_ values: [Double], _ scale: Scale) -> [Double] {
    let points = values.count > 1 ? values : [values.first ?? 0, values.first ?? 0]
    return Array(points.suffix(scale.gaps + 1))
  }

  /// The points' own range; a flat line gets a range around its value so it sits mid-height.
  static func span(_ values: [Double]) -> ClosedRange<Double> {
    let lowest = values.min() ?? 0
    let highest = values.max() ?? 0
    guard highest > lowest else { return (lowest - 1)...(highest + 1) }
    return lowest...highest
  }
}

/// What the layer view draws.
struct LiveSparkLayer: Equatable {
  /// The points shown, oldest first.
  let shown: [Double]
  /// How many values the whole line has: tells a new price (same count) from a closed bar (one
  /// more), so the line slides only for a bar.
  let total: Int
  let domain: ClosedRange<Double>
  let live: Bool
  let scale: LiveSparkline.Scale
  /// Reduce Motion: no draw-in, glide or ring.
  let still: Bool
}

/// Holds the line, its fill, the dot and its two rings, and moves them.
final class LiveSparkView: PlatformView {
  /// Keys of the animations on the layers.
  static let drawKey = "draw"
  static let glideKey = "glide"
  static let ringKey = "ring"
  static let toneKey = "tone"
  /// Key paths the animations drive.
  static let pathPath = "path"
  static let strokeEndPath = "strokeEnd"
  static let opacityPath = "opacity"
  static let positionPath = "position"
  static let scalePath = "transform.scale"
  static let strokeColorPath = "strokeColor"
  static let fillColorPath = "fillColor"

  /// Holds the layers below, with y growing down on both platforms.
  private let canvas = CALayer()
  private let fill = CAShapeLayer()
  private let line = CAShapeLayer()
  private let dotGroup = CALayer()
  private let dot = CAShapeLayer()
  private let rings = [CAShapeLayer(), CAShapeLayer()]
  private var config: LiveSparkLayer?
  /// What is on screen now, at which size; nil until the line has drawn in.
  private var drawn: (config: LiveSparkLayer, size: CGSize)?
  private var color: CGColor?

  override init(frame: CGRect) {
    super.init(frame: frame)
    line.fillColor = nil
    line.lineCap = .round
    line.lineJoin = .round
    fill.strokeColor = nil
    dot.strokeColor = nil
    for ring in rings {
      ring.fillColor = nil
      ring.lineWidth = Tokens.Sparkline.ringStroke
      ring.opacity = 0
      dotGroup.addSublayer(ring)
    }
    dotGroup.addSublayer(dot)
    canvas.addSublayer(fill)
    canvas.addSublayer(line)
    canvas.addSublayer(dotGroup)
    #if canImport(UIKit)
    isUserInteractionEnabled = false
    layer.addSublayer(canvas)
    #else
    // A layer-hosting view: set our own layer before asking for one, as AppKit documents for
    // views that add sublayers. AppKit owns the root layer's geometry, so the canvas under it is
    // the one flipped: y grows down as on iOS.
    let host = CALayer()
    layer = host
    wantsLayer = true
    canvas.isGeometryFlipped = true
    host.addSublayer(canvas)
    #endif
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  // A decoration: clicks and touches go through to what is under it.
  #if canImport(UIKit)
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }

  override func layoutSubviews() {
    super.layoutSubviews()
    render(animated: false)
  }
  #else
  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  override func layout() {
    super.layout()
    render(animated: false)
  }
  #endif

  /// Shows `config` with its colours resolved for `environment`.
  func show(_ config: LiveSparkLayer, environment: EnvironmentValues) {
    let tone = config.live ? Palette.accent : Palette.textQuaternary
    let resolved = tone.resolve(in: environment).cgColor
    let toneChanged = color.map { $0 != resolved } ?? false
    color = resolved
    self.config = config
    paint(animated: toneChanged && !config.still)
    render(animated: true)
  }

  /// Sets the colours; a change between live and stale fades over `toneSeconds`.
  private func paint(animated: Bool) {
    guard let color, let config else { return }
    let fillColor = color.copy(alpha: color.alpha * CGFloat(Tokens.Sparkline.fillOpacity))
    // Each layer, the colour it fades, and the colour it fades from.
    let changes: [(CALayer, String, CGColor?)] = [
      (line, Self.strokeColorPath, line.strokeColor),
      (fill, Self.fillColorPath, fill.fillColor),
      (dot, Self.fillColorPath, dot.fillColor),
    ]
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    line.strokeColor = color
    fill.fillColor = fillColor
    dot.fillColor = color
    for ring in rings { ring.strokeColor = color }
    line.opacity = config.live ? 1 : Tokens.Sparkline.staleOpacity
    line.lineWidth = config.scale.line
    fill.isHidden = !config.scale.filled
    CATransaction.commit()
    guard animated else { return }
    for (layer, path, from) in changes {
      let fade = CABasicAnimation(keyPath: path)
      fade.fromValue = from
      fade.duration = Tokens.Sparkline.toneSeconds
      layer.add(fade, forKey: Self.toneKey)
    }
  }

  /// Draws the line for the current config and size: drawn in the first time, then glided from
  /// what was on screen.
  private func render(animated: Bool) {
    guard let config, bounds.width > 0, bounds.height > 0 else { return }
    let size = bounds.size
    let points = Self.points(config.shown, domain: config.domain, gaps: config.scale.gaps, size: size)
    let previous = drawn
    if let previous, previous.config == config, previous.size == size { return }
    drawn = (config, size)
    guard let last = points.last else { return }

    let from: [CGPoint]? = previous.flatMap { old in
      guard animated, !config.still, old.size == size else { return nil }
      return Self.from(old.config, to: config, size: size)
    }
    let newPrice = previous.map { $0.config.shown.last != config.shown.last } ?? false

    CATransaction.begin()
    CATransaction.setDisableActions(true)
    canvas.frame = bounds
    line.frame = canvas.bounds
    fill.frame = canvas.bounds
    line.path = Self.linePath(points)
    fill.path = Self.fillPath(points, bottom: size.height)
    let dotRect = CGRect(x: -Tokens.Sparkline.dot / 2, y: -Tokens.Sparkline.dot / 2, width: Tokens.Sparkline.dot,
      height: Tokens.Sparkline.dot)
    dotGroup.bounds = CGRect(origin: .zero, size: dotRect.size)
    dotGroup.position = last
    dot.frame = dotGroup.bounds
    dot.path = CGPath(ellipseIn: dotGroup.bounds, transform: nil)
    for ring in rings {
      ring.frame = dotGroup.bounds
      ring.path = dot.path
    }
    CATransaction.commit()

    if previous == nil {
      if !config.still { drawIn() }
    } else if let from {
      glide(from: from, to: points)
      if newPrice, config.live { ring() }
    }
  }

  /// The first appearance: the line draws in from the left, the fill fades in with it, and the
  /// dot appears where the line ends once it is there. No ring.
  private func drawIn() {
    let curve = Self.timing(Tokens.Sparkline.drawCurve)
    let stroke = CABasicAnimation(keyPath: Self.strokeEndPath)
    stroke.fromValue = 0
    stroke.toValue = 1
    stroke.duration = Tokens.Sparkline.drawSeconds
    stroke.timingFunction = curve
    line.add(stroke, forKey: Self.drawKey)
    let fade = CABasicAnimation(keyPath: Self.opacityPath)
    fade.fromValue = 0
    fade.toValue = 1
    fade.duration = Tokens.Sparkline.drawSeconds
    fade.timingFunction = curve
    fill.add(fade, forKey: Self.drawKey)
    let appear = CABasicAnimation(keyPath: Self.opacityPath)
    appear.fromValue = 0
    appear.toValue = 0
    appear.duration = Tokens.Sparkline.drawSeconds
    dotGroup.add(appear, forKey: Self.drawKey)
  }

  /// A new price or a closed bar: every vertex moves from where it was to where it is now.
  private func glide(from: [CGPoint], to: [CGPoint]) {
    guard let start = from.last else { return }
    let curve = Self.timing(Tokens.Sparkline.glideCurve)
    let height = bounds.height
    let moves: [(CALayer, CGPath)] = [(line, Self.linePath(from)), (fill, Self.fillPath(from, bottom: height))]
    for (layer, path) in moves {
      let glide = CABasicAnimation(keyPath: Self.pathPath)
      // Mid-glide (prices faster than a glide), start from where the line is drawn now.
      glide.fromValue = layer.animation(forKey: Self.glideKey) == nil
        ? path : (layer.presentation() as? CAShapeLayer)?.path ?? path
      glide.duration = Tokens.Sparkline.glideSeconds
      glide.timingFunction = curve
      layer.add(glide, forKey: Self.glideKey)
    }
    let move = CABasicAnimation(keyPath: Self.positionPath)
    move.fromValue = dotGroup.animation(forKey: Self.glideKey) == nil
      ? Self.value(start) : dotGroup.presentation().map { Self.value($0.position) } ?? Self.value(start)
    move.duration = Tokens.Sparkline.glideSeconds
    move.timingFunction = curve
    dotGroup.add(move, forKey: Self.glideKey)
  }

  /// One ring out of the dot, on whichever ring is free; none when both still play.
  private func ring() {
    guard let ring = rings.first(where: { $0.animation(forKey: Self.ringKey) == nil }) else { return }
    let grow = CABasicAnimation(keyPath: Self.scalePath)
    grow.fromValue = 1
    grow.toValue = Tokens.Sparkline.ringScale
    let fade = CABasicAnimation(keyPath: Self.opacityPath)
    fade.fromValue = Tokens.Sparkline.ringOpacity
    fade.toValue = 0
    let pulse = CAAnimationGroup()
    pulse.animations = [grow, fade]
    pulse.duration = Tokens.Sparkline.ringSeconds
    pulse.timingFunction = Self.timing(Tokens.Sparkline.ringCurve)
    ring.add(pulse, forKey: Self.ringKey)
  }

  /// The vertices of `shown` in a view of `size`: right-aligned, one `gaps`-th of the width apart,
  /// always `gaps + 1` of them (a short line repeats its first point), so any two lines morph.
  static func points(_ shown: [Double], domain: ClosedRange<Double>, gaps: Int, size: CGSize) -> [CGPoint] {
    let step = size.width / CGFloat(gaps)
    let range = domain.upperBound - domain.lowerBound
    let placed = shown.enumerated().map { index, value in
      let share = range > 0 ? (value - domain.lowerBound) / range : 1 / 2
      return CGPoint(x: size.width - CGFloat(shown.count - 1 - index) * step,
        y: size.height - CGFloat(share) * size.height)
    }
    guard let first = placed.first else { return [] }
    return Array(repeating: first, count: max(gaps + 1 - placed.count, 0)) + placed
  }

  /// Where each vertex of `new` was in `old`: a point that was shown stays where it was drawn; a
  /// new point (a closed bar) starts at the old last point; a point that scrolled in from the
  /// left starts at the old first point.
  static func from(_ old: LiveSparkLayer, to new: LiveSparkLayer, size: CGSize) -> [CGPoint] {
    let oldPoints = points(old.shown, domain: old.domain, gaps: old.scale.gaps, size: size)
    let oldPlaced = Array(oldPoints.suffix(old.shown.count))
    let oldStart = old.total - old.shown.count
    let newStart = new.total - new.shown.count
    guard let oldFirst = oldPlaced.first, let oldLast = oldPlaced.last else { return [] }
    let placed = new.shown.indices.map { index in
      let at = newStart + index - oldStart
      return at < 0 ? oldFirst : at >= oldPlaced.count ? oldLast : oldPlaced[at]
    }
    guard let first = placed.first else { return [] }
    return Array(repeating: first, count: max(new.scale.gaps + 1 - placed.count, 0)) + placed
  }

  static func linePath(_ points: [CGPoint]) -> CGPath {
    let path = CGMutablePath()
    path.addLines(between: points)
    return path
  }

  /// The line closed down to `bottom`, with as many vertices for any line, so fills morph too.
  static func fillPath(_ points: [CGPoint], bottom: CGFloat) -> CGPath {
    guard let first = points.first, let last = points.last else { return CGMutablePath() }
    let path = CGMutablePath()
    path.addLines(between: points + [CGPoint(x: last.x, y: bottom), CGPoint(x: first.x, y: bottom)])
    path.closeSubpath()
    return path
  }

  static func timing(_ curve: [Float]) -> CAMediaTimingFunction {
    CAMediaTimingFunction(controlPoints: curve[0], curve[1], curve[2], curve[3])
  }

  #if canImport(UIKit)
  static func value(_ point: CGPoint) -> NSValue { NSValue(cgPoint: point) }
  #else
  static func value(_ point: CGPoint) -> NSValue { NSValue(point: point) }
  #endif
}

#if canImport(UIKit)
extension LiveSparkLayer: UIViewRepresentable {
  func makeUIView(context: Context) -> LiveSparkView { LiveSparkView(frame: .zero) }
  func updateUIView(_ view: LiveSparkView, context: Context) { view.show(self, environment: context.environment) }
}
#elseif canImport(AppKit)
extension LiveSparkLayer: NSViewRepresentable {
  func makeNSView(context: Context) -> LiveSparkView { LiveSparkView(frame: .zero) }
  func updateNSView(_ view: LiveSparkView, context: Context) { view.show(self, environment: context.environment) }
}
#endif
