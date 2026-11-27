import Foundation
import TickrKit

/// Where the phone reaches the bot, and how it proves itself there. The address is the bot's own
/// (TickrKit `BotAddress`), built into the app: nothing to type, no link to open. The phone signs
/// in with the owner's tickr.bot account (`SignInScreen`); the bot's tokens live in the Keychain
/// (`BotSession`) and go to the bot's address only, over HTTPS.
/// Two addresses replace the bot's for development, never in a build the owner runs by hand:
/// `addressKey` given as a launch argument (UI tests point the app at a recorded API), and in a
/// Simulator build the file `pair-simulator` left on the Mac (`SimulatorToken`), whose fixed token
/// needs no sign-in.
/// The "Demo day" switch (`demo`) never changes the address or the sign-in: on, the app talks to the
/// demo day it carries (TickrKit `DemoDay.address`, answered from its recording, never the
/// network); off, it is back on the address.
struct Connection: Equatable {
  /// UserDefaults key of an address that replaces the bot's (a launch argument of UI tests).
  static let addressKey = "apiBaseURL"
  /// UserDefaults keys the pairing and the web sign-in kept; a phone that had them loses them at
  /// the first launch of the native sign-in.
  static let retiredKeys = ["apiPairedAddress", "apiTokenAddress"]
  /// UserDefaults key of the "Demo day" switch.
  static let demoKey = "demoDay"
  /// The scheme a token is sent over to another machine.
  static let remoteScheme = "https"
  /// Plain HTTP, and the hosts that are this machine: a token may go to them over it (the Simulator reading
  /// the phone's listener on the Mac), since that traffic never leaves the machine.
  static let localScheme = "http"
  static let loopbackHosts: Set<String> = ["127.0.0.1", "localhost", "::1"]

  let address: URL
  /// The Simulator's own token (`SimulatorToken`); nil on a phone.
  var simulatorToken: String?
  /// Whether this phone is signed in with the bot (`SignInState`).
  var signedIn: Bool
  /// The "Demo day" switch: the demo day the app carries, and only that day.
  var demo: Bool

  init(address: URL = BotAddress.url, simulatorToken: String? = nil, signedIn: Bool = false, demo: Bool = false) {
    self.address = address
    self.simulatorToken = simulatorToken
    self.signedIn = signedIn
    self.demo = demo
  }

  /// Whether the phone shows the sign-in: the bot's own address without a sign-in. The demo day
  /// and a development address need none.
  var needsSignIn: Bool { !demo && address == BotAddress.url && simulatorToken == nil && !signedIn }

  /// The address the app talks to: the demo day while the switch is on, else the bot's once this
  /// phone is signed in; nil until then, so nothing is read. A development address needs no sign-in.
  var url: URL? {
    if demo { return DemoDay.address }
    return needsSignIn ? nil : address
  }

  /// The same connection with the demo day on or off; the address and sign-in are kept as they are.
  func demo(_ on: Bool) -> Connection {
    Connection(address: address, simulatorToken: simulatorToken, signedIn: signedIn, demo: on)
  }

  /// The same connection signed in or out.
  func signedIn(_ signedIn: Bool) -> Connection {
    Connection(address: address, simulatorToken: simulatorToken, signedIn: signedIn, demo: demo)
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

  /// What the API client needs for a request to `url`: the Simulator's token, or the sign-in's
  /// tokens for the bot's own address, only to the address's origin and where a token may go.
  func endpoint(for url: URL) -> APIClient.Endpoint {
    guard Self.carriesToken(url), Self.origin(url) == Self.origin(address) else {
      return APIClient.Endpoint(baseURL: url)
    }
    if let simulatorToken { return APIClient.Endpoint(baseURL: url, token: simulatorToken) }
    return APIClient.Endpoint(baseURL: url, signedIn: signedIn && address == BotAddress.url)
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

  /// The connection this launch starts with: the bot's address with this phone's sign-in, unless
  /// a development address replaces it (see the type's note).
  @MainActor
  static func load(_ defaults: UserDefaults = .standard) -> Connection {
    let demo = defaults.bool(forKey: demoKey)
    if let text = defaults.string(forKey: addressKey), let url = URL(string: text), url.host != nil {
      return Connection(address: url, demo: demo)
    }
    #if targetEnvironment(simulator)
    // The Simulator's own token and the address it opens (`pair-simulator`), read from the Mac
    // at every launch: the Simulator reads the bot on this Mac without signing in.
    if let simulator = SimulatorToken.read(), let url = URL(string: simulator.address) {
      return Connection(address: url, simulatorToken: simulator.token, demo: demo)
    }
    #endif
    for key in retiredKeys { defaults.removeObject(forKey: key) }
    return Connection(signedIn: Container.shared.signInState().signedIn, demo: demo)
  }

  /// Stores the demo switch (the sign-in is `BotSession`'s and `SignInState`'s).
  func save(_ defaults: UserDefaults = .standard) {
    defaults.set(demo, forKey: Self.demoKey)
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
