import Foundation
import Testing
@testable import TickrKit

@Suite("Continuous all-session chart: slots, bands, boundaries and the time axis (mockup v113)")
struct SessionAxisTests {
  static let five: TimeInterval = 300

  func time(_ text: String) throws -> Date { try WireTime(text).date }

  /// A 5-minute candle at `text` in `session`.
  func candle(_ text: String, _ session: ChartSession) throws -> Candle {
    let start = try time(text)
    return Candle(
      start: start, end: start.addingTimeInterval(Self.five), open: 1, high: 1, low: 1, close: 1, volume: 1,
      extended: session != .regular, session: session)
  }

  /// Monday 2026-11-16 in New York (UTC-5): pre-market from 09:00Z, regular 14:30Z-21:00Z,
  /// after-hours to 01:00Z.
  func today() throws -> SessionSpan {
    let json = """
      {"day": "2026-11-16", "regular_open": "2026-11-16T14:30:00.000Z",
       "last_entry_at": "2026-11-16T20:30:00.000Z", "flatten_at": "2026-11-16T20:50:00.000Z",
       "regular_close": "2026-11-16T21:00:00.000Z", "premarket_open": "2026-11-16T09:00:00.000Z",
       "extended_close": "2026-11-17T01:00:00.000Z"}
      """
    return SessionSpan(try Wire.decoder().decode(SessionTimesV1.self, from: Data(json.utf8)))
  }

  @Test("A real time keeps its place inside its candle; one in a gap sits at the boundary after it")
  func gaplessClock() throws {
    #expect(GaplessClock(real: ChartSeries(chartBars: [], interval: .m5)).drawn(.now) == nil)
    let candles = [
      try candle("2026-11-13T20:55:00.000Z", .regular), try candle("2026-11-16T09:00:00.000Z", .pre),
    ]
    let clock = GaplessClock(candles: candles, length: Self.five)
    let origin = candles[0].start
    #expect(clock.drawn(try time("2026-11-13T20:57:30.000Z")) == origin.addingTimeInterval(150))
    // Over the weekend: at the end of Friday's last candle, the start of Monday's first.
    #expect(clock.drawn(try time("2026-11-14T12:00:00.000Z")) == origin.addingTimeInterval(Self.five))
    #expect(clock.drawn(try time("2026-11-16T09:01:00.000Z")) == origin.addingTimeInterval(Self.five + 60))
    #expect(clock.drawn(try time("2026-11-13T20:00:00.000Z")) == nil)
    #expect(clock.real(origin.addingTimeInterval(Self.five + 60)) == (try time("2026-11-16T09:01:00.000Z")))
    #expect(clock.index(holding: try time("2026-11-14T12:00:00.000Z")) == nil)
    #expect(clock.index(holding: try time("2026-11-16T09:04:00.000Z")) == 1)
  }

  @Test("Slots follow each other through the parts of the day and the nights between days")
  func segmentsOverFiveDays() throws {
    let candles = [
      try candle("2026-11-13T20:55:00.000Z", .regular), try candle("2026-11-13T21:00:00.000Z", .after),
      try candle("2026-11-16T09:00:00.000Z", .pre), try candle("2026-11-16T09:05:00.000Z", .pre),
      try candle("2026-11-16T14:30:00.000Z", .regular),
    ]
    let axis = SessionAxis(candles: candles, timeframe: .m5)
    #expect(axis.slots == 5)
    #expect(axis.segments.map(\.first) == [0, 1, 2, 4])
    #expect(axis.segments.map(\.session) == [.regular, .after, .pre, .regular])
    #expect(axis.segments.map(\.newDay) == [true, false, true, false])
    #expect(axis.boundaries == [1, 2, 4])
    #expect(axis.bands.map(\.segment.first) == [1, 2])
    #expect(axis.bands.map(\.end) == [2, 4])
    let labels = axis.labels(range: .fiveDays, candles: candles, extendedClose: nil, hourStep: nil)
    #expect(labels.map(\.slot) == [0, 2])
    #expect(labels.allSatisfy { $0.anchor == .leading })
  }

