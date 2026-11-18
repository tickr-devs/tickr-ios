import SwiftUI

// Tokens of the scroll edge hints that stand in for scroll indicators (owner, 2026-11-18, variant
// B of the mockups in /mnt/project-files/scroll-hints): the content fades out at an edge with more
// beyond it, and a small capsule with a down chevron sits on the bottom edge while more is below.

public extension Tokens {
  /// Scroll edge hints (`scrollEdgeHints()`).
  enum Scroll {
    #if os(iOS)
    /// Height of the fade at an edge with more content beyond it, in points.
    public static let fade: CGFloat = 72
    /// The chevron capsule's width and height, in points.
    public static let capsuleWidth: CGFloat = 44
    public static let capsuleHeight: CGFloat = 28
    /// The chevron's point size.
    public static let chevronSize: CGFloat = 13
    #else
    /// Height of the fade at an edge with more content beyond it, in points.
    public static let fade: CGFloat = 56
    /// The chevron capsule's width and height, in points.
    public static let capsuleWidth: CGFloat = 40
    public static let capsuleHeight: CGFloat = 24
    /// The chevron's point size.
    public static let chevronSize: CGFloat = 11
    #endif
    /// The chevron's font.
    public static let chevronFont = Font.system(size: chevronSize, weight: .semibold)
    /// How far content must reach past an edge, in points, before that edge hints at more: below
    /// this a rounding difference would leave a hint on a list that is already at its end.
    public static let edgeTolerance: CGFloat = 2
    /// Share of the visible height one tap on the chevron scrolls by: a page, keeping a little of
    /// the last one in view so the eye finds its place.
    public static let pageShare: CGFloat = 0.8
    /// How long a hint takes to fade in or out when an edge is reached or left, in seconds.
    public static let fadeSeconds = 0.2
  }
}
