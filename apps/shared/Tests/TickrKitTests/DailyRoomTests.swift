import Foundation
import Testing
@testable import TickrKit

@Suite("Room under the daily loss limit")
struct DailyRoomTests {
  @Test("A loss uses room up")
  func lossUsesRoom() {
    #expect(DailyRoom.left(limit: 300, netResult: -120) == 180)
  }

  @Test("A profit never raises the room above the limit")
  func profitCapped() {
    #expect(DailyRoom.left(limit: 300, netResult: 250) == 300)
    #expect(DailyRoom.realizedLoss(netResult: 250) == 0)
  }

  @Test("Past the limit the room is zero, not negative")
  func neverNegative() {
    #expect(DailyRoom.left(limit: 300, netResult: -340) == 0)
  }

  @Test("A dash for the room is explained only when the bot's status has no room")
  func roomNote() throws {
    var raw = try #require(JSONSerialization.jsonObject(with: fixture("status-v1.example.json")) as? [String: Any])
    let known = try Wire.decoder().decode(StatusV1.self, from: JSONSerialization.data(withJSONObject: raw))
    raw["daily_room_usd"] = NSNull()
    let unknown = try Wire.decoder().decode(StatusV1.self, from: JSONSerialization.data(withJSONObject: raw))
    #expect(RiskRoomText.roomNote(known) == nil)
    #expect(RiskRoomText.roomNote(unknown)?.key == RiskRoomText.unknownRoom.key)
    #expect(RiskRoomText.roomNote(nil) == nil)
  }

  @Test("Profits offset losses: the net result counts")
  func netCounts() {
    #expect(DailyRoom.left(limit: 300, netResult: Decimal(string: "-40.5")!) == Decimal(string: "259.5")!)
  }
}
