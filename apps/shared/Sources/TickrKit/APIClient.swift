import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// An operator command as the API accepts it. The bot decides and acts; the API only queues.
public enum OperatorCommand: Hashable, Sendable {
  case entryStop(on: Bool)
  case cancelOwnOrders
  /// Close every position the bot holds.
  case flatten
  /// Close only the bot's position in one symbol.
  case flattenSymbol(String)
  /// Graceful stop that sticks until the owner starts the bot again.
  case stopBot
  /// Entry stop on, cancel own orders, flatten everything.
  case emergency

  /// API paths of the commands (docs/api.md).
  static let entryStopPath = "/commands/entry-stop"
  static let cancelOwnOrdersPath = "/commands/cancel-own-orders"
  static let flattenPath = "/commands/flatten"
  static let stopBotPath = "/commands/stop-bot"
  static let emergencyPath = "/commands/emergency"
  /// The flatten body's key for one symbol.
  static let symbolKey = "symbol"
  /// The entry-stop body's key and its two values.
  static let stateKey = "state"
  static let on = "on"
  static let off = "off"

  public var path: String {
    switch self {
    case .entryStop: return Self.entryStopPath
    case .cancelOwnOrders: return Self.cancelOwnOrdersPath
    case .flatten, .flattenSymbol: return Self.flattenPath
    case .stopBot: return Self.stopBotPath
    case .emergency: return Self.emergencyPath
    }
  }

  /// Exact JSON body the API requires.
  public var body: [String: String] {
    switch self {
    case .entryStop(let on): return [Self.stateKey: on ? Self.on : Self.off]
    case .flattenSymbol(let symbol): return [Self.symbolKey: symbol]
    case .cancelOwnOrders, .flatten, .stopBot, .emergency: return [:]
    }
  }

  public var kind: CommandKind {
    switch self {
    case .entryStop(let on): return on ? .entryStopOn : .entryStopOff
    case .cancelOwnOrders: return .cancelOwnOrders
    case .flatten, .flattenSymbol: return .flatten
    case .stopBot: return .stopBot
    case .emergency: return .emergency
    }
  }
}

public enum APIError: Error, LocalizedError, Equatable {
  /// The API answered with a typed refusal (error-v1).
  case refused(status: Int, error: String, cause: String)
  /// The answer does not match contract v1.
  case contract(String)
  /// The API could not be reached.
  case unreachable(String)

  public var errorDescription: String? {
    switch self {
    case .refused(let status, let error, let cause): return String(localized: L10n.apiRefused(status, error, cause))
    case .contract(let detail): return String(localized: L10n.apiContract(detail))
    case .unreachable(let detail): return String(localized: L10n.apiUnreachable(detail))
    }
  }
}

/// Any error as the apps show it: its own description in the person's language when it has
/// one (APIError, ContractError), a plain "unexpected error" otherwise; never Swift's English
/// debug form of the error.
public enum ErrorText {
  /// What a failed read shows, or nil for a cancelled one: whoever cancelled it has moved on,
  /// so it shows nothing.
  public static func describe(_ error: Error) -> String? {
    error is CancellationError ? nil : text(error)
  }

  /// Always a sentence, for a failure the person must see even when it was cancelled (a
  /// command that may not have been sent).
  public static func text(_ error: Error) -> String {
    (error as? LocalizedError)?.errorDescription ?? String(localized: L10n.unexpectedError)
  }
}

/// Client for the bot's local API. Stateless; safe to share.
public struct APIClient: Sendable {
  /// Where the bot's local API listens by default (config/bot.toml `[api]`); the apps' settings
  /// can point elsewhere.
  public static let defaultBaseURL = URL(string: "http://127.0.0.1:8766")!
  /// HTTP status of a successful read.
  static let ok = 200
  /// HTTP status of a queued command (accepted, not yet executed).
  static let accepted = 202
  /// API paths of the reads (docs/api.md); `daysPath` + "/" + date reads one day.
  static let statusPath = "/status"
  static let pendingPath = "/commands/pending"
  static let settingsPath = "/settings"
  static let daysPath = "/days"
  static let barsPath = "/bars"
  static let accountPath = "/account"
  static let jobsPath = "/jobs"
  static let journalPath = "/journal"
  static let labReplayPath = "/lab/replay"
  /// Remote port only: redeem a pairing link's one-time code for the bearer token.
  static let pairPath = "/pair"
  /// Body key of the pairing code.
  static let codeKey = "code"
  static let observersPath = "/observers"
  static let decisionsPath = "/decisions"
  static let skippedPath = "/skipped"
  static let performancePath = "/performance"
  static let flowPath = "/flow"
  static let watchingPath = "/watching"
  static let chartPath = "/chart"
  /// Query item names of the bars read.
  static let symbolQuery = "symbol"
  static let dateQuery = "date"
  static let fromQuery = "from"
  static let toQuery = "to"
  /// Query item names of the chart read.
  static let intervalQuery = "interval"
  static let rangeQuery = "range"
  /// HTTP methods, header names and the media type the API speaks.
  static let get = "GET"
  static let post = "POST"
  static let acceptHeader = "accept"
  static let contentTypeHeader = "content-type"
  /// HTTP header that makes a repeated command send answer the first send instead of queueing again.
  static let idempotencyKeyHeader = "idempotency-key"
  /// HTTP header that carries the bearer token.
  static let authorizationHeader = "authorization"
  /// Authentication scheme the bot's API expects before the token (RFC 6750).
  static let bearerScheme = "Bearer"
  static let json = "application/json"

