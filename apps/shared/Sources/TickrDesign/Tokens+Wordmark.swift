import CoreText
import SwiftUI

// Tokens of the wordmark (`Wordmark`, mockup v189, page p-logo option B): the mark's "t" without its
// tile, then "ickr" in Manrope 700. In their own file because Tokens.swift is at SwiftLint's file
// length limit.

extension Tokens.Size {
  /// The wordmark's height (its "t"): in a header and on the sign-in (the boards' `.wm`, 34 px).
  public static let wordmark: CGFloat = 34
  /// In the Mac's title bar and other small places (the boards' `.wm.sm`, 26 px).
  public static let wordmarkSmall: CGFloat = 26
  /// At the centre of the launch, before it flies into the header (the p-logo launch, 52 px); the
  /// iOS launch screen's image is drawn at this height (WORDMARK_LAUNCH in make_brand_assets.py).
  public static let wordmarkLaunch: CGFloat = 52
}

extension Tokens.Typography {
  /// "ickr" against a "t" of height 1 (the boards: 30 px type beside a 34 px mark).
  public static let wordmarkTextShare: CGFloat = 30.0 / 34.0
  /// "ickr" tucks under the mark's hook by this share of the mark's height (the boards' -4 px of 34).
  public static let wordmarkOverlapShare: CGFloat = 4.0 / 34.0
  /// The letters' tracking as a share of the type size (the boards' -0.03 em).
  public static let wordmarkTrackingShare: CGFloat = -0.03

  /// "ickr" beside a mark of height `markHeight`, in the wordmark's own font.
  public static func wordmark(markHeight: CGFloat) -> Font {
    WordmarkFont.register()
    return .custom(WordmarkFont.postScriptName, fixedSize: markHeight * wordmarkTextShare)
  }
}

/// The wordmark's font: Manrope 700 cut to the four letters of "ickr" (Resources/
/// TickrWordmark-Bold.ttf, SIL Open Font License in Resources/Manrope-OFL.txt), registered for this
/// process at its first use.
enum WordmarkFont {
  /// The font's file in this package's resources, and the name it registers under.
  static let fileName = "TickrWordmark-Bold"
  static let fileExtension = "ttf"
  static let postScriptName = "TickrWordmark-Bold"

  /// Registered once, at the first wordmark drawn.
  private static let registered: Bool = {
    guard let url = Bundle.module.url(forResource: fileName, withExtension: fileExtension) else { return false }
    return CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
  }()

  static func register() {
    _ = registered
  }
}

extension Tokens.Motion {
  /// "ickr" sliding out of the mark at the launch, before the wordmark flies into the header
  /// (p-logo, the board's `lr`: from a quarter to nearly half of the launch).
  public static let wordmarkRevealSeconds = 0.45
  public static let wordmarkReveal = Animation.easeOut(duration: wordmarkRevealSeconds)
}
