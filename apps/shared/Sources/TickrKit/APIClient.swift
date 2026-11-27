import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// An operator command as the API accepts it. The bot decides and acts; the API only queues.
public enum OperatorCommand: Hashable, Sendable {
  case entryStop(on: Bool)
  case cancelOwnOrders
  /// Cancel only the bot's working entry order in one symbol (nothing filled yet). The bot
  /// refuses it when that symbol has no working entry.
  case cancelEntry(String)
  /// Close every position the bot holds.
  case flatten
  /// Close only the bot's position in one symbol.
  case flattenSymbol(String)
  /// Graceful stop that sticks until the owner starts the bot again; refused while a trade is open.
  case stopBot
  /// The same stop with what to do with the open positions (backlog V4): close them first, or
  /// leave them open under their broker stops.
  case stopBotMode(StopMode)
  /// Entry stop on, cancel own orders, flatten everything.
  case emergency

  /// API paths of the commands (docs/api.md).
  static let entryStopPath = "/commands/entry-stop"
  static let cancelOwnOrdersPath = "/commands/cancel-own-orders"
  static let flattenPath = "/commands/flatten"
  static let stopBotPath = "/commands/stop-bot"
  static let emergencyPath = "/commands/emergency"
  /// The flatten and cancel-own-orders bodies' key for one symbol.
  static let symbolKey = "symbol"
  /// The stop-bot body's key for its mode.
  static let modeKey = "mode"
  /// The entry-stop body's key and its two values.
  static let stateKey = "state"
  static let on = "on"
  static let off = "off"

  public var path: String {
    switch self {
    case .entryStop: return Self.entryStopPath
    case .cancelOwnOrders, .cancelEntry: return Self.cancelOwnOrdersPath
    case .flatten, .flattenSymbol: return Self.flattenPath
    case .stopBot, .stopBotMode: return Self.stopBotPath
    case .emergency: return Self.emergencyPath
    }
  }

  /// Exact JSON body the API requires.
  public var body: [String: String] {
    switch self {
    case .entryStop(let on): return [Self.stateKey: on ? Self.on : Self.off]
    case .flattenSymbol(let symbol), .cancelEntry(let symbol): return [Self.symbolKey: symbol]
    case .stopBotMode(let mode): return [Self.modeKey: mode.rawValue]
    case .cancelOwnOrders, .flatten, .stopBot, .emergency: return [:]
    }
  }

  public var kind: CommandKind {
    switch self {
    case .entryStop(let on): return on ? .entryStopOn : .entryStopOff
    case .cancelOwnOrders, .cancelEntry: return .cancelOwnOrders
    case .flatten, .flattenSymbol: return .flatten
    case .stopBot, .stopBotMode: return .stopBot
    case .emergency: return .emergency
    }
  }
}

/// Client for the bot's local API. Stateless; safe to share.
public struct APIClient: Sendable {
  /// Where the bot's local API listens by default (config/bot.toml `[api]`); the apps' settings
  /// can point elsewhere.
  public static let defaultBaseURL = URL(string: "http://127.0.0.1:8766")!
  /// HTTP status of a successful read.
  static let ok = 200
  /// HTTP status and error-v1 `error` of a read the API has no answer for (docs/api.md).
  static let notFound = 404
  static let notFoundError = "not_found"
  /// HTTP status of a queued command (accepted, not yet executed).
  static let accepted = 202
  /// API paths of the reads (docs/api.md); `daysPath` + "/" + date reads one day.
  static let statusPath = "/status"
  static let pendingPath = "/commands/pending"
  static let settingsPath = "/settings"
  static let configPath = "/config"
  static let daysPath = "/days"
  static let barsPath = "/bars"
  static let accountPath = "/account"
  static let quotesPath = "/quotes"
  static let jobsPath = "/jobs"
  static let systemPath = "/system"
  static let journalPath = "/journal"
  static let eventsPath = "/events"
  static let labReplayPath = "/lab/replay"
  static let startBotPath = "/commands/start-bot"
  /// Body keys of a Lab replay start: the folder to replay, the one to compare it with, the day.
  static let labVersionKey = "version"
  static let labCompareKey = "compare"
  static let labDayKey = "day"
  static let tradeWhatIfPath = "/trades/whatif"
  /// Query item name of the strategy folder another-version reads replay.
  static let versionQuery = "version"
  /// Remote port only: POST signs this device in with a tickr.bot grant, DELETE signs it out.
  static let sessionPath = "/session"
  /// Where a signed-in device trades its refresh token for a new pair (no bearer token).
  static let refreshPath = "/session/refresh"
  /// The refresh body's key.
  static let refreshTokenKey = "refresh_token"
  /// Body keys of a sign-in: the grant and the device's name in the bot's device list.
  static let grantKey = "grant"
  static let nameKey = "name"
  /// HTTP status of a sign-out (no body).
  static let noContent = 204
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
  static let delete = "DELETE"
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
  private let transport: any APITransport
  /// Bearer token for a remote address (an HTTPS proxy in front of the API); nil on the Mac.
  private let token: String?
  /// The signed-in device's tokens (`BotSession`): each request carries its current access token,
  /// renewed first when it has run out. Nil for a fixed `token` or none.
  private let session: BotSession?

  public init(
    baseURL: URL = APIClient.defaultBaseURL, token: String? = nil, session: BotSession? = nil,
    transport: any APITransport = URLSession.shared
  ) {
    self.baseURL = baseURL
    self.token = token
    self.session = session
    self.transport = transport
  }

  public func status() async throws -> StatusResponseV1 {
    try await perform(request(path: Self.statusPath, body: nil), expect: Self.ok)
  }

