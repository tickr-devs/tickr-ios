import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// How the API client gets an answer: over HTTP from the bot's API (`URLSession`), or from the demo
/// day the apps carry (`DemoSource`), which never touches the network.
public protocol APITransport: Sendable {
  /// The answer to `request`: its body and its HTTP response.
  func response(to request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: APITransport {
  public func response(to request: URLRequest) async throws -> (Data, URLResponse) {
    try await data(for: request)
  }
}
