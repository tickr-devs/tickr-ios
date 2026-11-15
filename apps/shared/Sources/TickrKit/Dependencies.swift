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

  /// Client of the bot's local API at an address; a remote address adds its bearer token.
  public var apiClient: ParameterFactory<APIClient.Endpoint, APIClient> {
    self { endpoint in APIClient(baseURL: endpoint.baseURL, token: endpoint.token, session: self.urlSession()) }
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
