import QuartzCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// The lights running along the one-line funnel's rail (`FunnelRings`): `Motion.funnelTravellers`
/// glowing dots a run apart, each crossing the rail in `Motion.funnelTravelSeconds` and fading in
/// at its start and out at its end (`FunnelRings.fade`). An ornament: no data, no touch.
///
/// Core Animation plays them in the render server. Drawn from a `TimelineView(.animation)` they
/// re-evaluated SwiftUI on every display frame while Home sat still: the frame loop took 86% of
/// the idle main thread (Instruments Time Profiler, iPhone simulator, 2026-11-28).
struct FunnelRailLights {
  let color: Color
  let moving: Bool
}

/// Holds the lights' layers and their runs.
final class FunnelRailLightsView: PlatformView {
  /// Key of a light's run on its layer, and the key paths the run drives.
  static let runKey = "run"
  static let alongPath = "position.x"
  static let opacityPath = "opacity"

  private let lights: [CALayer] = (0..<Tokens.Motion.funnelTravellers).map { _ in CALayer() }
  private var moving = false
  /// The size the running runs were made for: a new width restarts them.
  private var runSize = CGSize.zero

  /// Whether the lights run now (their runs are on the layers).
  var isRunning: Bool { lights.first?.animation(forKey: Self.runKey) != nil }

  override init(frame: CGRect) {
    super.init(frame: frame)
    #if canImport(UIKit)
    isUserInteractionEnabled = false
    for light in lights { layer.addSublayer(light) }
    #else
    // A layer-hosting view: set our own layer before asking for one, as AppKit documents for
    // views that add sublayers.
    let host = CALayer()
    layer = host
    wantsLayer = true
    for light in lights { host.addSublayer(light) }
    #endif
    for light in lights { light.opacity = 0 }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  // An ornament: touches go through to the funnel's button under it.
  #if canImport(UIKit)
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }

  override func layoutSubviews() {
    super.layoutSubviews()
    place()
  }

  // Core Animation drops a layer's animation when its window goes away (or the app goes to the
  // background); start the runs again when the view is back on screen.
  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window != nil { run() }
  }
  #else
  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  override func layout() {
    super.layout()
    place()
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if window != nil { run() }
  }
  #endif

  /// Shows `rail` with its colour resolved for `environment`, and starts or stops the runs.
  func show(_ rail: FunnelRailLights, environment: EnvironmentValues) {
    let color = rail.color.resolve(in: environment).cgColor
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    for light in lights {
      light.backgroundColor = color
      light.shadowColor = color
    }
    CATransaction.commit()
    moving = rail.moving
    run()
  }

  /// Puts each light at the rail's start with its glow; a new size restarts the runs.
  private func place() {
    let side = Tokens.Size.funnelTraveller
    let dot = CGRect(x: 0, y: 0, width: side, height: side)
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    for light in lights {
      light.bounds = dot
      light.position = CGPoint(x: bounds.minX, y: bounds.midY)
      light.cornerRadius = side / 2
      light.shadowOffset = .zero
      light.shadowRadius = side / 2
      light.shadowOpacity = 1
      light.shadowPath = CGPath(ellipseIn: dot, transform: nil)
    }
    CATransaction.commit()
    guard bounds.size != runSize else { return }
    stop()
    run()
  }

  private func stop() {
    for light in lights { light.removeAnimation(forKey: Self.runKey) }
  }

  /// Starts the runs while `moving` and laid out (unless they run already), removes them otherwise.
  private func run() {
    guard moving, !bounds.isEmpty else {
      stop()
      return
    }
    guard !isRunning else { return }
    runSize = bounds.size
    let seconds = Tokens.Motion.funnelTravelSeconds
    let fade = Tokens.Motion.funnelTravelFade
    for (index, light) in lights.enumerated() {
      let along = CABasicAnimation(keyPath: Self.alongPath)
      along.fromValue = bounds.minX
      along.toValue = bounds.maxX
      let opacity = CAKeyframeAnimation(keyPath: Self.opacityPath)
      opacity.values = [0, 1, 1, 0]
      opacity.keyTimes = [0, fade, 1 - fade, 1].map { NSNumber(value: $0) }
      opacity.calculationMode = .linear
      let group = CAAnimationGroup()
      group.animations = [along, opacity]
      group.duration = seconds
      group.timingFunction = CAMediaTimingFunction(name: .linear)
      group.beginTime = light.convertTime(CACurrentMediaTime(), from: nil)
      // Each light a run's share ahead of the one before, so they are spread along the rail.
      group.timeOffset = seconds * Double(index) / Double(lights.count)
      // decorative: the lights along the rail say the bot is at work; they carry no data.
      group.repeatCount = .infinity
      group.isRemovedOnCompletion = false
      light.add(group, forKey: Self.runKey)
    }
  }
}

#if canImport(UIKit)
extension FunnelRailLights: UIViewRepresentable {
  func makeUIView(context: Context) -> FunnelRailLightsView { FunnelRailLightsView(frame: .zero) }
  func updateUIView(_ view: FunnelRailLightsView, context: Context) { view.show(self, environment: context.environment) }
}
#elseif canImport(AppKit)
extension FunnelRailLights: NSViewRepresentable {
  func makeNSView(context: Context) -> FunnelRailLightsView { FunnelRailLightsView(frame: .zero) }
  func updateNSView(_ view: FunnelRailLightsView, context: Context) { view.show(self, environment: context.environment) }
}
#endif
