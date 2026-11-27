import Foundation

/// Every text of the widget extension (the Live Activity) that a person reads, in English, with
/// its Spanish translation in Localizable.xcstrings beside this file (docs/design-system.md,
/// rule 2). Causes and other shared texts come from TickrKit. Keys are `live.<name>`.
enum L10n {
  /// The extension's bundle, where Xcode compiles its String Catalog.
  static var bundle: LocalizedStringResource.BundleDescription { .main }

  /// The product name beside the mark in the expanded island.
  static var brand: LocalizedStringResource {
    LocalizedStringResource("live.brand", defaultValue: "Tickr", bundle: bundle)
  }
  /// The compact island's leading side once every position is closed.
  static var flat: LocalizedStringResource {
    LocalizedStringResource("live.flat", defaultValue: "Flat", bundle: bundle)
  }
  /// The last state of the day, before the activity ends: "Flat · day +$14.30 · ends".
  static func flatDay(_ result: String) -> LocalizedStringResource {
    LocalizedStringResource("live.flatDay", defaultValue: "Flat · day \(result) · ends", bundle: bundle)
  }
  /// The Lock Screen's headline while every stop is confirmed: "Tickr · 2 positions protected".
  static func protected(_ count: Int) -> LocalizedStringResource {
    LocalizedStringResource("live.protected", defaultValue: "Tickr · \(count) positions protected", bundle: bundle)
  }
  /// Entries are paused for a reason the bot did not send.
  static var paused: LocalizedStringResource {
    LocalizedStringResource("live.paused", defaultValue: "Entries paused", bundle: bundle)
  }
  /// Entries are paused, and why: "Entries paused · Quote stream quiet".
  static func pausedBecause(_ reason: String) -> LocalizedStringResource {
    LocalizedStringResource("live.pausedBecause", defaultValue: "Entries paused · \(reason)", bundle: bundle)
  }
  /// The alarm without a symbol.
  static var alarm: LocalizedStringResource {
    LocalizedStringResource("live.alarm", defaultValue: "Stop not confirmed", bundle: bundle)
  }
  /// The alarm: the broker has not confirmed this position's stop: "Stop not confirmed · ABCD".
  static func alarmFor(_ symbol: String) -> LocalizedStringResource {
    LocalizedStringResource("live.alarmFor", defaultValue: "Stop not confirmed · \(symbol)", bundle: bundle)
  }
  /// A row without a target, in place of the bar: "stop $11.90".
  static func stopAt(_ price: String) -> LocalizedStringResource {
    LocalizedStringResource("live.stopAt", defaultValue: "stop \(price)", bundle: bundle)
  }
  /// The stops line's subject in the island: every stop.
  static var stops: LocalizedStringResource {
    LocalizedStringResource("live.stops", defaultValue: "Stops", bundle: bundle)
  }
  /// The stops line's subject on the Lock Screen: every stop's price, "Stops $11.90 · $8.78".
  static func stopsAt(_ prices: String) -> LocalizedStringResource {
    LocalizedStringResource("live.stopsAt", defaultValue: "Stops \(prices)", bundle: bundle)
  }
  /// During the alarm, the subject in the island is each other position: "KLMN stop".
  static func symbolStop(_ symbol: String) -> LocalizedStringResource {
    LocalizedStringResource("live.symbolStop", defaultValue: "\(symbol) stop", bundle: bundle)
  }
  /// During the alarm, on the Lock Screen: "KLMN stop $8.78".
  static func symbolStopAt(_ symbol: String, _ price: String) -> LocalizedStringResource {
    LocalizedStringResource("live.symbolStopAt", defaultValue: "\(symbol) stop \(price)", bundle: bundle)
  }
  /// When the broker last confirmed the stops: "Stops confirmed at broker 2 s ago". `age` is
  /// where the counting time goes (`TextSlot`).
  static func confirmed(_ subject: String, _ age: String) -> LocalizedStringResource {
    LocalizedStringResource("live.confirmed", defaultValue: "\(subject) confirmed at broker \(age) ago", bundle: bundle)
  }
}
