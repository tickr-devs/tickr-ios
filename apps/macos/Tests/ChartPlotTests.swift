import Foundation
import Testing
@testable import TickrKit
@testable import TickrMac

@Suite("Chart plot lookups")
struct ChartPlotTests {
  /// An M1 bar starting `minute` minutes after 15:00 UTC.
  func bar(_ minute: Int) throws -> BarV1 {
    let price = try DecimalString("10")
    return BarV1(
      start: try WireTime(String(format: "2026-11-16T15:%02d:00.000Z", minute)),
      open: price, high: price, low: price, close: price, volume: try DecimalString("100"))
  }

  /// Minutes 0, 1, 2 and 10 (a gap after 2), as M1 candles.
  func plot() throws -> ChartPlot {
    ChartPlot(bars: try [0, 1, 2, 10].map(bar), timeframe: .m1, revision: 0)
  }

  func time(_ minute: Int, _ second: Int = 0) throws -> Date {
    try WireTime(String(format: "2026-11-16T15:%02d:%02d.000Z", minute, second)).date
  }

  @Test("A day's candles are drawn back to back: a minute without trades leaves no gap (mockup v113)")
  func dayIsContinuous() throws {
    let plot = try plot()
    #expect(plot.candles.map(\.start) == [try time(0), try time(1), try time(2), try time(3)])
    #expect(plot.starts == [try time(0), try time(1), try time(2), try time(10)])
    #expect(plot.drawnEnd == (try time(4)))
    // A real time keeps its place inside its candle; one in a gap sits at the next boundary.
    #expect(plot.drawnTime(try time(10, 30)) == (try time(3, 30)))
    #expect(plot.drawnTime(try time(5)) == (try time(3)))
    #expect(plot.sessions?.segments.map(\.session) == [.regular])
  }

  @Test("The pointed candle is the one whose drawn slot holds the time")
  func indexAtTime() throws {
    let plot = try plot()
    #expect(plot.index(at: try time(0)) == 0)
    #expect(plot.index(at: try time(1, 59)) == 1)
    #expect(plot.index(at: try time(3, 30)) == 3)
    #expect(plot.index(at: try time(4)) == nil)
  }

  @Test("A window holds the candles that overlap it")
  func indicesInWindow() throws {
    let plot = try plot()
    #expect(plot.indices(from: try time(0, 30), to: try time(2)) == 0..<2)
    #expect(plot.indices(from: try time(0), to: try time(30)) == 0..<4)
    #expect(plot.indices(from: try time(20), to: try time(30)).isEmpty)
  }

  @Test("Today's Day chart from market data reserves the rest of the day; the readout names the part of the day")
  func todayFromMarketData() throws {
    let json = """
      {"symbol": "ABCD", "interval": "5m", "range": "1d", "source": "webull", "cached_at": null, "cause": null,
       "api_version": 1, "pending": null, "bars": [
        {"start": "2026-11-16T09:00:00.000Z", "open": "10", "high": "10", "low": "10", "close": "10",
         "volume": "100", "extended": true, "session": "pre"},
        {"start": "2026-11-16T14:30:00.000Z", "open": "10", "high": "10", "low": "10", "close": "10",
         "volume": "100", "extended": false, "session": "regular"}]}
      """
    let chart = try Wire.decoder().decode(ChartV1.self, from: Data(json.utf8))
    let session = """
      {"day": "2026-11-16", "regular_open": "2026-11-16T14:30:00.000Z",
       "last_entry_at": "2026-11-16T20:30:00.000Z", "flatten_at": "2026-11-16T20:50:00.000Z",
       "regular_close": "2026-11-16T21:00:00.000Z", "premarket_open": "2026-11-16T09:00:00.000Z",
       "extended_close": "2026-11-17T01:00:00.000Z"}
      """
    let today = SessionSpan(try Wire.decoder().decode(SessionTimesV1.self, from: Data(session.utf8)))
    let plot = ChartPlot(chart: chart, today: today, revision: 0)
    // Two candles, then 14:35 to 16:00 regular (77 slots) and 16:00 to 20:00 after-hours (48).
    #expect(plot.sessions?.slots == 2 + 77 + 48)
    #expect(plot.drawnEnd == plot.slotTime(2 + 77 + 48))
    #expect(plot.sessions?.boundaries == [1, 79])
    #expect(plot.extendedClose == today.end)
    #expect(plot.timeText(0).hasSuffix(String(localized: ChartSessionWords.preMarket)))
    #expect(plot.timeText(1) == "09:30")
    // The bot says the session before had 5 after-hours candles: 5 slots, not 16:00-20:00.
    let withYesterday = try Wire.decoder().decode(ChartV1.self, from: Data(json.replacingOccurrences(
      of: "\"pending\": null", with: "\"pending\": null, \"previous_after_candles\": 5").utf8))
    #expect(ChartPlot(chart: withYesterday, today: today, revision: 0).sessions?.slots == 2 + 77 + 5)
    // Without today's session the chart ends after its last candle.
    #expect(ChartPlot(chart: chart, revision: 0).sessions?.slots == 2)
  }

  @Test("Every study line has one value per candle")
  func studiesPerCandle() throws {
    let plot = try plot()
    let count = plot.candles.count
    #expect(plot.movingAverages.allSatisfy { $0.count == count })
    for line in [plot.bollingerUpper, plot.bollingerMiddle, plot.bollingerLower, plot.macd, plot.macdSignal,
      plot.macdHistogram, plot.rsi, plot.stochasticK, plot.stochasticD] {
      #expect(line.count == count)
    }
  }

  @Test("Leaving a pane clears the hover only when the pointer is still in that pane")
  @MainActor
  func hoverAcrossPanes() {
    let pointer = ChartPointer()
    pointer.move(in: .price, to: CGPoint(x: 10, y: 20))
    pointer.move(in: .rsi, to: CGPoint(x: 10, y: 5))
    pointer.leave(.price)
    #expect(pointer.hover == ChartHover(pane: .rsi, location: CGPoint(x: 10, y: 5)))
    pointer.leave(.rsi)
    #expect(pointer.hover == nil)
  }

  @Test("A click holds the crosshair on its candle while the pointer moves away; the next lets it go")
  @MainActor
  func pinHoldsTheCandle() {
    let pointer = ChartPointer()
    pointer.togglePin()
    #expect(!pointer.pinned, "nothing pointed, nothing to hold")
    pointer.index = 7
    pointer.move(in: .price, to: CGPoint(x: 10, y: 20))
    pointer.togglePin()
    #expect(pointer.pinned)
    pointer.move(in: .rsi, to: CGPoint(x: 90, y: 5))
    pointer.leave(.price)
    #expect(pointer.hover == ChartHover(pane: .price, location: CGPoint(x: 10, y: 20)))
    #expect(pointer.index == 7)
    pointer.togglePin()
    #expect(!pointer.pinned)
    pointer.unpin()
    #expect(!pointer.pinned)
  }
}
