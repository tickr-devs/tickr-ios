import Foundation

/// GET /commands/receipt: what the POST /commands/* with one Idempotency-Key was answered, read
/// without queuing anything. `queued` false (`accepted` nil): no command was queued with the key.
public struct CommandReceiptV1: Codable, Hashable, Sendable {
  public let queued: Bool
  public let accepted: CommandAcceptedV1?
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case queued, accepted
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    queued = try c.decode(Bool.self, forKey: .queued)
    accepted = try c.decodeNullable(CommandAcceptedV1.self, forKey: .accepted)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(apiVersion, forKey: .apiVersion)
    try c.encode(queued, forKey: .queued)
    try c.encodeNullable(accepted, forKey: .accepted)
  }
}

extension APIClient {
  /// API path of the receipt of an Idempotency-Key (docs/api.md).
  static let receiptPath = "/commands/receipt"

  /// What the send with `idempotencyKey` was answered, read without queuing anything: how a send
  /// whose answer was lost learns whether its command was queued (`CommandSend.receipt`). An API
  /// older than receipts answers `APIError.notServed`.
  public func commandReceipt(idempotencyKey: String) async throws -> CommandReceiptV1 {
    var get = request(path: Self.receiptPath, body: nil)
    get.setValue(idempotencyKey, forHTTPHeaderField: Self.idempotencyKeyHeader)
    return try await perform(get, expect: Self.ok)
  }
}

/// What became of one send of an operator command: the API queued it, the API refused it (nothing
/// was queued), or its answer was lost, so whether it was queued is not known yet.
public enum CommandSendOutcome: Sendable, Equatable {
  case queued(CommandAcceptedV1)
  /// The API's cause in the person's language, without its status or error code.
  case refused(String)
  /// Why the answer is missing (no connection, timeout, an answer this app cannot read).
  case unknown(String)
}

/// What the API's receipt of a key says about a send whose answer was lost.
public enum ReceiptOutcome: Sendable, Equatable {
  case queued(CommandAcceptedV1)
  /// No command was queued with the key: the send never reached the API's queue.
  case notQueued
  /// The API serves no receipts (older than them): the outcome can never be read, so the key goes.
  case unserved
  /// Still not known: the receipt could not be read this time.
  case unknown(String)
}

/// The idempotency keys of operator commands (backlog A3): one key per operator decision, kept
/// while that send's outcome is unknown, so pressing the same command again re-sends under the
/// same key and the API answers the first send instead of queuing a second command. A key goes
/// once the outcome is known (queued, refused, or not queued by the receipt), once the receipt
/// can never be read, and once it is older than the age past which the bot refuses a command
/// (`SettingsV1.commandMaxAgeSeconds`): past that age the first send can no longer act, so a
/// press is a new decision and must not be answered with the first send's old result.
public struct CommandKeys: Sendable, Equatable {
  /// The key of a send whose outcome is unknown, and when that send was made.
  public struct Kept: Sendable, Equatable {
    public let key: String
    public let since: Date
  }

  /// Commands whose send has an unknown outcome, with the key that send used.
  public private(set) var unknown: [OperatorCommand: Kept] = [:]

  public init() {}

  /// The key for a send of `command` at `now`: the key of its send still unknown while younger
  /// than `keepSeconds`, else `fresh()`. No `keepSeconds` (an API that does not say) keeps none.
  public func key(
    for command: OperatorCommand, now: Date, keepSeconds: Decimal?, fresh: () -> String = { UUID().uuidString }
  ) -> String {
    guard let kept = unknown[command], Self.young(kept, now: now, keepSeconds: keepSeconds) else { return fresh() }
    return kept.key
  }

  /// `command`'s send under `key`, made at `at`, lost its answer: the key stays until the outcome
  /// is known or it grows too old.
  public mutating func lost(_ command: OperatorCommand, key: String, at: Date) {
    unknown[command] = Kept(key: key, since: at)
  }

  /// `command`'s outcome is known, or can no longer be: its next send is a new decision with a new key.
  public mutating func settled(_ command: OperatorCommand) {
    unknown[command] = nil
  }

