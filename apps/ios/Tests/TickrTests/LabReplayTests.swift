import Foundation
import Testing
@testable import Tickr
import TickrKit

/// A refused replay start stays as a calm reason until the replay moves on or `replaySeconds` pass
/// (#333).
@MainActor
@Suite struct LabReplayTests {
  private let refusedAt = Date(timeIntervalSince1970: 1_800_000_000)

  @Test func sameReplayKeepsTheRefusal() throws {
    let done = try fixture(LabReplayV1.self, "lab-replay-v1.json")
    let refused = (state: Optional(done.state), runId: done.runId, at: refusedAt)
    let soon = refusedAt.addingTimeInterval(LabModel.replaySeconds - 1)
    #expect(!LabModel.refusalCleared(refused, by: done, now: soon))
  }

  @Test func refusalExpires() throws {
    let done = try fixture(LabReplayV1.self, "lab-replay-v1.json")
    let refused = (state: Optional(done.state), runId: done.runId, at: refusedAt)
    let later = refusedAt.addingTimeInterval(LabModel.replaySeconds)
    #expect(LabModel.refusalCleared(refused, by: done, now: later))
  }

  @Test func anotherStateClearsTheRefusal() throws {
    let idle = try fixture(LabReplayV1.self, "lab-replay-v1.idle.json")
    let running = try fixture(LabReplayV1.self, "lab-replay-v1.running.json")
    let refused = (state: Optional(idle.state), runId: idle.runId, at: refusedAt)
    #expect(LabModel.refusalCleared(refused, by: running, now: refusedAt))
  }

  @Test func anotherRunClearsTheRefusal() throws {
    let done = try fixture(LabReplayV1.self, "lab-replay-v1.json")
    let refused = (state: Optional(done.state), runId: Optional("another-run"), at: refusedAt)
    #expect(LabModel.refusalCleared(refused, by: done, now: refusedAt))
  }

  @Test func refusalBeforeAnyReadClearsOnTheFirstRead() throws {
    let idle = try fixture(LabReplayV1.self, "lab-replay-v1.idle.json")
    let refused = (state: LabReplayState?.none, runId: String?.none, at: refusedAt)
    #expect(LabModel.refusalCleared(refused, by: idle, now: refusedAt))
  }
}
