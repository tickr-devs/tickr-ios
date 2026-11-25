import SwiftUI

/// The Tickr mark, "the letter-level" (owner's choice, 2026-11-25): a lowercase t whose crossbar has
/// broken off and become a price level (teal), while the stem and hook are the price path that
/// meets the level and turns up. It sits on a dark tile, as on the app icon, the iOS launch screen
/// and the tickr.bot site (apps/scripts/make_brand_assets.py draws the same shapes).
///
/// On appear the letter fades in and the level slides into place. While `live` (the bot's data is
/// current) the level then breathes slowly; otherwise, and with Reduce Motion, it stands still.
/// It stands for the app only (launch, headers, icons, menu bar), never for missing data or
/// loading (owner, 2026-11-25): empty screens use `EmptyState`, loading the shared loaders.
public struct BrandMark: View {
  /// How the mark is coloured.
  public enum Tone: Sendable {
    /// Brand colours: light letter, teal level.
    case brand
    /// The level in a quiet grey: nothing can be known right now (bot unreachable).
    case muted
  }

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase
  @State private var drawn: CGFloat = 0
  @State private var popped: CGFloat = 0
  @State private var settled = false
  let size: CGFloat
  let live: Bool
  let tone: Tone
  /// How the letter appears; nil shows it at once.
  let drawing: Animation?
  /// How the level slides in; nil moves it with the letter.
  let sparkPop: Animation?

  /// The letter's 24-unit grid inside the tile: its inset from the tile's edge and its side, as
  /// shares of the tile (the icon draws the grid at 768 of 1024). GRID_INSET and GRID_SIDE in
  /// make_brand_assets.py.
  static let gridInset = 0.125
  static let gridSide = 0.75
  /// The level on the 24-unit grid: x from 12 to 19.5, y from 9 to 12 (LEVEL in the script).
  public static let level = CGRect(x: 12, y: 9, width: 7.5, height: 3)
  /// Units of the grid.
  static let gridUnits = 24.0
  /// The tile's corner radius and hairline edge, as shares of its side.
  static let tileRadius = 0.3
  static let tileEdge = 0.025
  /// How far the level starts to the right of its place as it slides in, in grid units.
  static let levelSlide = 3.0
  /// How much smaller the letter starts as it fades in.
  static let letterStartScale = 0.92
  /// Seconds of one breath of the level (out and back) while live.
  static let breathSeconds = 3.2
  /// Seconds before the letter starts appearing, so a window is on screen before it moves.
  static let drawDelay = 0.35

  /// `drawsIn` false shows the mark already drawn: where an opening animation has just put it.
  public init(size: CGFloat = Tokens.Size.logo, live: Bool, tone: Tone = .brand, drawsIn: Bool = true) {
    self.init(size: size, live: live, tone: tone, drawing: drawsIn ? Tokens.Motion.draw.delay(Self.drawDelay) : nil)
  }

  init(size: CGFloat, live: Bool, tone: Tone, drawing: Animation?, sparkPop: Animation? = nil) {
    self.size = size
    self.live = live
    self.tone = tone
    self.drawing = drawing
    self.sparkPop = sparkPop
    // Without a draw the mark starts drawn, so it shows where nothing appears or animates (the
    // Live Activity, which never runs `onAppear`).
    _drawn = State(initialValue: drawing == nil ? 1 : 0)
    _popped = State(initialValue: drawing == nil ? 1 : 0)
    _settled = State(initialValue: drawing == nil)
  }

  /// The level's frame in a tile of side `size`.
  public static func levelFrame(inTile size: CGFloat) -> CGRect {
    let unit = size * gridSide / gridUnits
    let inset = size * gridInset
    return CGRect(x: inset + level.minX * unit, y: inset + level.minY * unit,
      width: level.width * unit, height: level.height * unit)
  }

  private var levelColor: Color { tone == .brand ? Palette.brandLine : Palette.brandMuted }
  private var breathes: Bool { tone == .brand && live && settled && !reduceMotion }

  public var body: some View {
    let grid = size * Self.gridSide
    let unit = grid / Self.gridUnits
    let level = Self.levelFrame(inTile: size)
    let slide = (1 - (sparkPop == nil ? drawn : popped)) * Self.levelSlide * unit
    ZStack(alignment: .topLeading) {
      RoundedRectangle(cornerRadius: size * Self.tileRadius, style: .continuous)
        .fill(LinearGradient(colors: [Palette.brandTileTop, Palette.brandTileBottom],
          startPoint: .top, endPoint: .bottom))
        .strokeBorder(Palette.brandTileEdge, lineWidth: size * Self.tileEdge)
      BrandLetter()
        .fill(Palette.brandLetter)
        .frame(width: grid, height: grid)
        .scaleEffect(Self.letterStartScale + (1 - Self.letterStartScale) * drawn)
        .opacity(drawn)
        .offset(x: size * Self.gridInset, y: size * Self.gridInset)
      if breathes {
        // While live the level breathes (Core Animation runs it; see BrandMarkLive).
        BrandMarkLive(size: level.size, color: levelColor, active: scenePhase == .active)
          .frame(width: level.width, height: level.height)
          .offset(x: level.minX, y: level.minY)
          .allowsHitTesting(false)
      } else {
        Rectangle()
          .fill(levelColor)
          .frame(width: level.width, height: level.height)
          .offset(x: level.minX + slide, y: level.minY)
          .opacity(sparkPop == nil ? drawn : popped)
      }
    }
    .frame(width: size, height: size)
    .onAppear(perform: appear)
    .accessibilityHidden(true)
  }