  public let baseURL: URL
  private let session: URLSession
  /// Bearer token for a remote address (an HTTPS proxy in front of the API); nil on the Mac.
  private let token: String?

  public init(baseURL: URL = APIClient.defaultBaseURL, token: String? = nil, session: URLSession = .shared) {
    self.baseURL = baseURL
    self.token = token
    self.session = session
  }

  public func status() async throws -> StatusResponseV1 {
    try await perform(request(path: Self.statusPath, body: nil), expect: Self.ok)
  }

  /// The broker's positions and open orders at the bot's last read, and whether they matched
  /// its records.
  public func account() async throws -> AccountResponseV1 {
    try await perform(request(path: Self.accountPath, body: nil), expect: Self.ok)
  }

  /// Every configured observer with its decisions recorded on `day`, oldest first.
  public func observers(day: WireDate) async throws -> ObserversV1 {
    try await perform(request(path: Self.observersPath, query: [(Self.dateQuery, day.text)], body: nil),
      expect: Self.ok)
  }

  /// Every decision recorded for `symbol` on `day` (active strategy and observers), with checks.
  public func decisions(symbol: String, day: WireDate) async throws -> DecisionsV1 {
    try await perform(request(path: Self.decisionsPath, query: [(Self.symbolQuery, symbol), (Self.dateQuery, day.text)],
      body: nil),
      expect: Self.ok)
  }

  /// The active strategy's ENTERs on `day` that did not become a position, oldest first.
  public func skipped(day: WireDate) async throws -> SkippedV1 {
    try await perform(request(path: Self.skippedPath, query: [(Self.dateQuery, day.text)], body: nil),
      expect: Self.ok)
  }

  /// Gross performance in R of the trades closed from `from` to `to`, both inclusive.
  public func performance(from: WireDate, to: WireDate) async throws -> PerformanceV1 {
    try await perform(request(path: Self.performancePath, query: [(Self.fromQuery, from.text), (Self.toQuery, to.text)],
      body: nil), expect: Self.ok)
  }

  /// The day's live flow: screener chips, stage counts, stops and the latest reconciliation.
  public func flow(day: WireDate) async throws -> FlowV1 {
    try await perform(request(path: Self.flowPath, query: [(Self.dateQuery, day.text)], body: nil), expect: Self.ok)
  }

  /// The symbols the strategy is watching closely on `day`, closest to an entry first.
  public func watching(day: WireDate) async throws -> WatchingV1 {
    try await perform(request(path: Self.watchingPath, query: [(Self.dateQuery, day.text)], body: nil), expect: Self.ok)
  }

  /// Candles of any US stock from market data, `interval` long over `range`, oldest first.
  public func chart(symbol: String, interval: Timeframe, range: ChartRange) async throws -> ChartV1 {
    try await perform(request(path: Self.chartPath, query: [(Self.symbolQuery, symbol),
      (Self.intervalQuery, interval.rawValue), (Self.rangeQuery, range.rawValue)], body: nil), expect: Self.ok)
  }

  public func pendingCommands() async throws -> PendingCommandsV1 {
    try await perform(request(path: Self.pendingPath, body: nil), expect: Self.ok)
  }

  /// What runs on its own on the Mac (reconcile, backup, launchd jobs) and today's session times.
  public func jobs() async throws -> JobsV1 {
    try await perform(request(path: Self.jobsPath, body: nil), expect: Self.ok)
  }

  /// The latest rows of the bot's journal with their numbers, newest last.
  public func journal() async throws -> JournalV1 {
    try await perform(request(path: Self.journalPath, body: nil), expect: Self.ok)
  }

