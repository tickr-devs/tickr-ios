import Foundation

/// How alarming the current state is; drives colours and the menu-bar symbol.
public enum Severity: Int, Comparable, Sendable {
  case ok = 0, attention = 1, alarm = 2

  public static func < (a: Severity, b: Severity) -> Bool { a.rawValue < b.rawValue }
}

/// The one line a person reads first, plus its severity. Pure, so iOS and tests share it.
public struct Headline: Equatable, Sendable {
  public let text: String
  public let severity: Severity
  /// What a pulse or transition beside the headline marks: a change of it is a real change of
  /// state. Not `text`: a stale status's text counts its age, which grows with every read of the
  /// same stale status.
  public let pulse: Pulse

  /// The event key of `Headline.pulse`.
  public enum Pulse: Hashable, Sendable {
    /// The headline's words, which change only with the state they describe.
    case text(String)
    /// The status is stale, however old.
    case stale
  }

  /// `pulse` defaults to the text.
  public init(text: String, severity: Severity, pulse: Pulse? = nil) {
    self.text = text
    self.severity = severity
    self.pulse = pulse ?? .text(text)
  }

  /// `fetchError` is the last failure to read /status; it wins over an older good response.
  public static func make(response: StatusResponseV1?, fetchError: String?) -> Headline {
    if let fetchError {
      return Headline(text: String(localized: L10n.headlineFetchFailed(fetchError)), severity: .alarm)
    }
    guard let response else {
      return Headline(text: String(localized: L10n.headlineConnecting), severity: .attention)
    }
    guard let status = response.status, !response.stale else {
      let text = summary(response)
      return Headline(text: text, severity: .alarm, pulse: response.stale ? .stale : .text(text))
    }
    if let position = status.positions.first(where: { $0.stop.state != .verified }) {
      return Headline(
        text: String(localized: L10n.headlineNoVerifiedStop(position.symbol, Board.stopStateTitle(position.stop.state)))
          + summary(response),
        severity: .alarm)
    }
    // An ordinary refusal (a trade is open, outside the entry window) is calm; only a block that
    // needs the operator is attention.
    return Headline(text: summary(response), severity: status.entryBlock?.attention == true ? .attention : .ok)
  }

  /// The bot's one-line summary in the person's language, built from the status as the bot builds
  /// its English `summary` (contract.summarize): the status's absence, its age, the entry block,
  /// or that entries are allowed.
  static func summary(_ response: StatusResponseV1) -> String {
    guard let status = response.status else {
      return String(localized: L10n.headlineUnavailable(response.unavailableCause ?? response.summary))
    }
    if response.stale {
      let seconds = response.ageSeconds.map { NSDecimalNumber(decimal: $0.value).intValue }
      return seconds.map { String(localized: L10n.headlineStale($0)) } ?? response.summary
    }
    if let block = status.entryBlock { return ApiText.entryBlock(block) }
    return String(localized: L10n.headlineAllowed)
  }
}

public enum Display {
  /// Short local time, for tables.
  public static func time(_ time: WireTime?) -> String {
    guard let time else { return "—" }
    return time.date.formatted(date: .omitted, time: .standard)
  }

  /// The currency code shown after money amounts.
  static let currencyCode = "USD"

  public static func usd(_ value: DecimalString) -> String { "\(value.text) \(currencyCode)" }

  public static func commandTitle(_ kind: CommandKind) -> String {
    switch kind {
    case .entryStopOn: return String(localized: L10n.commandEntryStopOn)
    case .entryStopOff: return String(localized: L10n.commandEntryStopOff)
    case .cancelOwnOrders: return String(localized: L10n.commandCancelOwnOrders)
    case .flatten: return String(localized: L10n.commandFlatten)
    case .stopBot: return String(localized: L10n.commandStopBot)
    case .emergency: return String(localized: L10n.commandEmergency)
    }
  }
}
