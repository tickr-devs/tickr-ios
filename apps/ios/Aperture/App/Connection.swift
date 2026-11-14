import Foundation

/// Where the phone finds the bot's local API. Stored on the phone only.
struct Connection: Equatable {
  /// UserDefaults key of the saved address.
  static let defaultsKey = "apiBaseURL"
  /// URL schemes the bot's local API answers on.
  static let schemes: Set<String> = ["http", "https"]
  /// The API's loopback address, which the Simulator reaches because it shares the Mac's network.
  static let simulatorAddress = "http://127.0.0.1:8766"

  var address: String

  /// The address as a URL, or nil when it is empty or not an http(s) URL.
  var url: URL? {
    let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
      Self.schemes.contains(scheme), url.host != nil else { return nil }
    return url
  }

  static func load(_ defaults: UserDefaults = .standard) -> Connection {
    if let saved = defaults.string(forKey: defaultsKey) { return Connection(address: saved) }
    #if targetEnvironment(simulator)
    return Connection(address: simulatorAddress)
    #else
    return Connection(address: "")
    #endif
  }

  func save(_ defaults: UserDefaults = .standard) {
    defaults.set(address, forKey: Self.defaultsKey)
  }
}
