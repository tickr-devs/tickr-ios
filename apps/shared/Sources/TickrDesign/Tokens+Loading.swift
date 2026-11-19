import SwiftUI

// Tokens of the three loading pieces (mockup v102, v121, docs/design-system.md "Loading"): the
// breathing skeleton while content loads (`Skeleton`, `SkeletonBlock`), the spinner in a command's button
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

    // MARK: Breath

    /// Seconds of one breath of a skeleton: full, `breathLow` and full again (the board's 2.4 s,
    /// eased like a cosine; `Skeleton.breath(at:)`).
    public static let breathSeconds = 2.4
    /// A skeleton's opacity at the bottom of a breath: the board's block mix going from 60% to
    /// 25%, so the blocks keep 25/60 of their contrast.
    public static let breathLow = 0.42
    /// Shortest time between two frames of the breath, in seconds (30 a second: an opacity this
    /// slow needs no more).
    public static let breathFrameSeconds = 1.0 / 30
    /// Under Reduce Motion the spinner pulses from full to this opacity and back once every
    /// `pulseSeconds` (ease-in-out) in place of turning.
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
