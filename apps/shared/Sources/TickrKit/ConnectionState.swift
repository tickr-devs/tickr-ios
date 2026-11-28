import Foundation

/// Why the last read of /status failed. The apps say it in the same calm words whatever the cause
/// and show this technical detail (address, port, the API's own cause) only on request.
public struct ReadFailure: Equatable, Sendable {
  /// The failure as the API client describes it, in the person's language: for "Details" only.
  public let detail: String
  /// The API answered and refused this app at this address (a Host, Origin or token it does not
  /// accept): a setup mistake that reading again never fixes, unlike a bot that does not answer.
  public let refused: Bool

  /// The API's error codes that refuse the caller itself rather than one read.
  static let refusalCodes: Set<String> = ["forbidden_host", "forbidden_origin", "unauthorized"]

  public init(detail: String, refused: Bool = false) {
    self.detail = detail
    self.refused = refused
  }

  /// The failure of a read, or nil for a cancelled one: whoever cancelled it has moved on, and
  /// the failure seen before stays (`ReadFailure(error) ?? old`).
  public init?(_ error: Error) {
    guard let detail = ErrorText.describe(error) else { return nil }
    self.init(detail: detail, refused: Self.isRefusal(error))
  }

  /// Whether `error` is the API refusing the caller (`refusalCodes`).
  static func isRefusal(_ error: Error) -> Bool {
    guard case .refused(_, let code, _) = error as? APIError else { return false }
    return refusalCodes.contains(code)
  }
}

/// The failures of the /status reads in a row, and the one the apps show. A single read that
/// fails between answered ones (a Wi-Fi hiccup, the API busy for a moment) says nothing about the
/// link, and showing it flashed "Can't reach the bot" over a running bot: the failure is shown
/// once `shownAfter` reads in a row failed, or at once when no read has answered yet. Both apps
/// keep their failure here, so both say the same.
public struct ReadFailures: Equatable, Sendable {
  /// Failed reads in a row before the apps say the bot can't be reached: one more poll (a few
  /// seconds) to tell a hiccup from an outage.
  public static let shownAfter = 2
  /// The failure the apps show, or nil while the link is taken as up.
  public private(set) var shown: ReadFailure?
  /// Reads failed since the last answer.
  public private(set) var inRow = 0

  public init() {}

  /// A read answered: the link is up.
  public mutating func answered() {
    shown = nil
    inRow = 0
  }

  /// A read failed with `error`; `hadAnswer`: an earlier read answered, so there is last known
  /// data to keep showing meanwhile. A cancelled read counts for nothing.
  public mutating func failed(_ error: Error, hadAnswer: Bool) {
    guard let failure = ReadFailure(error) else { return }
    failed(failure, hadAnswer: hadAnswer)
  }

  public mutating func failed(_ failure: ReadFailure, hadAnswer: Bool) {
    inRow += 1
    if !hadAnswer || inRow >= Self.shownAfter { shown = failure }
  }
}

/// What the apps say about their link to the bot's API, from the last /status read. Every screen
/// takes it from here, so all of them say the same: never a screen replaced by an error, but the
/// last known data under a banner that names it as such, or a designed empty state when nothing
/// was ever read.
public enum ConnectionState: Equatable, Sendable {
  /// No address to read from yet (the phone before its first pairing).
  case notConfigured
  /// The first read is on its way: nothing to show, nothing failed.
  case connecting
  /// The last read answered.
  case connected
  /// The API answers, but the bot has written no usable status (`unavailable_cause`).
  case noBotStatus(cause: String)
  /// The last read failed after an earlier one answered at `lastSuccess` (this device's clock):
  /// what the screens show is the last known data.
  case stale(lastSuccess: Date, failure: ReadFailure)
  /// No read has answered since the app opened or the address changed: there is no data.
  case neverConnected(failure: ReadFailure)

  /// The state of a link that is `configured`, whose last read failed with `failure` (nil: it
  /// answered), whose last answer is `response` and whose last good read was at `lastSuccess`.
  public static func make(
    configured: Bool, response: StatusResponseV1?, failure: ReadFailure?, lastSuccess: Date?
  ) -> ConnectionState {
    guard configured else { return .notConfigured }
    if let failure {
      guard let lastSuccess, response != nil else { return .neverConnected(failure: failure) }
      return .stale(lastSuccess: lastSuccess, failure: failure)
    }
    guard let response else { return .connecting }
    guard response.status != nil else {
      return .noBotStatus(cause: response.unavailableCauseText ?? response.summary)
    }
    return .connected
  }

