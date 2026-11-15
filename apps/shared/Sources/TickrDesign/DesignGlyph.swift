import SwiftUI

/// Outline glyphs the design draws itself and SF Symbols has no match for: the iOS tab bar
/// (dashboard panels, thin lock, a bare polyline, three lines, star), the title-row actions
/// (Home's thin power and "sun" settings mark, Activity's calendar) and the chart-type buttons.
/// Each is the design's own SVG path on its 24-point grid, stroked with round caps and joins; the
/// path data separates numbers with "+" signs (valid SVG) rather than spaces.
public enum DesignGlyph: Sendable, CaseIterable {
  case home, positions, chart, activity, lab, power, settings, calendar, candles, line

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
    }
  }

  /// The design's stroke width on the 24-point grid.
  public var gridStroke: CGFloat {
    switch self {
    case .power, .candles, .line: return Tokens.Stroke.glyphHeavy
    default: return Tokens.Stroke.bold
    }
  }

  /// Tab bar: dashboard panels, a thin lock, a bare polyline, three lines (the last shorter), a star.
  static let homePath = "M4+13h6V4H4zM14+20h6V11h-6zM4+20h6v-3H4zM14+7h6V4h-6z"
  static let positionsPath = "M6+11h12v9H6zM8+11V8a4+4+0+0+1+8+0v3"
  static let chartPath = "M4+19l5-6l4+3l7-9"
  static let activityPath = "M4+6h16M4+12h16M4+18h10"
  static let labPath = "M12+3l2.2+5.3L20+9l-4.4+3.8L17+19l-5-3l-5+3l1.4-6.2L4+9l5.8-.7z"
  /// Home's bot control (a ring open at the top) and settings (a ring with four rays).
  static let powerPath = "M12+3v9M6.5+6.5a8+8+0+1+0+11+0"
  static let settingsPath = "M12+8a4+4+0+1+0+0+8a4+4+0+1+0+0-8zM12+2v3M12+19v3M2+12h3M19+12h3"
  /// Activity's day picker.
  static let calendarPath = "M4+6h16v14H4zM4+10h16M8+3v4M16+3v4"
  /// The chart-type buttons (the design's 16-point drawings, scaled onto the 24-point grid).
  static let candlesPath = "M7.5+3v18M16.5+4.5v15M5.25+7.5h4.5v7.5h-4.5zM14.25+9h4.5v6h-4.5z"
  static let linePath = "M3+18l6-6l4.5+3l7.5-9"
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
    return SVGPath.parse(glyph.pathData)
      .applying(CGAffineTransform(translationX: rect.midX - side / 2, y: rect.midY - side / 2)
        .scaledBy(x: scale, y: scale))
  }
}

/// A `DesignGlyph` at `side` points, stroked in the current foreground style at the design's
/// weight (its grid stroke scaled to the side).
public struct DesignGlyphView: View {
  let glyph: DesignGlyph
  let side: CGFloat

  public init(_ glyph: DesignGlyph, side: CGFloat) {
    self.glyph = glyph
    self.side = side
  }

  public var body: some View {
    DesignGlyphShape(glyph)
      .stroke(style: StrokeStyle(lineWidth: glyph.gridStroke * side / DesignGlyphShape.grid,
        lineCap: .round, lineJoin: .round))
      .frame(width: side, height: side)
      .accessibilityHidden(true)
  }
}

/// The part of SVG path data the design's glyphs use: moves, lines (also horizontal and vertical),
/// elliptical arcs without rotation and close, absolute (upper case) or relative (lower case).
enum SVGPath {
  /// Line segments that stand in for a quarter turn of an arc.
  static let segmentsPerQuarter: CGFloat = 6
  /// A whole turn, in radians.
  static let fullTurn = CGFloat.pi * 2

  /// The commands read, by their upper-case letter.
  enum Command: Character {
    case move = "M", line = "L", horizontal = "H", vertical = "V", arc = "A", close = "Z"
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
