import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Synchronization

/// The demo day the apps carry: every answer the demo's API gave while the real bot ran the
/// scenario on the simulated exchange (`tickr demo --record`, docs/demo.md), kept in TickrKit's
/// resources as `DemoDay.jsonl.xz`.
///
/// Layout (written by src/tickr/demo/record.py), xz-compressed: line 1 is the index, every
/// further line one piece. The index names, per route (path and sorted query), its change points
/// over the recorded cycle: [frame, HTTP status, op, op, …], each op a pair: (start, size) copies
/// those bytes of the route's previous answer, (-1, piece) inserts a piece; the first change
/// point inserts its whole answer. A POST, keyed by path and sorted JSON body, is [HTTP status,
/// piece, outcome piece]: the API's answer and, for a command, the bot's record of what it did
/// with it (-1: none).
public struct DemoRecording: Sendable {
  /// File name and extension of the recording in the bundle.
  static let resourceName = "DemoDay.jsonl"
  static let resourceExtension = "xz"
  /// Layout version this code reads (record.py FORMAT).
  static let format = 1
  /// Fields of a route's change point before its ops (frame, HTTP status), and of one op.
  static let pointHead = 2
  static let opFields = 2
  /// The first field of an op that inserts a piece (record.py INSERT).
  static let insert = -1
  /// Fields of a POST: HTTP status, piece, outcome piece.
  static let postFields = 3
  /// The outcome piece of a POST without one (record.py NONE).
  static let none = -1
  /// The line separator of the file (ASCII newline, protocol constant).
  static let newline = UInt8(ascii: "\n")

  struct Index: Decodable, Sendable {
    let format: Int
    let inputs: String
    let demoDay: String
    let frameSeconds: Int
    let frames: Int
    let routes: [String: [[Int]]]
    let posts: [String: [Int]]

    enum CodingKeys: String, CodingKey {
      case format, inputs, frames, routes, posts
      case demoDay = "demo_day"
      case frameSeconds = "frame_seconds"
    }
  }

  /// One change point of a route: its answer from the one before, op by op.
  struct Point: Sendable {
    let frame: Int
    let status: Int
    let ops: [Edit]
  }

  enum Edit: Sendable {
    /// Bytes of the route's previous answer.
    case copy(Range<Int>)
    /// A piece of the file.
    case insert(Int)
  }

  /// One recorded POST: the API's answer and, for a command, the bot's record of its outcome.
  struct Post: Sendable {
    let status: Int
    let piece: Int
    let outcome: Int?
  }

  /// The recorded demo day's New York date.
  public let demoDay: String
  /// Seconds between two recorded frames (the API's poll_seconds).
  public let frameSeconds: Int
  /// Frames in the recorded cycle; the clock wraps after the last.
  public let frames: Int
  /// Digest of the recording's inputs (config/demo.toml, the demo code, the API contract, the
  /// strategies); a test on the Python side checks it is current.
  public let inputs: String
  let routes: [String: [Point]]
  let posts: [String: Post]
  let pieces: [Data]

  /// The recording shipped in TickrKit.
  public static func bundled() throws -> DemoRecording {
    guard let url = Bundle.module.url(forResource: resourceName, withExtension: resourceExtension) else {
      throw APIError.contract(String(localized: L10n.demoMissing))
    }
    let compressed = try Data(contentsOf: url)
    return try DemoRecording(data: (compressed as NSData).decompressed(using: .lzma) as Data)
  }

  /// A recording from its uncompressed bytes.
  public init(data: Data) throws {
    let lines = data.split(separator: Self.newline, omittingEmptySubsequences: false)
    guard let first = lines.first else { throw APIError.contract(String(localized: L10n.demoMissing)) }
    let index = try JSONDecoder().decode(Index.self, from: Data(first))
    let refused = APIError.contract(String(localized: L10n.demoFormat(index.format)))
    guard index.format == Self.format, index.frames > 0, index.frameSeconds > 0 else { throw refused }
    let pieces = lines.dropFirst().map { Data($0) }
    func valid(_ piece: Int) -> Bool { pieces.indices.contains(piece) }
    var routes: [String: [Point]] = [:]
    for (key, raw) in index.routes {
      routes[key] = try raw.map { fields in
        let opFields = fields.dropFirst(Self.pointHead)
        guard fields.count >= Self.pointHead, opFields.count.isMultiple(of: Self.opFields) else { throw refused }
        let ops = try stride(from: opFields.startIndex, to: opFields.endIndex, by: Self.opFields).map { at in
          let (first, second) = (fields[at], fields[at + 1])
          if first == Self.insert {
            guard valid(second) else { throw refused }
            return Edit.insert(second)
          }
          guard first >= 0, second >= 0 else { throw refused }
          return Edit.copy(first..<(first + second))
        }
        return Point(frame: fields[0], status: fields[1], ops: ops)
      }
    }
    var posts: [String: Post] = [:]
    for (key, fields) in index.posts {
      guard fields.count == Self.postFields, valid(fields[1]), fields[2] == Self.none || valid(fields[2]) else {
        throw refused
      }
      posts[key] = Post(status: fields[0], piece: fields[1], outcome: fields[2] == Self.none ? nil : fields[2])
    }
    self.pieces = pieces
    self.routes = routes
    self.posts = posts
    demoDay = index.demoDay
    frameSeconds = index.frameSeconds
    frames = index.frames
    inputs = index.inputs
  }

