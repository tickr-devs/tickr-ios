import Foundation

/// Every text of TickrKit that a person reads, in English, with its Russian translation in
/// Resources/Localizable.xcstrings (docs/design-system.md, rule 2). Read with `String(localized:)`.
enum L10n {
  /// The package's resource bundle, which holds the String Catalog.
  static var bundle: LocalizedStringResource.BundleDescription { .atURL(Bundle.module.bundleURL) }

  // MARK: Event texts (Board.events)

  /// An entry or an open position: "ABCD 54 @ 28.30", in the cards' own wording.
  static func eventQuantityAt(_ symbol: String, _ quantity: String, _ price: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.event.quantityAt", defaultValue: "\(symbol) \(quantity) @ \(price)", bundle: bundle)
  }
  /// An exit with its result: "ABCD @ 29.10 +43.20".
  static func eventExitAt(_ symbol: String, _ price: String, _ result: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.event.exitAt", defaultValue: "\(symbol) @ \(price) \(result)", bundle: bundle)
  }

  // MARK: Event tags (Board.events)

  /// Event tag: a trade was entered.
  static var tagEnter: LocalizedStringResource {
    LocalizedStringResource("kit.event.enter", defaultValue: "ENTER", bundle: bundle)
  }
  /// Event tag: a position is open.
  static var tagOpen: LocalizedStringResource {
    LocalizedStringResource("kit.event.open", defaultValue: "OPEN", bundle: bundle)
  }
  /// Event tag: the bot raised a fence (a block on new entries).
  static var tagFence: LocalizedStringResource {
    LocalizedStringResource("kit.event.fence", defaultValue: "FENCE", bundle: bundle)
  }
  /// Event tag: an operator command was carried out.
  static var tagDone: LocalizedStringResource {
    LocalizedStringResource("kit.event.done", defaultValue: "DONE", bundle: bundle)
  }
  /// Event tag: the bot refused an operator command.
  static var tagRefused: LocalizedStringResource {
    LocalizedStringResource("kit.event.refused", defaultValue: "REFUSED", bundle: bundle)
  }
  /// Stop event text when the stop has no price yet.
  static var noPrice: LocalizedStringResource {
    LocalizedStringResource("kit.event.noPrice", defaultValue: "no price", bundle: bundle)
  }

  // MARK: Stop tags (Board.stopTag)

  /// Tag: the broker-side stop is verified.
  static var stopVerified: LocalizedStringResource {
    LocalizedStringResource("kit.stop.verified", defaultValue: "STOP \u{2713}", bundle: bundle)
  }
  /// Tag: the stop order is sent, not yet confirmed.
  static var stopPending: LocalizedStringResource {
    LocalizedStringResource("kit.stop.pending", defaultValue: "STOP PENDING", bundle: bundle)
  }
  /// Tag: the position has no broker-side stop.
  static var stopMissing: LocalizedStringResource {
    LocalizedStringResource("kit.stop.missing", defaultValue: "NO STOP", bundle: bundle)
  }
  /// Tag: the stop state could not be read.
  static var stopUnknown: LocalizedStringResource {
    LocalizedStringResource("kit.stop.unknown", defaultValue: "STOP UNKNOWN", bundle: bundle)
  }

  // MARK: Stop states in a sentence (Board.stopStateTitle)

  static var stateVerified: LocalizedStringResource {
    LocalizedStringResource("kit.state.verified", defaultValue: "verified", bundle: bundle)
  }
  static var statePending: LocalizedStringResource {
    LocalizedStringResource("kit.state.pending", defaultValue: "pending", bundle: bundle)
  }
  static var stateMissing: LocalizedStringResource {
    LocalizedStringResource("kit.state.missing", defaultValue: "missing", bundle: bundle)
  }
  static var stateUnknown: LocalizedStringResource {
    LocalizedStringResource("kit.state.unknown", defaultValue: "unknown", bundle: bundle)
  }

  // MARK: Exit reasons (Board.exitReasonTitle)

