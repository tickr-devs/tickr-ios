import FactoryTesting
import Foundation
import Testing
@testable import TickrKit

/// POST and DELETE /push-token, and the registrar that sends this device's tokens. In the
/// APIClient suite, which runs one test at a time, because both answer through `StubProtocol`.
extension APIClientTests {
  static let identity = PushIdentity(environment: .development, bundleId: "bot.tickr.ios", platform: .ios)
  static let registered = Data("""
    {"registered": true, "kind": "alert", "environment": "development", "bundle_id": "bot.tickr.ios",
     "platform": "ios", "registered_at": "2026-11-16T15:00:00.123Z", "api_version": 1}
    """.utf8)
  static let removed = Data("""
    {"registered": false, "kind": "activity_update", "environment": null, "bundle_id": null,
     "platform": null, "registered_at": null, "api_version": 1}
    """.utf8)

  @Test func tokenIsLowercaseHexWithTwoDigitsPerByte() {
    #expect(PushRegistration.hex(Data([0x00, 0x0A, 0xFF, 0x7B])) == "000aff7b")
    #expect(PushRegistration.hex(Data()) == "")
  }

  @Test func registerPostsTheExactBody() async throws {
    StubProtocol.answer = (200, Self.registered)
    let registration = PushRegistration(token: "00ff", kind: .activityStart, identity: Self.identity)
    let answer = try await client.registerPushToken(registration)
    #expect(answer.registered && answer.kind == .alert && answer.platform == .ios)
    let sent = try #require(StubProtocol.seen.first)
    #expect(sent.httpMethod == "POST")
    #expect(sent.url?.absoluteString == "http://127.0.0.1:8766/push-token")
    let body = try JSONSerialization.jsonObject(with: StubProtocol.seenBodies[0]) as? [String: String]
    #expect(body == ["token": "00ff", "environment": "development", "bundle_id": "bot.tickr.ios",
      "platform": "ios", "kind": "activity_start"])
  }

  @Test func removeDeletesOneKind() async throws {
    StubProtocol.answer = (200, Self.removed)
    let answer = try await client.removePushToken(kind: .activityUpdate)
    #expect(!answer.registered && answer.environment == nil && answer.registeredAt == nil)
    let sent = try #require(StubProtocol.seen.first)
    #expect(sent.httpMethod == "DELETE")
    #expect(sent.url?.absoluteString == "http://127.0.0.1:8766/push-token?kind=activity_update")
  }

  @Test func refusedTokenIsATypedRefusal() async throws {
    StubProtocol.answer = (400, Data(#"{"error":"bad_request","cause":"token is not hex","api_version":1}"#.utf8))
    let registration = PushRegistration(token: "zz", kind: .alert, identity: Self.identity)
    await #expect(throws: APIError.refused(status: 400, error: "bad_request", cause: "token is not hex")) {
      try await client.registerPushToken(registration)
    }
  }

  @Test func buildWithoutAnEnvironmentHasNoIdentity() {
    // The test runner's bundle names no APNs environment: such a build never registers.
    #expect(PushIdentity.of(.main, platform: .ios) == nil)
    #expect(PushIdentity.of(.main, platform: nil) == nil)
  }

  @MainActor @Test func registrarSendsEachTokenOnceAfterTheBotAnswered() async throws {
    Container.shared.urlSession.register { StubProtocol.session() }
    StubProtocol.answer = (200, Self.registered)
    let registrar = PushRegistrar(identity: Self.identity)
    let mac = APIClient.Endpoint(baseURL: try #require(URL(string: "https://mac.ts.net")), token: "t")
    // A token before the bot answered waits for it.
    #expect(registrar.received(Data([0xAB]), kind: .alert) == nil)
    await registrar.reached(mac)?.value
    #expect(StubProtocol.seen.count == 1)
    #expect(StubProtocol.seen[0].value(forHTTPHeaderField: "Authorization") == "Bearer t")
    // The same token at the same address goes once, even after a failure.
    #expect(registrar.reached(mac) == nil)
    #expect(registrar.received(Data([0xAB]), kind: .alert) == nil)
    // A new token, another kind or another address goes again.
    await registrar.received(Data([0xCD]), kind: .alert)?.value
    await registrar.received(Data([0x01]), kind: .activityStart)?.value
    let other = APIClient.Endpoint(baseURL: try #require(URL(string: "https://other.ts.net")), token: "u")
    await registrar.reached(other)?.value
    let bodies = try StubProtocol.seenBodies.map {
      try #require(JSONSerialization.jsonObject(with: $0) as? [String: String])
    }
    #expect(bodies.map { $0["token"] } == ["ab", "cd", "01", "cd", "01"])
    #expect(bodies.map { $0["kind"] } == ["alert", "alert", "activity_start", "alert", "activity_start"])
  }

  @MainActor @Test func registrarIgnoresTheDemoDayAndABuildWithoutIdentity() async throws {
    Container.shared.urlSession.register { StubProtocol.session() }
    let demo = PushRegistrar(identity: Self.identity)
    demo.received(Data([0xAB]), kind: .alert)
    #expect(demo.reached(APIClient.Endpoint(baseURL: DemoDay.address)) == nil)
    let unnamed = PushRegistrar(identity: nil)
    unnamed.received(Data([0xAB]), kind: .alert)
    #expect(unnamed.reached(APIClient.Endpoint(baseURL: try #require(URL(string: "http://127.0.0.1:8766")))) == nil)
    #expect(StubProtocol.seen.isEmpty)
  }

  @MainActor @Test func refusedRegistrationIsNotSentAgain() async throws {
    Container.shared.urlSession.register { StubProtocol.session() }
    StubProtocol.answer = (400, Data(#"{"error":"bad_request","cause":"bundle id","api_version":1}"#.utf8))
    let registrar = PushRegistrar(identity: Self.identity)
    registrar.received(Data([0xAB]), kind: .alert)
    await registrar.reached(APIClient.Endpoint(baseURL: try #require(URL(string: "http://127.0.0.1:8766"))))?.value
    #expect(registrar.reached(APIClient.Endpoint(baseURL: try #require(URL(string: "http://127.0.0.1:8766")))) == nil)
    #expect(StubProtocol.seen.count == 1)
  }
}
