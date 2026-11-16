import SwiftUI
import TickrDesign

/// How a screen's cards sit at one width: rows of columns, each column a stack of cards.
struct CardArrangement {
  /// Narrowest width of the grid, in points, that this arrangement is used at.
  let minWidth: CGFloat
  let rows: [CardRow]
}

extension CardArrangement {
  /// Columns in the design's widest card grids (Overview, Risk & account, Strategy lab).
  static let wideColumns = 3
  /// Edges a screen's padding is on across one axis (leading and trailing, or top and bottom).
  static let paddedEdges: CGFloat = 2

  /// Least width of `count` columns of the least grid column width with the grid's gap between.
  static func columnsMinWidth(_ count: Int) -> CGFloat {
    Tokens.Size.gridColumnMin * CGFloat(count) + Tokens.Space.l * CGFloat(max(count - 1, 0))
  }
}

/// One row of a `CardArrangement`.
struct CardRow {
  /// How tall the row is.
  enum Height {
    /// As tall as its tallest column.
    case natural
    /// As tall as its tallest column, never less than this many points.
    case atLeast(CGFloat)
    /// Takes what the other rows leave of the grid's `minHeight`, never less than this many
    /// points (the design's bottom row reaching the window's bottom).
    case fillsRest(atLeast: CGFloat)
  }

  let columns: [CardColumn]
  var height: Height = .natural
  /// Whether each column's last card is stretched to the row's height, so the row's cards line up
  /// (cards that fill what they are offered); otherwise every card keeps its own height, top-aligned.
  var linesUp = true
  /// Gap between the row's columns, in points; nil takes the grid's spacing.
  var columnGap: CGFloat?
}

/// One column of a `CardRow`: its width and its cards, top to bottom.
struct CardColumn {
  enum Width {
    /// A share of the width the fixed columns and the gaps leave (the design's CSS fr units).
    case share(CGFloat)
    /// This many points.
    case fixed(CGFloat)
  }

  let width: Width
  /// Positions of the cards in the grid's content, top to bottom.
  let cards: [Int]
}

/// A screen's cards in the first of its arrangements that the grid's width allows (they are
/// ordered widest first; the last one is used below every threshold).
///
/// The cards are the same views in every arrangement: a narrower window moves them, it never makes
/// new ones. Switching arrangements with `if`/`ViewThatFits` replaced the cards whenever the width
/// crossed a threshold during a window resize, and the new ones played their entrance again (the
/// screen emptied and the cards rose back in mid-drag). The choice is made here, from the width the
/// grid is offered in the same layout pass, so no measured width feeds back through view state.
struct CardGrid: Layout {
  let arrangements: [CardArrangement]
  let spacing: CGFloat
  /// Least height of the grid, in points: a `fillsRest` row takes what the other rows leave of it.
  var minHeight: CGFloat = 0

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let width = proposal.width ?? arrangements.first?.minWidth ?? 0
    return plan(width: width, count: subviews.count) { subviews[$0].sizeThatFits($1).height }.size
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let frames = plan(width: bounds.width, count: subviews.count) { subviews[$0].sizeThatFits($1).height }.frames
    for (index, subview) in subviews.enumerated() {
      guard let frame = frames[index] else {
        // A card no arrangement row names takes no room.
        subview.place(at: bounds.origin, proposal: .zero)
        continue
      }
      subview.place(
        at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), anchor: .topLeading,
        proposal: ProposedViewSize(frame.size))
    }
  }

  /// The arrangement for `width`.
  func arrangement(for width: CGFloat) -> CardArrangement? {
    arrangements.first { width >= $0.minWidth } ?? arrangements.last
  }

  /// Every card's frame in the grid (nil for a card the arrangement leaves out) and the grid's size,
  /// for `count` cards whose own heights at a proposal `height` gives.
  func plan(width: CGFloat, count: Int, height: (Int, ProposedViewSize) -> CGFloat) -> (frames: [CGRect?], size: CGSize) {
    var frames = [CGRect?](repeating: nil, count: count)
    guard let arrangement = arrangement(for: width) else { return (frames, CGSize(width: width, height: 0)) }
    let rows = arrangement.rows.map { measure($0, width: width, count: count, height: height) }
    var heights = rows.map(\.height)
    let natural = heights.reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
    if let filling = arrangement.rows.firstIndex(where: { if case .fillsRest = $0.height { true } else { false } }) {
      heights[filling] += max(minHeight - natural, 0)
    }
    var y: CGFloat = 0
    for (row, (measured, rowHeight)) in zip(arrangement.rows, zip(rows, heights)) {
      for (column, (x, columnWidth, cardHeights)) in zip(row.columns, measured.columns) {
        var cardY = y
        for (position, (card, cardHeight)) in zip(column.cards, cardHeights).enumerated() {
          let last = position == column.cards.count - 1
          let stretched = last && row.linesUp ? max(y + rowHeight - cardY, cardHeight) : cardHeight
          if frames.indices.contains(card) {
            frames[card] = CGRect(x: x, y: cardY, width: columnWidth, height: stretched)
          }
          cardY += stretched + spacing
        }
      }
      y += rowHeight + spacing
    }
    return (frames, CGSize(width: width, height: max(y - spacing, 0)))
  }

  /// A row's columns (leading edge, width, each card's own height) and its height before a
  /// `fillsRest` row takes the rest.
  private func measure(_ row: CardRow, width: CGFloat, count: Int, height: (Int, ProposedViewSize) -> CGFloat)
    -> (columns: [(CGFloat, CGFloat, [CGFloat])], height: CGFloat) {
    let gap = row.columnGap ?? spacing
    let widths = columnWidths(row.columns, width: width, gap: gap)
    var x: CGFloat = 0
    var columns: [(CGFloat, CGFloat, [CGFloat])] = []
    var tallest: CGFloat = 0
    for (column, columnWidth) in zip(row.columns, widths) {
      let heights = column.cards.map { card in
        (0..<count).contains(card) ? height(card, ProposedViewSize(width: columnWidth, height: nil)) : 0
      }
      columns.append((x, columnWidth, heights))
      tallest = max(tallest, heights.reduce(0, +) + spacing * CGFloat(max(heights.count - 1, 0)))
      x += columnWidth + gap
    }
    switch row.height {
    case .natural: return (columns, tallest)
    case .atLeast(let least), .fillsRest(let least): return (columns, max(tallest, least))
    }
  }

  /// Each column's width: fixed columns their points, the rest shared by weight.
  private func columnWidths(_ columns: [CardColumn], width: CGFloat, gap: CGFloat) -> [CGFloat] {
    var fixed: CGFloat = 0
    var shares: CGFloat = 0
    for column in columns {
      switch column.width {
      case .fixed(let points): fixed += points
      case .share(let share): shares += share
      }
    }
    let free = max(width - fixed - gap * CGFloat(max(columns.count - 1, 0)), 0)
    return columns.map { column in
      switch column.width {
      case .fixed(let points): points
      case .share(let share): shares > 0 ? free * share / shares : 0
      }
    }
  }
}
