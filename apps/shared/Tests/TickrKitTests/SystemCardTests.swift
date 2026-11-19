import Foundation
import Testing
@testable import TickrKit

/// The System card's judgement of each row (system-v1 fixtures), the same on both apps.
@Suite struct SystemCardTests {
  func system(_ name: String) throws -> SystemV1 {
    try Wire.decoder().decode(SystemV1.self, from: fixture(name))
  }

  @Test func everythingHealthyIsAllGood() throws {
    let system = try system("system-v1.json")
    #expect(SystemCard.all(system) == [.good, .good, .good, .good, .good])
    #expect(SystemCard.needingALook(system) == 0)
    #expect(system.mac?.watchdog.restarts.map(\.outcome) == [.started, .refused])
    #expect(system.mac?.watchdog.restarts.last?.causeCodes.map(\.code) == ["restart_refused_operator_stop"])
    #expect(system.training?.fraction == Double(130) / Double(209))
  }

  @Test func problemsAreCountedAndOnlyAStartRefusalIsDanger() throws {
    let system = try system("system-v1.attention.json")
    // Link stale while running, today's check failed and blocks the start, no training job,
    // the watchdog not started today (its failed restart was days ago), no sleep hold.
    #expect(SystemCard.all(system) == [.attention, .danger, .idle, .idle, .attention])
    #expect(SystemCard.needingALook(system) == 3)
    #expect(system.morningCheck?.failedCheck?.name == PreflightCheckName.token.rawValue)
  }

  @Test func aServerHasNoMacRowsAndAnUnknownLinkNeedsALook() throws {
    let system = try system("system-v1.server.json")
    #expect(system.mac == nil)
    #expect(system.hostCauseCodes.map(\.code) == ["no_host_services"])
    #expect(SystemCard.all(system) == [.unknown, .idle, .idle])
    #expect(SystemCard.needingALook(system) == 1)
  }

  @Test(arguments: [(59, SystemCard.Age.seconds(59)), (60, .minutes(1)), (3599, .minutes(59)), (7200, .hours(2))])
  func agesInWholeUnits(seconds: Int, age: SystemCard.Age) {
    let now = Date(timeIntervalSince1970: 0)
    #expect(SystemCard.Age(since: now.addingTimeInterval(-Double(seconds)), now: now) == age)
  }
}
