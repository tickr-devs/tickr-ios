import Foundation

/// The observer rows' texts (ObserverLabel), with their Russian translations in
/// Resources/Localizable.xcstrings.
extension L10n {
  /// The trading strategy's row: "v3 · active".
  static func observerActive(_ family: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.observer.active", defaultValue: "\(family) · active", bundle: bundle)
  }
  /// An observer the bot cannot compare with the active strategy: its name and version.
  static func observerVersion(_ name: String, _ version: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.observer.version", defaultValue: "\(name) v\(version)", bundle: bundle)
  }
  /// An observer whose settings equal the active strategy's.
  static var observerSameSettings: LocalizedStringResource {
    LocalizedStringResource("kit.observer.sameSettings", defaultValue: "same settings", bundle: bundle)
  }
  /// An observer's least relative volume: "rel vol 1.5×".
  static func observerRelativeVolume(_ value: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.observer.relativeVolume", defaultValue: "rel vol \(value)×", bundle: bundle)
  }
  /// Any other differing setting, by its key and the observer's value: "lookback_bars 8".
  static func observerSetting(_ key: String, _ value: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.observer.setting", defaultValue: "\(key) \(value)", bundle: bundle)
  }
  /// Since when an observer watched that day (New York time): "watching since 15:08".
  static func observerWatchingSince(_ time: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.observer.watchingSince", defaultValue: "watching since \(time)", bundle: bundle)
  }
  /// An observer that entered nothing so far.
  static var observerNoEntriesYet: LocalizedStringResource {
    LocalizedStringResource("kit.observer.noEntriesYet", defaultValue: "no entries yet", bundle: bundle)
  }
  /// The symbols an observer would have entered that the trading strategy did not trade.
  static func observerActiveSkipped(_ symbols: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.observer.activeSkipped", defaultValue: "active skipped: \(symbols)", bundle: bundle)
  }
}
