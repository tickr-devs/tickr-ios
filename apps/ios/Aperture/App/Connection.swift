import Foundation

/// Where the phone finds the bot's local API. Stored on the phone only.
struct Connection: Equatable {
  static let defaultsKey = "apiBaseURL"

  var address: String

  /// The address as a URL, or nil when it is empty or not an http(s) URL.
  var url: URL? {
    let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
      scheme == "http" || scheme == "https", url.host != nil else { return nil }
    return url
  }

  static func load(_ defaults: UserDefaults = .standard) -> Connection {
    if let saved = defaults.string(forKey: defaultsKey) { return Connection(address: saved) }
    #if targetEnvironment(simulator)
    // The Simulator shares the Mac's network, so the API's loopback address works as is.
    return Connection(address: "http://127.0.0.1:8766")
    #else
    return Connection(address: "")
    #endif
  }

  func save(_ defaults: UserDefaults = .standard) {
    defaults.set(address, forKey: Self.defaultsKey)
  }
}
