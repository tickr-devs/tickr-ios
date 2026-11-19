import SwiftUI

// Tokens of the three loading pieces (mockup v102, docs/design-system.md "Loading"): the skeleton
// shimmer while content loads (`Skeleton`, `SkeletonBlock`), the spinner in a command's button
// while it is in flight (`Spinner`), and the progress line of an operation of known length
// (`ProgressLine`). The same on the Mac and the phone, except the spinner's size.

public extension Tokens {
  /// Loading states (`Skeleton`, `Spinner`, `ProgressLine`).
  enum Loading {
    // MARK: Skeleton blocks

    /// A skeleton block's fill: `separatorStrong` mixed into `surfaceSunken` by this share (the
    /// board's `color-mix(line2 60%, deep)`).
    public static let blockMix = 0.6
    /// Opacity of a skeleton's grid lines (`separator`, the board's `line` at 45%).
    public static let gridOpacity = 0.45
    /// Corner radius of a plain skeleton block, in points.
    public static let blockRadius: CGFloat = 5
    /// A text line's block: height and corner radius, in points.
    public static let lineHeight: CGFloat = 9
    public static let lineRadius: CGFloat = 4
    /// A value's block (a price, a figure): height, in points (radius `blockRadius`).
    public static let valueHeight: CGFloat = 16
    /// A pill's block (a badge, a chip): height and corner radius, in points.
    public static let pillHeight: CGFloat = 20
    public static let pillRadius: CGFloat = 6

    #if os(iOS)
    /// A skeleton list row's height when the caller names none (`SkeletonRows`), in points: a
    /// touch target, as the phone's rows.
    public static let rowHeight: CGFloat = 44
    #else
    /// A skeleton list row's height when the caller names none (`SkeletonRows`), in points: the
    /// Mac's list rows.
    public static let rowHeight: CGFloat = 28
    #endif

    /// How many lines, rows or tiles a skeleton stands in with while the real count is not
    /// known yet: a short note, a card's paragraph, a long one; a short list, a list, a long one;
    /// a row of stat tiles.
    public static let fewLines = 2
    public static let lines = 3
    public static let manyLines = 5
    public static let fewRows = 3
    public static let rows = 4
    public static let manyRows = 5
    public static let tiles = 3

    // MARK: Shimmer

    /// Seconds of one sweep of the shimmer across a skeleton (the board's 1.6 s, ease-in-out).
    public static let shimmerSeconds = 1.6
    /// The shimmer band: its gradient's angle in degrees (CSS: 0 points up, 90 to the right) and
    /// the band image's width as a multiple of the skeleton's. It sweeps from wholly off the
    /// skeleton on the left to wholly off it on the right (`ShimmerBandView.travel`).
    public static let shimmerAngle = 110.0
    public static let shimmerWidth = 2.5
    /// The band's gradient stops, as shares of its width: clear, `textPrimary` at
    /// `shimmerOpacity`, clear.
    public static let shimmerStops = [0.35, 0.5, 0.65]
    public static let shimmerOpacity = 0.05
    /// Under Reduce Motion nothing sweeps: the blocks pulse from full to this opacity and back
    /// once every `pulseSeconds` (ease-in-out). The spinner pulses alike in place of turning.
    public static let pulseLow = 0.6
    public static let pulseSeconds = 2.4

    // MARK: Spinner

    #if os(iOS)
    /// The spinner in a command's button: side and stroke, in points (iOS 20 / 2.5).
    public static let spinner: CGFloat = 20
    public static let spinnerStroke: CGFloat = 2.5
    #else
    /// The spinner in a command's button: side and stroke, in points (Mac 16 / 2).
    public static let spinner: CGFloat = 16
    public static let spinnerStroke: CGFloat = 2
    #endif
    /// Opacity of the spinner's track (`textTertiary`, the board's `mut` at 22%); the arc is
    /// `textTertiary` itself.
    public static let spinnerTrackOpacity = 0.22
    /// Share of the ring the arc covers (the board's `border-top`: a quarter).
    public static let spinnerArc = 0.25
    /// Seconds of one turn of the spinner, at an even pace.
    public static let spinnerTurnSeconds = 0.9

    // MARK: Progress line

    /// The progress line: height and corner radius, in points.
    public static let progressHeight: CGFloat = 2
    public static let progressRadius: CGFloat = 2
    /// Opacity of the progress line's track (`info`, the board's `blue` at 18%).
    public static let progressTrackOpacity = 0.18
    /// Seconds the progress line's fill takes to grow to a new width (CSS `ease`).
    public static let progressSeconds = 0.3
    /// CSS `ease` as a Bézier curve: the progress line's fill grows along it.
    public static let progressCurve = Animation.timingCurve(0.25, 0.1, 0.25, 1, duration: progressSeconds)
  }
}
