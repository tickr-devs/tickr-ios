import Foundation
import Testing
@testable import TickrKit

@Suite("Where the chart's round markers go")
struct ChartMarkerLayoutTests {
  /// 15:00 UTC on the test day.
  static let base = Date(timeIntervalSince1970: 1_794_841_200)
  /// Seconds in one M1 candle.
  static let minute: TimeInterval = 60
  /// Ten minutes on screen from 15:10 and prices 9 to 21, 7 points per one-minute candle, 100
  /// points per dollar, 16-point markers moved 18 points at a time.
  static let scale = ChartMarkerLayout.Scale(
    shown: base.addingTimeInterval(10 * minute)...base.addingTimeInterval(20 * minute), prices: 9...21,
    pointsPerSecond: 7 / minute, pointsPerPrice: 100, side: 16, step: 18)

  func marker(_ id: String, _ minute: Double, _ price: Double) -> ChartMarkerLayout.Marker<String> {
    ChartMarkerLayout.Marker(id: id, time: Self.base.addingTimeInterval(minute * Self.minute), price: price)
  }

  @Test("A marker before or after the stretch on screen, or cut by its edge, is not drawn")
  func outsideTheScreen() {
    // Half a 16-point marker is 8 points, 8/7 of a minute: closer to an edge it would be cut.
    let lifts = ChartMarkerLayout.place([
      marker("before", 1, 10), marker("onLeftEdge", 10, 10), marker("cutLeft", 11.1, 10),
      marker("first", 11.2, 10), marker("last", 18.8, 20), marker("cutRight", 18.9, 20),
      marker("onRightEdge", 20, 20), marker("after", 21, 10),
    ], scale: Self.scale)
    #expect(lifts == ["first": 0, "last": 0])
  }

  @Test("Markers on the same and the next candle at one price are stacked one step apart")
  func sameAndAdjacentCandles() {
    let lifts = ChartMarkerLayout.place([
      marker("entry", 12, 10), marker("exit", 12, 10), marker("watch", 13, 10.01),
    ], scale: Self.scale)
    #expect(lifts == ["entry": 0, "exit": 1, "watch": 2])
  }

  @Test("In the upper half of the pane a stack grows down, never off the top")
  func upperHalfGrowsDown() {
    let lifts = ChartMarkerLayout.place([
      marker("entry", 12, 20), marker("exit", 12, 20), marker("watch", 13, 19.99),
    ], scale: Self.scale)
    #expect(lifts == ["entry": 0, "exit": -1, "watch": -2])
  }

  @Test("Markers far apart in time or in price stay where they belong")
  func farApart() {
    let lifts = ChartMarkerLayout.place([
      marker("entry", 12, 10), marker("later", 15, 10), marker("lower", 12, 9),
    ], scale: Self.scale)
    #expect(lifts == ["entry": 0, "later": 0, "lower": 0])
  }

  @Test("A lifted marker takes the first free step, not one past every earlier marker")
  func firstFreeStep() {
    // One step up from `entry` is 0.18 higher in price: `above` already sits there.
    let lifts = ChartMarkerLayout.place([
      marker("entry", 12, 10), marker("above", 12, 10.18), marker("exit", 12.5, 10),
    ], scale: Self.scale)
    #expect(lifts == ["entry": 0, "above": 0, "exit": 2])
  }

  @Test("Markers are placed oldest first whatever order they come in")
  func oldestFirst() {
    let lifts = ChartMarkerLayout.place([marker("exit", 12.5, 10), marker("entry", 12, 10)], scale: Self.scale)
    #expect(lifts == ["entry": 0, "exit": 1])
  }

  @Test("A pinned marker (a trade's entry) stays on its price; an older strategy mark moves instead")
  func pinnedStaysOnItsPrice() {
    // The strategy decided a minute before the fill, at nearly the same price: without the pin
    // the entry would be lifted off the price it states.
    let decision = marker("decision", 12, 10)
    let entry = ChartMarkerLayout.Marker(id: "entry", time: Self.base.addingTimeInterval(12.5 * Self.minute),
      price: 10, pinned: true)
    let lifts = ChartMarkerLayout.place([decision, entry], scale: Self.scale)
    #expect(lifts == ["entry": 0, "decision": 1])
  }

  @Test("A strategy mark that would move past the reach is left out; a pinned one never is")
  func reach() {
    let near = ChartMarkerLayout.Scale(
      shown: Self.scale.shown, prices: Self.scale.prices, pointsPerSecond: Self.scale.pointsPerSecond,
      pointsPerPrice: Self.scale.pointsPerPrice, side: Self.scale.side, step: Self.scale.step, reach: 1)
    let exit = ChartMarkerLayout.Marker(id: "exit", time: Self.base.addingTimeInterval(12.5 * Self.minute),
      price: 10, pinned: true)
    let lifts = ChartMarkerLayout.place([
      marker("watch", 12, 10), marker("enter", 12, 10), marker("watch2", 12.5, 10), exit,
    ], scale: near)
    // The pinned exit sits on its price; the watch moves one step; the rest would need more.
    #expect(lifts == ["exit": 0, "watch": 1])
  }
}
