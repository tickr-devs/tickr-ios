import SwiftUI

// Tokens of the one-line funnel and its bars (`FunnelRings`, `FunnelBarRow`), of the dots falling
// through the bars (`FunnelDrops`, IOSFunnel board, mockup v159) and of the iPhone's day switch
// (`DaySwitch`, `daySwipe`), as on the IOS2Home and IOS2Funnel boards (mockup v155).

extension Tokens.Size {
  /// A stage's ring on the one-line funnel (the board's `.fnd`), and the glyph inside it.
  public static let funnelRing: CGFloat = 26
  public static let funnelGlyph: CGFloat = 13
  /// Height of the one-line funnel's row of rings (the board's `.fnline`).
  public static let funnelLine: CGFloat = 28
  /// A light running along the funnel's rail (the board's `.travel`).
  public static let funnelTraveller: CGFloat = 8
  /// Height of a stage's bar in the funnel sheet (the board's `.fnbar`), and its least width.
  public static let funnelBar: CGFloat = 24
  public static let funnelBarMin: CGFloat = 12
  /// A ticker dot falling through the funnel sheet's bars (`FunnelDrops`, the IOSFunnel board's
  /// `.fndot`, mockup v159): its white's diameter, its dark rim's width outside the white, its
  /// glow's blur and how far the glow spreads past the rim, in points.
  public static let funnelDrop: CGFloat = 7
  public static let funnelDropRim: CGFloat = 1.5
  public static let funnelDropGlow: CGFloat = 10
  public static let funnelDropGlowSpread: CGFloat = 2
  /// How far in from each side of the funnel sheet's bars the dots' column starts (the board's
  /// `.fnflow`: the name column and its gap on the left, the value, chevron and gaps on the right),
  /// in points; the dots fall down its middle.
  public static let funnelFlowInset: CGFloat = 106
  /// How far sideways a dot that drops out at the middle stages slides, in points (`fnout`).
  public static let funnelDropShift: CGFloat = 34
  /// The day button's least height (the board's `.daycap`); its touch target is `touchTarget`.
  public static let dayButton: CGFloat = 36
  /// A row of the day picker (the board's `.dlist > button`).
  public static let dayRow: CGFloat = 48
}

extension Tokens.Opacity {
  /// The funnel's rail in the stages' colours, under the rings (the board's `.fnrail`).
  public static let funnelRail = 0.35
  /// The falling dots' dark rim and their white glow (`FunnelDrops`, the board's `.fndot`).
  public static let funnelDropRim = 0.28
  public static let funnelDropGlow = 0.55
}

extension Tokens.Motion {
  /// One run of a light along the funnel's rail, in seconds, and how many run one after another.
  public static let funnelTravelSeconds = 4.2
  public static let funnelTravellers = 3
  /// Share of a run over which a light fades in at the rail's start and out at its end.
  public static let funnelTravelFade = 0.08
  /// One fall of a ticker dot through the funnel sheet's bars, in seconds (`FunnelDrops`, the
  /// board's `fndrop`, linear), and the share of a fall over which it fades in at the top and out
  /// at the bottom.
  public static let funnelDropSeconds = 3.8
  public static let funnelDropFade = 0.06
  /// Each dot's start after the sheet opens, in seconds: four dots a quarter of a fall apart.
  public static let funnelDropDelays: [Double] = [0, 0.95, 1.9, 2.85]
  /// The dots (indices into `funnelDropDelays`) that drop out at the middle stages (`fnout`).
  public static let funnelDropOuts: Set<Int> = [1, 3]
  /// A dot that drops out: the shares of the cycle over which it slides aside and fades out, and
  /// how far down the bars it is when that starts and when it ends.
  public static let funnelDropOutStart = 0.40
  public static let funnelDropOutEnd = 0.60
  public static let funnelDropOutFall: CGFloat = 0.42
  public static let funnelDropOutRest: CGFloat = 0.48
  /// How far a finger moves sideways before the page changes the day (`daySwipe`), in points, and
  /// how many times its vertical move the sideways one must be (a scroll never changes the day).
  public static let daySwipeDistance: CGFloat = 70
  public static let daySwipeDominance: CGFloat = 2
  /// Share of the page's width a swipe (or its fling, `predictedEndTranslation`) must reach to
  /// change the day; a shorter one springs back.
  public static let daySwipeCommitShare: CGFloat = 0.25
  /// Points a page can be pulled toward a day that does not exist at most (rubber band).
  public static let daySwipeStretch: CGFloat = 60
  /// The page sliding out and the next day's sliding in after a swipe.
  public static let daySlide = Animation.smooth(duration: daySlideSeconds)
  /// Seconds of each half of `daySlide`.
  public static let daySlideSeconds = 0.22
}

extension Tokens {
  /// Proportions of the funnel sheet's bars (`FunnelBarRow`).
  public enum Funnel {
    /// The shortest bar as a share of the widest, so a stage with a few symbols still shows one.
    public static let leastShare: CGFloat = 0.04
  }
}
