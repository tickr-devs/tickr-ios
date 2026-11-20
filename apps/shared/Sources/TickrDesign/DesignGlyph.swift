import SwiftUI

/// Outline glyphs the design draws itself and SF Symbols has no match for: the iOS tab bar
/// (dashboard panels, thin lock, a bare polyline, three lines, star), the title-row actions
/// (Home's thin power and settings gear, Activity's calendar), the chart-type buttons and
/// the macOS Overview live flow's stages.
/// Each is the design's own SVG path on its 24-point grid, stroked with round caps and joins; the
/// path data separates numbers with "+" signs (valid SVG) rather than spaces.
public enum DesignGlyph: Sendable, CaseIterable {
  case home, positions, chart, activity, lab, power, settings, calendar, candles, line
  /// The live flow's stages, in the order a setup passes them.
  case screeners, universe, quote, bars, strategy, risk, order, brokerStop, reconcile

  /// The design's SVG path data, on the 24-point grid (the boards' `<path d>`).
  public var pathData: String {
    switch self {
    case .home: return Self.homePath
    case .positions: return Self.positionsPath
    case .chart: return Self.chartPath
    case .activity: return Self.activityPath
    case .lab: return Self.labPath
    case .power: return Self.powerPath
    case .settings: return Self.settingsPath
    case .calendar: return Self.calendarPath
    case .candles: return Self.candlesPath
    case .line: return Self.linePath
    case .screeners: return Self.screenersPath
    case .universe: return Self.universePath
    case .quote: return Self.quotePath
    case .bars: return Self.barsPath
    case .strategy: return Self.strategyPath
    case .risk: return Self.riskPath
    case .order: return Self.orderPath
    case .brokerStop: return Self.brokerStopPath
    case .reconcile: return Self.reconcilePath
    }
  }

  /// The design's stroke width on the 24-point grid.
  public var gridStroke: CGFloat {
    switch self {
    case .power, .candles, .line: return Tokens.Stroke.glyphHeavy
    case .settings: return Tokens.Stroke.gear
    default: return Tokens.Stroke.bold
    }
  }

