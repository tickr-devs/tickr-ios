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
  /// The scheme a token is sent over to another machine.
  static let remoteScheme = "https"
  /// Plain HTTP, and the hosts that are this machine: a token may go to them over it (the Simulator reading
  /// the phone's listener on the Mac), since that traffic never leaves the machine.
  static let localScheme = "http"
  static let loopbackHosts: Set<String> = ["127.0.0.1", "localhost", "::1"]

  /// Info.plist key of the address the build starts with (`TICKR_API_ADDRESS` in
  /// Config/Signing.xcconfig: the phone listener on loopback for the Simulator, this Mac's
  /// Tailscale name for an iPhone).
  static let builtAddressKey = "TickrAPIAddress"
  /// The address field's example when the build names none.
  static let exampleAddress = "https://mac.tailnet.ts.net"
  /// The address field's example: the address this build starts with, else `exampleAddress`.
  static var addressExample: String {
    let built = builtAddress()
    return built.isEmpty ? exampleAddress : built
  }

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
    guard Self.carriesToken(url), let token, let pairedAddress,
      let paired = Self.origin(pairedAddress), paired == Self.origin(url.absoluteString) else { return nil }
    return token
  }

  /// Whether a token may go over plain HTTP to this machine: in a Simulator build only (its own
  /// token to the phone's listener on the Mac); an iPhone build sends a token over HTTPS only.
  #if targetEnvironment(simulator)
  static let carriesOverLoopback = true
  #else
  static let carriesOverLoopback = false
  #endif

  /// Whether a token may travel to `url`: over HTTPS, or in a Simulator build over HTTP to this
  /// machine only.
  static func carriesToken(_ url: URL) -> Bool {
    switch url.scheme?.lowercased() {
    case remoteScheme: true
    case localScheme: carriesOverLoopback && (url.host.map { loopbackHosts.contains($0.lowercased()) } ?? false)
    default: false
    }
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
    // The Simulator's own token and the address it opens (`pair-simulator`), read from the Mac
    // at every launch: no pairing by hand for a new Simulator, the phone's token never touched.
    if let pairing = SimulatorPairing.read() {
      return Connection(address: pairing.address, token: pairing.token, pairedAddress: pairing.address,
        demo: defaults.bool(forKey: demoKey))
    }
    #endif
    return Connection(address: builtAddress(), demo: defaults.bool(forKey: demoKey))
  }

  /// The address this build starts with (`builtAddressKey`), or "" when it names no host (an
  /// iPhone build without TICKR_TAILSCALE_HOST): Settings then asks for one.
  static func builtAddress(_ bundle: Bundle = .main) -> String {
    guard let address = bundle.object(forInfoDictionaryKey: builtAddressKey) as? String,
      URL(string: address)?.host?.isEmpty == false else { return "" }
    return address
  }

  /// Stores the address, the demo switch and the pairing. The token and its paired address are
  /// deleted only when this connection has no token to keep; a write the Keychain refuses (a
  /// locked phone) leaves the earlier token and paired address as they were, never deletes them.
  func save(_ defaults: UserDefaults = .standard, keychain: Keychain = Container.shared.keychain()) {
    defaults.set(address, forKey: Self.defaultsKey)
    defaults.set(demo, forKey: Self.demoKey)
    guard let token, let pairedAddress else {
      keychain.deleteToken()
      defaults.removeObject(forKey: Self.pairedKey)
      return
    }
    // The paired address is written only when the token really is in the Keychain.
    if keychain.saveToken(token) {
      defaults.set(pairedAddress, forKey: Self.pairedKey)
    }
  }
}

/// The Simulator's own pairing, from the file `python -m tickr.api pair-simulator` left on the Mac
/// (JSON: the address it opens, made from bot.toml's [api] host and remote_port, and the token).
/// Its path is Info.plist's `TickrSimulatorTokenFile`, set for Simulator builds only. The token is
/// never logged.
struct SimulatorPairing: Decodable, Equatable {
  /// Info.plist key of the file's path (`TICKR_SIMULATOR_TOKEN_FILE` in Local.xcconfig).
  static let fileKey = "TickrSimulatorTokenFile"

  let address: String
  let token: String

  /// The pairing in the file the build names, or nil without a readable, complete one.
  static func read(_ bundle: Bundle = .main) -> SimulatorPairing? {
    guard let path = bundle.object(forInfoDictionaryKey: fileKey) as? String, !path.isEmpty,
      let data = FileManager.default.contents(atPath: path) else { return nil }
    return decode(data)
  }

  /// The pairing in `data`, or nil when it is not one: a missing field or an empty value.
  static func decode(_ data: Data) -> SimulatorPairing? {
    guard let pairing = try? JSONDecoder().decode(SimulatorPairing.self, from: data),
      !pairing.token.isEmpty, URL(string: pairing.address)?.host != nil else { return nil }
    return pairing
  }
}
