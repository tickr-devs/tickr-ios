import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// An operator command as the API accepts it. The bot decides and acts; the API only queues.
public enum OperatorCommand: Hashable, Sendable {
  case entryStop(on: Bool)
  case cancelOwnOrders
  case flatten

  /// API paths of the commands (docs/api.md).
  static let entryStopPath = "/commands/entry-stop"
  static let cancelOwnOrdersPath = "/commands/cancel-own-orders"
  static let flattenPath = "/commands/flatten"
  /// The entry-stop body's key and its two values.
  static let stateKey = "state"
  static let on = "on"
  static let off = "off"

  public var path: String {
    switch self {
    case .entryStop: return Self.entryStopPath
    case .cancelOwnOrders: return Self.cancelOwnOrdersPath
    case .flatten: return Self.flattenPath
    }
  }

  /// Exact JSON body the API requires.
  public var body: [String: String] {
    switch self {
    case .entryStop(let on): return [Self.stateKey: on ? Self.on : Self.off]
    case .cancelOwnOrders, .flatten: return [:]
    }
  }

  public var kind: CommandKind {
    switch self {
    case .entryStop(let on): return on ? .entryStopOn : .entryStopOff
    case .cancelOwnOrders: return .cancelOwnOrders
    case .flatten: return .flatten
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
  /// Query item names of the bars read.
  static let symbolQuery = "symbol"
  static let dateQuery = "date"
  /// HTTP methods, header names and the media type the API speaks.
  static let get = "GET"
  static let post = "POST"
  static let acceptHeader = "accept"
  static let contentTypeHeader = "content-type"
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

  public func pendingCommands() async throws -> PendingCommandsV1 {
    try await perform(request(path: Self.pendingPath, body: nil), expect: Self.ok)
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
  /// `StatusV1.recentCommands` under the returned command id.
  public func send(_ command: OperatorCommand) async throws -> CommandAcceptedV1 {
    let body = try JSONSerialization.data(withJSONObject: command.body, options: [.sortedKeys])
    return try await perform(request(path: command.path, body: body), expect: Self.accepted)
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
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
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
      throw APIError.contract(String(describing: error))
    }
  }
}
