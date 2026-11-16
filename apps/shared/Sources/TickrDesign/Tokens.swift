import SwiftUI

/// The operator apps' design system: one fixed scale for each kind of value, used by every screen
/// of the macOS and iOS apps. Views never write a size, duration or opacity of their own; they
/// pick a step from here, so the same thing looks and moves the same everywhere.
///
/// Colours are the semantic roles in `Palette`. Numbers anywhere else in the apps' Swift code fail
/// CI (`scripts/check_swift_literals.py`), unless they are a named, documented constant.
public enum Tokens {
  /// Spacing scale, in points: paddings, gaps between items, insets. A 4-point grid.
  public enum Space {
    /// Hairline gap: between a value and its unit, inside a badge.
    public static let xxs: CGFloat = 2
    /// Between an icon and its label, between lines of a compact row.
    public static let xs: CGFloat = 4
    /// Between items in a row, between rows of a list.
    public static let s: CGFloat = 8
    /// Between groups inside a card, around a banner's content.
    public static let m: CGFloat = 12
    /// Between cards, and a card's inner padding.
    public static let l: CGFloat = 16
    /// Around a screen's content, between sections.
    public static let xl: CGFloat = 24
    /// Between large blocks on wide screens.
    public static let xxl: CGFloat = 32
  }

  /// Corner radius scale, in points.
  public enum Radius {
    /// Badges, tags, small chips.
    public static let small: CGFloat = 6
    /// Chips and tabs (ranges, intervals, studies, position tabs).
    public static let chip: CGFloat = 8
    /// Banners, inset panels, menus.
    public static let medium: CGFloat = 10
    /// Small cards (sidebar, menu-bar panel).
    public static let large: CGFloat = 14
    /// Standard cards.
    public static let card: CGFloat = 18
  }

  /// Type scale. System font throughout; numbers and protocol values are monospaced so digits
  /// line up. Sizes in points.
  public enum Typography {
    /// Card section labels (uppercase), table headers.
    public static let labelSize: CGFloat = 11
    /// Letter spacing of uppercase section labels, in points.
    public static let labelTracking: CGFloat = 0.8
    /// Badges and tags.
    public static let badgeSize: CGFloat = 10.5
    /// Letter spacing of badge text, in points.
    public static let badgeTracking: CGFloat = 0.6
    /// Small mono annotations: chart axes, ticker, pipeline values.
    public static let annotationSize: CGFloat = 10.5
    /// Large figures inside cards (a result, a symbol).
    public static let metricSize: CGFloat = 24
    /// The single most important figure on a screen.
    public static let heroSize: CGFloat = 34
    /// The headline figure set apart from cards (Overview's day result on the Mac).
    public static let displaySize: CGFloat = 44
    /// Window and screen titles drawn in content.
    public static let titleSize: CGFloat = 28
    /// The mono word next to a screen title ("Operator"): as large as the title, lighter.
    public static let subtitleSize: CGFloat = 28
    /// The day result in the macOS menu-bar panel: a little smaller than `hero`, drawn tight.
    public static let panelFigureSize: CGFloat = 32
    /// Letter spacing of `panelFigure`, in points (negative: tighter).
    public static let panelFigureTracking: CGFloat = -1
    /// SF Symbols inside a compact round icon button.
    public static let symbolCompactSize: CGFloat = 13
    /// A screen's heading in its content ("Today · Mon, Nov 16" on Trades).
    public static let headingSize: CGFloat = 22
    /// A price beside a symbol heading (the Chart's last price).
    public static let quoteSize: CGFloat = 20
    /// Figures in compact tiles and stat rows (Trades' day figures, performance figures).
    public static let figureSize: CGFloat = 18
    /// Tab names under the tab glyphs in the iPhone tab bar.
    public static let tabLabelSize: CGFloat = 11

