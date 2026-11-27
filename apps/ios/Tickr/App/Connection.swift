import Foundation
import TickrKit

/// Where the phone reaches the bot, and this phone's token for it. The address is the bot's own
/// (TickrKit `BotAddress`), built into the app: nothing to type, no link to open. The token comes
/// from signing in with the owner's tickr.bot account (`SignIn`), lives in the Keychain only, and
/// goes to the address it was issued by and nowhere else.
/// Two addresses replace the bot's for development, never in a build the owner runs by hand:
/// `addressKey` given as a launch argument (UI tests point the app at a recorded API), and in a
/// Simulator build the file `pair-simulator` left on the Mac (`SimulatorToken`).
/// The "Demo day" switch (`demo`) never changes the address or the token: on, the app talks to the
/// demo day it carries (TickrKit `DemoDay.address`, answered from its recording, never the
/// network); off, it is back on the address.
struct Connection: Equatable {
  /// UserDefaults key of an address that replaces the bot's (a launch argument of UI tests).
  static let addressKey = "apiBaseURL"
  /// UserDefaults key of the address the saved token was issued by.
  static let tokenAddressKey = "apiTokenAddress"
  /// UserDefaults keys the pairing kept (the address typed in Settings and the paired address);
  /// a phone that paired before has them, and they are deleted on the first launch.
  static let pairingKeys = ["apiPairedAddress"]
  /// UserDefaults key of the "Demo day" switch.
  static let demoKey = "demoDay"
  /// The scheme a token is sent over to another machine.
  static let remoteScheme = "https"
  /// Plain HTTP, and the hosts that are this machine: a token may go to them over it (the Simulator reading
  /// the phone's listener on the Mac), since that traffic never leaves the machine.
  static let localScheme = "http"
  static let loopbackHosts: Set<String> = ["127.0.0.1", "localhost", "::1"]

  let address: URL
  var token: String?
  /// The "Demo day" switch: the demo day the app carries, and only that day.
  var demo: Bool

  init(address: URL = BotAddress.url, token: String? = nil, demo: Bool = false) {
    self.address = address
    self.token = token
    self.demo = demo
  }

  /// Whether this phone holds a token for the address.
  var signedIn: Bool { token != nil }

  /// The address the app talks to: the demo day while the switch is on, else the bot's once this
  /// phone is signed in; nil until then, so nothing is read and Settings offers the sign-in. A
  /// development address needs no sign-in.
  var url: URL? {
    if demo { return DemoDay.address }
    return signedIn || address != BotAddress.url ? address : nil
  }

  /// The same connection with the demo day on or off; the address and token are kept as they are.
  func demo(_ on: Bool) -> Connection {
    Connection(address: address, token: token, demo: on)
  }

  /// The same connection with `token` (a sign-in), or without one (a sign-out).
  func token(_ token: String?) -> Connection {
    Connection(address: address, token: token, demo: demo)
  }

  /// The token, for the address the app talks to now.
  var bearer: String? { url.flatMap(bearer(for:)) }

  /// The token for a request to `url`: only to the address's origin, and only over HTTPS (or, in
  /// a Simulator build, over HTTP to this machine).
  func bearer(for url: URL) -> String? {
    guard Self.carriesToken(url), let token, Self.origin(url) == Self.origin(address) else { return nil }
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
  static func origin(_ url: URL) -> String? {
    guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
      let scheme = parts.scheme?.lowercased(), let host = parts.host?.lowercased() else { return nil }
    var origin = URLComponents()
    origin.scheme = scheme
    origin.host = host
    origin.port = parts.port
    return origin.string
  }

  /// The connection this launch starts with: the bot's address and the token saved for it, unless
  /// a development address replaces it (see the type's note).
  static func load(_ defaults: UserDefaults = .standard, keychain: Keychain = Container.shared.keychain()) -> Connection {
    let demo = defaults.bool(forKey: demoKey)
    if let text = defaults.string(forKey: addressKey), let url = URL(string: text), url.host != nil {
      return Connection(address: url, demo: demo)
    }
    #if targetEnvironment(simulator)
    // The Simulator's own token and the address it opens (`pair-simulator`), read from the Mac
    // at every launch: the Simulator reads the bot on this Mac without signing in.
    if let simulator = SimulatorToken.read(), let url = URL(string: simulator.address) {
      return Connection(address: url, token: simulator.token, demo: demo)
    }
    #endif
    for key in pairingKeys { defaults.removeObject(forKey: key) }
    // A token is kept only for the address it was issued by: a token the pairing left (issued by
    // the Mac, no address saved with it) is deleted, never sent to the bot's address.
    guard defaults.string(forKey: tokenAddressKey).flatMap(URL.init(string:)).flatMap(origin) == origin(BotAddress.url)
    else {
      keychain.deleteToken()
      defaults.removeObject(forKey: tokenAddressKey)
      return Connection(demo: demo)
    }
    return Connection(token: keychain.readToken(), demo: demo)
  }

  /// Stores the demo switch and the token. The token is deleted only when this connection has none
  /// to keep (a sign-out); a write the Keychain refuses (a locked phone) leaves the earlier token as
  /// it was. A development address saves nothing but the demo switch.
  func save(_ defaults: UserDefaults = .standard, keychain: Keychain = Container.shared.keychain()) {
    defaults.set(demo, forKey: Self.demoKey)
    guard address == BotAddress.url else { return }
    guard let token else {
      keychain.deleteToken()
      defaults.removeObject(forKey: Self.tokenAddressKey)
      return
    }
    // The address is written only when the token really is in the Keychain.
    if keychain.saveToken(token) {
      defaults.set(address.absoluteString, forKey: Self.tokenAddressKey)
    }
  }
}

/// The Simulator's own token, from the file `python -m tickr.api pair-simulator` left on the Mac
/// (JSON: the address it opens, made from bot.toml's [api] host and remote_port, and the token).
/// Its path is Info.plist's `TickrSimulatorTokenFile`, set for Simulator builds only. The token is
/// never logged.
struct SimulatorToken: Decodable, Equatable {
  /// Info.plist key of the file's path (`TICKR_SIMULATOR_TOKEN_FILE` in Local.xcconfig).
  static let fileKey = "TickrSimulatorTokenFile"

  let address: String
  let token: String

  /// The token in the file the build names, or nil without a readable, complete one.
  static func read(_ bundle: Bundle = .main) -> SimulatorToken? {
    guard let path = bundle.object(forInfoDictionaryKey: fileKey) as? String, !path.isEmpty,
      let data = FileManager.default.contents(atPath: path) else { return nil }
    return decode(data)
  }

  /// The token in `data`, or nil when it is not one: a missing field or an empty value.
  static func decode(_ data: Data) -> SimulatorToken? {
    guard let simulator = try? JSONDecoder().decode(SimulatorToken.self, from: data),
      !simulator.token.isEmpty, URL(string: simulator.address)?.host != nil else { return nil }
    return simulator
  }
}
