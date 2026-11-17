import SwiftUI

// The continuous all-session chart (mockup v113, Day and 5D on both apps): the extended-hours
// bands, the session boundaries and the time axis's labels.

extension Tokens.Chart {
  /// Fill of the band behind the pre-market and after-hours slots: `textPrimary` at this share,
  /// in the price area and the volume pane, per theme (mockup v114: `--tx` 5% in light, 9% in
  /// dark, where 5% of a light text on a dark plot hardly showed).
  public static let extendedBandOpacityLight = 0.05
  public static let extendedBandOpacityDark = 0.09

  /// `extendedBandOpacityLight` or `extendedBandOpacityDark` for the theme on screen.
  public static func extendedBandOpacity(_ scheme: ColorScheme) -> Double {
    scheme == .dark ? extendedBandOpacityDark : extendedBandOpacityLight
  }
  /// A session boundary: 1 point, dashed 3 and 3 (`Tokens.Stroke.dashFine`), `textQuaternary`
  /// (the board's `--dim`) at this share.
  public static let sessionBoundaryOpacity = 0.7
  /// Volume bars of extended-hours candles, as a share of a regular bar's opacity.
  public static let extendedVolumeShare = 0.6
  /// Letter spacing of a band's "PRE" / "AFTER" caption, as a share of its size (.06em).
  public static let bandCaptionTracking = 0.06

  #if os(iOS)
  /// A band caption's size and its inset from the band's left and top edge, in points.
  public static let bandCaptionSize: CGFloat = 8.5
  public static let bandCaptionInset: CGFloat = 4
  /// The time axis's label size, in points.
  public static let sessionAxisLabelSize: CGFloat = 9
  /// Least room between two round-hour labels, and between any two labels, in points.
  public static let hourLabelSpacing: CGFloat = 56
  public static let axisLabelGap: CGFloat = 6
  /// How far every time label stays in from the chart's edges, in points.
  public static let axisLabelInset: CGFloat = 8
  #else
  /// A band caption's size on the Mac, in points.
  public static let bandCaptionSize: CGFloat = 9
  /// Its inset from the band's left and top edge, in points.
  public static let bandCaptionInset: CGFloat = 6
  /// The time axis's label size on the Mac, in points.
  public static let sessionAxisLabelSize: CGFloat = 10
  /// Least room between two round-hour labels on the Mac, in points.
  public static let hourLabelSpacing: CGFloat = 64
  /// Least room between any two labels on the Mac, in points.
  public static let axisLabelGap: CGFloat = 8
  /// The Mac's labels may reach the chart's edges.
  public static let axisLabelInset: CGFloat = 0
  #endif

  /// The band caption: mono, semibold.
  public static var bandCaption: Font { .system(size: bandCaptionSize, weight: .semibold, design: .monospaced) }
  /// A session or round-hour label on the time axis: mono.
  public static var sessionAxisLabel: Font { .system(size: sessionAxisLabelSize, design: .monospaced) }
}