    #if os(iOS)
    // iOS: each role follows a text style, so Dynamic Type (Settings › Display & Brightness ›
    // Text Size, and the accessibility sizes) scales it. At the default size the styles are
    // the design's sizes or within a point or two of them (caption2 11, title2 22, title 28,
    // largeTitle 34). The size constants above stay the macOS sizes, which has no Dynamic Type.
    public static let label = Font.system(.caption2, design: .monospaced, weight: .semibold)
    public static let badge = Font.system(.caption2, design: .monospaced, weight: .bold)
    public static let annotation = Font.system(.caption2, design: .monospaced)
    public static let annotationBold = Font.system(.caption2, design: .monospaced, weight: .bold)
    public static let metric = Font.system(.title2, design: .monospaced, weight: .bold)
    public static let hero = Font.system(.largeTitle, design: .monospaced, weight: .bold)
    public static let display = Font.system(.largeTitle, design: .monospaced, weight: .bold)
    public static let title = Font.system(.title, weight: .bold)
    public static let subtitle = Font.system(.title, design: .monospaced, weight: .medium)
    public static let heading = Font.system(.title2, weight: .bold)
    public static let quote = Font.system(.title3, design: .monospaced, weight: .semibold)
    public static let figure = Font.system(.headline, design: .monospaced, weight: .bold)
    /// SF Symbols inside a round icon well.
    public static let symbol = Font.system(.subheadline, weight: .semibold)
    public static let panelFigure = Font.system(.largeTitle, design: .monospaced, weight: .bold)
    /// SF Symbols inside a compact round icon button.
    public static let symbolCompact = Font.system(.footnote, weight: .semibold)
    /// Tab names under the tab glyphs in the iPhone tab bar.
    public static let tabLabel = Font.system(.caption2, weight: .medium)
    #else
    public static let label = Font.system(size: labelSize, weight: .semibold, design: .monospaced)
    public static let badge = Font.system(size: badgeSize, weight: .bold, design: .monospaced)
    public static let annotation = Font.system(size: annotationSize, design: .monospaced)
    public static let annotationBold = Font.system(size: annotationSize, weight: .bold, design: .monospaced)
    public static let metric = Font.system(size: metricSize, weight: .bold, design: .monospaced)
    public static let hero = Font.system(size: heroSize, weight: .bold, design: .monospaced)
    public static let display = Font.system(size: displaySize, weight: .bold, design: .monospaced)
    public static let title = Font.system(size: titleSize, weight: .bold)
    public static let subtitle = Font.system(size: subtitleSize, weight: .medium, design: .monospaced)
    public static let heading = Font.system(size: headingSize, weight: .bold)
    public static let quote = Font.system(size: quoteSize, weight: .semibold, design: .monospaced)
    public static let figure = Font.system(size: figureSize, weight: .bold, design: .monospaced)
    /// SF Symbols inside a round icon well.
    public static let symbol = Font.system(size: Size.iconWellSymbol, weight: .semibold)
    /// The day result in the macOS menu-bar panel.
    public static let panelFigure = Font.system(size: panelFigureSize, weight: .bold, design: .monospaced)
    /// SF Symbols inside a compact round icon button.
    public static let symbolCompact = Font.system(size: symbolCompactSize, weight: .semibold)
    /// Tab names under the tab glyphs in the iPhone tab bar.
    public static let tabLabel = Font.system(size: tabLabelSize, weight: .medium)
    #endif
    /// Buttons drawn by the apps' own button style (bot controls).
    public static let button = Font.system(.body, weight: .semibold)
    /// Tabs and chips that name a symbol or a value (position tabs).
    public static let chip = Font.system(.callout, design: .monospaced, weight: .bold)
    /// Compact buttons inline in a row or a card header.
    public static let buttonCompact = Font.system(.callout, weight: .semibold)
    /// The figure of a metric chip, an icon metric and a large delta tag.
    public static let chipValue = Font.system(.headline, design: .monospaced, weight: .bold)
    /// Chevrons and direction triangles beside a figure or a button title.
    public static let chevron = Font.system(.caption2, weight: .bold)
    /// Body text and values in rows: the platform's text styles, so Dynamic Type applies.
    public static let body = Font.body
    public static let bodyMono = Font.body.monospaced()
    public static let callout = Font.callout
    public static let calloutMono = Font.callout.monospaced()
    public static let caption = Font.caption
    public static let captionMono = Font.caption.monospaced()
    /// A symbol heading a compact row (the menu-bar panel's positions).
    public static let headingMono = Font.title3.monospaced()
    /// A detail line under a figure or beside a symbol (trades and room, a size in shares); the Mac
    /// title bar's connection status (11 points on the Mac).
    public static let subheadlineMono = Font.subheadline.monospaced()
    /// The Mac title bar's day stepper: the shown day in 11.5-point mono.
    public static let dayStepperSize: CGFloat = 11.5
    public static let dayStepper = Font.system(size: dayStepperSize, design: .monospaced)
  }

