import SwiftUI
import TickrDesign

/// The price pane over the study panes (mockup v103): each study pane is a fixed
/// `Chart.studyPaneHeight`; the price pane fills what they leave, clamped to
/// `Chart.priceMinHeight`…`Chart.priceMaxHeight`; the bottom pane (the price pane when there is
/// no study) also holds the time axis's labels, `Chart.timeAxisHeight` more. The stack asks for
/// exactly the panes' sum, so the chart's card holds it whole: nothing is clipped and nothing
/// scrolls inside it.
///
/// Before, every study pane asked for up to 96 points and at least 56 and the price pane at least
/// 240, and the stack answered at least their sum whatever height it was offered: with the
/// volume and four indicator panes on (240 + 5 × 56 = 520) it overflowed the card by 26 points,
/// which clipped the time axis.
struct PaneStack: Layout {
  /// The price pane's height when the stack is offered `available` points with `studies` study
  /// panes under it.
  static func priceHeight(available: CGFloat, studies: Int) -> CGFloat {
    let rest = available - CGFloat(studies) * Tokens.Chart.studyPaneHeight - Tokens.Chart.timeAxisHeight
    return min(max(rest, Tokens.Chart.priceMinHeight), Tokens.Chart.priceMaxHeight)
  }

  /// The stack's whole height: the price pane, the study panes and the time axis.
  static func height(available: CGFloat?, studies: Int) -> CGFloat {
    let price = priceHeight(available: available ?? .infinity, studies: studies)
    return price + CGFloat(studies) * Tokens.Chart.studyPaneHeight + Tokens.Chart.timeAxisHeight
  }

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let studies = max(subviews.count - 1, 0)
    return CGSize(width: proposal.width ?? 0, height: Self.height(available: proposal.height, studies: studies))
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let studies = max(subviews.count - 1, 0)
    let price = Self.priceHeight(available: bounds.height, studies: studies)
    var y = bounds.minY
    for (index, view) in subviews.enumerated() {
      let pane = index == 0 ? price : Tokens.Chart.studyPaneHeight
      let height = pane + (index == subviews.count - 1 ? Tokens.Chart.timeAxisHeight : 0)
      view.place(at: CGPoint(x: bounds.minX, y: y), proposal: ProposedViewSize(width: bounds.width, height: height))
      y += height
    }
  }
}
