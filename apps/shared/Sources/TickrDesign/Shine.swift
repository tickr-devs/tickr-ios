import QuartzCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// A band of light that passes across a title, again and again, as the design's shine on the AI
/// advisor's title: the title keeps its own colour and the band, in `color`, is drawn only inside
/// its letters. Ornament: it runs only while `moving` (the caller's `OrnamentGate`) and never with
/// Reduce Motion; still, the title is plain.
public struct Shine: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase
  let moving: Bool
  let color: Color

  public func body(content: Content) -> some View {
    content.overlay {
      if moving && !reduceMotion {
        ShineBand(color: color, active: scenePhase == .active)
          .mask(content)
          .allowsHitTesting(false)
          .accessibilityHidden(true)
      }
    }
  }
}

/// The band itself, as wide as the title, sweeping from before its start to past its end in
/// `Motion.shineSeconds`. Core Animation runs it in the render server, like the brand mark's halo
/// and the ticker: a SwiftUI `repeatForever` drew every display frame on the main thread (about as
/// much as any SwiftUI frame loop, offscreen measurement 2026-11-16). It starts as `Shine` shows it
/// and ends with it, so the loop runs only while the gate holds.
struct ShineBand {
  let color: Color
  /// Whether the scene is in front; a change updates the view, which starts the sweep again.
  let active: Bool
}

/// Holds the band layer and its sweep.
final class ShineBandView: PlatformView {
  /// Key of the sweep on the band layer, and the key path it drives.
  static let sweepKey = "sweep"
  static let translationPath = "transform.translation.x"
  /// Where the band is brightest, as a share of its width.
  static let middle = 0.5

  private let band = CAGradientLayer()
  private var laidOutWidth: CGFloat?

  override init(frame: CGRect) {
    super.init(frame: frame)
    band.startPoint = CGPoint(x: 0, y: Self.middle)
    band.endPoint = CGPoint(x: 1, y: Self.middle)
    band.locations = [0, NSNumber(value: Self.middle), 1]
    #if canImport(UIKit)
    isUserInteractionEnabled = false
    layer.addSublayer(band)
    #else
    // A layer-hosting view: set our own layer before asking for one, as AppKit documents for
    // views that add sublayers.
    let host = CALayer()
    layer = host
    wantsLayer = true
    host.addSublayer(band)
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
  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window != nil { startSweep() }
  }
  #else
  override func hitTest(_ point: NSPoint) -> NSView? { nil }
  override func layout() {
    super.layout()
    place()
  }
  // Core Animation drops a layer's animation when its window goes away; start it again.
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if window != nil { startSweep() }
  }
  #endif

  /// Shows `shine` with its colour resolved for `environment`; starts the sweep if it is not running.
  func show(_ shine: ShineBand, environment: EnvironmentValues) {
    let light = shine.color.resolve(in: environment).cgColor
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    band.colors = [light.copy(alpha: 0) ?? light, light, light.copy(alpha: 0) ?? light]
    CATransaction.commit()
    if band.animation(forKey: Self.sweepKey) == nil { startSweep() }
  }

  /// Sizes the band to the title; a new width starts the sweep over that width.
  private func place() {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    band.frame = bounds
    CATransaction.commit()
    if laidOutWidth != bounds.width {
      laidOutWidth = bounds.width
      startSweep()
    }
  }

  /// The band passes from fully before the title to fully past it, at an even pace, again and again.
  private func startSweep() {
    let width = bounds.width
    guard width > 0 else { return }
    let sweep = CABasicAnimation(keyPath: Self.translationPath)
    sweep.fromValue = -width
    sweep.toValue = width
    sweep.duration = Tokens.Motion.shineSeconds
    sweep.timingFunction = CAMediaTimingFunction(name: .linear)
    // decorative: the advisor title's shine is ornament (owner wants the design's motion, 2026-11-16).
    sweep.repeatCount = .infinity
    sweep.isRemovedOnCompletion = false
    band.add(sweep, forKey: Self.sweepKey)
  }
}

#if canImport(UIKit)
extension ShineBand: UIViewRepresentable {
  func makeUIView(context: Context) -> ShineBandView { ShineBandView(frame: .zero) }
  func updateUIView(_ view: ShineBandView, context: Context) { view.show(self, environment: context.environment) }
}
#elseif canImport(AppKit)
extension ShineBand: NSViewRepresentable {
  func makeNSView(context: Context) -> ShineBandView { ShineBandView(frame: .zero) }
  func updateNSView(_ view: ShineBandView, context: Context) { view.show(self, environment: context.environment) }
}
#endif

public extension View {
  /// A band of light in `color` passing across the view while `moving` (see `Shine`).
  func shine(moving: Bool, color: Color) -> some View { modifier(Shine(moving: moving, color: color)) }
}

public extension EnvironmentValues {
  /// Section headers below it pass a light across their title (`Shine`): the Lab's AI advisor
  /// card sets it while its ornament may move (`OrnamentGate`); its content resets it.
  @Entry var titleShines = false
}
