import Foundation

/// Texts beside the status headline (mockup v108): its detail line, the session countdown and the
/// entry gate's badge (HeadlineFacts.swift).
extension L10n {
  // MARK: Headline detail

  /// The headline's detail when no position is open.
  static var headlineNoOpenPosition: LocalizedStringResource {
    LocalizedStringResource("kit.headline.noOpenPosition", defaultValue: "No open position", bundle: bundle)
  }
  /// The headline's detail with open positions; arguments: how many are open, and how many of
  /// them a verified broker stop protects.
  static func headlineProtectedPositions(_ count: Int, _ protected: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.headline.protectedPositions",
      defaultValue: "\(count) open · \(protected) protected by a verified broker stop", bundle: bundle)
  }

  /// The headline while the trading gate is closed by configuration (mockup v109).
  static var headlineEntriesOff: LocalizedStringResource {
    LocalizedStringResource("kit.headline.entriesOff", defaultValue: "Entries off", bundle: bundle)
  }
  /// Its detail.
  static var headlineGateClosedInConfig: LocalizedStringResource {
    LocalizedStringResource("kit.headline.gateClosedInConfig", defaultValue: "trading gate closed in config",
      bundle: bundle)
  }

  /// The holding headline's detail with one position.
  static var headlineStopVerified: LocalizedStringResource {
    LocalizedStringResource("kit.headline.stopVerified", defaultValue: "stop verified", bundle: bundle)
  }
  /// The holding headline's detail with several positions.
  static var headlineStopsVerified: LocalizedStringResource {
    LocalizedStringResource("kit.headline.stopsVerified", defaultValue: "stops verified", bundle: bundle)
  }

  // MARK: Session countdown

  /// Before the regular session: the label in front of the time left.
  static var countdownOpensIn: LocalizedStringResource {
    LocalizedStringResource("kit.countdown.opensIn", defaultValue: "Opens in", bundle: bundle)
  }
  /// Inside the regular session: the label in front of the time left.
  static var countdownClosesIn: LocalizedStringResource {
    LocalizedStringResource("kit.countdown.closesIn", defaultValue: "Closes in", bundle: bundle)
  }
  /// The time left, an hour or more; arguments: whole hours, then minutes. Abbreviated units take
  /// no plural forms in either language ("ч", "м"), so any count reads right.
  static func countdownHoursMinutes(_ hours: Int, _ minutes: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.countdown.hoursMinutes", defaultValue: "\(hours) h \(minutes) m", bundle: bundle)
  }
  /// The time left under an hour; argument: whole minutes (an abbreviated unit, no plural forms).
  static func countdownMinutes(_ minutes: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.countdown.minutes", defaultValue: "\(minutes) m", bundle: bundle)
  }

  // MARK: Entry gate badge

  /// The trading gate is open and the operator has not paused entries.
  static var gateOpen: LocalizedStringResource {
    LocalizedStringResource("kit.entryGate.open", defaultValue: "Gate open", bundle: bundle)
  }
  /// The operator's entry stop is on.
  static var gatePaused: LocalizedStringResource {
    LocalizedStringResource("kit.entryGate.paused", defaultValue: "Entries paused", bundle: bundle)
  }
  /// The trading gate is closed (configuration or the Production lock).
  static var gateClosed: LocalizedStringResource {
    LocalizedStringResource("kit.entryGate.closed", defaultValue: "Gate closed", bundle: bundle)
  }
}
