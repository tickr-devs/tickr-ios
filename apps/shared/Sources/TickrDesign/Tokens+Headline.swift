import SwiftUI

public extension Tokens {
  /// The status headline on both apps (`HeadlineBanner`, mockup v108): a pill that hugs its text,
  /// and beside it the session countdown with the gate badge. Sizes in points.
  enum Headline {
    /// Corners of the pill on one line: a capsule (the boards' 99 px).
    public static let pillRadius: CGFloat = 99
    /// Corners once the pill wraps or takes the whole row (an alarm): the boards' `.hl.wide`.
    public static let wrappedRadius: CGFloat = 12
    /// Corners of the stacked pill on iOS (title over detail), on one line or wrapped (`.hl.v`).
    public static let stackedRadius: CGFloat = 16
    /// The pill's tint and its border, as shares of the tone's fill (the boards' 12 % and 45 %).
    public static let tint = 0.12
    public static let border = Opacity.border
    /// An alarm's stronger tint (16 %); its border is the full tone at `Stroke.regular` (1.5).
    public static let alarmTint = 0.16
    /// Width of the pill's border outside an alarm.
    public static let borderWidth = Stroke.thin
    public static let alarmBorderWidth = Stroke.regular
    /// Inner padding of a one-line pill (the boards' 6 px 12 px 6 px 10 px).
    public static let pillVertical: CGFloat = 6
    public static let pillLeading: CGFloat = 10
    public static let pillTrailing: CGFloat = 12
    /// Inner padding of a wrapped or full-width pill (9 px 14 px 9 px 12 px).
    public static let wrappedVertical: CGFloat = 9
    public static let wrappedLeading: CGFloat = 12
    public static let wrappedTrailing: CGFloat = 14
    /// Inner padding of the stacked iOS pill (7 px 14 px 7 px 11 px; wrapped 10 px 14 px 10 px 12 px).
    public static let stackedVertical: CGFloat = 7
    public static let stackedLeading: CGFloat = 11
    public static let stackedWrappedVertical: CGFloat = 10
    /// Between the dot and the text.
    public static let dotGap = Space.s
    /// Where a wrapped pill's dot sits below its top edge, so it centres on the first line.
    public static let wrappedDotTop: CGFloat = 5
    /// Between the pill and the facts beside it, and between the countdown and the gate badge
    /// (the boards' 14 px row gap; 12 px inside the facts).
    public static let rowGap: CGFloat = 14
    public static let factsGap = Space.m
    /// Between the pill and the facts when they wrap to the next line.
    public static let lineGap = Space.s
    /// Between the clock glyph, the label and the time left (5 px).
    public static let countdownGap: CGFloat = 5
    /// Between the title and the detail of the stacked iOS pill.
    public static let stackedLineGap = Space.xxs

    #if os(iOS)
    /// The stacked pill's title (14 pt bold on IOSHome) and detail (12.5 pt): Dynamic Type styles.
    public static let title = Font.system(.subheadline, weight: .semibold)
    public static let detail = Font.footnote
    /// The countdown's label, time left and clock glyph (12 pt on the boards).
    public static let countdown = Font.footnote
    public static let countdownValue = Font.system(.footnote, design: .monospaced, weight: .semibold)
    #else
    /// The pill's title (13 pt, weight 650) and detail (13 pt): the Mac's body style.
    public static let title = Font.system(.body, weight: .semibold)
    public static let detail = Font.body
    /// The countdown's label, time left and clock glyph (12 pt): the Mac's callout style.
    public static let countdown = Font.callout
    public static let countdownValue = Font.system(.callout, design: .monospaced, weight: .semibold)
    #endif
  }
}
