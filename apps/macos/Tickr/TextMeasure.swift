import AppKit

/// Text sizes measured with AppKit, for least window sizes that follow from what is drawn rather
/// than from a layout pass (`TitleBarWidth`, `ChartView.leastHeight`).
enum TextMeasure {
  /// Width of `string` in `font`, rounded up to whole points; `kern` adds tracking per character.
  static func width(_ string: String, font: NSFont, kern: CGFloat = 0) -> CGFloat {
    var attributes: [NSAttributedString.Key: Any] = [.font: font]
    if kern != 0 { attributes[.kern] = kern }
    return NSAttributedString(string: string, attributes: attributes).size().width.rounded(.up)
  }

  /// Height of one line of text in `font`, in whole points, as SwiftUI draws a `Text` (the
  /// Chart's 24-point symbol 28, an 11-point chip label 14: both read with Accessibility).
  static func lineHeight(_ font: NSFont) -> CGFloat {
    NSAttributedString(string: lineSample, attributes: [.font: font]).size().height.rounded(.up)
  }

  /// A one-line sample with an ascender and a descender.
  static let lineSample = "hg"
}