  /// Drops every key older than `keepSeconds` at `now` (all of them without `keepSeconds`) and
  /// returns their commands, whose outcome the app can then only learn from the status.
  public mutating func expire(now: Date, keepSeconds: Decimal?) -> [OperatorCommand] {
    let old = unknown.filter { !Self.young($0.value, now: now, keepSeconds: keepSeconds) }.map { $0.key }
    for command in old { unknown[command] = nil }
    return old
  }

  /// Another server: keys of the one before mean nothing there.
  public mutating func clear() {
    unknown = [:]
  }

  private static func young(_ kept: Kept, now: Date, keepSeconds: Decimal?) -> Bool {
    guard let keepSeconds else { return false }
    return now.timeIntervalSince(kept.since) < NSDecimalNumber(decimal: keepSeconds).doubleValue
  }
}

/// The one place an app keeps its command keys (`CommandKeys`), shared by every model that sends
/// commands. On iPad the iPhone screens (compact width) and the Mac screens (regular width) each
/// have a model, and the person can switch between them by resizing the window: a send lost in
/// one layout and pressed again in the other must re-send under the same key, never a new one
/// (hard rule 3: one send per decision). The keys belong to one server: pointing at another one
/// (`use(_:)`) drops them.
@MainActor
public final class CommandKeyStore {
  /// The keys of sends whose outcome is unknown, on `server`.
  public var keys = CommandKeys()
  /// The server the keys were made for; nil before the first send.
  public private(set) var server: URL?
  /// Commands being sent now, by any model: a second press of one in the other layout while its
  /// first send has no answer yet would go out under a new key (the first is not lost yet), so it
  /// is refused instead (Fable on #847, 2026-11-26).
  public private(set) var sending: Set<OperatorCommand> = []

  public init() {}

  /// Starts a send of `command`; false while another send of it is under way.
  public func begin(_ command: OperatorCommand) -> Bool {
    sending.insert(command).inserted
  }

  /// The send of `command` has its outcome (or never went out).
  public func end(_ command: OperatorCommand) {
    sending.remove(command)
  }

  /// The models now talk to `server`: keys made for another server mean nothing there and go.
  /// The same server again keeps them, so a second model joining it never forgets a lost send.
  /// A send under way stays marked until it ends. Both models follow the one connection; a demo
  /// day in one model alone would drop the real server's keys, which the iPad does not offer (its
  /// settings are the iPhone screens').
  public func use(_ server: URL) {
    guard server != self.server else { return }
    keys.clear()
    self.server = server
  }
}

/// Sends an operator command and reads a lost send's receipt, the same way in both apps.
public enum CommandSend {
  /// The first HTTP status of a server error. The API refuses with a 4xx before it queues
  /// anything, but a 5xx can come after the command file was written (`internal` while storing
  /// the key), so a 5xx proves nothing about the queue.
  static let serverErrorFloor = 500

  /// Sends `command` once under `key`.
  public static func send(_ command: OperatorCommand, key: String, client: APIClient) async -> CommandSendOutcome {
    do {
      return .queued(try await client.send(command, idempotencyKey: key))
    } catch {
      return outcome(of: error)
    }
  }

  /// What a failed send says: a 4xx refusal queued nothing; anything else (no answer, a timeout, a
  /// cancelled request, a 5xx, an answer this app cannot read) leaves the outcome unknown.
  static func outcome(of error: Error) -> CommandSendOutcome {
    if case .refused(let status, _, let cause) = error as? APIError, status < serverErrorFloor {
      return .refused(cause)
    }
    return .unknown(ErrorText.text(error))
  }

  /// Reads whether the send under `key` was queued; an API without receipts says `unserved`, and
  /// any other failure keeps it unknown.
  public static func receipt(key: String, client: APIClient) async -> ReceiptOutcome {
    do {
      let receipt = try await client.commandReceipt(idempotencyKey: key)
      if receipt.queued, let accepted = receipt.accepted { return .queued(accepted) }
      return receipt.queued ? .unknown(String(localized: L10n.apiUnreadable)) : .notQueued
    } catch APIError.notServed {
      return .unserved
    } catch {
      return .unknown(ErrorText.text(error))
    }
  }
}
