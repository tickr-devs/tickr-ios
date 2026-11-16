import Foundation
import Testing
@testable import Tickr
import TickrDesign
import TickrKit

/// The Home entries glyph follows the bot's entry block and its precedence (#317), and the
/// connection dot follows the answer's freshness.
@MainActor
@Suite struct HomeLogicTests {
  /// The example status with its entry block, operator pause and gate replaced.
  private func status(
    block cause: String?, attention: Bool = true, entryStop: Bool = false, gateOpen: Bool = true
  ) throws -> StatusV1 {
    var object = try fixtureObject("status-v1.example.json")
    object["entry_block"] = cause.map {
      ["cause": $0, "text": "held", "attention": attention, "params": [String: String]()] as [String: Any]
    } ?? NSNull()
    object["entry_stop"] = entryStop
    var gate = try #require(object["trading_gate"] as? [String: Any])
    gate["open"] = gateOpen
    object["trading_gate"] = gate
    return try decode(StatusV1.self, object)
  }

  @Test func noBlockMeansAllowed() throws {
    let glyph = EntriesGlyph.make(try status(block: nil))
    #expect(glyph.symbol == EntriesGlyph.entriesAllowedSymbol)
    #expect(glyph.tone == .profit)
  }

  @Test func ownersPauseIsPaused() throws {
    let glyph = EntriesGlyph.make(try status(block: BlockCode.entryStop.rawValue, entryStop: true))
    #expect(glyph.symbol == Symbols.pause)
    #expect(glyph.tone == .warning)
  }

  /// The bot's block outranks the owner's pause: a stopped bot with the pause on reads blocked.
  @Test func botsBlockOutranksThePause() throws {
    let glyph = EntriesGlyph.make(try status(block: "bot_not_running", entryStop: true))
    #expect(glyph.symbol == EntriesGlyph.entriesBlockedSymbol)
    #expect(glyph.tone == .warning)
  }

  @Test func ordinaryStateIsACalmNotNow() throws {
    let glyph = EntriesGlyph.make(try status(block: "own_trade_open", attention: false))
    #expect(glyph.symbol == EntriesGlyph.entriesNotNowSymbol)
    #expect(glyph.tone == .neutral)
  }

  @Test func blockNeedingAttentionIsBlocked() throws {
    let glyph = EntriesGlyph.make(try status(block: "daily_loss_limit", attention: true))
    #expect(glyph.symbol == EntriesGlyph.entriesBlockedSymbol)
    #expect(glyph.tone == .warning)
  }

  @Test func connectionDot() throws {
    let current = try fixture(StatusResponseV1.self, "status-response-v1.json")
    let stale = try fixture(StatusResponseV1.self, "status-response-v1.stale.json")
    #expect(ConnectionFreshness.color(response: current, fetchError: nil) == Palette.profit)
    #expect(ConnectionFreshness.color(response: stale, fetchError: nil) == Palette.warning)
    #expect(ConnectionFreshness.color(response: current, fetchError: "offline") == Palette.loss)
    #expect(ConnectionFreshness.color(response: nil, fetchError: nil) == Palette.loss)
  }
}
