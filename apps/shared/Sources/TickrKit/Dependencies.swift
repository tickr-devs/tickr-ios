// The apps resolve services through Factory (hmlongco/Factory). Importing TickrKit brings
// FactoryKit with it, so every target uses the same container and the same @Injected.
@_exported import FactoryKit
import Foundation

/// Services shared by the operator apps. A model asks the container for what it needs
/// (`@ObservationIgnored @Injected(\.now) private var now`, `Container.shared.apiClient(url)`)
/// instead of building it; tests replace a registration under `@Suite(.container)`.
extension Container {
  /// HTTP session of the API client. Tests register one with a stub URLProtocol.
  public var urlSession: Factory<URLSession> {
    self { .shared }
  }

  /// Client of the bot's local API at an address; a remote address adds its bearer token. The
  /// demo day's address (`DemoDay.address`) is answered by the recording the apps carry
  /// (`demoSource`), never by the network.
  public var apiClient: ParameterFactory<APIClient.Endpoint, APIClient> {
    self { endpoint in
      DemoDay.isDemo(endpoint.baseURL)
        ? APIClient(baseURL: endpoint.baseURL, transport: self.demoSource())
        : APIClient(baseURL: endpoint.baseURL, token: endpoint.token, transport: self.urlSession())
    }
  }

  /// The demo day the apps carry (`DemoDay.jsonl`, `tickr demo --record`), playing in a loop
  /// from the moment it is first asked for. One per app run, so every screen sees the same frame.
  public var demoSource: Factory<DemoSource> {
    self {
      let now = self.now()
      let recording = Result { try DemoRecording.bundled() }
        .mapError { $0 as? APIError ?? .contract(Wire.detail($0)) }
      return DemoSource(recording: recording, started: now(), now: now)
    }.cached
  }

  /// The app's command keys, one store for every model that sends commands (`CommandKeyStore`).
  /// Tests get a fresh one under `@Suite(.container)`.
  @MainActor
  public var commandKeys: Factory<CommandKeyStore> {
    self { CommandKeyStore() }.cached
  }

  /// The bot's live quotes as last read (GET /quotes): one per app run, so every screen shows the
  /// same price for one symbol at one moment. The app model reads it every second.
  @MainActor
  public var liveQuotes: Factory<LiveQuotes> {
    self { LiveQuotes() }.cached
  }

  /// The current moment. Tests pin it.
  public var now: Factory<@Sendable () -> Date> {
    self { { Date() } }
  }
}

extension APIClient {
  /// Where to reach the API: its address and, for a remote address, the pairing token.
  public struct Endpoint: Hashable, Sendable {
    public let baseURL: URL
    public let token: String?

    public init(baseURL: URL, token: String? = nil) {
      self.baseURL = baseURL
      self.token = token
    }
  }
}
