import Foundation
import Testing
@testable import TickrKit

@Suite("Contract: codes of the API's own causes")
struct ContractCauseCodesTests {
  @Test func performanceExclusion() throws {
    let performance = try Wire.decoder().decode(PerformanceV1.self, from: fixture("performance-v1.json"))
    #expect(performance.exclusions.first?.causeCodes.first?.code == "planned_loss_not_positive_r")
  }

  /// A version the Lab cannot replay, and a failed run, read in the person's words.
  @Test func labReplay() throws {
    let idle = try Wire.decoder().decode(LabReplayV1.self, from: fixture("lab-replay-v1.idle.json"))
    let refused = try #require(idle.versions.first { $0.cause != nil })
    #expect(refused.causeCodes.first?.code == "strategy_without_name")
    #expect(refused.causeText != refused.cause)
    let failed = try Wire.decoder().decode(LabReplayV1.self, from: fixture("lab-replay-v1.failed.json"))
    #expect(failed.causeCodes.first?.code == "backtest_refused")
  }

  /// The session's close is known from the document: a start waits for it, and not after it.
  @Test func labReplayWaitsForTheClose() throws {
    let idle = try Wire.decoder().decode(LabReplayV1.self, from: fixture("lab-replay-v1.idle.json"))
    #expect(idle.waitsUntil(now: .now) == nil)
    var json = try #require(try JSONSerialization.jsonObject(with: fixture("lab-replay-v1.idle.json")) as? [String: Any])
    json["available_at"] = "2026-11-16T21:00:00.000Z"
    let waiting = try Wire.decoder().decode(LabReplayV1.self, from: JSONSerialization.data(withJSONObject: json))
    let close = try #require(waiting.availableAt?.date)
    #expect(waiting.waitsUntil(now: close.addingTimeInterval(-1)) == close)
    #expect(waiting.waitsUntil(now: close) == nil)
  }

  /// Every cause these screens show reads in the person's words, never in the bot's.
  @Test func jobsMoversStatusAndChart() throws {
    let jobs = try Wire.decoder().decode(JobsV1.self, from: fixture("jobs-v1.weekend.json"))
    #expect(jobs.sessionCauseCodes.first?.code == "calendar_weekend")
    #expect(jobs.sessionCauseText?.contains("WEEKEND") == false)
    let movers = try Wire.decoder().decode(MoversV1.self, from: fixture("movers-v1.no-rules.json"))
    #expect(movers.rulesCauseText == ProseReason.noFastMoverRules.text([:]))
    let status = try Wire.decoder().decode(StatusResponseV1.self, from: fixture("status-response-v1.unavailable.json"))
    #expect(status.unavailableCauseText == ProseReason.noStatusFile.text([:]))
    let chart = try Wire.decoder().decode(ChartV1.self, from: fixture("chart-v1.empty.json"))
    #expect(chart.causeCodes.first?.code == "no_chart_bars")
    #expect(chart.causeText != chart.cause)
  }

  @Test func flowAndSize() throws {
    let flow = try Wire.decoder().decode(FlowV1.self, from: fixture("flow-v1.empty.json"))
    #expect(flow.reconcile.agreementCause == nil || flow.reconcile.agreementCauseText != flow.reconcile.agreementCause)
    #expect(flow.reconcile.fencesCause == nil || flow.reconcile.fencesCauseText != flow.reconcile.fencesCause)
    let watching = try Wire.decoder().decode(WatchingV1.self, from: fixture("watching-v1.json"))
    let size = try #require(watching.latestSize)
    #expect(size.bindingCauseText == ProseReason.bindingNotProven.text([:]))
  }

  /// An emergency's steps read as the commands' titles with what each did.
  @Test func emergencySteps() throws {
    let json = #"""
      {"command_id": "c1", "kind": "emergency", "requested_at": "2026-11-16T15:00:00.000Z",
       "processed_at": "2026-11-16T15:00:01.000Z", "outcome": "done",
       "cause": "entry-stop-on: done; flatten: no open position in ABCD",
       "cause_codes": [
         {"code": "command_step", "params": {"step": "entry-stop-on", "step_code": "step_done"}},
         {"code": "command_step", "params": {"step": "flatten", "step_code": "no_open_position", "symbol": "ABCD"}}]}
      """#
    let record = try Wire.decoder().decode(CommandRecord.self, from: Data(json.utf8))
    let text = try #require(record.causeText)
    #expect(text.hasPrefix(Board.commandTitle(.entryStopOn)))
    #expect(text.contains(Board.commandTitle(.flatten)))
    #expect(text.contains("ABCD"))
    #expect(!text.contains("entry-stop-on"))
    let steps = ReasonV1(code: "steps_not_run", params: ["steps": "cancel-own-orders, flatten"])
    #expect(ApiText.prose([steps], text: "x").contains(Board.commandTitle(.cancelOwnOrders)))
    let unknown = ReasonV1(code: "steps_not_run", params: ["steps": "reboot"])
    #expect(ApiText.prose([unknown], text: "x") == "x")
  }

  @Test("A document written before codes reads with none")
  func older() throws {
    let json = #"{"minutes": 1, "at": "2026-11-16T15:01:00.000Z", "price": null, "change_usd": null, "cause": "x"}"#
    let price = try Wire.decoder().decode(PriceAfterV1.self, from: Data(json.utf8))
    #expect(price.causeCodes.isEmpty)
  }
}