  /// Every recorded GET route (path and sorted query).
  public var routeKeys: [String] { routes.keys.sorted() }

  /// Every recorded POST (path and sorted body).
  public var postKeys: [String] { posts.keys.sorted() }

  /// The answer to GET `route` at `frame` (status and body), nil for a route never recorded.
  public func answer(route: String, frame: Int) -> (status: Int, body: Data)? {
    guard let points = routes[route], let first = points.first else { return nil }
    let shown = points.prefix { $0.frame <= frame || $0.frame == first.frame }
    var body = Data()
    for point in shown { body = apply(point, to: body) }
    return (shown.last?.status ?? first.status, body)
  }

  /// A change point's answer, from the answer before it.
  private func apply(_ point: Point, to body: Data) -> Data {
    var next = Data()
    for op in point.ops {
      switch op {
      case .copy(let range): next.append(body.subdata(in: range.clamped(to: 0..<body.count)))
      case .insert(let piece): next.append(pieces[piece])
      }
    }
    return next
  }

  /// Every answer `route` gives over the cycle, at the frame it starts at, oldest first (empty
  /// for a route never recorded).
  public func changes(route: String) -> [(frame: Int, status: Int, body: Data)] {
    var body = Data()
    return (routes[route] ?? []).map { point in
      body = apply(point, to: body)
      return (point.frame, point.status, body)
    }
  }

  /// The recorded answer to POST `key` and the bot's record of its outcome, nil when the POST
  /// was not recorded.
  public func post(_ key: String) -> (status: Int, body: Data, outcome: Data?)? {
    posts[key].map { ($0.status, pieces[$0.piece], $0.outcome.map { pieces[$0] }) }
  }
}

/// Answers the API client from the demo day's recording on a looping clock: frame
/// `(now - started) / frameSeconds`, wrapping after the last frame. Nothing goes to the network.
/// A GET is answered with the frame's recorded answer; a read the recording does not hold is 404
/// `not_found`. A POST (a command, Start, a Lab replay, an advisor note) is answered as the demo's
/// API answered it, and nothing is sent or queued anywhere. A command the bot acted on when it
/// was recorded gets a fresh id, and the bot's recorded outcome of it, under that id and at the
/// frame's time, joins the recent commands of every later status, as the bot's own would.
public struct DemoSource: APITransport {
  /// HTTP details of every answer (protocol constants).
  static let accepted = 202
  static let notFound = 404
  static let notFoundError = "not_found"
  static let httpVersion = "HTTP/1.1"
  static let contentTypeHeader = "Content-Type"
  static let json = "application/json"
  static let post = "POST"
  /// Separator of a POST key's path and body (record.py `post_key`).
  static let postSeparator = " "
  /// The body a POST is looked up with when its own was not recorded: none.
  static let emptyBody = "{}"
  /// The status route, whose recent commands get the outcomes of the commands sent here.
  static let statusRoute = "/status"
  /// Keys of the documents the outcomes are written into (docs/api.md).
  enum Key {
    /// Wire keys (docs/api.md), protocol constants.
    static let error = "error"
    static let cause = "cause"
    static let version = "api_version"
    static let command = "command"
    static let commandID = "command_id"
    static let requestedAt = "requested_at"
    static let processedAt = "processed_at"
    static let servedAt = "served_at"
    static let status = "status"
    static let recentCommands = "recent_commands"
  }

  private let recording: Result<DemoRecording, APIError>
  private let started: Date
  private let now: @Sendable () -> Date
  /// Outcomes of the commands sent here, newest first (command-record documents).
  private let sent: Sent

  /// The commands sent on this demo day: shared by every copy of the source.
  final class Sent: Sendable {
    let records = Mutex<[Data]>([])
  }

  /// Plays `recording` from its first frame at `started`, on the clock `now`.
  public init(recording: Result<DemoRecording, APIError>, started: Date, now: @escaping @Sendable () -> Date) {
    self.recording = recording
    self.started = started
    self.now = now
    sent = Sent()
  }

