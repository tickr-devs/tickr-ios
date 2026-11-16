import Testing
@testable import TickrDesign

/// A count bumps only when it rises: one bump per real rise, none when it falls or stays.
@Suite struct EventMotionTests {
  @Test(arguments: [(3, 4, true), (3, 9, true), (4, 4, false), (4, 3, false), (1, 0, false)])
  func countBumpsOnlyOnARise(old: Int, new: Int, bumps: Bool) {
    #expect(CountBump.rises(from: old, to: new) == bumps)
  }
}