  static var exitStoppedOut: LocalizedStringResource {
    LocalizedStringResource("kit.exit.stoppedOut", defaultValue: "stopped out", bundle: bundle)
  }
  static var exitStrategy: LocalizedStringResource {
    LocalizedStringResource("kit.exit.strategy", defaultValue: "strategy exit", bundle: bundle)
  }
  static var exitOperator: LocalizedStringResource {
    LocalizedStringResource("kit.exit.operator", defaultValue: "operator exit", bundle: bundle)
  }
  static var exitOperatorFlatten: LocalizedStringResource {
    LocalizedStringResource("kit.exit.operatorFlatten", defaultValue: "closed", bundle: bundle)
  }
  static var exitInterrupted: LocalizedStringResource {
    LocalizedStringResource("kit.exit.interrupted", defaultValue: "interrupted", bundle: bundle)
  }
  static var exitSessionEnd: LocalizedStringResource {
    LocalizedStringResource("kit.exit.sessionEnd", defaultValue: "end-of-day close", bundle: bundle)
  }
  static var exitStreamLost: LocalizedStringResource {
    LocalizedStringResource("kit.exit.streamLost", defaultValue: "quotes lost", bundle: bundle)
  }
  static var exitStopRejected: LocalizedStringResource {
    LocalizedStringResource("kit.exit.stopRejected", defaultValue: "stop rejected", bundle: bundle)
  }
  static var exitUnprotected: LocalizedStringResource {
    LocalizedStringResource("kit.exit.unprotected", defaultValue: "unprotected too long", bundle: bundle)
  }
  static var exitEntryNotFilled: LocalizedStringResource {
    LocalizedStringResource("kit.exit.entryNotFilled", defaultValue: "entry not filled", bundle: bundle)
  }
  static var exitHoldElapsed: LocalizedStringResource {
    LocalizedStringResource("kit.exit.holdElapsed", defaultValue: "hold time over", bundle: bundle)
  }
  static var exitClosed: LocalizedStringResource {
    LocalizedStringResource("kit.exit.closed", defaultValue: "closed", bundle: bundle)
  }

  // MARK: Operator commands

  /// Operator command: stop opening new positions.
  static var commandPauseEntries: LocalizedStringResource {
    LocalizedStringResource("kit.command.pauseEntries", defaultValue: "Pause entries", bundle: bundle)
  }
  /// Operator command: allow new positions again.
  static var commandResumeEntries: LocalizedStringResource {
    LocalizedStringResource("kit.command.resumeEntries", defaultValue: "Resume entries", bundle: bundle)
  }
  /// Operator command: cancel every open order the bot placed.
  static var commandCancelOwnOrders: LocalizedStringResource {
    LocalizedStringResource("kit.command.cancelOwnOrders", defaultValue: "Cancel own orders", bundle: bundle)
  }
  /// Operator command: close every position the bot holds.
  static var commandFlatten: LocalizedStringResource {
    LocalizedStringResource("kit.command.flatten", defaultValue: "Close all", bundle: bundle)
  }
  /// Operator command: stop the bot gracefully; it stays stopped until started again.
  static var commandStopBot: LocalizedStringResource {
    LocalizedStringResource("kit.command.stopBot", defaultValue: "Stop bot", bundle: bundle)
  }
  /// Operator command: entry stop on, cancel own orders and flatten everything at once.
  static var commandEmergency: LocalizedStringResource {
    LocalizedStringResource("kit.command.emergency", defaultValue: "Emergency stop", bundle: bundle)
  }

  // MARK: Headline