  /// Line widths, in points.
  public enum Stroke {
    /// Grid lines, chart guides.
    public static let hairline: CGFloat = 0.5
    /// Card borders, separators, dashed levels.
    public static let thin: CGFloat = 1
    /// Indicator lines, outlines that must read at a glance.
    public static let regular: CGFloat = 1.5
    /// Price lines and sparklines; also the design's own outline glyphs on their 24-point grid.
    public static let bold: CGFloat = 2
    /// The design's power glyph, on its 24-point grid (`DesignGlyph.power`).
    public static let glyphHeavy: CGFloat = 2.2
    /// Rings (loss room, results).
    public static let ring: CGFloat = 12
    /// Track and fill of a small gauge ring (`MiniRing`).
    public static let gauge: CGFloat = 5
    /// Dash pattern of a level line (stop, entry), in points: dash, gap.
    public static let dash: [CGFloat] = [5, 4]
    /// Dash pattern of planned (BACKLOG) outlines and the crosshair.
    public static let dashFine: [CGFloat] = [3, 3]
  }

  /// Opacity steps for tints, washes and glows over a surface.
  public enum Opacity {
    /// Background wash of a banner or badge.
    public static let wash = 0.1
    /// Light-mode corner glows of the background.
    public static let glow = 0.14
    /// Volume bars, inactive bars, faint fills.
    public static let faint = 0.35
    /// Borders tinted with an accent, secondary marks.
    public static let border = 0.45
    /// An off chip among on ones (the Chart's studies).
    public static let muted = 0.55
    /// Visible but not dominant: inactive elements, pulse rings at start.
    public static let medium = 0.7
    /// Light-mode card shadow.
    public static let shadow = 0.12
    /// Overlays that must stay readable over content (crosshair readout).
    public static let overlay = 0.85
    /// A new row's tint at the start of its one flash (`arrivalFlash`).
    public static let flash = 0.22
  }

  /// How far a line of text may shrink to fit before it truncates, as a share of its size
  /// (`minimumScaleFactor`).
  public enum Shrink {
    /// Button titles and tile text: barely.
    public static let slight = 0.8
    /// Figures, values and day labels in cards, chips and charts.
    public static let standard = 0.7
    /// Results in tight cells: calendar day cells, the day ring, the day's figures (Trades).
    public static let tight = 0.6
    /// A large amount inside a ring.
    public static let most = 0.5
  }

