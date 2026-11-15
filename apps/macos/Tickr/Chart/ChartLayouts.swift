import SwiftUI
import TickrDesign

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
