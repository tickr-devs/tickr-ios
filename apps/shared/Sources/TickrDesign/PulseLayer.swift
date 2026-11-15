import QuartzCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// The ring of an event pulse: `shape`'s outline, grown to `scale` and faded out once each time
/// `event` changes. Core Animation plays it in the render server. Played by SwiftUI it laid out
/// the screen around it on every display frame of the pulse, and a pulse keyed to the bot's status
/// write (about once a second, each pulse `Tokens.Motion.pulseSeconds` long) never stopped: about
/// 25 points of a core on the Overview (Instruments, 2026-11-15).
struct PulseLayer<S: Shape> {
  let shape: S
  let color: Color
  let scale: CGFloat
  /// What the pulse marks; a change plays one pulse. The first value plays none.
  let event: AnyHashable
}

/// Holds the ring layer and plays its pulse.
final class PulseLayerView: PlatformView {
  /// Key of the pulse on the ring layer.
  static let pulseKey = "pulse"
  /// Key paths the pulse drives.
  static let scalePath = "transform.scale"
  static let opacityPath = "opacity"

  private let ring = CAShapeLayer()
  private var outline: ((CGRect) -> CGPath)?
  private var scale: CGFloat = 1
  private var event: AnyHashable?

  override init(frame: CGRect) {
    super.init(frame: frame)
    ring.fillColor = nil
    ring.lineWidth = Tokens.Stroke.bold
    ring.opacity = 0
    #if canImport(UIKit)
    isUserInteractionEnabled = false
    layer.addSublayer(ring)
    #else
    // A layer-hosting view: set our own layer before asking for one, as AppKit documents for
    // views that add sublayers.
    let host = CALayer()
    layer = host
    wantsLayer = true
    host.addSublayer(ring)
    #endif
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  // A decoration: clicks and touches go through to what is under it.
  #if canImport(UIKit)
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }

  override func layoutSubviews() {
    super.layoutSubviews()
    place()
  }
  #else
  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  override func layout() {
    super.layout()
    place()
  }
  #endif

  /// Shows `pulse` with its colour resolved for `environment`; plays one pulse when its event is
  /// new.
  func show<S: Shape>(_ pulse: PulseLayer<S>, environment: EnvironmentValues) {
    let shape = pulse.shape
    outline = { shape.path(in: $0).cgPath }
    scale = pulse.scale
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    ring.strokeColor = pulse.color.resolve(in: environment).cgColor
    CATransaction.commit()
    place()
    defer { event = pulse.event }
    guard let event, event != pulse.event else { return }
    play()
  }

  /// Sizes the ring to the view; shapes the pulses use are symmetric, so the layer's flipped or
  /// upright origin does not matter.
  private func place() {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    ring.frame = bounds
    ring.path = outline?(bounds)
    CATransaction.commit()
  }

  /// One pulse: shown at the outline at `Tokens.Opacity.medium`, then grown and faded out, easing
  /// out, over `Tokens.Motion.pulseSeconds`.
  private func play() {
    let grow = CABasicAnimation(keyPath: Self.scalePath)
    grow.fromValue = 1
    grow.toValue = scale
    let fade = CABasicAnimation(keyPath: Self.opacityPath)
    fade.fromValue = Tokens.Opacity.medium
    fade.toValue = 0
    let pulse = CAAnimationGroup()
    pulse.animations = [grow, fade]
    pulse.duration = Tokens.Motion.pulseSeconds
    pulse.timingFunction = CAMediaTimingFunction(name: .easeOut)
    ring.add(pulse, forKey: Self.pulseKey)
  }
}

#if canImport(UIKit)
extension PulseLayer: UIViewRepresentable {
  func makeUIView(context: Context) -> PulseLayerView { PulseLayerView(frame: .zero) }
  func updateUIView(_ view: PulseLayerView, context: Context) { view.show(self, environment: context.environment) }
}
#elseif canImport(AppKit)
extension PulseLayer: NSViewRepresentable {
  func makeNSView(context: Context) -> PulseLayerView { PulseLayerView(frame: .zero) }
  func updateNSView(_ view: PulseLayerView, context: Context) { view.show(self, environment: context.environment) }
}
#endif
