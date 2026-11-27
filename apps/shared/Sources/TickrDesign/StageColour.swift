import SwiftUI
import TickrKit

/// The one colour of each live-flow stage (mockup v151, owner-approved 2026-11-25): nine stages, nine
/// hues, in the order a symbol passes them. Mac Overview and iOS Home read this map, never a colour
/// of their own. A stage whose state can change its colour (the broker stop, the reconciliation)
/// takes this one while healthy and the app's tone of the state otherwise.
public extension PipelineStage {
  /// Found teal, Stocks pink, Priced cyan, Liquid blue, Model violet, Risk amber, Bought orange,
  /// Protected green, Checked lime.
  var fill: Color { Color(fillSwatch) }

  /// The same hue for words (the stage's name), 4.5:1 on `surface`.
  var text: Color { Color(textSwatch) }

  /// The fill's light and dark values: the one place a stage's colour is chosen.
  var fillSwatch: Swatch {
    switch self {
    case .screeners: .accent
    case .universe: .seriesATR
    case .quote: .cyan
    case .bars: .info
    case .strategy: .highlight
    case .risk: .warning
    case .order: .orange
    case .stop: .profit
    case .reconcile: .lime
    }
  }

  /// The words' light and dark values.
  var textSwatch: Swatch {
    switch self {
    case .screeners: .accentText
    case .universe: .seriesATRText
    case .quote: .cyanText
    case .bars: .infoText
    case .strategy: .highlightText
    case .risk: .warningText
    case .order: .orangeText
    case .stop: .profitText
    case .reconcile: .limeText
    }
  }
}
