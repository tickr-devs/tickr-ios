import Foundation

/// The live flow's stages by name, the same in both apps (mockup v155): what a symbol has become
/// at each stage.
public extension PipelineStage {
  /// Found, Stocks, Priced, Liquid, Model, Risk, Bought, Protected, Checked.
  var title: LocalizedStringResource {
    switch self {
    case .screeners: LocalizedStringResource("kit.pipeline.screeners", defaultValue: "Found", bundle: L10n.bundle)
    case .universe: LocalizedStringResource("kit.pipeline.universe", defaultValue: "Stocks", bundle: L10n.bundle)
    case .quote: LocalizedStringResource("kit.pipeline.quote", defaultValue: "Priced", bundle: L10n.bundle)
    case .bars: LocalizedStringResource("kit.pipeline.bars", defaultValue: "Liquid", bundle: L10n.bundle)
    case .strategy: LocalizedStringResource("kit.pipeline.strategy", defaultValue: "Model", bundle: L10n.bundle)
    case .risk: LocalizedStringResource("kit.pipeline.risk", defaultValue: "Risk", bundle: L10n.bundle)
    case .order: LocalizedStringResource("kit.pipeline.order", defaultValue: "Bought", bundle: L10n.bundle)
    case .stop: LocalizedStringResource("kit.pipeline.stop", defaultValue: "Protected", bundle: L10n.bundle)
    case .reconcile: LocalizedStringResource("kit.pipeline.reconcile", defaultValue: "Checked", bundle: L10n.bundle)
    }
  }
}

/// The words of the shown day's switch on the iPhone (`DaySwitch`): the picker sheet's title, its
/// rows and the swipe hint under them.
public enum DayWords {
  /// The day button's caption on today, and the picker's row back to it.
  public static var today: LocalizedStringResource {
    LocalizedStringResource("kit.day.today", defaultValue: "Today", bundle: L10n.bundle)
  }
  /// The picker sheet's title.
  public static var title: LocalizedStringResource {
    LocalizedStringResource("kit.day.title", defaultValue: "Trading day", bundle: L10n.bundle)
  }
  /// The picker's row to the recorded day before the shown one.
  public static var previous: LocalizedStringResource {
    LocalizedStringResource("kit.day.previous", defaultValue: "Previous trading day", bundle: L10n.bundle)
  }
  /// The picker's row to the day after the shown one (a recorded day, or today).
  public static var next: LocalizedStringResource {
    LocalizedStringResource("kit.day.next", defaultValue: "Next trading day", bundle: L10n.bundle)
  }
  /// Under the picker's rows: the page changes the day with a sideways swipe too.
  public static var swipeHint: LocalizedStringResource {
    LocalizedStringResource("kit.day.swipeHint", defaultValue: "You can also swipe the page left or right.",
      bundle: L10n.bundle)
  }
  /// VoiceOver label of the day button; argument: the day in full ("Fri Nov 13 · today").
  public static func label(_ day: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.day.label", defaultValue: "Day: \(day)", bundle: L10n.bundle)
  }
}
