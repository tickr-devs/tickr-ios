import Foundation

/// What a command button says while its command is in flight (mockup v102: the spinner in the
/// button, "Closing ABCD position"), in English with their Spanish translation in
/// Resources/Localizable.xcstrings. Both apps show the same words.
extension L10n {
  static var inFlightPauseEntries: LocalizedStringResource {
    LocalizedStringResource("kit.inFlight.pauseEntries", defaultValue: "Pausing entries", bundle: bundle)
  }
  static var inFlightResumeEntries: LocalizedStringResource {
    LocalizedStringResource("kit.inFlight.resumeEntries", defaultValue: "Resuming entries", bundle: bundle)
  }
  static var inFlightCancelOrders: LocalizedStringResource {
    LocalizedStringResource("kit.inFlight.cancelOrders", defaultValue: "Cancelling the bot's orders", bundle: bundle)
  }
  /// Closing one position; argument: its symbol.
  static func inFlightFlattenSymbol(_ symbol: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.inFlight.flattenSymbol", defaultValue: "Closing \(symbol) position", bundle: bundle)
  }
  /// Cancelling one working entry order; same words as the entry's own "Cancelling…" line.
  static var inFlightCancelEntry: LocalizedStringResource {
    LocalizedStringResource("kit.inFlight.cancelEntry", defaultValue: "Cancelling…", bundle: bundle)
  }
  static var inFlightFlatten: LocalizedStringResource {
    LocalizedStringResource("kit.inFlight.flatten", defaultValue: "Closing all positions", bundle: bundle)
  }
  static var inFlightStopBot: LocalizedStringResource {
    LocalizedStringResource("kit.inFlight.stopBot", defaultValue: "Stopping the bot", bundle: bundle)
  }
  static var inFlightCloseAndStop: LocalizedStringResource {
    LocalizedStringResource("kit.inFlight.closeAndStop", defaultValue: "Closing and stopping", bundle: bundle)
  }
  static var inFlightEmergency: LocalizedStringResource {
    LocalizedStringResource("kit.inFlight.emergency", defaultValue: "Stopping everything", bundle: bundle)
  }
}

extension OperatorCommand {
  /// What the command's button says while the command is in flight ("Closing ABCD position").
  public var inFlightTitle: LocalizedStringResource {
    switch self {
    case .entryStop(let on): on ? L10n.inFlightPauseEntries : L10n.inFlightResumeEntries
    case .cancelOwnOrders: L10n.inFlightCancelOrders
    case .cancelEntry: L10n.inFlightCancelEntry
    case .flatten: L10n.inFlightFlatten
    case .flattenSymbol(let symbol): L10n.inFlightFlattenSymbol(symbol)
    case .stopBot, .stopBotMode(.leaveOpen): L10n.inFlightStopBot
    case .stopBotMode(.closeAndStop): L10n.inFlightCloseAndStop
    case .emergency: L10n.inFlightEmergency
    }
  }
}

/// What other buttons say while their action is in flight, on both apps.
public enum InFlightText {
  /// Start bot, while the Mac starts the bot's job.
  public static var startBot: LocalizedStringResource {
    LocalizedStringResource("kit.inFlight.startBot", defaultValue: "Starting the bot", bundle: L10n.bundle)
  }
  /// The Lab's replay button while the bot accepts the run.
  public static var replayStarting: LocalizedStringResource {
    LocalizedStringResource("kit.inFlight.replayStarting", defaultValue: "Starting the replay", bundle: L10n.bundle)
  }
  /// The Lab's replay button while the replay runs (the bot reports no share done, so no bar).
  public static var replayRunning: LocalizedStringResource {
    LocalizedStringResource("kit.inFlight.replayRunning", defaultValue: "Replaying", bundle: L10n.bundle)
  }
}
