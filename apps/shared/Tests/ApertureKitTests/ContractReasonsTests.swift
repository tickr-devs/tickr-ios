@testable import ApertureKit
import Foundation
import Testing

@Suite("Contract: reason codes and params")
struct ContractReasonsTests {
  @Test func statusReasons() throws {
    let response = try Wire.decoder().decode(StatusResponseV1.self, from: fixture("status-response-v1.json"))
    let status = try #require(response.status)
    #expect(status.entryBlock?.cause == "own_trade_open")
    #expect(status.entryBlock?.params == [:])
    #expect(status.fences.first?.code == "foreign_position")
    #expect(!status.tradingGate.code.isEmpty)
  }

  @Test func refusalParams() throws {
    let skipped = try Wire.decoder().decode(SkippedV1.self, from: fixture("skipped-v1.json"))
    #expect(skipped.signals.first?.refusal?.params == ["open": "1", "limit": "1"])
  }

  @Test("A status written before codes reads as unrecorded, with no params")
  func olderStatus() throws {
    let fence = try Wire.decoder().decode(Fence.self, from: Data(
      #"{"kind": "entry-stop", "since": "2026-11-16T15:00:00.123Z", "text": "operator command"}"#.utf8))
    #expect(fence.code == ReasonCode.unrecorded)
    #expect(fence.params.isEmpty)
    let gate = try Wire.decoder().decode(Gate.self, from: Data(#"{"open": true, "cause": "enabled"}"#.utf8))
    #expect(gate.code == ReasonCode.unrecorded)
    let block = try Wire.decoder().decode(EntryBlock.self, from: Data(
      #"{"cause": "entry_stop", "text": "Entries stopped by the operator."}"#.utf8))
    #expect(block.params.isEmpty)
  }
}
