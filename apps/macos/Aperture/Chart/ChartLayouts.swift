import ApertureDesign
import SwiftUI

/// The price pane over the study panes: each study pane gets its full height while the price
/// pane keeps at least `priceMinimum`; when there is less room the study panes shrink together,
/// down to `paneMinimum`, so the price pane never collapses under many studies.
struct PaneStack: Layout {
  let priceMinimum: CGFloat
  let paneHeight: CGFloat
  let paneMinimum: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let panes = CGFloat(max(subviews.count - 1, 0))
    let least = priceMinimum + panes * paneMinimum
    return CGSize(width: proposal.width ?? 0, height: max(proposal.height ?? least, least))
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    guard let price = subviews.first else { return }
    let panes = subviews.dropFirst()
    let count = CGFloat(panes.count)
    let pane = count == 0 ? 0 : min(paneHeight, max(paneMinimum, (bounds.height - priceMinimum) / count))
    let priceHeight = bounds.height - count * pane
    price.place(at: bounds.origin, proposal: ProposedViewSize(width: bounds.width, height: priceHeight))
    var y = bounds.minY + priceHeight
    for view in panes {
      view.place(at: CGPoint(x: bounds.minX, y: y), proposal: ProposedViewSize(width: bounds.width, height: pane))
      y += pane
    }
  }
}

/// Chips in rows: as many as fit across, the rest on the next row, so none is out of reach in
/// a narrow window.
struct ChipFlow: Layout {
  let spacing: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let rows = rows(width: proposal.width ?? .infinity, subviews: subviews)
    let width = rows.map(\.width).max() ?? 0
    let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
    return CGSize(width: proposal.width.map { min($0, width) } ?? width, height: height)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    var y = bounds.minY
    for row in rows(width: bounds.width, subviews: subviews) {
      var x = bounds.minX
      for index in row.indices {
        let size = subviews[index].sizeThatFits(.unspecified)
        subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: .unspecified)
        x += size.width + spacing
      }
      y += row.height + spacing
    }
  }

  private struct Row {
    var indices: [Int] = []
    var width: CGFloat = 0
    var height: CGFloat = 0
  }

  private func rows(width: CGFloat, subviews: Subviews) -> [Row] {
    var rows: [Row] = []
    var row = Row()
    for index in subviews.indices {
      let size = subviews[index].sizeThatFits(.unspecified)
      let needed = row.indices.isEmpty ? size.width : row.width + spacing + size.width
      if needed > width, !row.indices.isEmpty {
        rows.append(row)
        row = Row()
      }
      row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
      row.height = max(row.height, size.height)
      row.indices.append(index)
    }
    if !row.indices.isEmpty { rows.append(row) }
    return rows
  }
}
