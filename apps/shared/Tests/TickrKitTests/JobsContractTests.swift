import Foundation
import Testing
@testable import TickrKit

/// The launchd jobs screen's contract (jobs-v1), beyond the round-trip in `ContractTests`.
@Suite struct JobsContractTests {
  @Test func nightlyFetchJob() throws {
    let jobs = try Wire.decoder().decode(JobsV1.self, from: fixture("jobs-v1.json"))
    #expect(jobs.nightlyFetch.finishedAt != nil)
    #expect(jobs.nightlyFetch.lastDay?.text == "2026-11-13")
    #expect(jobs.nightlyFetch.newSessions == 1)
    #expect(jobs.nightlyFetch.cause == nil)
    let weekend = try Wire.decoder().decode(JobsV1.self, from: fixture("jobs-v1.weekend.json"))
    #expect(weekend.nightlyFetch.lastDay == nil)
    #expect(weekend.nightlyFetch.newSessions == 0)
    #expect(weekend.nightlyFetch.cause != nil)
  }
}
