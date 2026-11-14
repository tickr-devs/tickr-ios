import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// An operator command as the API accepts it. The bot decides and acts; the API only queues.
public enum OperatorCommand: Hashable, Sendable {
  case entryStop(on: Bool)
  case cancelOwnOrders
  case flatten

  public var path: String {
    switch self {
    case .entryStop: return "/commands/entry-stop"
    case .cancelOwnOrders: return "/commands/cancel-own-orders"
    case .flatten: return "/commands/flatten"
    }
  }

  /// Exact JSON body the API requires.
  public var body: [String: String] {
    switch self {
    case .entryStop(let on): return ["state": on ? "on" : "off"]
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
    case .refused(let status, let error, let cause): return "API refused (\(status) \(error)): \(cause)"
    case .contract(let detail): return "API answer does not match contract v1: \(detail)"
    case .unreachable(let detail): return "Local API not reachable: \(detail)"
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

  public let baseURL: URL
  private let session: URLSession

  public init(baseURL: URL = APIClient.defaultBaseURL, session: URLSession = .shared) {
    self.baseURL = baseURL
    self.session = session
  }

  public func status() async throws -> StatusResponseV1 {
    try await perform(request(path: "/status", body: nil), expect: Self.ok)
  }

  public func pendingCommands() async throws -> PendingCommandsV1 {
    try await perform(request(path: "/commands/pending", body: nil), expect: Self.ok)
  }

  /// Risk limits and session times from the bot's config, as the API loaded them.
  public func settings() async throws -> SettingsV1 {
    try await perform(request(path: "/settings", body: nil), expect: Self.ok)
  }

  /// Every New York date with records, newest first.
  public func days() async throws -> DaysV1 {
    try await perform(request(path: "/days", body: nil), expect: Self.ok)
  }

  /// Trades closed on `day` and the symbols with captured bars.
  public func day(_ day: WireDate) async throws -> DayV1 {
    try await perform(request(path: "/days/\(day.text)", body: nil), expect: Self.ok)
  }

  /// Captured M1 bars of `symbol` on `day`, oldest first.
  public func bars(symbol: String, day: WireDate) async throws -> BarsV1 {
    try await perform(request(path: "/bars", query: [("symbol", symbol), ("date", day.text)], body: nil),
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
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if let body {
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = body
    } else {
      request.httpMethod = "GET"
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
      throw APIError.contract("not an HTTP response")
    }
    let decoder = Wire.decoder()
    if http.statusCode != expect {
      guard let refusal = try? decoder.decode(ErrorV1.self, from: data) else {
        throw APIError.contract("HTTP \(http.statusCode) without an error-v1 body")
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
