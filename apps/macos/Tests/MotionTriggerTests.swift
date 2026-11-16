import Foundation
import Testing
import TickrDesign
@testable import TickrKit
@testable import TickrMac

@Suite("Motion triggers")
struct MotionTriggerTests {
  @Test("A Settings job's dot pulses when its state changes, not when the same state is read again")
  func jobDot() {
    #expect(JobDot(tone: .accent, live: true) == JobDot(tone: .accent, live: true))
    #expect(JobDot(tone: .accent, live: true) != JobDot(tone: .neutral, live: false))
    #expect(JobDot(tone: .info, live: true) != JobDot(tone: .info, live: false))
  }

  @Test("Only the first rows of the Trades table rise, in order; later rows and rows that rose show at once")
  func tableEntrance() {
    let ids = (0..<30).map { "t\($0)" }
    let steps = RowEntrance.steps(ids, first: 10, risen: [])
    #expect(steps.count == 10)
    #expect(steps["t0"] == 0)
    #expect(steps["t9"] == 9)
    #expect(steps["t10"] == nil, "a row past the first screenful never waits")
    #expect(steps["t29"] == nil)
    // A recycled row that has risen does not rise again; the others keep their turn.
    let again = RowEntrance.steps(ids, first: 10, risen: ["t0", "t3"])
    #expect(again["t0"] == nil)
    #expect(again["t3"] == nil)
    #expect(again["t4"] == 4)
    #expect(RowEntrance.steps([String](), first: 10, risen: []).isEmpty)
    #expect(RowEntrance.steps(ids, first: 10, risen: Set(ids)).isEmpty)
  }

  @Test("The Trades table's last rising row waits well under a second")
  func tableEntranceIsShort() {
    #expect(Double(RowEntrance.tradesRows) * Tokens.Motion.stagger < 1)
  }
}