  /// Tab bar: dashboard panels, a thin lock, a bare polyline, three lines (the last shorter), a star.
  static let homePath = "M4+13h6V4H4zM14+20h6V11h-6zM4+20h6v-3H4zM14+7h6V4h-6z"
  static let positionsPath = "M6+11h12v9H6zM8+11V8a4+4+0+0+1+8+0v3"
  static let chartPath = "M4+19l5-6l4+3l7-9"
  static let activityPath = "M4+6h16M4+12h16M4+18h10"
  static let labPath = "M12+3l2.2+5.3L20+9l-4.4+3.8L17+19l-5-3l-5+3l1.4-6.2L4+9l5.8-.7z"
  /// Home's bot control: a ring open at the top.
  static let powerPath = "M12+3v9M6.5+6.5a8+8+0+1+0+11+0"
  /// Settings: a gear of twelve rounded teeth around a hub ring (mockup v94, owner 2026-11-16),
  /// in pieces that keep each line readable.
  static let settingsPath = settingsPart1 + settingsPart2 + settingsPart3 + settingsPart4 + settingsPart5 +
    settingsPart6 + settingsPart7 + settingsPart8 + settingsPart9
  /// Settings gear path data, piece 1 of 9.
  static let settingsPart1 = "M9.78+4.73L10.23+2.87A9.3+9.3+0+0+1+13.77+2.87L14.22+4.73A7.6+7.6+0+0+1+15.57+5.29"
  /// Settings gear path data, piece 2 of 9.
  static let settingsPart2 = "L17.2+4.29A9.3+9.3+0+0+1+19.71+6.8L18.71+8.43A7.6+7.6+0+0+1+19.27+9.78L21.13+10.23"
  /// Settings gear path data, piece 3 of 9.
  static let settingsPart3 = "A9.3+9.3+0+0+1+21.13+13.77L19.27+14.22A7.6+7.6+0+0+1+18.71+15.57L19.71+17.2"
  /// Settings gear path data, piece 4 of 9.
  static let settingsPart4 = "A9.3+9.3+0+0+1+17.2+19.71L15.57+18.71A7.6+7.6+0+0+1+14.22+19.27L13.77+21.13"
  /// Settings gear path data, piece 5 of 9.
  static let settingsPart5 = "A9.3+9.3+0+0+1+10.23+21.13L9.78+19.27A7.6+7.6+0+0+1+8.43+18.71L6.8+19.71"
  /// Settings gear path data, piece 6 of 9.
  static let settingsPart6 = "A9.3+9.3+0+0+1+4.29+17.2L5.29+15.57A7.6+7.6+0+0+1+4.73+14.22L2.87+13.77"
  /// Settings gear path data, piece 7 of 9.
  static let settingsPart7 = "A9.3+9.3+0+0+1+2.87+10.23L4.73+9.78A7.6+7.6+0+0+1+5.29+8.43L4.29+6.8"
  /// Settings gear path data, piece 8 of 9.
  static let settingsPart8 = "A9.3+9.3+0+0+1+6.8+4.29L8.43+5.29"
  /// Settings gear path data, piece 9 of 9.
  static let settingsPart9 = "A7.6+7.6+0+0+1+9.78+4.73ZM15.2+12a3.2+3.2+0+1+1-6.4+0a3.2+3.2+0+1+1+6.4+0Z"
  /// Activity's day picker.
  static let calendarPath = "M4+6h16v14H4zM4+10h16M8+3v4M16+3v4"
  /// The chart-type buttons (the design's 16-point drawings, scaled onto the 24-point grid).
  static let candlesPath = "M7.5+3v18M16.5+4.5v15M5.25+7.5h4.5v7.5h-4.5zM14.25+9h4.5v6h-4.5z"
  static let linePath = "M3+18l6-6l4.5+3l7.5-9"
  /// The live flow's stages, as on the Overview board: screeners (lines under a magnifier),
  /// universe (lines narrowing), strategy (a path branching right), risk (a half gauge with ticks
  /// and its needle), order (a paper plane), broker stop (a shield with a check) and reconcile
  /// (two arrows going round).
  static let screenersPath = "M4+6h10M4+11h6M4+16h4M15.5+10.5a3.5+3.5+0+1+0+0+7a3.5+3.5+0+1+0+0-7zM18+17l3+3"
  static let universePath = "M4+7h16M7+12h10M10+17h4"
  /// Quote (mockup v89): a coin, then the dollar sign's S and its two strokes.
  static let quotePath = quoteCoinPath + quoteDollarPath
  /// The quote glyph's coin.
  static let quoteCoinPath = "M12+4a8+8+0+1+0+0+16a8+8+0+1+0+0-16z"
  /// The quote glyph's dollar sign: its S, then its two strokes.
  static let quoteDollarPath = quoteSPath + quoteStrokesPath
  /// The dollar sign's S: its upper curve, then its lower one.
  static let quoteSPath = quoteUpperPath + quoteLowerPath
  /// The S's upper curve, from its top right end to its middle.
  static let quoteUpperPath = "M14.5+9.2c-.5-.8-1.4-1.2-2.5-1.2-1.4+0-2.5.7-2.5+1.9+0+2.6+5+1.4+5+4.1"
  /// The S's lower curve, from its middle to its bottom left end.
  static let quoteLowerPath = "c0+1.2-1.1+2-2.5+2-1.2+0-2.1-.5-2.6-1.3"
  /// The dollar sign's strokes above and below the S.
  static let quoteStrokesPath = "M12+6.5V8M12+16v1.5"
  /// Bars (mockup v89): four bars on a baseline.
  static let barsPath = "M5+20V12M10+20V6M15+20V9M20+20V14M3+20h18"
  static let strategyPath = "M6+20V10a4+4+0+0+1+4-4h9M16+3l3+3-3+3M6+14a4+4+0+0+0+4+4h9M16+15l3+3-3+3"
  static let riskPath = "M3.5+17a8.5+8.5+0+0+1+17+0M12+17l4-5M6.5+11l1+.8M12+8.5V10M17.5+11l-1+.8"
  static let orderPath = "M21+3L3+10.5l7.5+3L13+21zM21+3L10.5+13.5"
  static let brokerStopPath = "M12+3l7+3v6c0+4.5-3+7.5-7+9c-4-1.5-7-4.5-7-9V6zM9+12l2+2+4-4"
  static let reconcilePath = "M4+12a8+8+0+0+1+14-5.3M20+3v4h-4M20+12a8+8+0+0+1-14+5.3M4+21v-4h4"
}

