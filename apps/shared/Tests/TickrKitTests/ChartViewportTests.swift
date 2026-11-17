import Foundation
import Testing
@testable import TickrKit

@Suite("The chart's window keeps the person's zoom and scroll across new candles")
struct ChartViewportTests {
  static let origin = Date(timeIntervalSince1970: 1_794_841_200)  // 2026-11-16 15:00 UTC
  static let minute: TimeInterval = 60

  /// `count` M1 candles from 15:00 UTC on 2026-11-16 (`origin`).
  func series(_ count: Int) -> ChartSeries {
    let bars = (0..<count).compactMap { index -> BarV1? in
      guard let one = try? DecimalString("1"),
        let start = try? WireTime(String(format: "2026-11-16T%02d:%02d:00.000Z", 15 + index / 60, index % 60))
      else { return nil }
      return BarV1(start: start, open: one, high: one, low: one, close: one, volume: one)
    }
    return ChartSeries(bars: bars, timeframe: .m1)
  }

  @Test("A fitted chart stays fitted over the new candle and today's reserved slots")
  func fittedStaysFitted() {
    var viewport = ChartViewport()
    viewport.fit(series(100), slots: 300)
    viewport.take(series(101), slots: 300, previous: series(100))
    #expect(viewport.isFitted)
    #expect(viewport.visible == 300)
    #expect(viewport.scroll == Self.origin)
  }

  @Test("A zoomed window at the live edge follows the new candle to the right edge")
  func liveEdgeFollows() {
    var viewport = ChartViewport()
    viewport.fit(series(100), slots: 100)
    viewport.zoom(by: 0.2, series(100))
    #expect(!viewport.isFitted)
    viewport.followEnd(series(100))
    let visible = viewport.visible
    viewport.take(series(101), slots: 101, previous: series(100))
    #expect(viewport.visible == visible)
    #expect(viewport.showsEnd(series(101)))
  }

  @Test("A window scrolled back stays where the person left it")
  func scrolledBackStays() {
    var viewport = ChartViewport()
    viewport.fit(series(100), slots: 100)
    viewport.zoom(by: 0.2, series(100))
    viewport.scroll = Self.origin.addingTimeInterval(10 * Self.minute)
    let before = viewport
    viewport.take(series(101), slots: 101, previous: series(100))
    #expect(viewport == before)
  }

  @Test("Zooming all the way out again shows the whole range, today's reserve included")
  func zoomOutToFit() {
    var viewport = ChartViewport()
    viewport.fit(series(100), slots: 300)
    viewport.zoom(by: 0.1, series(100))
    #expect(viewport.canZoomOut(series(100)))
    viewport.zoom(by: 100, series(100))
    #expect(viewport.isFitted)
    #expect(!viewport.canZoomOut(series(100)))
  }
}
