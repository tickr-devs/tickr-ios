import FactoryTesting
import Foundation
import Synchronization
import Testing
@testable import TickrKit

/// Fails every request and counts it: the demo day must never reach the network.
final class NetworkTrap: URLProtocol {
  static let asked = Mutex(0)

  static func session() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [NetworkTrap.self]
    return URLSession(configuration: configuration)
  }

  override static func canInit(with request: URLRequest) -> Bool { true }
  override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    Self.asked.withLock { $0 += 1 }
    client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
  }
  override func stopLoading() {}
}

/// The demo day the apps carry (DemoDay.jsonl, `tickr demo --record`).
@Suite(.container, .serialized) struct DemoSourceTests {
  let recording: DemoRecording

  init() throws {
    recording = try DemoRecording.bundled()
    Container.shared.urlSession.register { NetworkTrap.session() }
    NetworkTrap.asked.withLock { $0 = 0 }
  }

  /// The live decoder of each recorded GET path (the type APIClient decodes it as).
  static let decoders: [String: @Sendable (Data) throws -> Void] = [
    "/status": { _ = try Wire.decoder().decode(StatusResponseV1.self, from: $0) },
    "/account": { _ = try Wire.decoder().decode(AccountResponseV1.self, from: $0) },
    "/commands/pending": { _ = try Wire.decoder().decode(PendingCommandsV1.self, from: $0) },
    "/jobs": { _ = try Wire.decoder().decode(JobsV1.self, from: $0) },
    "/journal": { _ = try Wire.decoder().decode(JournalV1.self, from: $0) },
    "/settings": { _ = try Wire.decoder().decode(SettingsV1.self, from: $0) },
    "/config": { _ = try Wire.decoder().decode(ConfigV1.self, from: $0) },
    "/advisor": { _ = try Wire.decoder().decode(AdvisorRunsV1.self, from: $0) },
    "/lab/replay": { _ = try Wire.decoder().decode(LabReplayV1.self, from: $0) },
    "/days": { _ = try Wire.decoder().decode(DaysV1.self, from: $0) },
    "/days/": { _ = try Wire.decoder().decode(DayV1.self, from: $0) },
    "/flow": { _ = try Wire.decoder().decode(FlowV1.self, from: $0) },
    "/watching": { _ = try Wire.decoder().decode(WatchingV1.self, from: $0) },
    "/observers": { _ = try Wire.decoder().decode(ObserversV1.self, from: $0) },
    "/skipped": { _ = try Wire.decoder().decode(SkippedV1.self, from: $0) },
    "/performance": { _ = try Wire.decoder().decode(PerformanceV1.self, from: $0) },
    "/decisions": { _ = try Wire.decoder().decode(DecisionsV1.self, from: $0) },
    "/bars": { _ = try Wire.decoder().decode(BarsV1.self, from: $0) },
    "/chart": { _ = try Wire.decoder().decode(ChartV1.self, from: $0) },
  ]

  static func decode(path: String, body: Data) throws {
    let key = path.hasPrefix("/days/") ? "/days/" : path
    let decoder = try #require(decoders[key], "no decoder for recorded path \(path)")
    try decoder(body)
  }

  @Test func everyRecordedAnswerDecodesWithTheLiveDecoders() throws {
    #expect(recording.frames > 1)
    #expect(!recording.routeKeys.isEmpty)
    var checked = 0
    for route in recording.routeKeys {
      let path = String(route.prefix { $0 != "?" })
      // Documents that grow through the day (charts, decisions, bars, observers): their first
      // and last answer, which hold every kind of row; the others are the same rows a minute
      // apart. Every answer of every other route.
      let all = recording.changes(route: route)
      let grows = route.contains("symbol=") || route.hasPrefix("/observers")
      for (index, answer) in all.enumerated() where !grows || index == 0 || index == all.count - 1 {
        if answer.status == 200 {
          try Self.decode(path: path, body: answer.body)
        } else {
          _ = try Wire.decoder().decode(ErrorV1.self, from: answer.body)
        }
        checked += 1
      }
    }
    #expect(checked >= recording.routeKeys.count)
    // Every screen's resource is there for the demo day.
    let day = recording.demoDay
    for route in ["/status", "/account", "/days", "/days/\(day)", "/flow?date=\(day)",
      "/watching?date=\(day)", "/observers?date=\(day)", "/skipped?date=\(day)", "/jobs", "/settings", "/config"] {
      #expect(recording.answer(route: route, frame: 0)?.status == 200, "\(route)")
    }
  }

  @Test func everyRecordedPostDecodes() throws {
    #expect(!recording.postKeys.isEmpty)
    for key in recording.postKeys {
      let answer = try #require(recording.post(key))
      if answer.status == 202, key.hasPrefix("/commands/start-bot") {
        _ = try Wire.decoder().decode(BotStartV1.self, from: answer.body)
      } else if answer.status == 202, key.hasPrefix("/commands/") {
        let accepted = try Wire.decoder().decode(CommandAcceptedV1.self, from: answer.body)
        // The real bot acted on every command the apps can send; its outcome is recorded.
        let outcome = try #require(answer.outcome, "\(key) has no recorded outcome")
        let record = try Wire.decoder().decode(CommandRecord.self, from: outcome)
        #expect(record.commandId == accepted.command.commandId)
      } else if answer.status >= 300 {
        _ = try Wire.decoder().decode(ErrorV1.self, from: answer.body)
      }
    }
  }

