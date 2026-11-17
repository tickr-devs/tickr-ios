import Foundation

/// Where a real time sits on a chart whose candles are drawn back to back (`ChartSeries.gapless`):
/// one candle length per candle from the first one's start, so nights, weekends, holidays and
/// minutes without trades take no room. A trade, a decision or the position's entry keeps its
/// place inside its candle; a time in a gap between candles sits at the boundary after the
/// candle before it.
public struct GaplessClock: Hashable, Sendable {
  /// Real start and end of each candle, oldest first.
  let starts: [Date]
  let ends: [Date]
  /// Drawn start of the first candle (its real start).
  let origin: Date
  /// Drawn length of every candle, in seconds.
  let length: TimeInterval

  /// The clock of `real`'s candles drawn back to back.
  public init(real: ChartSeries) {
    self.init(candles: real.candles, length: real.timeframe.seconds)
  }

  /// The clock of `candles` (real times, oldest first) drawn `length` seconds each.
  public init(candles: [Candle], length: TimeInterval) {
    starts = candles.map(\.start)
    ends = candles.map(\.end)
    origin = starts.first ?? .distantPast
    self.length = length
  }

  /// Index of the last candle starting at or before `time`; nil before the first.
  public func index(atOrBefore time: Date) -> Int? {
    var low = 0
    var high = starts.count
    while low < high {
      let middle = (low + high) / 2
      if starts[middle] <= time { low = middle + 1 } else { high = middle }
    }
    return low > 0 ? low - 1 : nil
  }

  /// Index of the candle whose real span holds `time`; nil in a gap or outside the candles.
  public func index(holding time: Date) -> Int? {
    guard let index = index(atOrBefore: time), time < ends[index] else { return nil }
    return index
  }

  /// The drawn time of real `time`; nil before the first candle.
  public func drawn(_ time: Date) -> Date? {
    guard let index = index(atOrBefore: time) else { return nil }
    let span = ends[index].timeIntervalSince(starts[index])
    let into = min(max(time.timeIntervalSince(starts[index]), 0), span)
    let share = span > 0 ? into / span : 0
    return origin.addingTimeInterval((Double(index) + share) * length)
  }

  /// The real time of drawn time `drawn`, inside the candle drawn there (the first or last
  /// candle's edge beyond them); nil without candles.
  public func real(_ drawn: Date) -> Date? {
    guard !starts.isEmpty, length > 0 else { return nil }
    let position = drawn.timeIntervalSince(origin) / length
    let index = min(max(Int(position.rounded(.down)), 0), starts.count - 1)
    let share = min(max(position - Double(index), 0), 1)
    return starts[index].addingTimeInterval(share * ends[index].timeIntervalSince(starts[index]))
  }
}
