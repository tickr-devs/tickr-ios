import Foundation
import Testing
@testable import TickrKit

/// Stop bot with open positions (backlog V4 variant A) on the contract fixtures: the question,
/// the command each answer sends, the close-and-stop steps, its refusal, and the panel of a bot
/// stopped with positions left open.
@Suite struct StopFlowTests {
  /// A status fixture, its `status` object changed by `change` first.
  private func status(_ name: String, _ change: (inout [String: Any]) -> Void = { _ in }) throws -> StatusV1 {
    var response = try #require(JSONSerialization.jsonObject(with: fixture(name)) as? [String: Any])
    var status = try #require(response["status"] as? [String: Any])
    change(&status)
    response["status"] = status
    let data = try JSONSerialization.data(withJSONObject: response)
    return try #require(try Wire.decoder().decode(StatusResponseV1.self, from: data).status)
  }

  private static let closing = "status-response-v1.closing.json"
  private static let leftOpen = "status-response-v1.stopped-left-open.json"
  private static let running = "status-response-v1.json"
  /// A later step's start, after the fixtures' single time.
  private static let later = "2026-11-16T15:00:03.000Z"

  @Test func stopBotAsksToChooseOnlyWithPositionsOpen() throws {
    let open = try status(Self.closing)
    #expect(StopQuestion.asked(positions: open.positions) == .choose(symbols: ["ABCD"]))
    #expect(StopQuestion.asked(positions: []) == .confirm)
  }

  @Test func eachAnswerSendsItsModeToStopBot() throws {
    let accepted = try Wire.decoder().decode(CommandAcceptedV1.self,
      from: fixture("command-accepted-v1.stop-close-and-stop.json"))
    #expect(accepted.command.kind == .stopBot)
    #expect(accepted.command.mode == .closeAndStop)
    for mode in StopMode.allCases {
      let command = OperatorCommand.stopBotMode(mode)
      #expect(command.kind == .stopBot)
      #expect(command.path == OperatorCommand.stopBot.path)
      #expect(command.body == ["mode": mode.rawValue])
    }
    #expect(OperatorCommand.stopBot.body.isEmpty, "the plain stop keeps its empty body")
  }

  @Test func closingShowsTheFirstStepUnderWayAndTheRestWaiting() throws {
    let status = try status(Self.closing)
    var watch = StopWatch()
    watch.read(status)
    let rows = try #require(watch.steps(status))
    #expect(rows.map(\.step) == StopWatch.order)
    #expect(rows.map(\.phase) == [.running, .waiting, .waiting, .waiting])
    #expect(rows[0].since == status.stopProgress?.since.date)
    #expect(rows.dropFirst().allSatisfy { $0.since == nil }, "a step not reached has no time")
  }

  @Test func earlierStepsKeepTheTimesReadBefore() throws {
    let closing = try status(Self.closing)
    let stopping = try status(Self.closing) { status in
      var progress = status["stop_progress"] as? [String: Any] ?? [:]
      progress["step"] = "stopping"
      progress["since"] = Self.later
      status["stop_progress"] = progress
    }
    var watch = StopWatch()
    watch.read(closing)
    watch.read(stopping)
    let rows = try #require(watch.steps(stopping))
    #expect(rows.map(\.phase) == [.done, .done, .running, .waiting])
    #expect(rows[0].since == closing.stopProgress?.since.date)
    #expect(rows[1].since == nil, "positions_closed was never read: no time, never a guess")
    #expect(rows[2].since == stopping.stopProgress?.since.date)
    // A watch that never saw the closing step shows no time for it.
    #expect(StopWatch().steps(stopping)?.first?.since == nil)
  }

  @Test func aRefusalIsSaidOnceTheProgressIsGone() throws {
    let closing = try status(Self.closing)
    let id = try #require(closing.stopProgress?.commandId)
    var watch = StopWatch()
    watch.read(closing)
    #expect(watch.refusal(closing) == nil, "still running")
    let refused = try status(Self.closing) { status in
      status["stop_progress"] = NSNull()
      status["recent_commands"] = [[
        "command_id": id, "kind": "stop-bot", "requested_at": Self.later, "processed_at": Self.later,
        "outcome": "refused", "cause": "close-and-stop interrupted by a restart",
        "cause_codes": [["code": "stop_interrupted", "params": [String: String]()]],
      ]]
    }
    watch.read(refused)
    #expect(watch.steps(refused) == nil, "the normal controls come back")
    // The cause in words through the prose mapping, never the raw code.
    let cause = try #require(refused.recentCommands.first?.causeText)
    #expect(!cause.contains("stop_interrupted"))
    #expect(watch.refusal(refused) == String(localized: StopText.refused(cause)))
    watch.forget()
    #expect(watch.refusal(refused) == nil)
  }

  @Test func stoppedWithPositionsLeftOpenShowsTheLastKnownPositions() throws {
    let status = try status(Self.leftOpen)
    #expect(StopWatch().steps(status) == nil, "leave open has no steps")
    let panel = try #require(StoppedPositions.make(status))
    #expect(panel.rows == [StoppedPositions.Row(symbol: "ABCD", quantity: 10, stop: Decimal(string: "11.90"))])
    #expect(panel.stoppedAt == status.stopProgress?.since.date)
    #expect(panel.readAt == status.freshness.lastBrokerReadAt?.date)
    #expect(StoppedPositions.make(try self.status(Self.running)) == nil, "a running bot has no panel")
    #expect(StoppedPositions.make(try self.status(Self.leftOpen) { $0["positions"] = [Any]() }) == nil)
  }

  @Test func withoutABrokerReadThePanelSaysSo() throws {
    let status = try status(Self.leftOpen) { status in
      var freshness = status["freshness"] as? [String: Any] ?? [:]
      freshness["last_broker_read_at"] = NSNull()
      status["freshness"] = freshness
    }
    let panel = try #require(StoppedPositions.make(status))
    #expect(panel.readAt == nil)
    #expect(panel.note.key == StopText.lastKnownUnknown.key)
  }
}
