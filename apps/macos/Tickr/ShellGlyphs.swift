import SwiftUI
import TickrDesign

/// The window shell's line icons as the design draws them: the sidebar's section icons on a
/// 24-point grid (stroked 2 points wide there, so 1⅓ at the row's 16 points) and the title bar's
/// sidebar button on a 16-point grid. SF Symbols draw the same ideas with other shapes and
/// weights; the design's own outlines keep the sidebar as drawn.
struct ShellGlyph: Shape {
  enum Kind {
    case overview, chart, trades, risk, lab
    /// The title bar's button that hides and shows the sidebar.
    case sidebar
  }

  let kind: Kind

  /// Grid of the section icons and of the sidebar button, in the design's units.
  static let sectionGrid: CGFloat = 24
  static let sidebarGrid: CGFloat = 16
  /// Stroke width in grid units: 2 on the section icons, 1.5 on the sidebar button.
  static let sectionStroke: CGFloat = 2
  static let sidebarStroke: CGFloat = 1.5

  /// Overview: four tiles, tall and short ones crossed.
  static let tileTallLeft = CGRect(x: 4, y: 4, width: 6, height: 9)
  static let tileTallRight = CGRect(x: 14, y: 11, width: 6, height: 9)
  static let tileShortLeft = CGRect(x: 4, y: 17, width: 6, height: 3)
  static let tileShortRight = CGRect(x: 14, y: 4, width: 6, height: 3)
  static let overviewTiles = [tileTallLeft, tileTallRight, tileShortLeft, tileShortRight]
  /// Chart: one rising line.
  static let chartStart = CGPoint(x: 4, y: 19)
  static let chartPeak = CGPoint(x: 9, y: 13)
  static let chartDip = CGPoint(x: 13, y: 16)
  static let chartEnd = CGPoint(x: 20, y: 7)
  static let chartLine = [chartStart, chartPeak, chartDip, chartEnd]
  /// Trades: three lines, the last one shorter (left edge, right ends, heights).
  static let tradesLeft: CGFloat = 4
  static let tradesRights: [CGFloat] = [20, 20, 14]
  static let tradesRows: [CGFloat] = [6, 12, 18]
  /// Risk: a shield, its top, shoulders, the curves' control points and its tip.
  static let shieldTop = CGPoint(x: 12, y: 3)
  static let shieldRight = CGPoint(x: 19, y: 6)
  static let shieldRightWaist = CGPoint(x: 19, y: 12)
  static let shieldRightControls = (CGPoint(x: 19, y: 16.5), CGPoint(x: 16, y: 19.5))
  static let shieldTip = CGPoint(x: 12, y: 21)
  static let shieldLeftControls = (CGPoint(x: 8, y: 19.5), CGPoint(x: 5, y: 16.5))
  static let shieldLeftWaist = CGPoint(x: 5, y: 12)
  static let shieldLeft = CGPoint(x: 5, y: 6)
  /// Strategy lab: a five-pointed star, its points and inner corners clockwise from the top.
  static let starTop = CGPoint(x: 12, y: 3)
  static let starInnerTopRight = CGPoint(x: 14.2, y: 8.3)
  static let starRight = CGPoint(x: 20, y: 9)
  static let starInnerRight = CGPoint(x: 15.6, y: 12.8)
  static let starBottomRight = CGPoint(x: 17, y: 19)
  static let starInnerBottom = CGPoint(x: 12, y: 16)
  static let starBottomLeft = CGPoint(x: 7, y: 19)
  static let starInnerLeft = CGPoint(x: 8.4, y: 12.8)
  static let starLeft = CGPoint(x: 4, y: 9)
  static let starInnerTopLeft = CGPoint(x: 9.8, y: 8.3)
  static let star = [
    starTop, starInnerTopRight, starRight, starInnerRight, starBottomRight, starInnerBottom, starBottomLeft,
    starInnerLeft, starLeft, starInnerTopLeft,
  ]
  /// Sidebar button: a window outline with the sidebar's edge in it.
  static let windowOutline = CGRect(x: 1.5, y: 2.5, width: 13, height: 11)
  static let windowCorner: CGFloat = 2
  static let sidebarEdge: CGFloat = 6

  /// Stroke width in points for the glyph drawn `size` points wide.
  static func lineWidth(_ kind: Kind, size: CGFloat) -> CGFloat {
    kind == .sidebar ? sidebarStroke * size / sidebarGrid : sectionStroke * size / sectionGrid
  }

  func path(in rect: CGRect) -> Path {
    let grid = kind == .sidebar ? Self.sidebarGrid : Self.sectionGrid
    let scale = min(rect.width, rect.height) / grid
    var path = Path()
    switch kind {
    case .overview:
      for tile in Self.overviewTiles { path.addRect(tile) }
    case .chart:
      path.addLines(Self.chartLine)
    case .trades:
      for (row, right) in zip(Self.tradesRows, Self.tradesRights) {
        path.move(to: CGPoint(x: Self.tradesLeft, y: row))
        path.addLine(to: CGPoint(x: right, y: row))
      }
    case .risk:
      path.move(to: Self.shieldTop)
      path.addLine(to: Self.shieldRight)
      path.addLine(to: Self.shieldRightWaist)
      path.addCurve(to: Self.shieldTip, control1: Self.shieldRightControls.0, control2: Self.shieldRightControls.1)
      path.addCurve(to: Self.shieldLeftWaist, control1: Self.shieldLeftControls.0, control2: Self.shieldLeftControls.1)
      path.addLine(to: Self.shieldLeft)
      path.closeSubpath()
    case .lab:
      path.addLines(Self.star)
      path.closeSubpath()
    case .sidebar:
      path.addRoundedRect(in: Self.windowOutline, cornerSize: CGSize(width: Self.windowCorner, height: Self.windowCorner))
      path.move(to: CGPoint(x: Self.sidebarEdge, y: Self.windowOutline.minY))
      path.addLine(to: CGPoint(x: Self.sidebarEdge, y: Self.windowOutline.maxY))
    }
    let offset = CGPoint(x: rect.midX - grid * scale / 2, y: rect.midY - grid * scale / 2)
    return path.applying(CGAffineTransform(scaleX: scale, y: scale).concatenating(
      CGAffineTransform(translationX: offset.x, y: offset.y)))
  }
}

/// A shell glyph stroked as the design strokes it: round ends and joins, in the text's colour.
struct ShellIcon: View {
  let kind: ShellGlyph.Kind
  let size: CGFloat

  var body: some View {
    ShellGlyph(kind: kind)
      .stroke(style: StrokeStyle(lineWidth: ShellGlyph.lineWidth(kind, size: size), lineCap: .round, lineJoin: .round))
      .frame(width: size, height: size)
      .accessibilityHidden(true)
  }
}
