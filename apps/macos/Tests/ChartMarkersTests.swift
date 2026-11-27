import Foundation
import Testing
import TickrDesign
@testable import TickrKit
@testable import TickrScreens

@Suite("Trade marks and position levels on the chart")
struct ChartMarkersTests {
  @Test("Each closed trade has an entry and an exit mark coloured by its result")
  func marks() throws {
    let trades = try fixture(DayV1.self, "day-v1.json").trades
    let marks = ChartMarkers.marks(trades: trades, place: { $0 })
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

  @Test("Marks sit at their drawn times on candles drawn back to back; one before the first candle has none")
  func marksAtDrawnTimes() throws {
    let trades = try fixture(DayV1.self, "day-v1.json").trades
    let trade = try #require(trades.first)
    let shift: TimeInterval = 3_600
    let marks = ChartMarkers.marks(trades: [trade], place: { $0 == trade.openedAt.date ? nil : $0 - shift })
    #expect(marks.map(\.kind).count == 1)
    #expect(marks.first?.time == trade.closedAt.date - shift)
  }

  @Test("No position, no levels")
  func noPosition() {
    #expect(ChartMarkers.levels(position: nil, place: { $0 }).isEmpty)
  }

  @Test("An open position shows its entry and its stop; an unverified stop is marked so")
  func levels() throws {
    let position = try #require(try fixture(StatusResponseV1.self, "status-response-v1.json").status?.position)
    let row = PositionRow(position: position, lastBarClose: nil, lastBarAt: nil, closes: [])
    let levels = ChartMarkers.levels(position: row, place: { $0 })
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
    let marks = ChartMarkers.decisionMarks(decisions: decisions, real: [candle], place: { $0 })
    // The fixture's second decision is a shadow strategy's ENTER: it never trades, so no mark.
    #expect(marks.map(\.id) == [0, 2])
    #expect(marks.map(\.action) == [.exit, .enter])
    #expect(marks[0].price == 12.35)
    #expect(marks[0].hollow == false)
    // The fixture's third decision: the strategy's own ENTER, refused by the platform.
    #expect(marks[1].price == ChartMarkers.double(try #require(decisions[2].entryPrice).value))
    #expect(marks[1].skipped == true)
    #expect(marks[1].hollow == true)
  }

  @Test("The strategy's ENTER with a what-if entry was not taken: it is marked skipped and hollow")
  func skippedEnter() throws {
    let url = fixturesDir.appendingPathComponent("decisions-v1.json")
    let text = try String(contentsOf: url, encoding: .utf8)
      .replacingOccurrences(of: "\"observer\": true", with: "\"observer\": false")
    let decisions = try Wire.decoder().decode(DecisionsV1.self, from: Data(text.utf8)).decisions
    let mark = try #require(ChartMarkers.decisionMarks(decisions: decisions, real: [], place: { $0 }).first)
    #expect(mark.action == .enter)
    #expect(mark.skipped == true)
    #expect(mark.hollow == true)
    let expected = L10n.Chart.skippedMark(String(localized: Verdict.enter.title))
    #expect(String(localized: mark.label) == String(localized: expected))
  }

  @Test("The strategy's first WATCH is marked at its candle's close; a WATCH after IGNORE bars is the same watch")
  func watchMarks() throws {
    let url = fixturesDir.appendingPathComponent("decisions-v1.json")
    let watch = try Wire.decoder().decode(DecisionsV1.self, from: Data(contentsOf: url)).decisions
      .filter { $0.action == .watch }
    let first = try #require(watch.first)
    let start = first.at.date
    let candle = Candle(start: start, end: start.addingTimeInterval(60), open: 12.3, high: 12.4, low: 12.2,
      close: 12.35, volume: 1000)
    // The same WATCH twice in a row (as after an IGNORE bar in between) is one mark.
    let marks = ChartMarkers.decisionMarks(decisions: watch + watch, real: [candle], place: { $0 })
    #expect(marks.map(\.action) == [.watch])
    #expect(marks[0].price == 12.35)
    #expect(marks[0].id == 0)
  }

  @Test("A decision with no price and no candle around it has no mark; a WATCH without a candle neither")
  func decisionWithoutCandle() throws {
    let marks = ChartMarkers.decisionMarks(decisions: try decisions(), real: [], place: { $0 })
    // Only the strategy's skipped ENTER has its own price; the shadow strategy's ENTER is left out.
    #expect(marks.map(\.action) == [.enter])
    let watch = try fixture(DecisionsV1.self, "decisions-v1.json").decisions.filter { $0.action == .watch }
    #expect(ChartMarkers.decisionMarks(decisions: watch, real: [], place: { $0 }).isEmpty)
  }

  @Test("The highest high and lowest low on screen are plain tags on the price axis, one for a flat stretch")
  @MainActor
  func extremeTags() {
    let start = Date(timeIntervalSince1970: 0)
    let candles = [(12.40, 12.10), (12.80, 12.30), (12.50, 11.90)].enumerated().map { index, range in
      Candle(start: start.addingTimeInterval(Double(index) * 60), end: start.addingTimeInterval(Double(index + 1) * 60),
        open: 12.3, high: range.0, low: range.1, close: 12.3, volume: 1000)
    }
    let tags = CandleChart.extremeTags(candles, in: candles.indices)
    #expect(tags.map(\.value) == [12.80, 11.90])
    #expect(tags.filter { !$0.plain }.isEmpty)
    #expect(tags[0].text == String(localized: L10n.Chart.highTag(Money.price(12.80 as Double))))
    // Only the candles on screen count.
    #expect(CandleChart.extremeTags(candles, in: 0..<1).map(\.value) == [12.40, 12.10])
    let flat = [Candle(start: start, end: start.addingTimeInterval(60), open: 5, high: 5, low: 5, close: 5, volume: 1)]
    #expect(CandleChart.extremeTags(flat, in: flat.indices).count == 1)
  }
}