  private func appear() {
    guard !reduceMotion, let drawing else {
      drawn = 1
      popped = 1
      settled = true
      return
    }
    withAnimation(drawing) {
      drawn = 1
    } completion: {
      settled = true
    }
    if let sparkPop { withAnimation(sparkPop) { popped = 1 } }
  }
}

/// The mark's letter on its 24-unit grid, without the level: the stem with its 45-degree cut top,
/// the hook on concentric arcs (radii 3 and 6) ending in a 45-degree cut, and the crossbar's stub
/// left of the stem (STEM and STUB in make_brand_assets.py).
struct BrandLetter: Shape {
  /// The stem and hook's outline, clockwise from the top cut, in grid units.
  static let cutTop = CGPoint(x: 7.5, y: 7.5)
  static let stemTop = CGPoint(x: 10.5, y: 4.5)
  static let innerCorner = CGPoint(x: 10.5, y: 18)
  static let innerEnd = CGPoint(x: 13.5, y: 18)
  static let hookTop = CGPoint(x: 18, y: 18)
  static let hookBottom = CGPoint(x: 15, y: 21)
  static let outerCorner = CGPoint(x: 7.5, y: 21)
  static let outerEnd = CGPoint(x: 7.5, y: 15)
  static let innerRadius = 3.0
  static let outerRadius = 6.0
  /// The crossbar's stub left of the stem: x from 4.5 to 7.5, y from 9 to 12.
  static let stub = CGRect(x: 4.5, y: 9, width: 3, height: 3)

  func path(in rect: CGRect) -> Path {
    let unit = min(rect.width, rect.height) / BrandMark.gridUnits
    func p(_ point: CGPoint) -> CGPoint { CGPoint(x: rect.minX + point.x * unit, y: rect.minY + point.y * unit) }
    var path = Path()
    path.move(to: p(Self.cutTop))
    path.addLine(to: p(Self.stemTop))
    path.addArc(tangent1End: p(Self.innerCorner), tangent2End: p(Self.innerEnd), radius: Self.innerRadius * unit)
    path.addLine(to: p(Self.hookTop))
    path.addLine(to: p(Self.hookBottom))
    path.addArc(tangent1End: p(Self.outerCorner), tangent2End: p(Self.outerEnd), radius: Self.outerRadius * unit)
    path.closeSubpath()
    path.addRect(CGRect(x: rect.minX + Self.stub.minX * unit, y: rect.minY + Self.stub.minY * unit,
      width: Self.stub.width * unit, height: Self.stub.height * unit))
    return path
  }
}

/// The mark alone, letter and level in one colour, filling its frame with the 24-unit grid: for
/// one-colour places such as the Mac menu bar (a template image).
public struct BrandGlyph: View {
  /// The glyph's side in the Mac menu bar: a menu-bar extra's image side.
  public static let menuBarSide: CGFloat = 18
  /// The level's start at 16 to 18 points: a wider gap from the stem (3 units, 2 pixels), so the
  /// level never fuses with the letter in the menu bar.
  static let smallLevelStart = 13.5
  let size: CGFloat

  public init(size: CGFloat) {
    self.size = size
  }

  /// The level on the grid at small sizes.
  static var level: CGRect {
    CGRect(x: smallLevelStart, y: BrandMark.level.minY,
      width: BrandMark.level.maxX - smallLevelStart, height: BrandMark.level.height)
  }

  /// Draws the glyph in black into `rect` of a top-left-origin context (an image's drawing).
  public static func draw(in context: CGContext, rect: CGRect) {
    let unit = min(rect.width, rect.height) / BrandMark.gridUnits
    context.setFillColor(CGColor(gray: 0, alpha: 1))
    context.addPath(BrandLetter().path(in: rect).cgPath)
    context.addRect(CGRect(x: rect.minX + level.minX * unit, y: rect.minY + level.minY * unit,
      width: level.width * unit, height: level.height * unit))
    context.fillPath()
  }

  public var body: some View {
    let unit = size / BrandMark.gridUnits
    ZStack(alignment: .topLeading) {
      BrandLetter()
      Rectangle()
        .frame(width: Self.level.width * unit, height: Self.level.height * unit)
        .offset(x: Self.level.minX * unit, y: Self.level.minY * unit)
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}

#Preview {
  HStack(spacing: Tokens.Space.xl) {
    BrandMark(live: true)
    BrandMark(live: false, tone: .muted)
    BrandGlyph(size: BrandGlyph.menuBarSide)
  }
    .padding()
    .background(Palette.background)
}
