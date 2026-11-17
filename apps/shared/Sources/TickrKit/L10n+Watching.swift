import Foundation

/// Texts of a "Watching closely" row's deciding check (WatchingCheck) and of a check's values
/// (`CheckV1.valueText`).
extension L10n {
  /// A check against the trigger, not met: measured, the trigger, how far is left.
  static func watchingToGo(_ measured: String, _ trigger: String, _ distance: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.watching.toGo", defaultValue: "\(measured) · trigger \(trigger) · \(distance) to go",
      bundle: bundle)
  }
  /// A strict check exactly at the trigger, not met: it needs a value above it.
  static func watchingAtTriggerNeedsAbove(_ measured: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.watching.atTriggerNeedsAbove", defaultValue: "\(measured) · at the trigger, needs above",
      bundle: bundle)
  }
  /// A strict check exactly at the trigger, not met: it needs a value below it.
  static func watchingAtTriggerNeedsBelow(_ measured: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.watching.atTriggerNeedsBelow", defaultValue: "\(measured) · at the trigger, needs below",
      bundle: bundle)
  }
  /// A check against the trigger, met above it.
  static func watchingAboveTrigger(_ measured: String, _ trigger: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.watching.aboveTrigger", defaultValue: "\(measured) · above trigger \(trigger)",
      bundle: bundle)
  }
  /// A check against the trigger, met below it.
  static func watchingBelowTrigger(_ measured: String, _ trigger: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.watching.belowTrigger", defaultValue: "\(measured) · below trigger \(trigger)",
      bundle: bundle)
  }
  /// A check against the trigger, met exactly at it (`>=` or `<=`).
  static func watchingAtTrigger(_ measured: String, _ trigger: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.watching.atTrigger", defaultValue: "\(measured) · at trigger \(trigger)", bundle: bundle)
  }
  /// A WATCH with no failed check and a recorded trigger: the setup is ready and the entry waits
  /// for the price to reach the trigger.
  static func watchingNoQuoteCheck(_ trigger: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.watching.noQuoteCheck",
      defaultValue: "Setup ready · waiting for the price to reach trigger \(trigger)", bundle: bundle)
  }
  /// A WATCH with no failed check and no recorded trigger.
  static var watchingNothingToMeasure: LocalizedStringResource {
    LocalizedStringResource("kit.watching.nothingToMeasure",
      defaultValue: "Setup ready · no trigger recorded to measure against", bundle: bundle)
  }
  /// What the closeness bar's ends mean for a check against the trigger.
  static func watchingScale(_ invalidation: String, _ trigger: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.watching.scale",
      defaultValue: "Empty at the invalidation \(invalidation), full at the trigger \(trigger)", bundle: bundle)
  }
  /// A failed check's values: measured, then what it needs.
  static func checkNeeds(_ measured: String, _ op: String, _ threshold: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.check.needs", defaultValue: "\(measured) · needs \(op) \(threshold)", bundle: bundle)
  }
  /// A yes/no check that passed.
  static var checkMet: LocalizedStringResource {
    LocalizedStringResource("kit.check.met", defaultValue: "met", bundle: bundle)
  }
  /// A yes/no check that failed.
  static var checkNotMet: LocalizedStringResource {
    LocalizedStringResource("kit.check.notMet", defaultValue: "not met", bundle: bundle)
  }
}
