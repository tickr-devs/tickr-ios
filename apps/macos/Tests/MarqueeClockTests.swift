import CoreGraphics
import Testing
@testable import TickrMac

@Suite("Screener chips row: the row's clock")
struct MarqueeClockTests {
  @Test("A running row moves at its speed and stops where its page scrolls out")
  func runs() {
    var clock = MarqueeClock()
    clock.run(from: 10, at: 100, speed: 20)
    #expect(clock.shift(at: 102, limit: 500) == 50)
    #expect(clock.shift(at: 200, limit: 500) == 500)
  }

  @Test("Held, the row stays put however long; released, it goes on from that very point")
  func holdsWithoutJump() {
    var clock = MarqueeClock()
    clock.run(from: 0, at: 100, speed: 20)
    let held = clock.shift(at: 103, limit: 500)
    clock.stop(at: held)
    #expect(clock.shift(at: 160, limit: 500) == held)
    clock.run(from: clock.shift(at: 160, limit: 500), at: 160, speed: 20)
    #expect(clock.shift(at: 160, limit: 500) == held)
    #expect(clock.shift(at: 161, limit: 500) == held + 20)
  }
}