  /// Whether the screens' data is the last known rather than current: commands that need a live
  /// bot stay off, and the banner says so.
  public var isLastKnown: Bool {
    if case .stale = self { return true }
    return false
  }

  /// Whether there is nothing to show yet: the screen's card area shows an empty state.
  public var hasNoData: Bool {
    switch self {
    case .notConfigured, .noBotStatus, .neverConnected: return true
    case .connecting, .connected, .stale: return false
    }
  }

  /// No read has answered and the last one failed: every card has nothing true to show, so it
  /// shows its outline (`ReadFailureContext.noData`), never zeros or "nothing today".
  public var isNeverConnected: Bool {
    if case .neverConnected = self { return true }
    return false
  }

  /// The failure behind the state, if any.
  public var failure: ReadFailure? {
    switch self {
    case .stale(_, let failure), .neverConnected(let failure): return failure
    case .notConfigured, .connecting, .connected, .noBotStatus: return nil
    }
  }

  /// The banner's or empty state's words (the mockup's calm "Can't reach the bot" banner);
  /// `retrySeconds` is how often the app reads again. Nil while the link is fine (or still
  /// connecting).
  public func message(retrySeconds: Int) -> ConnectionMessage? {
    switch self {
    case .connecting, .connected:
      return nil
    case .notConfigured:
      return ConnectionMessage(title: L10n.connectionNotConfiguredTitle, subtitle: L10n.connectionNotConfiguredBody,
        details: nil)
    case .noBotStatus(let cause):
      return ConnectionMessage(title: L10n.connectionNoBotStatusTitle, subtitle: L10n.connectionNoBotStatusBody,
        details: cause)
    case .stale(_, let failure) where failure.refused, .neverConnected(let failure) where failure.refused:
      return ConnectionMessage(title: L10n.connectionRefusedTitle, subtitle: L10n.connectionRefusedBody,
        details: failure.detail, refused: true)
    case .stale(let lastSuccess, let failure):
      return ConnectionMessage(title: L10n.connectionUnreachableTitle,
        subtitle: L10n.connectionLastKnown(Self.time(lastSuccess), retrySeconds), details: failure.detail)
    case .neverConnected(let failure):
      return ConnectionMessage(title: L10n.connectionUnreachableTitle,
        subtitle: L10n.connectionNothingYet(retrySeconds), details: failure.detail)
    }
  }

  /// The clock time of the last good read, to the second ("10:46:12").
  static func time(_ date: Date) -> String {
    ClockText.seconds(date)
  }
}

/// The words of a connection banner or empty state: a short title, one mono line under it, and
/// the technical detail kept for "Details". Calm in every case (no alarm colour): the health dot
/// and the headline already say the bot cannot be trusted, and commands are off.
public struct ConnectionMessage: Equatable, Sendable {
  public let title: LocalizedStringResource
  public let subtitle: LocalizedStringResource
  /// The technical cause (address, port, the API's own words); shown only when asked for.
  public let details: String?
  /// The bot refused this app's address or token (`ReadFailure.refused`): the banner offers the
  /// way to fix the setup rather than another read.
  public let refused: Bool

  init(title: LocalizedStringResource, subtitle: LocalizedStringResource, details: String?, refused: Bool = false) {
    self.title = title
    self.subtitle = subtitle
    self.details = details
    self.refused = refused
  }

  /// Labels of the actions every banner offers.
  public static var retry: LocalizedStringResource { L10n.connectionRetry }
  public static var settings: LocalizedStringResource { L10n.connectionSettings }
  public static var detailsLabel: LocalizedStringResource { L10n.connectionDetails }
  /// A card's calm placeholder while the link is down.
  public static var waiting: LocalizedStringResource { L10n.connectionWaiting }
  /// The details' first line: the address the app reads from.
  public static func address(_ address: String) -> LocalizedStringResource { L10n.connectionAddress(address) }
}
