import Foundation
import Testing
@testable import TickrKit

@Suite("Decision marks on the chart's candles")
struct ChartEventsTests {
  /// 15:00 UTC on the test day.
  static let base = Date(timeIntervalSince1970: 1_794_841_200)
  /// Seconds in one M1 candle.
  static let minute: TimeInterval = 60

  /// A decision at `minute` past 15:00 UTC; `admission` as the bot records it.
  func decision(
    _ minute: Int,
    _ action: String,
    observer: Bool = false,
    admission: String = "not_applicable"
  ) throws -> DecisionV1 {
    let json = """
      {"at": "2026-11-16T15:\(String(format: "%02d", minute)):30.000Z", "action": "\(action)",
       "strategy": {"name": "price-action", "version": "2"}, "observer": \(observer), "checks": [],
       "entry_price": null, "stop_price": null, "admission": "\(admission)", "refusal_cause": null,
       "refusal": null}
      """
    return try Wire.decoder().decode(DecisionV1.self, from: Data(json.utf8))
  }

  /// `count` M1 candles from 15:00 UTC, each closing at 10 plus its index.
  func candles(_ count: Int, length: TimeInterval = minute) -> [Candle] {
    (0..<count).map { index in
      let start = Self.base.addingTimeInterval(Double(index) * length)
      let close = 10 + Double(index)
      return Candle(start: start, end: start.addingTimeInterval(length), open: close, high: close, low: close,
        close: close, volume: 1)
    }
  }

  @Test("On candles drawn back to back a mark sits on the drawn candle of its real candle's index")
  func drawnCandles() throws {
    // Real candles an hour apart; drawn back to back a minute apart.
    let real = candles(3, length: 3_600).map {
      Candle(start: $0.start, end: $0.start.addingTimeInterval(Self.minute), open: $0.open, high: $0.high,
        low: $0.low, close: $0.close, volume: 1)
    }
    let drawn = candles(3)
    let events = ChartEvent.make([try decision(0, "WATCH")], candles: real, drawn: drawn)
    #expect(events.map(\.candle) == [drawn[0].start])
    // 16:00 UTC is the second real candle, drawn at 15:01.
    let json = """
      {"at": "2026-11-16T16:00:30.000Z", "action": "ENTER",
       "strategy": {"name": "price-action", "version": "2"}, "observer": false, "checks": [],
       "entry_price": null, "stop_price": null, "admission": "taken", "refusal_cause": null, "refusal": null}
      """
    let enter = try Wire.decoder().decode(DecisionV1.self, from: Data(json.utf8))
    let marked = ChartEvent.make([enter], candles: real, drawn: drawn)
    #expect(marked.map(\.candle) == [drawn[1].start])
    #expect(marked.map(\.price) == [11])
  }

  @Test("A run of WATCH is marked once at its start; a taken and a refused ENTER each get a mark")
  func runs() throws {
    let events = ChartEvent.make([
      try decision(1, "WATCH"), try decision(2, "WATCH"), try decision(3, "WATCH"),
      try decision(4, "ENTER", admission: "taken"), try decision(5, "HOLD"),
      try decision(6, "ENTER", admission: "refused"), try decision(7, "EXIT"),
    ], candles: candles(10))
    #expect(events.map(\.kind) == [.watch, .enter, .refused])
    #expect(events.map(\.price) == [11, 14, 16])
    #expect(events[0].candle == Self.base.addingTimeInterval(Self.minute))
  }

  /// The owner's ABX day (2026-11-17): WATCH bars broken by IGNORE and HOLD, and WATCH bars whose
  /// checks changed, drew dozens of watch dots. One watch is one mark until something else.
  @Test("IGNORE and HOLD between WATCH bars do not start a new watch; an EXIT does")
  func watchThroughIgnore() throws {
    let events = ChartEvent.make([
      try decision(1, "WATCH"), try decision(2, "IGNORE"), try decision(3, "WATCH"), try decision(4, "HOLD"),
      try decision(5, "WATCH"), try decision(6, "ENTER", admission: "taken"), try decision(7, "EXIT"),
      try decision(8, "WATCH"), try decision(9, "IGNORE"), try decision(9, "WATCH"),
    ], candles: candles(12))
    #expect(events.map(\.kind) == [.watch, .enter, .watch])
    #expect(events.map(\.price) == [11, 16, 18])
  }

  @Test("Observers are left out, and so is a decision outside every candle")
  func outside() throws {
    let events = ChartEvent.make([
      try decision(1, "ENTER", observer: true, admission: "not_evaluated"),
      try decision(2, "WATCH"), try decision(20, "ENTER", admission: "taken"),
    ], candles: candles(10))
    #expect(events.map(\.kind) == [.watch])
  }

  @Test("An ENTER the platform never evaluated is not marked as an entry")
  func notEvaluated() throws {
    let events = ChartEvent.make([
      try decision(1, "ENTER", admission: "not_evaluated"), try decision(2, "ENTER", admission: "not_applicable"),
    ], candles: candles(10))
    #expect(events.isEmpty)
  }

  @Test("Two runs of one kind in one longer candle make one mark")
  func sameCandle() throws {
    let events = ChartEvent.make([
      try decision(1, "WATCH"), try decision(2, "HOLD"), try decision(3, "WATCH"),
    ], candles: candles(2, length: Timeframe.m5.seconds))
    #expect(events.count == 1)
    #expect(events[0].price == 10)
  }
}
