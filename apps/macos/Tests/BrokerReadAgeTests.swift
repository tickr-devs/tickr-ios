import Foundation
import Testing
import TickrDesign
import TickrKit
@testable import TickrMac

@Suite("Age of the last broker read on the Safety card")
struct BrokerReadAgeTests {
  func limits() throws -> BrokerReadAge.Limits {
    let data = try Data(contentsOf: fixturesDir.appendingPathComponent("settings-v1.json"))
    return try #require(BrokerReadAge.Limits(try Wire.decoder().decode(SettingsV1.self, from: data)))
  }

  @Test("The limits are the bot's own settings")
  func fromSettings() throws {
    #expect(try limits() == BrokerReadAge.Limits(warn: 15, block: 30))
    #expect(BrokerReadAge.Limits(nil) == nil)
  }

  @Test("Up to the warn age is green, up to the block age a warning, past it or never red")
  func color() throws {
    let limits = try limits()
    let now = Date()
    #expect(BrokerReadAge.color(since: now, now: now, limits: limits) == Palette.profitText)
    #expect(BrokerReadAge.color(since: now.addingTimeInterval(-limits.warn), now: now, limits: limits)
      == Palette.profitText)
    #expect(BrokerReadAge.color(since: now.addingTimeInterval(-limits.block), now: now, limits: limits)
      == Palette.warningText)
    #expect(BrokerReadAge.color(since: now.addingTimeInterval(-limits.block - 1), now: now, limits: limits)
      == Palette.lossText)
    #expect(BrokerReadAge.color(since: nil, now: now, limits: limits) == Palette.lossText)
  }

  @Test("Without the bot's limits an age is not judged; a missing read still is")
  func noSettings() {
    let now = Date()
    #expect(BrokerReadAge.tone(since: now, now: now, limits: nil) == .neutral)
    #expect(BrokerReadAge.tone(since: nil, now: now, limits: nil) == .loss)
  }
}
