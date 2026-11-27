import Foundation
import os

/// Hands this device's APNs tokens to the bot (POST /push-token): the alert token from the app
/// delegate, and on iOS the Live Activity's push-to-start and update tokens. A token goes once
/// the app has reached the bot (an answered status read), and each token of a kind goes once to
/// one address per run: a failed registration is recorded in the diagnostics log and not sent
/// again until the token, the address or the app run changes, never in a loop.
/// The token is never logged.
@MainActor
public final class PushRegistrar {
  /// Where a refused or failed registration is recorded (subsystem `ApiText.diagnosticsSubsystem`).
  static let logCategory = "push-token"

  /// One registration sent: a kind's token to one address.
  struct Sent: Hashable {
    let kind: PushTokenKind
    let token: String
    let endpoint: APIClient.Endpoint
  }

  /// This build's environment, bundle id and platform; nil registers nothing.
  private let identity: PushIdentity?
  /// The newest token of each kind, in hex.
  private var tokens: [PushTokenKind: String] = [:]
  /// The bot's address, once a status read there has answered.
  private var endpoint: APIClient.Endpoint?
  private var sent: Set<Sent> = []
  private let log = Logger(subsystem: ApiText.diagnosticsSubsystem, category: logCategory)

  public init(identity: PushIdentity?) {
    self.identity = identity
    if identity == nil { log.error("\(PushIdentity.environmentKey, privacy: .public)") }
  }

  /// A new token of `kind` from the system. Returns the registration it starts, if any.
  @discardableResult
  public func received(_ deviceToken: Data, kind: PushTokenKind) -> Task<Void, Never>? {
    tokens[kind] = PushRegistration.hex(deviceToken)
    return registerDue()
  }

  /// The bot answered at `endpoint`. The demo day's address is no bot and registers nothing.
  @discardableResult
  public func reached(_ endpoint: APIClient.Endpoint) -> Task<Void, Never>? {
    guard !DemoDay.isDemo(endpoint.baseURL) else { return nil }
    self.endpoint = endpoint
    return registerDue()
  }

  /// This device signed in with the bot again. The bot drops a device's push tokens when its
  /// sign-in ends (sign-out, expiry, the name taken by another device), so every token goes again,
  /// once the next status read answers with the new sign-in (`reached`).
  public func signedIn() {
    sent.removeAll()
    endpoint = nil
  }

  /// The system could not give a token of `kind` (no entitlement, no network): recorded only.
  public func failed(_ error: any Error, kind: PushTokenKind) {
    log.error("\(kind.rawValue, privacy: .public) \(error.localizedDescription, privacy: .public)")
  }

  /// Sends every token not yet sent to the current address, each once, one after another.
  private func registerDue() -> Task<Void, Never>? {
    guard let identity, let endpoint else { return nil }
    let due = PushTokenKind.allCases.compactMap { kind in
      tokens[kind].map { Sent(kind: kind, token: $0, endpoint: endpoint) }
    }.filter { !sent.contains($0) }
    guard !due.isEmpty else { return nil }
    sent.formUnion(due)
    let client = Container.shared.apiClient(endpoint)
    let registrations = due.map { PushRegistration(token: $0.token, kind: $0.kind, identity: identity) }
    return Task { [log] in
      for registration in registrations {
        do {
          _ = try await client.registerPushToken(registration)
        } catch {
          log.error("\(registration.kind.rawValue, privacy: .public) \(error.localizedDescription, privacy: .public)")
        }
      }
    }
  }
}