  /// The Lab's replay of the current strategy over the recent sessions: idle, running, done with
  /// its summary, or failed with a cause.
  public func labReplay() async throws -> LabReplayV1 {
    try await perform(request(path: Self.labReplayPath, body: nil), expect: Self.ok)
  }

  /// Start a Lab replay. Accepted (202) answers the replay as it now stands; the API refuses a
  /// start while one runs with 409 `conflict`, thrown as `APIError.refused`.
  public func startLabReplay() async throws -> LabReplayV1 {
    let body = try JSONSerialization.data(withJSONObject: [String: String]())
    return try await perform(request(path: Self.labReplayPath, body: body), expect: Self.accepted)
  }

  /// Redeem a pairing link's one-time code at the Mac's HTTPS address for the bearer token the
  /// phone keeps from then on. Sent without a token; the code works once, before it expires, and
  /// a refused code is thrown as `APIError.refused` (401 `unauthorized`).
  public func redeemPairing(code: String) async throws -> PairedV1 {
    let body = try JSONSerialization.data(withJSONObject: [Self.codeKey: code], options: [.sortedKeys])
    return try await perform(request(path: Self.pairPath, body: body), expect: Self.ok)
  }

  /// Risk limits and session times from the bot's config, as the API loaded them.
  public func settings() async throws -> SettingsV1 {
    try await perform(request(path: Self.settingsPath, body: nil), expect: Self.ok)
  }

  /// Every New York date with records, newest first.
  public func days() async throws -> DaysV1 {
    try await perform(request(path: Self.daysPath, body: nil), expect: Self.ok)
  }

  /// Trades closed on `day` and the symbols with captured bars.
  public func day(_ day: WireDate) async throws -> DayV1 {
    try await perform(request(path: "\(Self.daysPath)/\(day.text)", body: nil), expect: Self.ok)
  }

  /// Captured M1 bars of `symbol` on `day`, oldest first.
  public func bars(symbol: String, day: WireDate) async throws -> BarsV1 {
    try await perform(request(path: Self.barsPath, query: [(Self.symbolQuery, symbol), (Self.dateQuery, day.text)],
      body: nil),
      expect: Self.ok)
  }

  /// Queue a command. Success means queued, not executed: its outcome appears later in
  /// `StatusV1.recentCommands` under the returned command id. Sending again with the same
  /// `idempotencyKey` (one per operator action) answers the first send and queues nothing, so an
  /// action whose answer was lost can be sent again safely; the API refuses a key reused for
  /// another command with 409 `conflict`.
  public func send(_ command: OperatorCommand, idempotencyKey: String? = nil) async throws -> CommandAcceptedV1 {
    let body = try JSONSerialization.data(withJSONObject: command.body, options: [.sortedKeys])
    var post = request(path: command.path, body: body)
    if let idempotencyKey {
      post.setValue(idempotencyKey, forHTTPHeaderField: Self.idempotencyKeyHeader)
    }
    return try await perform(post, expect: Self.accepted)
  }

  func request(path: String, query: [(String, String)] = [], body: Data?) -> URLRequest {
    var url = baseURL.appendingPathComponent(String(path.dropFirst()))
    if !query.isEmpty, var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) {
      parts.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
      url = parts.url ?? url
    }
    var request = URLRequest(url: url)
    request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    request.setValue(Self.json, forHTTPHeaderField: Self.acceptHeader)
    if let token {
      request.setValue("\(Self.bearerScheme) \(token)", forHTTPHeaderField: Self.authorizationHeader)
    }
    if let body {
      request.httpMethod = Self.post
      request.setValue(Self.json, forHTTPHeaderField: Self.contentTypeHeader)
      request.httpBody = body
    } else {
      request.httpMethod = Self.get
    }
    return request
  }

  private func perform<T: Decodable>(_ request: URLRequest, expect: Int) async throws -> T {
    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await session.data(for: request)
    } catch {
      // A cancelled request stays a cancellation, so callers can tell it from a failure.
      if error is CancellationError || (error as? URLError)?.code == .cancelled { throw CancellationError() }
      throw APIError.unreachable(error.localizedDescription)
    }
    guard let http = response as? HTTPURLResponse else {
      throw APIError.contract(String(localized: L10n.apiNotHTTP))
    }
    let decoder = Wire.decoder()
    if http.statusCode != expect {
      guard let refusal = try? decoder.decode(ErrorV1.self, from: data) else {
        throw APIError.contract(String(localized: L10n.apiNoErrorBody(http.statusCode)))
      }
      throw APIError.refused(status: http.statusCode, error: refusal.error, cause: refusal.cause)
    }
    do {
      return try decoder.decode(T.self, from: data)
    } catch {
      throw APIError.contract(Wire.detail(error))
    }
  }
}
