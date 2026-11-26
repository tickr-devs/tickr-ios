import SwiftUI

// Tokens of the three loading pieces (mockup v102, loader E, docs/design-system.md "Loading"):
// the still skeleton with a running bar while content loads (`Skeleton`, `SkeletonBlock`), the
// spinner in a command's button while it is in flight (`Spinner`), and the progress line of an
// operation of known length (`ProgressLine`). The same on the Mac and the phone, except the spinner's size.

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

    // MARK: Running bar (loader E, "assembly", owner 2026-11-25)

    /// Seconds a run of the bar takes: its segment crosses the track once, eased in and out
    /// (`Skeleton.runningOffset(at:)`).
    public static let barSeconds = 2.0
    /// The bar's segment, as a share of its track's width (the board's 32%).
    public static let barShare = 0.32
    /// Opacity of the bar's track (`accent`, the board's 10%); the segment is `accent` itself.
    public static let barTrackOpacity = 0.1
    /// Share of the track at each end that fades out (the board's mask: transparent to opaque
    /// over 10%).
    public static let barFade = 0.1
    /// The run's ease, CSS `cubic-bezier(.45, 0, .55, 1)`, and its two control points.
    public static let barCurveFrom = UnitPoint(x: 0.45, y: 0)
    public static let barCurveTo = UnitPoint(x: 0.55, y: 1)
    public static let barCurve = UnitCurve.bezier(startControlPoint: barCurveFrom, endControlPoint: barCurveTo)

    // MARK: Chart build (loader E)

    /// Seconds of one build of the loading chart's candles: they rise in left to right, hold,
    /// then fade out together (`SkeletonCandles.build(_:of:at:)`; the board's 5.6 s).
    public static let buildSeconds = 5.6
    /// Share of the cycle at which the first candle starts to rise, and the share over which the
    /// starts spread from the first candle to the last.
    public static let buildStart = 0.06
    public static let buildSpread = 0.42
    /// Share of the cycle one candle takes to rise in.
    public static let buildRise = 0.08
    /// Shares of the cycle at which the candles start to fade, and by which they are gone.
    public static let buildHoldEnd = 0.78
    public static let buildFadeEnd = 0.93
    /// A candle's height as it starts to rise, as a share of its own (it grows from its middle).
    public static let buildLowScale = 0.35
    /// The share of the cycle shown, still, under Reduce Motion: every candle in place.
    public static let buildRestPhase = 0.7
    /// The rise's ease, CSS `cubic-bezier(.2, .7, .2, 1)`, and its two control points.
    public static let buildRiseFrom = UnitPoint(x: 0.2, y: 0.7)
    public static let buildRiseTo = UnitPoint(x: 0.2, y: 1)
    public static let buildRiseCurve = UnitCurve.bezier(startControlPoint: buildRiseFrom, endControlPoint: buildRiseTo)
    /// The fade's ease, CSS `cubic-bezier(.37, 0, .63, 1)`, and its two control points.
    public static let buildFadeFrom = UnitPoint(x: 0.37, y: 0)
    public static let buildFadeTo = UnitPoint(x: 0.63, y: 1)
    public static let buildFadeCurve = UnitCurve.bezier(startControlPoint: buildFadeFrom, endControlPoint: buildFadeTo)

    // MARK: Spinner

    /// Under Reduce Motion the spinner pulses from full to this opacity and back once every
    /// `pulseSeconds` (ease-in-out) in place of turning.
    public static let pulseLow = 0.6
    public static let pulseSeconds = 2.4

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
