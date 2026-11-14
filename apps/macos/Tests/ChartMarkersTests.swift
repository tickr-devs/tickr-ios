@testable import ApertureKit
@testable import ApertureMac
import Foundation
import Testing

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
}
