import Testing
@testable import Tickr
import TickrKit

/// Home's looping ornaments (brand halo, ticker scroll) move only while the bot is at work.
@Suite struct OrnamentGateTests {
  @Test("Moves only while the bot runs with live, fresh status and motion is allowed")
  func moves() {
    #expect(OrnamentGate.moves(reduceMotion: false, current: true, botState: .running))
    #expect(!OrnamentGate.moves(reduceMotion: true, current: true, botState: .running))
    // Stale, unreachable or a recorded day: not current.
    #expect(!OrnamentGate.moves(reduceMotion: false, current: false, botState: .running))
    for state in [BotState.starting, .stopping, .stopped] {
      #expect(!OrnamentGate.moves(reduceMotion: false, current: true, botState: state))
    }
    #expect(!OrnamentGate.moves(reduceMotion: false, current: true, botState: nil))
  }
}
