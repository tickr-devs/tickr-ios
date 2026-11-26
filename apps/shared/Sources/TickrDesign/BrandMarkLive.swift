import QuartzCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// The live part of the brand mark: its level breathing slowly (from `Opacity.muted` to full and
/// back, every `BrandMark.breathSeconds`). Core Animation runs it in the render server. As a
/// SwiftUI `repeatForever` animation it moved every display frame inside the Overview's header, and
/// each frame laid out the whole Overview again, texts included: about a full CPU core at idle
/// (Instruments, 2026-11-15).
struct BrandMarkLive {
  /// Size of the level, in points.
  let size: CGSize
  let color: Color
  /// Whether the scene is in front. Core Animation drops a layer's loops when the app goes to the
  /// background; a change here updates the view, which starts them again.
  let active: Bool
}

/// Holds the level layer and its loop.
final class BrandMarkLiveView: PlatformView {
  /// Key of the loop on the level layer.
  static let breathKey = "breath"
  /// Key path the loop drives.
  static let opacityPath = "opacity"

  private let root = CALayer()
  private let level = CALayer()
  private var laidOutSize: CGSize?

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
    root.addSublayer(level)
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
    level.backgroundColor = mark.color.resolve(in: environment).cgColor
    if laidOutSize != mark.size { layOut(size: mark.size) }
    CATransaction.commit()
    if level.animation(forKey: Self.breathKey) == nil { startLoop() }
  }

  private func layOut(size: CGSize) {
    laidOutSize = size
    let bounds = CGRect(origin: .zero, size: size)
    root.frame = bounds
    level.frame = bounds
    startLoop()
  }

  /// The level dims and brightens, easing in and out, once every breath.
  private func startLoop() {
    let breath = CABasicAnimation(keyPath: Self.opacityPath)
    breath.fromValue = 1
    breath.toValue = Tokens.Opacity.muted
    // Half a breath out, the same back.
    breath.duration = BrandMark.breathSeconds / 2
    breath.autoreverses = true
    breath.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    // decorative: the brand mark's level is an ornament (owner, 2026-11-15).
    breath.repeatCount = .infinity
    breath.isRemovedOnCompletion = false
    level.add(breath, forKey: Self.breathKey)
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