extension DesignGlyph {
  /// Every glyph's path on its grid, parsed once: parsed on each draw, the live flow's stage
  /// glyphs took 5% of the main thread while Overview scrolled (Time Profiler, 2026-11-19).
  static let parsed: [DesignGlyph: Path] = Dictionary(
    uniqueKeysWithValues: allCases.map { ($0, SVGPath.parse($0.pathData)) })

  /// The glyph's path on its 24-point grid.
  var path: Path { Self.parsed[self] ?? SVGPath.parse(pathData) }
}

/// A `DesignGlyph` as a shape filling its rectangle (the 24-point grid scaled to fit).
public struct DesignGlyphShape: Shape {
  /// Side of the grid the design's paths are drawn on.
  static let grid: CGFloat = 24

  public let glyph: DesignGlyph

  public init(_ glyph: DesignGlyph) {
    self.glyph = glyph
  }

  public func path(in rect: CGRect) -> Path {
    let scale = min(rect.width, rect.height) / Self.grid
    let side = Self.grid * scale
    return glyph.path
      .applying(CGAffineTransform(translationX: rect.midX - side / 2, y: rect.midY - side / 2)
        .scaledBy(x: scale, y: scale))
  }
}

/// A `DesignGlyph` at `side` points, stroked in the current foreground style at the design's
/// weight (its grid stroke scaled to the side).
public struct DesignGlyphView: View {
  let glyph: DesignGlyph
  let side: CGFloat
  let gridStroke: CGFloat

  /// `gridStroke` replaces the glyph's own weight on the 24-point grid, for a size the design
  /// draws heavier (the settings gear in the 13-point menu bar).
  public init(_ glyph: DesignGlyph, side: CGFloat, gridStroke: CGFloat? = nil) {
    self.glyph = glyph
    self.side = side
    self.gridStroke = gridStroke ?? glyph.gridStroke
  }

  public var body: some View {
    DesignGlyphShape(glyph)
      .stroke(style: StrokeStyle(lineWidth: gridStroke * side / DesignGlyphShape.grid,
        lineCap: .round, lineJoin: .round))
      .frame(width: side, height: side)
      .accessibilityHidden(true)
  }
}

/// The part of SVG path data the design's glyphs use: moves, lines (also horizontal and vertical),
/// cubic curves, elliptical arcs without rotation and close, absolute (upper case) or relative
/// (lower case).
enum SVGPath {
  /// Line segments that stand in for a quarter turn of an arc.
  static let segmentsPerQuarter: CGFloat = 6
  /// A whole turn, in radians.
  static let fullTurn = CGFloat.pi * 2

  /// The commands read, by their upper-case letter.
  enum Command: Character {
    case move = "M", line = "L", horizontal = "H", vertical = "V", cubic = "C", arc = "A", close = "Z"
  }

  static func parse(_ data: String) -> Path {
    var path = Path()
    var tokens = Tokenizer(data)
    var current = CGPoint.zero
    var start = CGPoint.zero
    var command = Command.move
    var relative = false
    while let next = tokens.command() ?? (tokens.hasNumber ? (command, relative) : nil) {
      (command, relative) = next
      let base = relative ? current : .zero
      switch command {
      case .close:
        path.closeSubpath()
        current = start
      case .cubic:
        guard let first = tokens.point(base), let second = tokens.point(base), let end = tokens.point(base)
        else { return path }
        path.addCurve(to: end, control1: first, control2: second)
        current = end
      case .arc:
        guard let arc = tokens.arc(base) else { return path }
        addArc(to: &path, from: current, arc)
        current = arc.end
      case .move, .line, .horizontal, .vertical:
        guard let point = tokens.target(command, base: base, current: current) else { return path }
        if command == .move {
          path.move(to: point)
          start = point
          // Further pairs after a move are lines.
          command = .line
        } else {
          path.addLine(to: point)
        }
        current = point
      }
    }
    return path
  }

  /// An arc command's end point, radii and flags (no rotation: the glyphs use none).
  struct Arc {
    let end: CGPoint
    let radius: CGSize
    let large: Bool
    let sweep: Bool
  }