  /// Headline before the first answer of the local API.
  static var headlineConnecting: LocalizedStringResource {
    LocalizedStringResource("kit.headline.connecting", defaultValue: "Connecting to the local API…",
      bundle: bundle)
  }
  /// Headline: the bot holds one open position with a verified broker stop, and nothing needs the
  /// operator. Its own key: the catalog's plural forms are not applied everywhere (swift test).
  static var headlineHoldingOne: LocalizedStringResource {
    LocalizedStringResource("kit.headline.holdingOne",
      defaultValue: "Holding 1 position · protected by a broker stop", bundle: bundle)
  }
  /// Headline: the bot holds several open positions, every one with a verified broker stop, and
  /// nothing needs the operator; argument: how many (Russian has plural forms).
  static func headlineHolding(_ count: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.headline.holding",
      defaultValue: "Holding \(count) positions · all protected by broker stops", bundle: bundle)
  }
  /// Headline: entries are allowed.
  static var headlineAllowed: LocalizedStringResource {
    LocalizedStringResource("kit.headline.allowed", defaultValue: "Entries allowed.", bundle: bundle)
  }
  /// Headline: the status is old; argument: its age in whole seconds.
  static func headlineStale(_ seconds: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.headline.stale",
      defaultValue: "Bot status is \(seconds) s old: the bot may be down. Do not trust the rest of this page.",
      bundle: bundle)
  }
  /// Headline: the bot has no status; argument: the API's cause.
  static func headlineUnavailable(_ cause: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.headline.unavailable",
      defaultValue: "Bot status unavailable: \(cause). Entries are not possible.", bundle: bundle)
  }
  /// Headline start; arguments: symbol, stop state. The bot's summary follows the space.
  static func headlineNoVerifiedStop(_ symbol: String, _ state: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.headline.noVerifiedStop",
      defaultValue: "Position \(symbol) has no verified stop (\(state)). ", bundle: bundle)
  }

  // MARK: API errors

  /// Arguments: HTTP status, error code, cause from the bot.
  static func apiRefused(_ status: Int, _ error: String, _ cause: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.api.refused", defaultValue: "API refused (\(status) \(error)): \(cause)",
      bundle: bundle)
  }
  /// Argument: what does not match.
  static func apiContract(_ detail: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.api.contract", defaultValue: "API answer does not match contract v1: \(detail)",
      bundle: bundle)
  }
  /// Argument: the system's network error.
  static func apiUnreachable(_ detail: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.api.unreachable", defaultValue: "Local API not reachable: \(detail)",
      bundle: bundle)
  }
  /// An error that brings no description of its own.
  static var unexpectedError: LocalizedStringResource {
    LocalizedStringResource("kit.error.unexpected", defaultValue: "unexpected error in the app", bundle: bundle)
  }
  /// Contract error detail.
  static var apiNotHTTP: LocalizedStringResource {
    LocalizedStringResource("kit.api.notHTTP", defaultValue: "not an HTTP response", bundle: bundle)
  }
  /// Contract error detail; argument: HTTP status.
  static func apiNoErrorBody(_ status: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.api.noErrorBody", defaultValue: "HTTP \(status) without an error-v1 body",
      bundle: bundle)
  }

  // MARK: Wire format errors

  /// Contract error detail.
  static var expectedDecimal: LocalizedStringResource {
    LocalizedStringResource("kit.wire.expectedDecimal", defaultValue: "expected a decimal string",
      bundle: bundle)
  }
  /// Contract error detail; argument: the value received.
  static func badDecimal(_ text: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.wire.badDecimal", defaultValue: "expected a decimal string, got \"\(text)\"",
      bundle: bundle)
  }
  /// Contract error detail.
  static var expectedTime: LocalizedStringResource {
    LocalizedStringResource("kit.wire.expectedTime", defaultValue: "expected a time string",
      bundle: bundle)
  }
  /// Contract error detail; argument: the value received.
  static func badTime(_ text: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.wire.badTime",
      defaultValue: "expected a UTC time like 2026-01-02T15:04:05.000Z, got \"\(text)\"",
      bundle: bundle)
  }
  /// Contract error detail.
  static var expectedDate: LocalizedStringResource {
    LocalizedStringResource("kit.wire.expectedDate", defaultValue: "expected a date string",
      bundle: bundle)
  }
  /// Contract error detail; argument: the value received.
  static func badDate(_ text: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.wire.badDate", defaultValue: "expected a date like 2026-01-02, got \"\(text)\"",
      bundle: bundle)
  }
  /// Contract error detail.
  static var nullableKeyMissing: LocalizedStringResource {
    LocalizedStringResource("kit.wire.nullableKeyMissing", defaultValue: "nullable key must be present",
      bundle: bundle)
  }
  /// Contract error detail; argument: the field's path ("positions.0.stop").
  static func fieldMissing(_ field: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.wire.fieldMissing", defaultValue: "field \(field) is missing", bundle: bundle)
  }
  /// Contract error detail; argument: the field's path.
  static func fieldNull(_ field: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.wire.fieldNull", defaultValue: "field \(field) is null", bundle: bundle)
  }
  /// Contract error detail; argument: the field's path.
  static func fieldWrongType(_ field: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.wire.fieldWrongType", defaultValue: "field \(field) has the wrong type",
      bundle: bundle)
  }
  /// Contract error detail; argument: the field's path. A value this app cannot read (an unknown case, a number out of range).
  static func fieldUnknownValue(_ field: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.wire.fieldUnknownValue",
      defaultValue: "field \(field) has a value this app cannot read", bundle: bundle)
  }
  /// Contract error detail; arguments: the field's path, what is wrong with its value.
  static func fieldInvalid(_ field: String, _ cause: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.wire.fieldInvalid", defaultValue: "field \(field): \(cause)", bundle: bundle)
  }
  /// Contract error detail: the answer could not be read as JSON at all.
  static var notJSON: LocalizedStringResource {
    LocalizedStringResource("kit.wire.notJSON", defaultValue: "the answer is not valid JSON", bundle: bundle)
  }
  /// Contract error detail: the answer is JSON, but not an object of the kind asked for
  /// (for example a list where one record was expected).
  static var wrongShape: LocalizedStringResource {
    LocalizedStringResource("kit.wire.wrongShape", defaultValue: "the answer has the wrong shape", bundle: bundle)
  }
  /// Contract error detail; arguments: version key, version received, version this app reads.
  static func unsupportedVersion(_ key: String, _ value: Int, _ expected: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.wire.unsupportedVersion",
      defaultValue: "unsupported \(key) \(value), this app reads \(expected)", bundle: bundle)
  }

  // MARK: Environments (ApiText.environment)

  /// Where the bot trades: the broker's test environment.
  static var environmentSandbox: LocalizedStringResource {
    LocalizedStringResource("kit.environment.sandbox", defaultValue: "Sandbox", bundle: bundle)
  }
  /// Where the bot runs: `tickr demo`, a made-up day with no broker.
  static var environmentDemo: LocalizedStringResource {
    LocalizedStringResource("kit.environment.demo", defaultValue: "Demo", bundle: bundle)
  }
  /// Where the bot trades: the real account.
  static var environmentProduction: LocalizedStringResource {
    LocalizedStringResource("kit.environment.production", defaultValue: "Production", bundle: bundle)
  }
  /// The environment badge as VoiceOver reads it, on every screen of both apps: "Environment: Sandbox".
  static func environmentLabel(_ name: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.environment.label", defaultValue: "Environment: \(name)", bundle: bundle)
  }
  /// Where the bot trades, when the bot sends no environment name.
  static var environmentUnknown: LocalizedStringResource {
    LocalizedStringResource("kit.environment.unknown", defaultValue: "Unknown environment", bundle: bundle)
  }

  // MARK: Fences (ApiText.fenceTitle)

  /// A fence of a kind this app does not know; the bot's detail follows it.
  static var fenceOther: LocalizedStringResource {
    LocalizedStringResource("kit.fenceKind.other", defaultValue: "Other block", bundle: bundle)
  }

  // MARK: Codes this app does not know (ApiText)

  /// A broker order's side this app does not know.
  static var orderSideOther: LocalizedStringResource {
    LocalizedStringResource("kit.orderOther.side", defaultValue: "Unknown side", bundle: bundle)
  }
  /// A broker order's type this app does not know.
  static var orderTypeOther: LocalizedStringResource {
    LocalizedStringResource("kit.orderOther.type", defaultValue: "Unknown type", bundle: bundle)
  }
  /// A broker order's status this app does not know.
  static var orderStatusOther: LocalizedStringResource {
    LocalizedStringResource("kit.orderOther.status", defaultValue: "Unknown status", bundle: bundle)
  }
  /// A strategy check whose rule this app does not know (a newer strategy).
  static var ruleOther: LocalizedStringResource {
    LocalizedStringResource("kit.ruleOther", defaultValue: "Other check", bundle: bundle)
  }
}