  @Test("Today's Day chart reserves the rest of the day, its parts on their own segments")
  func todayReservesTheDay() throws {
    // 10:00 New York: pre-market from 04:00, the regular session from 09:30.
    let candles = [try candle("2026-11-16T09:00:00.000Z", .pre), try candle("2026-11-16T14:55:00.000Z", .regular)]
    let axis = SessionAxis(candles: candles, timeframe: .m5, today: try today())
    // 15:00Z to 21:00Z is 72 regular slots after the last candle, then 48 after-hours ones.
    #expect(axis.candleSlots == 2)
    #expect(axis.slots == 2 + 72 + 48)
    #expect(axis.segments.map(\.session) == [.pre, .regular, .after])
    #expect(axis.segments.map(\.future) == [false, false, true])
    #expect(axis.segments[2].first == 74)
    #expect(axis.realTime(ofSlot: 74, candles: candles) == (try time("2026-11-16T21:00:00.000Z")))
    let labels = axis.labels(
      range: .oneDay, candles: candles, extendedClose: try today().end, hourStep: 60)
    #expect(labels.first == SessionAxis.Label(
      slot: 0, kind: .sessionStart(.pre, try time("2026-11-16T09:00:00.000Z"), atEdge: true), anchor: .leading))
    #expect(labels.contains(SessionAxis.Label(
      slot: 74, kind: .sessionStart(.after, try time("2026-11-16T21:00:00.000Z"), atEdge: false), anchor: .centre)))
    #expect(labels.contains(SessionAxis.Label(slot: axis.slots, kind: .end(try today().end), anchor: .trailing)))
    // Round hours fall on reserved slots too: 12:00 New York is slot 2 + (17:00Z - 15:00Z) / 5 min.
    #expect(labels.contains(SessionAxis.Label(
      slot: 26, kind: .hour(try time("2026-11-16T17:00:00.000Z")), anchor: .centre)))
  }

  /// Hourly candles of the regular session are cut from its 09:30 open (src/tickr/api/chart.py),
  /// so none opens on a round hour: the axis steps from the open instead of showing nothing
  /// between 09:30 and 16:00.
  @Test("Hourly regular candles get labels stepped from the open")
  func hourlyCandlesFromTheOpen() throws {
    let starts = ["14:30", "15:30", "16:30", "17:30", "18:30", "19:30", "20:30"]
    let candles = try starts.map { try candle("2026-11-16T\($0):00.000Z", .regular) }
    let axis = SessionAxis(candles: candles, timeframe: .h1)
    let labels = axis.labels(range: .oneDay, candles: candles, extendedClose: nil, hourStep: 60)
    let hours = labels.compactMap { label -> Int? in
      if case .hour = label.kind { return label.slot }
      return nil
    }
    #expect(hours == Array(1..<starts.count))
  }

  @Test("Today's after-hours reserves as many slots as the session before had, less those already drawn")
  func afterHoursAsYesterday() throws {
    let morning = [try candle("2026-11-16T09:00:00.000Z", .pre), try candle("2026-11-16T14:55:00.000Z", .regular)]
    let axis = SessionAxis(candles: morning, timeframe: .m5, today: try today(), afterSlots: 7)
    // 72 regular slots to 16:00, then 7 after-hours ones (yesterday's), not the 48 of 16:00-20:00.
    #expect(axis.slots == 2 + 72 + 7)
    #expect(axis.segments.last?.session == .after)
    #expect(axis.segments.last.map { $0.last - $0.first + 1 } == 7)
    let evening = morning + [try candle("2026-11-16T21:00:00.000Z", .after), try candle("2026-11-16T21:30:00.000Z", .after)]
    let later = SessionAxis(candles: evening, timeframe: .m5, today: try today(), afterSlots: 7)
    #expect(later.slots == evening.count + 5)
    // Busier than yesterday: nothing more is reserved.
    #expect(SessionAxis(candles: evening, timeframe: .m5, today: try today(), afterSlots: 1).slots == evening.count)
  }

  @Test("A past day reserves nothing; round hours are a whole number of candles apart")
  func pastDayAndSteps() throws {
    let candles = [try candle("2026-11-13T14:30:00.000Z", .regular)]
    #expect(SessionAxis(candles: candles, timeframe: .m5, today: try today()).slots == 1)
    #expect(SessionAxis.hourStep(timeframe: .m5, pointsPerSlot: 4, least: 64) == 120)
    #expect(SessionAxis.hourStep(timeframe: .m30, pointsPerSlot: 40, least: 64) == 60)
    #expect(SessionAxis.hourStep(timeframe: .h1, pointsPerSlot: 1, least: 64) == 240)
    #expect(SessionAxis.hourStep(timeframe: .d1, pointsPerSlot: 1, least: 64) == nil)
  }

  @Test("Labels are placed in order, never closer than the gap; a session label falls back to its short form")
  func placement() {
    let items = [
      AxisLabelPlacer.Item(x: 0, widths: [60, 30], anchor: .leading),
      AxisLabelPlacer.Item(x: 100, widths: [30], anchor: .centre),
      AxisLabelPlacer.Item(x: 300, widths: [70, 30], anchor: .trailing),
      AxisLabelPlacer.Item(x: 70, widths: [30], anchor: .centre),
      AxisLabelPlacer.Item(x: 200, widths: [30], anchor: .centre),
    ]
    let placed = AxisLabelPlacer.place(items, width: 300, gap: 8, inset: 0)
    #expect(placed.map(\.item) == [0, 1, 2, 4])
    #expect(placed.map(\.left) == [0, 85, 230, 185])
    let crowded = [
      AxisLabelPlacer.Item(x: 0, widths: [30], anchor: .leading),
      AxisLabelPlacer.Item(x: 34, widths: [60, 20], anchor: .leading),
    ]
    // The long form would start 4 points after the first label: the short one fits after a gap.
    let tight = AxisLabelPlacer.place(crowded, width: 300, gap: 2, inset: 0)
    #expect(tight.map(\.text) == [0, 0])
    #expect(AxisLabelPlacer.place(crowded, width: 300, gap: 8, inset: 0).map(\.item) == [0])
    // A long pre-market label would leave no room for "09:30": every label takes its short form.
    let long = [
      AxisLabelPlacer.Item(x: 0, widths: [90, 30], anchor: .leading, required: true),
      AxisLabelPlacer.Item(x: 80, widths: [30], anchor: .centre, required: true),
    ]
    let both = AxisLabelPlacer.place(long, width: 300, gap: 6, inset: 0)
    #expect(both.map(\.item) == [0, 1])
    #expect(both.map(\.text) == [1, 0])
    let edge = [AxisLabelPlacer.Item(x: 0, widths: [30], anchor: .centre)]
    let inset = AxisLabelPlacer.place(edge, width: 300, gap: 6, inset: 8)
    #expect(inset.first?.left == 8)
  }
}
