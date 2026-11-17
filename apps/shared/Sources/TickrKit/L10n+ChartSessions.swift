import Foundation

/// Words of the continuous all-session chart (mockup v113), shared by both apps, in English with
/// their Russian translation in Resources/Localizable.xcstrings (docs/design-system.md, rule 2).
public enum ChartSessionWords {
  /// The caption on the pre-market band.
  public static var preBand: LocalizedStringResource {
    LocalizedStringResource("kit.chart.preBand", defaultValue: "PRE", bundle: L10n.bundle)
  }
  /// The caption on the after-hours band.
  public static var afterBand: LocalizedStringResource {
    LocalizedStringResource("kit.chart.afterBand", defaultValue: "AFTER", bundle: L10n.bundle)
  }
  /// The pre-market open at the left edge of a Day axis: "Pre 04:00".
  public static func preAt(_ time: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.chart.preAt", defaultValue: "Pre \(time)", bundle: L10n.bundle)
  }
  /// The extended close at the right end of a Day axis: "After 20:00".
  public static func afterAt(_ time: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.chart.afterAt", defaultValue: "After \(time)", bundle: L10n.bundle)
  }
  /// The readout's part of the day on the Mac: "19:50 · after-hours".
  public static var preMarket: LocalizedStringResource {
    LocalizedStringResource("kit.chart.preMarket", defaultValue: "pre-market", bundle: L10n.bundle)
  }
  public static var afterHours: LocalizedStringResource {
    LocalizedStringResource("kit.chart.afterHours", defaultValue: "after-hours", bundle: L10n.bundle)
  }
  /// The readout's part of the day on the iPhone, shorter: "19:50 · after".
  public static var preShort: LocalizedStringResource {
    LocalizedStringResource("kit.chart.preShort", defaultValue: "pre", bundle: L10n.bundle)
  }
  public static var afterShort: LocalizedStringResource {
    LocalizedStringResource("kit.chart.afterShort", defaultValue: "after", bundle: L10n.bundle)
  }
  /// A 5D chart filling while the chart's request budget allows: "Loading 3 of 5 days".
  public static func loadingDays(_ read: Int, _ total: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.chart.loadingDays", defaultValue: "Loading \(read) of \(total) days", bundle: L10n.bundle)
  }
  /// A chart waiting for the chart's request budget before its first read.
  public static var waitingForBudget: LocalizedStringResource {
    LocalizedStringResource("kit.chart.waitingForBudget", defaultValue: "Loading · market data in a moment",
      bundle: L10n.bundle)
  }
}