  /// The frame shown at `date`: whole frames since `started`, wrapped to the recorded cycle.
  public static func frame(at date: Date, started: Date, frameSeconds: Int, frames: Int) -> Int {
    let elapsed = max(date.timeIntervalSince(started), 0)
    return Int(elapsed / Double(frameSeconds)) % frames
  }

  /// The key a GET is recorded under: the path after the demo address, then its query items
  /// sorted by name (record.py `route`).
  public static func route(of url: URL) -> String {
    let parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
    let path = parts?.percentEncodedPath ?? url.path
    let items = (parts?.queryItems ?? []).sorted { $0.name < $1.name }
    guard !items.isEmpty else { return path }
    var query = URLComponents()
    query.queryItems = items
    return path + "?" + (query.percentEncodedQuery ?? "")
  }

  /// The key a POST is recorded under: its path and its JSON body with sorted keys.
  static func postKey(path: String, body: Data?) -> String {
    let sorted = body.flatMap { try? JSONSerialization.jsonObject(with: $0) }
      .flatMap { try? JSONSerialization.data(withJSONObject: $0, options: [.sortedKeys]) }
      .flatMap { String(data: $0, encoding: .utf8) } ?? emptyBody
    return path + postSeparator + sorted
  }

  public func response(to request: URLRequest) async throws -> (Data, URLResponse) {
    let recording = try recording.get()
    guard let url = request.url else { throw APIError.contract(String(localized: L10n.apiNotHTTP)) }
    let frame = Self.frame(at: now(), started: started, frameSeconds: recording.frameSeconds,
      frames: recording.frames)
    let route = Self.route(of: url)
    let answer: (status: Int, body: Data)?
    if request.httpMethod == Self.post {
      let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? url.path
      let recorded = recording.post(Self.postKey(path: path, body: request.httpBody))
        ?? recording.post(path + Self.postSeparator + Self.emptyBody)
      answer = recorded.map { command($0, at: recording.answer(route: Self.statusRoute, frame: frame)?.body) }
    } else {
      answer = recording.answer(route: route, frame: frame).map { found in
        route == Self.statusRoute ? (found.status, withSentCommands(found.body)) : found
      }
    }
    let (status, body) = answer ?? (Self.notFound, Self.notRecorded(url))
    guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: Self.httpVersion,
      headerFields: [Self.contentTypeHeader: Self.json]) else {
      throw APIError.contract(String(localized: L10n.apiNotHTTP))
    }
    return (body, response)
  }

  /// A recorded POST's answer. A command the bot acted on gets a fresh id (each send is its own),
  /// and its recorded outcome is kept under that id, at the time of `status` (the frame's).
  private func command(_ recorded: (status: Int, body: Data, outcome: Data?), at status: Data?)
    -> (status: Int, body: Data) {
    guard recorded.status == Self.accepted, let outcome = recorded.outcome,
      var answer = Self.object(recorded.body), var command = answer[Self.Key.command] as? [String: Any],
      var record = Self.object(outcome),
      let servedAt = status.flatMap(Self.object)?[Self.Key.servedAt] else {
      return (recorded.status, recorded.body)
    }
    let id = UUID().uuidString
    command[Self.Key.commandID] = id
    answer[Self.Key.command] = command
    record[Self.Key.commandID] = id
    record[Self.Key.requestedAt] = servedAt
    record[Self.Key.processedAt] = servedAt
    guard let body = try? JSONSerialization.data(withJSONObject: answer),
      let kept = try? JSONSerialization.data(withJSONObject: record) else { return (recorded.status, recorded.body) }
    sent.records.withLock { $0.insert(kept, at: 0) }
    return (recorded.status, body)
  }

  /// A status answer with the outcomes of the commands sent here first among its recent
  /// commands, as many in all as the bot lists (the oldest recorded ones make room).
  private func withSentCommands(_ body: Data) -> Data {
    let records = sent.records.withLock { $0 }.compactMap { try? JSONSerialization.jsonObject(with: $0) }
    guard !records.isEmpty, var document = Self.object(body),
      var status = document[Self.Key.status] as? [String: Any],
      let recent = status[Self.Key.recentCommands] as? [Any] else { return body }
    let all = records + recent
    status[Self.Key.recentCommands] = recent.isEmpty ? all : Array(all.prefix(recent.count))
    document[Self.Key.status] = status
    return (try? JSONSerialization.data(withJSONObject: document)) ?? body
  }

  private static func object(_ data: Data) -> [String: Any]? {
    (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
  }

  /// The error-v1 answer of a route the recording does not hold.
  static func notRecorded(_ url: URL) -> Data {
    let document: [String: Any] = [
      Key.error: notFoundError, Key.cause: String(localized: L10n.demoNotRecorded(url.path)),
      Key.version: Wire.apiVersion,
    ]
    return (try? JSONSerialization.data(withJSONObject: document, options: [.sortedKeys])) ?? Data()
  }
}
