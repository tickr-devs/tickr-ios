import Foundation
import Testing
@testable import TickrKit
@testable import TickrMac

@Suite("Trade marks and position levels on the chart")
struct ChartMarkersTests {
  @Test("Each closed trade has an entry and an exit mark coloured by its result")
  func marks() throws {
    let trades = try fixture(DayV1.self, "day-v1.json").trades
    let marks = ChartMarkers.marks(trades: trades)
    #expect(marks.count == trades.count * 2)
    let loser = try #require(trades.first { $0.resultGrossUsd.value < 0 })
    let winner = try #require(trades.first { $0.resultGrossUsd.value > 0 })
    let loserMarks = marks.filter { $0.id.trade == loser.tradeId }
    #expect(loserMarks.map(\.kind) == [.entry, .exitLoss])
    #expect(loserMarks[0].time == loser.openedAt.date)
    #expect(loserMarks[1].time == loser.closedAt.date)
    #expect(loserMarks[1].price == ChartMarkers.double(loser.exitPrice.value))
    #expect(marks.filter { $0.id.trade == winner.tradeId }.map(\.kind) == [.entry, .exitWin])
  }

  @Test("No position, no levels")
  func noPosition() {
    #expect(ChartMarkers.levels(position: nil).isEmpty)
  }

  @Test("An open position shows its entry and its stop; an unverified stop is marked so")
  func levels() throws {
    let position = try #require(try fixture(StatusResponseV1.self, "status-response-v1.json").status?.position)
    let row = PositionRow(position: position, lastBarClose: nil, lastBarAt: nil, closes: [])
    let levels = ChartMarkers.levels(position: row)
    #expect(levels.map(\.kind) == [.entry, position.stop.state == .verified ? .stop : .stopUnverified])
    #expect(levels[0].price == ChartMarkers.double(position.entryPrice.value))
    #expect(levels[0].since == position.openedAt.date)
  }

  /// The decisions fixture with its first decision (a WATCH at 15:00, no price) turned into an EXIT.
  private func decisions() throws -> [DecisionV1] {
    let url = fixturesDir.appendingPathComponent("decisions-v1.json")
    let text = try String(contentsOf: url, encoding: .utf8)
      .replacingOccurrences(of: "\"WATCH\"", with: "\"EXIT\"")
    return try Wire.decoder().decode(DecisionsV1.self, from: Data(text.utf8)).decisions
  }

  @Test("ENTER and EXIT decisions are marked: an ENTER at its entry, an EXIT at its candle's close")
  func decisionMarks() throws {
    let decisions = try decisions()
    let start = decisions[0].at.date
    let candle = Candle(start: start, end: start.addingTimeInterval(60), open: 12.3, high: 12.4, low: 12.2,
      close: 12.35, volume: 1000)
    let marks = ChartMarkers.decisionMarks(decisions: decisions, candles: [candle])
    #expect(marks.map(\.action) == [.exit, .enter, .enter])
    #expect(marks[0].price == 12.35)
    #expect(marks[0].observer == false)
    #expect(marks[1].price == ChartMarkers.double(try #require(decisions[1].entryPrice).value))
    #expect(marks[1].observer == true)
    #expect(marks[0].hollow == false)
    #expect(marks[1].hollow == true)
    // The fixture's third decision: the strategy's own ENTER, refused by the platform.
    #expect(marks[2].observer == false)
    #expect(marks[2].skipped == true)
  }

  @Test("The strategy's ENTER with a what-if entry was not taken: it is marked skipped and hollow")
  func skippedEnter() throws {
    let url = fixturesDir.appendingPathComponent("decisions-v1.json")
    let text = try String(contentsOf: url, encoding: .utf8)
      .replacingOccurrences(of: "\"observer\": true", with: "\"observer\": false")
    let decisions = try Wire.decoder().decode(DecisionsV1.self, from: Data(text.utf8)).decisions
    let mark = try #require(ChartMarkers.decisionMarks(decisions: decisions, candles: []).first)
    #expect(mark.action == .enter)
    #expect(mark.observer == false)
    #expect(mark.skipped == true)
    #expect(mark.hollow == true)
    let expected = L10n.Chart.skippedMark(String(localized: Verdict.enter.title))
    #expect(String(localized: mark.label) == String(localized: expected))
  }

  @Test("A decision with no price and no candle around it has no mark; WATCH is never marked")
  func decisionWithoutCandle() throws {
    let marks = ChartMarkers.decisionMarks(decisions: try decisions(), candles: [])
    #expect(marks.map(\.action) == [.enter, .enter])
    let watch = try fixture(DecisionsV1.self, "decisions-v1.json").decisions.filter { $0.action == .watch }
    #expect(ChartMarkers.decisionMarks(decisions: watch, candles: []).isEmpty)
  }
}