  /// An arc without rotation, as line segments: the endpoint form of the SVG spec turned into its
  /// centre form (SVG 1.1, appendix F.6.5).
  private static func addArc(to path: inout Path, from: CGPoint, _ arc: Arc) {
    let to = arc.end
    let large = arc.large
    let sweep = arc.sweep
    var rx = abs(arc.radius.width)
    var ry = abs(arc.radius.height)
    guard rx > 0, ry > 0, from != to else {
      path.addLine(to: to)
      return
    }
    let mid = CGPoint(x: (from.x - to.x) / 2, y: (from.y - to.y) / 2)
    // Radii too small for the chord grow until they reach it.
    let lambda = (mid.x * mid.x) / (rx * rx) + (mid.y * mid.y) / (ry * ry)
    if lambda > 1 {
      rx *= lambda.squareRoot()
      ry *= lambda.squareRoot()
    }
    let numerator = max(0, rx * rx * ry * ry - rx * rx * mid.y * mid.y - ry * ry * mid.x * mid.x)
    let denominator = rx * rx * mid.y * mid.y + ry * ry * mid.x * mid.x
    let factor = (large == sweep ? -1 : 1) * (numerator / denominator).squareRoot()
    let offset = CGPoint(x: factor * rx * mid.y / ry, y: -factor * ry * mid.x / rx)
    let centre = CGPoint(x: offset.x + (from.x + to.x) / 2, y: offset.y + (from.y + to.y) / 2)
    let startAngle = atan2((mid.y - offset.y) / ry, (mid.x - offset.x) / rx)
    let endAngle = atan2((-mid.y - offset.y) / ry, (-mid.x - offset.x) / rx)
    var delta = endAngle - startAngle
    if sweep, delta < 0 { delta += fullTurn }
    if !sweep, delta > 0 { delta -= fullTurn }
    let quarters = abs(delta) / (CGFloat.pi / 2)
    let count = max(1, Int((quarters * segmentsPerQuarter).rounded(.up)))
    for index in 1...count {
      let angle = startAngle + delta * CGFloat(index) / CGFloat(count)
      path.addLine(to: CGPoint(x: centre.x + rx * cos(angle), y: centre.y + ry * sin(angle)))
    }
  }

  /// Reads commands and numbers off SVG path data.
  private struct Tokenizer {
    private let characters: [Character]
    private var index = 0

    init(_ data: String) {
      characters = Array(data)
    }

    private mutating func skipSeparators() {
      while index < characters.count, characters[index] == " " || characters[index] == "," { index += 1 }
    }

    /// The next command and whether it is relative (lower case), consumed; nil when numbers
    /// follow instead or the letter is not one this reader knows.
    mutating func command() -> (Command, Bool)? {
      skipSeparators()
      guard index < characters.count, let upper = characters[index].uppercased().first,
        let command = Command(rawValue: upper) else { return nil }
      defer { index += 1 }
      return (command, characters[index].isLowercase)
    }

    var hasNumber: Bool {
      var probe = self
      probe.skipSeparators()
      guard probe.index < probe.characters.count else { return false }
      let character = probe.characters[probe.index]
      return character.isNumber || character == "-" || character == "+" || character == "."
    }

    /// The next number: an optional sign, digits and at most one decimal point (".7", "-.7").
    mutating func number() -> CGFloat? {
      skipSeparators()
      let first = index
      if index < characters.count, characters[index] == "-" || characters[index] == "+" { index += 1 }
      var seenPoint = false
      while index < characters.count {
        let character = characters[index]
        if character.isNumber {
          index += 1
        } else if character == ".", !seenPoint {
          seenPoint = true
          index += 1
        } else {
          break
        }
      }
      return Double(String(characters[first..<index])).map { CGFloat($0) }
    }

    /// Where a move, line, horizontal or vertical command goes.
    mutating func target(_ command: Command, base: CGPoint, current: CGPoint) -> CGPoint? {
      switch command {
      case .horizontal: return number().map { CGPoint(x: $0 + base.x, y: current.y) }
      case .vertical: return number().map { CGPoint(x: current.x, y: $0 + base.y) }
      default: return point(base)
      }
    }

    /// An arc's numbers: radii, rotation (ignored), the large-arc and sweep flags, the end point.
    mutating func arc(_ base: CGPoint) -> Arc? {
      guard let rx = number(), let ry = number(), number() != nil, let large = number(), let sweep = number(),
        let end = point(base) else { return nil }
      return Arc(end: end, radius: CGSize(width: rx, height: ry), large: large != 0, sweep: sweep != 0)
    }

    mutating func point(_ base: CGPoint) -> CGPoint? {
      guard let x = number(), let y = number() else { return nil }
      return CGPoint(x: x + base.x, y: y + base.y)
    }
  }
}
