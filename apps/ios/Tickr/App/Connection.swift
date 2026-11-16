import Foundation
import TickrKit

/// Where the phone finds the bot's local API, and the paired token for a remote (HTTPS) address.
/// The address is in UserDefaults, the token in the Keychain; both stay on this phone. The token
/// belongs to the address it was paired with (`pairedAddress`) and is sent nowhere else.
/// The "Demo day" switch (`demo`) never changes the address or the token: on, the app talks to the
/// demo day it carries (TickrKit `DemoDay.address`, answered from its recording, never the
/// network), so it works without an address, away from the Mac; off, it is back on the address.
struct Connection: Equatable {
  /// UserDefaults key of the saved address.
  static let defaultsKey = "apiBaseURL"
  /// UserDefaults key of the address the token was paired with.
  static let pairedKey = "apiPairedAddress"
  /// UserDefaults key of the "Demo day" switch.
  static let demoKey = "demoDay"
  /// URL schemes the bot's local API answers on.
  static let schemes: Set<String> = ["http", "https"]
  /// The only scheme a token is ever sent over.
  static let remoteScheme = "https"
  /// The API's loopback address, which the Simulator reaches because it shares the Mac's network.
  static let simulatorAddress = "http://127.0.0.1:8766"

  var address: String
  var token: String?
  /// The exact address from the pairing link the token came with.
  var pairedAddress: String?
  /// The "Demo day" switch: the demo day the app carries, and only that day.
  var demo: Bool

  init(address: String, token: String? = nil, pairedAddress: String? = nil, demo: Bool = false) {
    self.address = address
    self.token = token
    self.pairedAddress = pairedAddress
    self.demo = demo
  }

  /// A connection to the Mac at `url`, with the token its pairing code bought. Replaces any
  /// earlier pairing.
  init(paired url: URL, token: String) {
    self.init(address: url.absoluteString, token: token, pairedAddress: url.absoluteString)
  }

  var isRemote: Bool { url?.scheme?.lowercased() == Self.remoteScheme }

  /// The address the app talks to: the demo day while the switch is on (whatever the address),
  /// else the bot's address; nil when that is empty or not an http(s) URL.
  var url: URL? {
    if demo { return DemoDay.address }
    let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
      Self.schemes.contains(scheme), url.host != nil else { return nil }
    return url
  }

  /// The same connection with the demo day on or off; the address and token are kept as they are.
  func demo(_ on: Bool) -> Connection {
    Connection(address: address, token: token, pairedAddress: pairedAddress, demo: on)
  }

  /// The token, only when the current address is HTTPS and has the paired address's origin.
  var bearer: String? { url.flatMap(bearer(for:)) }

  /// The token for a request to `url`: only over HTTPS and only to the paired origin.
  func bearer(for url: URL) -> String? {
    guard url.scheme?.lowercased() == Self.remoteScheme, let token, let pairedAddress,
      let paired = Self.origin(pairedAddress), paired == Self.origin(url.absoluteString) else { return nil }
    return token
  }

  /// What the API client needs for a request to `url`, with the token only where it may go.
  func endpoint(for url: URL) -> APIClient.Endpoint {
    APIClient.Endpoint(baseURL: url, token: bearer(for: url))
  }

  /// Scheme, host and port, lowercased; what decides where the token may go.
  static func origin(_ address: String) -> String? {
    guard let parts = URLComponents(string: address.trimmingCharacters(in: .whitespacesAndNewlines)),
      let scheme = parts.scheme?.lowercased(), let host = parts.host?.lowercased() else { return nil }
    var origin = URLComponents()
    origin.scheme = scheme
    origin.host = host
    origin.port = parts.port
    return origin.string
  }

  /// Host and, when it is not the scheme's default, port: what the owner confirms when pairing.
  static func displayHost(_ url: URL) -> String? {
    guard let host = url.host else { return nil }
    return url.port.map { "\(host):\($0)" } ?? host
  }

  /// Keeps the token only while `address` has the paired origin; any other address drops it, so
  /// the token is never sent to a host it was not paired with.
  func moved(to address: String) -> Connection {
    let samePairing = pairedAddress.flatMap(Self.origin) == Self.origin(address)
    return samePairing ? Connection(address: address, token: token, pairedAddress: pairedAddress, demo: demo)
      : Connection(address: address, demo: demo)
  }

  static func load(_ defaults: UserDefaults = .standard) -> Connection {
    if let saved = defaults.string(forKey: defaultsKey) {
      return Connection(address: saved, token: Container.shared.keychain().readToken(),
        pairedAddress: defaults.string(forKey: pairedKey), demo: defaults.bool(forKey: demoKey))
    }
    #if targetEnvironment(simulator)
    return Connection(address: simulatorAddress, demo: defaults.bool(forKey: demoKey))
    #else
    return Connection(address: "", demo: defaults.bool(forKey: demoKey))
    #endif
  }

  func save(_ defaults: UserDefaults = .standard) {
    defaults.set(address, forKey: Self.defaultsKey)
    defaults.set(demo, forKey: Self.demoKey)
    let keychain = Container.shared.keychain()
    // The paired address is kept only when the token really is in the Keychain.
    if let token, let pairedAddress, keychain.saveToken(token) {
      defaults.set(pairedAddress, forKey: Self.pairedKey)
    } else {
      keychain.deleteToken()
      defaults.removeObject(forKey: Self.pairedKey)
    }
  }
}
