@testable import ApertureKit
@testable import ApertureMac
import Foundation
import Testing

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

  @Test("The pointed candle is the one whose slot holds the time; a gap points at none")
  func indexAtTime() throws {
    let plot = try plot()
    #expect(plot.index(at: try time(0)) == 0)
    #expect(plot.index(at: try time(1, 59)) == 1)
    #expect(plot.index(at: try time(5)) == nil)
    #expect(plot.index(at: try time(10, 30)) == 3)
    #expect(plot.index(at: try time(11)) == nil)
  }

  @Test("A window holds the candles that overlap it, and none when it falls in a gap")
  func indicesInWindow() throws {
    let plot = try plot()
    #expect(plot.indices(from: try time(0, 30), to: try time(2)) == 0..<2)
    #expect(plot.indices(from: try time(0), to: try time(30)) == 0..<4)
    #expect(plot.indices(from: try time(4), to: try time(8)).isEmpty)
    #expect(plot.indices(from: try time(20), to: try time(30)).isEmpty)
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
}
