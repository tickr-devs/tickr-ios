import Foundation
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

  @Test("The live day: a fresh status written today on the bot's clock")
  func liveDay() throws {
    let status = try #require(try fixture(StatusResponseV1.self, "status-response-v1.json").status)
    let today = WireDate(newYorkDateOf: status.writtenAt.date)
    #expect(AppModel.showsLiveDay(status, fresh: true, today: today))
    #expect(!AppModel.showsLiveDay(status, fresh: false, today: today))
    #expect(!AppModel.showsLiveDay(nil, fresh: true, today: today))
    let tomorrow = WireDate(newYorkDateOf: status.writtenAt.date.addingTimeInterval(Self.day))
    #expect(!AppModel.showsLiveDay(status, fresh: true, today: tomorrow))
  }

  /// Seconds in a day.
  static let day: TimeInterval = 86_400
}