  /// Fixed element sizes, in points.
  public enum Size {
    /// Status dots.
    public static let dot: CGFloat = 8
    /// Small dots in lists.
    public static let dotSmall: CGFloat = 6
    /// Round icon wells (pipeline stages).
    public static let iconWell: CGFloat = 44
    /// Stages of the live flow, larger than an icon well so the pipeline reads at a glance.
    public static let stage: CGFloat = 52
    /// The line glyph inside a live-flow stage (`DesignGlyph`), as on the Overview board.
    public static let stageGlyph: CGFloat = 22
    /// Width of the day result set beside Overview's header.
    public static let dayResultWidth: CGFloat = 300
    /// Narrowest a column of a card grid gets before the grid stacks into fewer columns.
    public static let gridColumnMin: CGFloat = 300
    /// SF Symbols inside an icon well.
    public static let iconWellSymbol: CGFloat = 15
    /// The brand mark (BrandMark) in a header, and small in a panel.
    public static let logo: CGFloat = 64
    public static let logoSmall: CGFloat = 26
    /// The brand mark as the illustration of an empty screen.
    public static let emptyMark: CGFloat = 88
    /// The brand mark in the centre of the macOS opening (BrandOpening).
    public static let openingMark: CGFloat = 120
    /// The brand mark on the iOS launch screen (LAUNCH_MARK in apps/scripts/make_brand_assets.py).
    public static let launchMark: CGFloat = 160
    /// Height of a sparkline and of a progress bar.
    public static let sparkline: CGFloat = 34
    /// A tab bar glyph (`DesignGlyph`), as on the iOS boards.
    public static let tabGlyph: CGFloat = 24
    /// Home's title-row action glyphs (power, settings), as on the iOS Home board.
    public static let headerGlyph: CGFloat = 16
    /// A glyph inside a chip-height button (the chart-type buttons), as on the iOS Chart board.
    public static let chipGlyph: CGFloat = 14
    public static let bar: CGFloat = 8
    /// Height of a thin progress bar inside a row (Watching closely).
    public static let barThin: CGFloat = 4
    /// Height of the ticker strip.
    public static let ticker: CGFloat = 22
    /// A symbol's dot on the live flow board.
    public static let flowMark: CGFloat = 7
    /// Least width of a symbol chip in the live flow (symbol over screener and change).
    public static let flowChip: CGFloat = 96
    /// Width of a side column of cards on wide screens.
    public static let sideColumn: CGFloat = 378
    /// Widest a screen's content grows before it centres.
    public static let contentMaxWidth: CGFloat = 1500
    /// Card shadow in light mode: blur radius and downward offset.
    public static let shadowRadius: CGFloat = 10
    public static let shadowOffset: CGFloat = 6
    /// Reach of the soft halo behind a ring.
    public static let ringHalo: CGFloat = 60
    /// How far a view rises while it fades in.
    public static let riseOffset: CGFloat = 12
    /// Smallest comfortable touch target (Apple HIG): large buttons are at least this tall.
    public static let touchTarget: CGFloat = 44
    /// Round icon buttons, regular and compact.
    public static let iconButton: CGFloat = 36
    public static let iconButtonCompact: CGFloat = 28
    /// State glyph tiles (`StateGlyph`), regular and compact.
    public static let glyph: CGFloat = 30
    public static let glyphCompact: CGFloat = 22
    /// Column of the leading symbol in a `ValueRow`, so labels line up.
    public static let rowSymbol: CGFloat = 16
    /// Small gauge ring (`MiniRing`).
    public static let miniRing: CGFloat = 52
    /// Widest a hint bubble gets before its text wraps.
    public static let hintMaxWidth: CGFloat = 260
    /// Blur of the accent glow under a primary button.
    public static let glowRadius: CGFloat = 8
  }

