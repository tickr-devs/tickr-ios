@testable import ApertureKit
import Foundation
import Testing

@Suite("What if each skipped setup had been entered")
struct WhatIfSummaryTests {
  func skipped() throws -> [SkippedSignalV1] {
    try Wire.decoder().decode(SkippedV1.self, from: fixture("skipped-v1.json")).signals
  }

  @Test("Replayed setups add up; one that could not run is counted apart")
  func fixtureDay() throws {
    let summary = try #require(WhatIfSummary.make(SkippedGroup.make(try skipped())))
    #expect(summary.resultUsd == Decimal(string: "10.85"))
    #expect(summary.resultR == Decimal(string: "-0.538"))
    #expect(summary.wins == 1)
    #expect(summary.losses == 1)
    #expect(summary.notReplayed == 1)
  }

  @Test("A repeat of the same setup is not a second trade")
  func repeatsCountOnce() throws {
    let abcd = try #require(try skipped().first { $0.symbol == "ABCD" })
    let summary = try #require(WhatIfSummary.make([SkippedGroup(signals: [abcd, abcd])]))
    #expect(summary.losses == 1)
    #expect(summary.resultUsd == Decimal(string: "-6.20"))
  }

  @Test("No skipped setup, no summary")
  func empty() {
    #expect(WhatIfSummary.make([]) == nil)
  }
}
