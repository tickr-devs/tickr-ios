import Foundation
import SwiftUI
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
    #expect(ConnectionFreshness.color(response: current, fetchError: "offline") == Palette.textQuaternary)
    #expect(ConnectionFreshness.color(response: nil, fetchError: "offline") == Palette.textQuaternary)
    #expect(ConnectionFreshness.color(response: nil, fetchError: nil) == Palette.loss)
  }

  /// Close all on Positions is the existing emergency command, behind Face ID, and its question
  /// names how many positions it closes.
  @Test func closeAllIsTheEmergencyBehindFaceID() {
    #expect(PositionsCloseAll.command == .emergency)
    #expect(PositionsCloseAll.command.path == "/commands/emergency")
    #expect(BotControl.needsOwner(PositionsCloseAll.command))
    #expect(PositionsCloseAll.title(1).key == "positions.closeLastTitle")
    #expect(PositionsCloseAll.title(2).key == "positions.closeAllTitle")
  }

  /// VoiceOver reads "no data yet" before the day is read, never a $0.00 day with 0 wins.
  @Test func dayResultBeforeTheDayIsReadSaysNoData() throws {
    let unread = String(localized: HomeView.dayResultLabel(stats: nil, result: 0))
    #expect(unread == String(localized: L10n.Home.dayResultUnavailable))
    let stats = Board.dayStats(try decode(StatusV1.self, try fixtureObject("status-v1.example.json")))
    let read = String(localized: HomeView.dayResultLabel(stats: stats, result: stats.resultUsd))
    #expect(read == String(localized: L10n.Home.dayResult(Money.signedUSD(stats.resultUsd), stats.wins, stats.losses)))
  }
}

/// The tab bar takes its own height whatever height it is offered, and fits the screen's width:
/// at large text sizes it once grew to the whole screen and pushed the first tab off the left
/// edge (layout sweep, 2026-11-19).
@MainActor
@Suite struct TabBarLayoutTests {
  /// A standard iPhone's width, in points.
  static let screenWidth: CGFloat = 402
  /// Two heights offered to the bar, in points: a phone screen's and far more.
  static let screenHeight: CGFloat = 874
  static let tallHeight: CGFloat = 4000

  private func size(offered height: CGFloat, text: DynamicTypeSize) -> CGSize {
    let bar = TickrTabBar().environment(AppModel()).environment(\.dynamicTypeSize, text)
    return UIHostingController(rootView: bar).sizeThatFits(in: CGSize(width: Self.screenWidth, height: height))
  }

  @Test(arguments: [DynamicTypeSize.large, .xxxLarge, .accessibility5])
  func theBarKeepsItsHeightAndFitsTheWidth(text: DynamicTypeSize) {
    let onScreen = size(offered: Self.screenHeight, text: text)
    let offeredMore = size(offered: Self.tallHeight, text: text)
    #expect(onScreen.height == offeredMore.height)
    #expect(onScreen.height < Self.screenHeight)
    #expect(onScreen.width <= Self.screenWidth)
  }
}