  @Test func theLoopClockWraps() {
    let started = Date(timeIntervalSince1970: 0)
    let seconds = recording.frameSeconds
    let frames = recording.frames
    func frame(_ after: Int) -> Int {
      DemoSource.frame(at: started.addingTimeInterval(TimeInterval(after)), started: started,
        frameSeconds: seconds, frames: frames)
    }
    #expect(frame(0) == 0)
    #expect(frame(seconds - 1) == 0)
    #expect(frame(seconds) == 1)
    #expect(frame(seconds * frames - 1) == frames - 1)
    #expect(frame(seconds * frames) == 0)
    #expect(frame(seconds * frames * 3 + seconds * 2) == 2)
    #expect(frame(-seconds) == 0)
  }

  @Test func theStatusMovesWithTheClockAndComesBackAfterTheCycle() async throws {
    let started = Date(timeIntervalSince1970: 0)
    let clock = Mutex(started)
    let source = DemoSource(recording: .success(recording), started: started, now: { clock.withLock { $0 } })
    let client = APIClient(baseURL: DemoDay.address, transport: source)
    let first = try await client.status()
    clock.withLock { $0 = started.addingTimeInterval(TimeInterval(recording.frameSeconds * (recording.frames / 2))) }
    let later = try await client.status()
    #expect(later.servedAt.date > first.servedAt.date)
    clock.withLock { $0 = started.addingTimeInterval(TimeInterval(recording.frameSeconds * recording.frames)) }
    let wrapped = try await client.status()
    #expect(wrapped.servedAt.date == first.servedAt.date)
  }

  @Test func theContainerAnswersTheDemoAddressAndNeverTheNetwork() async throws {
    let client = Container.shared.apiClient(APIClient.Endpoint(baseURL: DemoDay.address, token: "t"))
    let status = try await client.status()
    #expect(status.status?.environment == "demo")
    let today = try WireDate(recording.demoDay)
    _ = try await client.flow(day: today)
    _ = try await client.day(today)
    _ = try await client.chart(symbol: "MVLD", interval: .m1, range: .oneDay)
    for command in [OperatorCommand.entryStop(on: true), .entryStop(on: false), .cancelOwnOrders, .flatten,
      .flattenSymbol("MVLD"), .stopBot, .emergency] {
      let accepted = try await client.send(command, idempotencyKey: UUID().uuidString)
      #expect(accepted.command.kind == command.kind)
    }
    _ = try? await client.startBot()
    _ = try? await client.startLabReplay(version: "x")
    #expect(NetworkTrap.asked.withLock { $0 } == 0)
    // The bot's own address still goes to the network (here: the trap).
    let bot = Container.shared.apiClient(APIClient.Endpoint(baseURL: APIClient.defaultBaseURL))
    await #expect(throws: APIError.self) { try await bot.status() }
    #expect(NetworkTrap.asked.withLock { $0 } == 1)
  }

  @Test func aCommandPlaysItsRecordedOutcomeUnderItsOwnId() async throws {
    let source = DemoSource(recording: .success(recording), started: Date(), now: { Date() })
    let client = APIClient(baseURL: DemoDay.address, transport: source)
    let before = try await client.status()
    let first = try await client.send(.flatten, idempotencyKey: UUID().uuidString)
    let second = try await client.send(.flatten, idempotencyKey: UUID().uuidString)
    #expect(first.command.commandId != second.command.commandId)
    let after = try await client.status()
    let records = try #require(after.status?.recentCommands)
    #expect(records.prefix(2).map(\.commandId) == [second.command.commandId, first.command.commandId])
    #expect(records.first?.processedAt.date == after.servedAt.date)
    #expect(records.count == max(before.status?.recentCommands.count ?? 0, 2))
    // Another source (the other app, a fresh start) has its own commands.
    let fresh = APIClient(baseURL: DemoDay.address,
      transport: DemoSource(recording: .success(recording), started: Date(), now: { Date() }))
    #expect(try await fresh.status().status?.recentCommands.first?.commandId != second.command.commandId)
  }

  @Test func aReadTheRecordingDoesNotHoldSaysSoInTheReadersLanguage() async throws {
    let client = Container.shared.apiClient(APIClient.Endpoint(baseURL: DemoDay.address))
    await #expect(throws: APIError.notServed(demo: true)) {
      try await client.chart(symbol: "NOPE", interval: .m1, range: .oneDay)
    }
    #expect(APIError.notServed(demo: true).errorDescription == String(localized: L10n.apiNotRecordedDemo))
  }
}