  /// Motion: every animation uses one of these curves or durations.
  public enum Motion {
    /// Small state changes: a value rolling, a toggle, a selection.
    public static let quick = Animation.snappy
    /// Views entering or leaving, list changes, section switches.
    public static let standard = Animation.spring(response: 0.5, dampingFraction: 0.85)
    /// Screens assembling on appear (each card rises).
    public static let entrance = Animation.spring(response: 0.7, dampingFraction: 0.85)
    /// Figures filling up: rings, bars, counters.
    public static let fill = Animation.spring(response: 1.2, dampingFraction: 0.9)
    /// Lines drawing themselves on appear.
    public static let draw = Animation.easeOut(duration: drawSeconds)
    /// Delay between cards of a screen as it assembles, in seconds.
    public static let stagger = 0.05
    /// Seconds for a line or a chart to draw itself.
    public static let drawSeconds = 1.4
    /// Seconds of one "live" pulse ring.
    public static let pulseSeconds = 2.4
    /// How far a pulse ring grows, as a multiple of the dot.
    public static let pulseScale: CGFloat = 2.2
    /// How much a button shrinks while pressed.
    public static let pressScale: CGFloat = 0.97
    /// Seconds the pointer rests on a view before its hint appears.
    public static let hintDelay = 0.45
    /// How far a live state glyph's pulse outline grows.
    public static let glyphPulseScale: CGFloat = 1.35
    /// Seconds of one breath of a glow (rings, alarms).
    public static let breatheSeconds = 2.4
    /// How much a breathing glow grows.
    public static let breatheScale: CGFloat = 1.08
    /// iOS opening: seconds the launch screen's mark holds while its spark flashes once, then the
    /// mark flies into the Home title as the launch background fades.
    public static let launchHoldSeconds = 0.45
    public static let launchFlySeconds = 0.75
    /// A timing curve, not a spring: it ends exactly at its seconds, where the fade that follows
    /// starts (a spring still trails points behind its target then, and fades beside it).
    public static let launchFly = Animation.easeInOut(duration: launchFlySeconds)
    /// Seconds the window shows the plain background before the mark starts drawing.
    public static let openingDelaySeconds = 0.1
    /// Seconds the opening waits for its window to come to the front; then it plays anyway, so a
    /// window opened in the background is never left covered.
    public static let openingWaitSeconds = 1.0
    /// macOS opening (BrandOpening): seconds for the centred mark to draw itself, then its flight
    /// into the Overview header.
    public static let openingDrawSeconds = 0.45
    public static let openingFlySeconds = 0.45
    /// A timing curve for the same reason as `launchFly`.
    public static let openingFly = Animation.easeInOut(duration: openingFlySeconds)
    /// The cross-fade that replaces the opening animation under Reduce Motion.
    public static let launchFadeSeconds = 0.35
    /// Seconds for one turn of the radar sweep.
    public static let rotationSeconds = 3.0
    /// The radar's blips: how far each one's ring grows (a multiple of the dot), and how long the
    /// second blip trails the first, in seconds.
    public static let blipScale: CGFloat = 1.9
    public static let blipLagSeconds = 0.8
    /// macOS opening: when the mark's spark pops in, in seconds from the start (after the line
    /// has nearly drawn), and how long it takes.
    public static let openingSparkDelaySeconds = 0.45
    public static let openingSparkSeconds = 0.25
    /// The opening's spark pop: a timing curve that ends at its seconds, like the line's draw.
    public static let openingSpark = Animation.easeOut(duration: openingSparkSeconds)
    /// Delay between the tiles of a grid (the Trades calendar) as it fills in, in seconds.
    public static let cellStagger = 0.025
    /// How far a button rises under the pointer, and a calendar tile, in points.
    public static let hoverLift: CGFloat = 1
    public static let cellLift: CGFloat = 2
    /// Seconds a new row's tint takes to fade out (`arrivalFlash`).
    public static let flashSeconds = 1.6
    /// The fade of a new row's tint.
    public static let flash = Animation.easeOut(duration: flashSeconds)
    /// Seconds of the cross-fade when the app's appearance (light, dark) is switched.
    public static let themeFadeSeconds = 0.4
    /// Points per second of the event ticker.
    public static let tickerSpeed = 22.0
    /// Seconds between redraws of a clock or an age ("3 s ago"), and of the session bar's cursor.
    public static let clockTickSeconds: TimeInterval = 1
    /// Seconds the iOS Home ticker takes to scroll its whole row once (the board's 45 s marquee).
    public static let tickerLoopSeconds = 45.0
    /// A dot or step popping in (`popIn`): a quick spring that overshoots a little, as the boards'
    /// `pop` (0.5 s, overshooting curve).
    public static let pop = Animation.spring(response: 0.5, dampingFraction: 0.55)
    /// Seconds between the protection chain's steps popping in, top to bottom.
    public static let popStagger = 0.4
  }

  /// The loss-room ring (Risk on both apps), as shares of the daily loss limit.
  public enum Room {
    /// Room left below this share turns the ring amber.
    public static let calm = 0.5
    /// Room left below this share turns the ring red.
    public static let alarm = 0.2
  }

  /// Candle charts on both apps.
  public enum Chart {
    /// Space above and below the visible prices, as a share of their range.
    public static let pricePadding = 0.08
    /// Height of the volume bars along the bottom of the price pane, as a share of the price
    /// range.
    public static let volumeShare = 0.22
    /// Each zoom step shows this many times fewer (or more) candles.
    public static let zoomStep = 1.5
  }
}