  /// The broker's positions and open orders at the bot's last read, and whether they matched
  /// its records.
  public func account() async throws -> AccountResponseV1 {
    try await perform(request(path: Self.accountPath, body: nil), expect: Self.ok)
  }

  /// The newest quote of every symbol on the bot's quote stream (display only).
  public func quotes() async throws -> QuotesResponseV1 {
    try await perform(request(path: Self.quotesPath, body: nil), expect: Self.ok)
  }

  /// Every decision recorded for `symbol` on `day`, with checks (a shadow strategy's marked
  /// `observer`).
  public func decisions(symbol: String, day: WireDate) async throws -> DecisionsV1 {
    try await perform(request(path: Self.decisionsPath, query: [(Self.symbolQuery, symbol), (Self.dateQuery, day.text)],
      body: nil),
      expect: Self.ok)
  }

  /// What the bot did on `day`, as events a person reads, oldest first.
  public func events(day: WireDate) async throws -> DayEventsV1 {
    try await perform(request(path: Self.eventsPath, query: [(Self.dateQuery, day.text)], body: nil),
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

  /// The System card: the Webull link, the latest preflight, training and the Mac's services.
  public func system() async throws -> SystemV1 {
    try await perform(request(path: Self.systemPath, body: nil), expect: Self.ok)
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

  /// Start a Lab replay of strategy folder `version` (the active one when nil), then of
  /// `compare` over the same window, over the last sessions or over `day` only. Accepted (202)
  /// answers the replay as it now stands; the API refuses a start while one runs, or a choice it
  /// does not offer, with 409 `conflict`, thrown as `APIError.refused`.
  public func startLabReplay(
    version: String? = nil, compare: String? = nil, day: WireDate? = nil
  ) async throws -> LabReplayV1 {
    var fields: [String: String] = [:]
    fields[Self.labVersionKey] = version
    fields[Self.labCompareKey] = compare
    fields[Self.labDayKey] = day?.text
    let body = try JSONSerialization.data(withJSONObject: fields)
    return try await perform(request(path: Self.labReplayPath, body: body), expect: Self.accepted)
  }

  /// Risk limits and session times from the bot's config, as the API loaded them.
  public func settings() async throws -> SettingsV1 {
    try await perform(request(path: Self.settingsPath, body: nil), expect: Self.ok)
  }

  /// The bot's configuration file as it is on disk now, read-only, and whether it loads.
  public func config() async throws -> ConfigV1 {
    try await perform(request(path: Self.configPath, body: nil), expect: Self.ok)
  }

  /// Every New York date with records, newest first.
  public func days() async throws -> DaysV1 {
    try await perform(request(path: Self.daysPath, body: nil), expect: Self.ok)
  }

  /// Trades closed on `day` and the symbols with captured bars.
  public func day(_ day: WireDate) async throws -> DayV1 {
    try await perform(request(path: "\(Self.daysPath)/\(day.text)", body: nil), expect: Self.ok)
  }

  /// What strategy folder `version` would have done on `symbol`'s day (simulated, read-only).
  /// The API refuses it during the regular session with 409 `conflict`, thrown as
  /// `APIError.refused`.
  public func tradeWhatIf(symbol: String, day: WireDate, version: String) async throws -> TradeWhatIfV1 {
    try await perform(
      request(path: Self.tradeWhatIfPath,
        query: [(Self.dateQuery, day.text), (Self.symbolQuery, symbol), (Self.versionQuery, version)],
        body: nil),
      expect: Self.ok)
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

  /// Start the bot job through launchd on the Mac (never inside the API). Accepted (202) means
  /// launchd took the start; the bot's preflight may still refuse, so follow the status. The API
  /// refuses while the bot is alive with 409 `conflict`, and answers 503 `unavailable` where no
  /// start command is configured or it failed; both throw `APIError.refused`.
  public func startBot() async throws -> BotStartV1 {
    let body = try JSONSerialization.data(withJSONObject: [String: String]())
    return try await perform(request(path: Self.startBotPath, body: body), expect: Self.accepted)
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

  /// Whether a refusal says the bot has no route for this read: 404 `not_found` on a GET. The one
  /// GET the bot answers 404 for a missing record (no decision recorded for a symbol and day,
  /// `decisionsPath`) stays a refusal with its cause; the demo day answers 404 for every read its
  /// recording does not hold, that one included.
  static func notServed(_ request: URLRequest, status: Int, error: String, demo: Bool) -> Bool {
    guard status == notFound, error == notFoundError, request.httpMethod == get, let url = request.url else {
      return false
    }
    return demo || !url.path.hasSuffix(decisionsPath)
  }

  func perform<T: Decodable>(_ request: URLRequest, expect: Int) async throws -> T {
    var request = request
    if let session {
      request.setValue("\(Self.bearerScheme) \(try await session.accessToken())",
        forHTTPHeaderField: Self.authorizationHeader)
    }
    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await transport.response(to: request)
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
      let demo = DemoDay.isDemo(baseURL)
      if Self.notServed(request, status: http.statusCode, error: refusal.error, demo: demo) {
        throw APIError.notServed(demo: demo)
      }
      // The cause in the person's language, so no screen shows the bot's raw words for a known code.
      throw APIError.refused(status: http.statusCode, error: refusal.error, cause: refusal.causeText)
    }
    if T.self == Empty.self, let empty = Empty() as? T { return empty }
    do {
      return try decoder.decode(T.self, from: data)
    } catch {
      throw APIError.unreadable(Wire.detail(error))
    }
  }
}

/// The answer of a request whose success has no body (204).
struct Empty: Decodable {}
