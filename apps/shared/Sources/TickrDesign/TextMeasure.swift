import CoreText
#if canImport(AppKit)
import AppKit
#else
import SwiftUI
import UIKit
#endif

/// Text sizes measured with Core Text, for sizes that follow from what is drawn rather than from a
/// layout pass (the Mac's `TitleBarWidth`, `ChartView.leastHeight`, `StageRows.leastCellWidth`,
/// both apps' chart axis labels and band captions).
///
/// Never through `NSAttributedString.size()` or `NSString.size(withAttributes:)`: that string
/// drawing engine is not safe while another thread measures text at the same time. On macOS 27
/// it threw "attempt to insert nil object" in the Overview's `Pipeline` body (2026-11-19), and a
/// stress test on the Mac reproduced it in 17 s; Core Text on the same load ran clean.
public enum TextMeasure {
  /// The platform's font (`NSFont` on the Mac, `UIFont` on iPhone); both are Core Text fonts.
  #if canImport(AppKit)
  public typealias PlatformFont = NSFont
  #else
  public typealias PlatformFont = UIFont
  #endif

  /// The point size a type role is drawn at: on the Mac its fixed design size `mac`; on iOS the
  /// size of its text style `ios` now, as Dynamic Type sets it (`Tokens.Typography`'s iOS roles
  /// follow text styles). Text measured to size a layout must use this, or the layout is cut to
  /// the Mac's sizes while iOS draws bigger (the iPad's live flow broke "price-action-v3" at its
  /// hyphen, 2026-11-26).
  public static func pointSize(mac: CGFloat, ios: PlatformFont.TextStyle) -> CGFloat {
    #if canImport(AppKit)
    mac
    #else
    PlatformFont.preferredFont(forTextStyle: ios).pointSize
    #endif
  }

  #if !canImport(AppKit)
  /// The size of text style `style` at Dynamic Type size `size`: what a view drawn under
  /// `.dynamicTypeSize(size)` uses, which the system-wide setting alone does not tell.
  public static func pointSize(_ style: PlatformFont.TextStyle, at size: DynamicTypeSize) -> CGFloat {
    let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(size))
    return PlatformFont.preferredFont(forTextStyle: style, compatibleWith: traits).pointSize
  }
  #endif

  /// Width of `string` in `font`, rounded up to whole points; `kern` adds tracking per character.
  public static func width(_ string: String, font: PlatformFont, kern: CGFloat = 0) -> CGFloat {
    CGFloat(CTLineGetTypographicBounds(line(string, font: font, kern: kern), nil, nil, nil)).rounded(.up)
  }

  /// Height of one line of text in `font`, in whole points, as Core Text sets a line (the
  /// Chart's 24-point symbol 29, an 11-point chip label 14, measured on macOS 27). The string
  /// drawing engine gave 28 for the symbol: the Chart screen's least height is 1 point taller.
  public static func lineHeight(_ font: PlatformFont) -> CGFloat {
    let setter = CTFramesetterCreateWithAttributedString(text(lineSample, font: font, kern: 0))
    let unbounded = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    let whole = CFRange(location: 0, length: 0)
    return CTFramesetterSuggestFrameSizeWithConstraints(setter, whole, nil, unbounded, nil).height.rounded(.up)
  }

  /// A one-line sample with an ascender and a descender.
  static let lineSample = "hg"

  /// One Core Text line of `string`.
  private static func line(_ string: String, font: PlatformFont, kern: CGFloat) -> CTLine {
    CTLineCreateWithAttributedString(text(string, font: font, kern: kern))
  }

  /// `string` in `font` with `kern`; each call builds its own attributes and string.
  private static func text(_ string: String, font: PlatformFont, kern: CGFloat) -> CFAttributedString {
    var attributes: [NSAttributedString.Key: Any] = [Key.font: font as CTFont]
    if kern != 0 { attributes[Key.kern] = kern as NSNumber }
    return NSAttributedString(string: string, attributes: attributes) as CFAttributedString
  }

  /// The Core Text attribute names, as attributed-string keys.
  private enum Key {
    static let font = NSAttributedString.Key(kCTFontAttributeName as String)
    static let kern = NSAttributedString.Key(kCTKernAttributeName as String)
  }
}
