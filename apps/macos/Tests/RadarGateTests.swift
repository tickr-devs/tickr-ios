import Testing
import TickrKit
@testable import TickrMac

@Suite("Empty-positions radar")
struct RadarGateTests {
  @Test("Turns only while the bot runs with live, fresh status and motion is allowed")
  func turns() {
    #expect(RadarGate.turns(reduceMotion: false, current: true, botState: .running))
    #expect(!RadarGate.turns(reduceMotion: true, current: true, botState: .running))
    // Stale, unreachable or a recorded day: not current.
    #expect(!RadarGate.turns(reduceMotion: false, current: false, botState: .running))
    for state in [BotState.starting, .stopping, .stopped] {
      #expect(!RadarGate.turns(reduceMotion: false, current: true, botState: state))
    }
    #expect(!RadarGate.turns(reduceMotion: false, current: true, botState: nil))
  }
}
