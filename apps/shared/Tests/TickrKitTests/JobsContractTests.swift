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

/// GET /jobs `next_session`: the next regular open, null with its cause when the calendar cannot answer.
@Suite struct NextSessionContractTests {
  @Test func nextSessionDecodes() throws {
    let jobs = try Wire.decoder().decode(JobsV1.self, from: fixture("jobs-v1.json"))
    #expect(jobs.nextSession?.day.text == "2026-11-17")
    #expect(jobs.nextSession?.kind == .regular)
    #expect(jobs.nextSessionCause == nil)
    let refused = try Wire.decoder().decode(JobsV1.self, from: fixture("jobs-v1.no-next-session.json"))
    #expect(refused.nextSession == nil)
    #expect(refused.nextSessionCauseCodes.map(\.code) == ["calendar_not_covered"])
  }

  @Test("An older API without next_session decodes it as nil")
  func olderApi() throws {
    var object = try #require(JSONSerialization.jsonObject(with: fixture("jobs-v1.json")) as? [String: Any])
    for key in ["next_session", "next_session_cause", "next_session_cause_codes"] { object[key] = nil }
    let jobs = try Wire.decoder().decode(JobsV1.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(jobs.nextSession == nil && jobs.nextSessionCauseCodes.isEmpty)
  }
}
