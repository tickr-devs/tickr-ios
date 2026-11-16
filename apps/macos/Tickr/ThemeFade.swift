import AppKit
import QuartzCore
import TickrDesign

/// Switches the app's appearance (Settings, "Appearance · theme") with a short cross-fade, as the
/// design's cards fade their colours: each visible window is covered with a picture of itself in
/// the old appearance, which fades out over the new one. With Reduce Motion it switches at once.
@MainActor
enum ThemeFade {
  /// Key of the fade on a cover's layer.
  static let fadeKey = "theme-fade"
  /// Key path the fade drives.
  static let opacityPath = "opacity"
  /// Bits per colour component of a cover's picture (8-bit sRGB, as the screen).
  static let pictureBits = 8

  static func apply(_ appearance: NSAppearance?) {
    guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
      NSApplication.shared.appearance = appearance
      return
    }
    let covers = NSApplication.shared.windows.filter(\.isVisible).compactMap(cover)
    NSApplication.shared.appearance = appearance
    for cover in covers {
      let fade = CABasicAnimation(keyPath: opacityPath)
      fade.fromValue = 1
      fade.toValue = 0
      fade.duration = Tokens.Motion.themeFadeSeconds
      fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
      cover.layer?.opacity = 0
      cover.layer?.add(fade, forKey: fadeKey)
    }
    Task {
      try? await Task.sleep(for: .seconds(Tokens.Motion.themeFadeSeconds))
      covers.forEach { $0.removeFromSuperview() }
    }
  }

  /// A still picture of the window's content laid over it, or nil when it cannot be drawn. The
  /// content's layer tree is rendered (SwiftUI draws into layers, which `cacheDisplay` skips).
  private static func cover(_ window: NSWindow) -> NSView? {
    guard let content = window.contentView, let layer = content.layer, !content.bounds.isEmpty else { return nil }
    let scale = window.backingScaleFactor
    let width = Int(content.bounds.width * scale)
    let height = Int(content.bounds.height * scale)
    guard let context = CGContext(
      data: nil, width: width, height: height, bitsPerComponent: pictureBits, bytesPerRow: 0,
      space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    // The window's own background under the content, in the old appearance, as on screen.
    window.effectiveAppearance.performAsCurrentDrawingAppearance {
      context.setFillColor(window.backgroundColor.cgColor)
    }
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    // The content's layers draw top-down; the picture's origin is at the bottom.
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: scale, y: -scale)
    layer.render(in: context)
    guard let picture = context.makeImage() else { return nil }
    // A layer-hosting view: its own layer holds the picture, which AppKit then leaves alone.
    let cover = NSView(frame: content.frame)
    let host = CALayer()
    host.contents = picture
    host.contentsGravity = .resize
    cover.layer = host
    cover.wantsLayer = true
    cover.autoresizingMask = [.width, .height]
    // Beside the content, above it: SwiftUI owns the content view's own subviews.
    guard let frame = content.superview else { return nil }
    frame.addSubview(cover, positioned: .above, relativeTo: content)
    return cover
  }
}
