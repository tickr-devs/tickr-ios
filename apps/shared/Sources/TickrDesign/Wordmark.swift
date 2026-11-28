import SwiftUI
import TickrKit

/// The brand inside the apps (owner, 2026-11-28, mockup v189, page p-logo option B, and v191,
/// page p-machead): the mark's "t" without its tile, the letter in the text colour and the level
/// in teal, then "ickr" and ".bot" (owner, 2026-11-28 05:08Z: the wordmark reads "tickr.bot";
/// the Home Screen and Dock name stays "tickr"). It stands in the headers, on the sign-in and at the launch; the app icon
/// (the mark on its dark tile) stays on the Home Screen, the Dock and the App Store only, and
/// explanation screens show a symbol for their meaning instead of any logo.
///
/// `height` is the mark's height. `rest` is how much of "ickr.bot" shows, from 0 (the mark alone, as
/// the iOS launch screen draws it) to 1: the launch slides it out. `tone` mutes the level while
/// nothing about the bot can be known, as `BrandMark` does.
public struct Wordmark: View {
  /// The part of the mark's 24-unit grid the wordmark shows (the boards' `viewBox="3 3 18 20"`):
  /// the letter and level with a 1.5-unit margin, cut off on the right at the level's end + 1.5.
  static let crop = CGRect(x: 3, y: 3, width: 18, height: 20)

  @State private var restWidth: CGFloat = 0
  let height: CGFloat
  let tone: BrandMark.Tone
  let rest: CGFloat

  public init(height: CGFloat = Tokens.Size.wordmark, tone: BrandMark.Tone = .brand, rest: CGFloat = 1) {
    self.height = height
    self.tone = tone
    self.rest = rest
  }

  /// The mark's width at `height`.
  public static func markWidth(height: CGFloat) -> CGFloat {
    height * crop.width / crop.height
  }

  public var body: some View {
    HStack(spacing: -height * Tokens.Typography.wordmarkOverlapShare * rest) {
      WordmarkGlyph(height: height, tone: tone)
      HStack(spacing: .zero) {
        Text(BrandText.rest)
          .font(Tokens.Typography.wordmark(markHeight: height))
          .foregroundStyle(Palette.textPrimary)
        Text(BrandText.domain)
          .font(Tokens.Typography.wordmarkDomain(markHeight: height))
          .foregroundStyle(Palette.wordmarkDomain)
      }
        .tracking(height * Tokens.Typography.wordmarkTextShare * Tokens.Typography.wordmarkTrackingShare)
        .fixedSize()
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { restWidth = $0 }
        .frame(width: restWidth * rest, alignment: .leading)
        .clipped()
        .opacity(rest)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(BrandText.name))
  }
}

/// The wordmark's "t": `BrandLetter` and the level, cut to `Wordmark.crop`.
struct WordmarkGlyph: View {
  let height: CGFloat
  let tone: BrandMark.Tone

  var body: some View {
    let crop = Wordmark.crop
    let unit = height / crop.height
    let level = BrandMark.level
    ZStack(alignment: .topLeading) {
      BrandLetter()
        .fill(Palette.textPrimary)
        .frame(width: BrandMark.gridUnits * unit, height: BrandMark.gridUnits * unit)
        .offset(x: -crop.minX * unit, y: -crop.minY * unit)
      Rectangle()
        .fill(tone == .brand ? Palette.brandLine : Palette.brandMuted)
        .frame(width: level.width * unit, height: level.height * unit)
        .offset(x: (level.minX - crop.minX) * unit, y: (level.minY - crop.minY) * unit)
    }
    .frame(width: crop.width * unit, height: height, alignment: .topLeading)
    .accessibilityHidden(true)
  }
}

#Preview {
  VStack(spacing: Tokens.Space.xl) {
    Wordmark()
    Wordmark(height: Tokens.Size.wordmarkSmall, tone: .muted)
    Wordmark(height: Tokens.Size.wordmarkLaunch, rest: .zero)
  }
  .padding()
  .background(Palette.background)
}
