#if DEBUG
import ApertureKit
import Foundation

/// Xcode previews of the screens with realistic data and no running bot: the API client's
/// URLSession is replaced (through Factory) by one that answers every read from the repository's
/// contract fixtures (tests/api/fixtures). Debug builds only.
enum PreviewAPI {
  /// Environment variable that makes the app read the fixtures instead of a running bot (the UI
  /// tests set it; debug builds only). Not a launch argument: AppKit takes an unknown argument for
  /// a file to open and then opens no main window.
  static let fixturesKey = "APERTURE_FIXTURES"
  /// Size of a previewed main-window screen, in points.
  static let windowWidth: CGFloat = 1280
  static let windowHeight: CGFloat = 820

  /// Whether the app was launched with `fixturesKey` set, so it shows fixture data.
  static var servesFixtures: Bool {
    ProcessInfo.processInfo.environment[fixturesKey] != nil
  }

  /// Serve the API from the fixtures when the app was launched with `fixturesKey` set.
  static func serveFixturesIfAsked() {
    guard servesFixtures else { return }
    Container.shared.urlSession.register { FixtureProtocol.session() }
  }

  /// The app model as the screens see it, reading the fixtures.
  @MainActor
  static func model() -> AppModel {
    Container.shared.urlSession.register { FixtureProtocol.session() }
    let model = AppModel(baseURL: APIClient.defaultBaseURL)
    model.start()
    return model
  }

  /// The decisions fixture, as the Chart's inspector shows it.
  static func decisions() -> DecisionsV1? {
    let url = FixtureProtocol.folder.appendingPathComponent(FixtureProtocol.decisionsFile)
    guard let data = try? Data(contentsOf: url) else { return nil }
    return try? Wire.decoder().decode(DecisionsV1.self, from: data)
  }
}

/// Answers each API read with its fixture file; anything else is a 404.
final class FixtureProtocol: URLProtocol {
  /// The fixtures folder, found from this file's place in the repository.
  static let folder = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // Previews
    .deletingLastPathComponent()  // Aperture
    .deletingLastPathComponent()  // macos
    .deletingLastPathComponent()  // apps
    .deletingLastPathComponent()  // repository root
    .appendingPathComponent(fixturesPath)
  /// Where the contract fixtures live, from the repository root.
  static let fixturesPath = "tests/api/fixtures"
  /// API paths and the fixture each answers with (docs/api.md).
  static let statusPath = "/status"
  static let statusFile = "status-response-v1.json"
  static let settingsPath = "/settings"
  static let settingsFile = "settings-v1.json"
  static let daysPath = "/days"
  static let daysFile = "days-v1.json"
  static let dayFile = "day-v1.json"
  static let barsPath = "/bars"
  static let barsFile = "bars-v1.json"
  static let pendingPath = "/commands/pending"
  static let pendingFile = "pending-commands-v1.json"
  static let accountPath = "/account"
  static let accountFile = "account-response-v1.json"
  static let observersPath = "/observers"
  static let observersFile = "observers-v1.json"
  static let decisionsPath = "/decisions"
  static let decisionsFile = "decisions-v1.json"
  static let skippedPath = "/skipped"
  static let skippedFile = "skipped-v1.json"
  static let performancePath = "/performance"
  static let performanceFile = "performance-v1.json"
  static let flowPath = "/flow"
  static let flowFile = "flow-v1.json"
  static let watchingPath = "/watching"
  static let watchingFile = "watching-v1.json"
  static let jobsPath = "/jobs"
  static let jobsFile = "jobs-v1.json"
  static let labReplayPath = "/lab/replay"
  static let labReplayFile = "lab-replay-v1.json"
  /// HTTP status codes, version and the JSON content type of an answer.
  static let ok = 200
  static let notFound = 404
  static let httpVersion = "HTTP/1.1"
  static let contentTypeHeader = "Content-Type"
  static let json = "application/json"

  /// A session whose every request is answered from the fixtures.
  static func session() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [FixtureProtocol.self]
    return URLSession(configuration: configuration)
  }

  /// The fixture for an API path, nil for a path the previews do not serve.
  static func file(for path: String) -> String? {
    switch path {
    case statusPath: return statusFile
    case settingsPath: return settingsFile
    case daysPath: return daysFile
    case barsPath: return barsFile
    case pendingPath: return pendingFile
    case accountPath: return accountFile
    case observersPath: return observersFile
    case decisionsPath: return decisionsFile
    case skippedPath: return skippedFile
    case performancePath: return performanceFile
    case flowPath: return flowFile
    case watchingPath: return watchingFile
    case jobsPath: return jobsFile
    case labReplayPath: return labReplayFile
    default: return path.hasPrefix(daysPath + "/") ? dayFile : nil
    }
  }

  override static func canInit(with request: URLRequest) -> Bool { true }
  override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let url = request.url else {
      client?.urlProtocol(self, didFailWithError: URLError(.badURL))
      return
    }
    let data = Self.file(for: url.path()).flatMap { try? Data(contentsOf: Self.folder.appendingPathComponent($0)) }
    let code = data == nil ? Self.notFound : Self.ok
    if let response = HTTPURLResponse(url: url, statusCode: code, httpVersion: Self.httpVersion,
      headerFields: [Self.contentTypeHeader: Self.json]) {
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    }
    client?.urlProtocol(self, didLoad: data ?? Data())
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}
#endif
