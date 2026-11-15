import Foundation

// Chart data built from the M1 bars of GET /bars: candles in a chosen timeframe and the indicator
// lines drawn over them. The API serves M1 only; clients aggregate and compute indicators
// themselves (docs/api.md, "History"). Indicator lines follow the bot's own definitions in
// src/aperture/strategy/indicators.py: they are computed on the M1 bars and each candle shows the
// value at its last M1 bar, so a line reads the same in every timeframe and matches what the
// strategy saw. Values are `Double` because they are only drawn, never sent or added up as money.

/// Candle length. The raw value is the length in minutes.
public enum Timeframe: Int, CaseIterable, Identifiable, Sendable {
  case m1 = 1
  case m5 = 5
  case m15 = 15
  case m30 = 30
  case h1 = 60

  public var id: Int { rawValue }

  /// Seconds in one minute (unit factor).
  static let secondsPerMinute = 60

  /// Minutes in one hour (unit factor).
  static let minutesPerHour = 60

  /// Whole hours in one candle, or nil when the length is not a whole number of hours (1h reads
  /// better than 60m).
  public var hours: Int? { rawValue % Self.minutesPerHour == 0 ? rawValue / Self.minutesPerHour : nil }

  /// Length of one candle in seconds.
  public var seconds: TimeInterval { TimeInterval(rawValue * Self.secondsPerMinute) }
}

/// One candle; `start` is its opening time, `end` the opening time of the next.
public struct Candle: Hashable, Sendable, Identifiable {
  public let start: Date
  public let end: Date
  public let open: Double
  public let high: Double
  public let low: Double
  public let close: Double
  public let volume: Double

  public var id: Date { start }
  /// Whether the candle closed at or above its open.
  public var isUp: Bool { close >= open }

  public init(start: Date, end: Date, open: Double, high: Double, low: Double, close: Double, volume: Double) {
    self.start = start
    self.end = end
    self.open = open
    self.high = high
    self.low = low
    self.close = close
    self.volume = volume
  }
}

/// Candles of one timeframe with the indicator lines, one line value per candle (nil where the
/// line is not defined yet).
public struct ChartSeries: Hashable, Sendable {
  public let timeframe: Timeframe
  public let candles: [Candle]
  public let vwap: [Double?]
  public let fastEMA: [Double?]
  public let slowEMA: [Double?]

  /// Candles and lines from one day's M1 bars (oldest first, as GET /bars serves them).
  public init(bars: [BarV1], timeframe: Timeframe) {
    let groups = Candles.groups(bars, timeframe: timeframe)
    let closes = bars.map { Candles.double($0.close) }
    let vwap = Indicators.vwap(bars)
    let fast = Indicators.ema(closes, period: Indicators.fastEMAPeriod)
    let slow = Indicators.ema(closes, period: Indicators.slowEMAPeriod)
    self.timeframe = timeframe
    candles = groups.map(\.candle)
    self.vwap = groups.map { vwap[$0.lastBar] }
    fastEMA = groups.map { fast[$0.lastBar] }
    slowEMA = groups.map { slow[$0.lastBar] }
  }
}

public enum Candles {
  /// Candles of `timeframe` from M1 bars (oldest first). A candle starts on a whole multiple of
  /// the timeframe (09:35, 09:40 for M5) and holds the bars that start inside it; a candle without
  /// bars is not made, so gaps stay gaps.
  public static func make(_ bars: [BarV1], timeframe: Timeframe) -> [Candle] {
    groups(bars, timeframe: timeframe).map(\.candle)
  }

  /// Each candle with the index of its last M1 bar in `bars`.
  static func groups(_ bars: [BarV1], timeframe: Timeframe) -> [(candle: Candle, lastBar: Int)] {
    var groups: [(candle: Candle, lastBar: Int)] = []
    let length = timeframe.seconds
    for (index, bar) in bars.enumerated() {
      let start = Date(timeIntervalSince1970: (bar.start.date.timeIntervalSince1970 / length).rounded(.down) * length)
      let high = double(bar.high)
      let low = double(bar.low)
      let close = double(bar.close)
      let volume = double(bar.volume)
      if let last = groups.last?.candle, last.start == start {
        let merged = Candle(
          start: start, end: last.end, open: last.open, high: max(last.high, high),
          low: min(last.low, low), close: close, volume: last.volume + volume)
        groups[groups.count - 1] = (merged, index)
      } else {
        let candle = Candle(
          start: start, end: start.addingTimeInterval(length), open: double(bar.open), high: high,
          low: low, close: close, volume: volume)
        groups.append((candle, index))
      }
    }
    return groups
  }

  static func double(_ value: DecimalString) -> Double {
    NSDecimalNumber(decimal: value.value).doubleValue
  }
}

/// The bot's indicator definitions (src/aperture/strategy/indicators.py), one value per M1 bar.
public enum Indicators {
  /// Period of the fast EMA line, in M1 bars (price-action-v1's fast_ema_period).
  public static let fastEMAPeriod = 9
  /// Period of the slow EMA line, in M1 bars (price-action-v1's slow_ema_period).
  public static let slowEMAPeriod = 20
  /// Smoothing factor of an EMA: each new value weighs smoothing / (period + 1).
  static let emaSmoothing = 2.0
  /// Number of prices averaged in the typical price (high, low, close).
  static let typicalPriceParts = 3.0

  /// vwap_series: session VWAP of the typical price, cumulative from the first bar given (a day's
  /// bars are one session). Nil while cumulative volume is zero.
  public static func vwap(_ bars: [BarV1]) -> [Double?] {
    var priceVolume = 0.0
    var volume = 0.0
    return bars.map { bar in
      let typical = (Candles.double(bar.high) + Candles.double(bar.low) + Candles.double(bar.close)) / typicalPriceParts
      let barVolume = Candles.double(bar.volume)
      priceVolume += typical * barVolume
      volume += barVolume
      return volume > 0 ? priceVolume / volume : nil
    }
  }

  /// ema_series: seeded with the first value, then `ema = prev + (value - prev) * 2 / (period + 1)`.
  /// The bot also feeds prior sessions, so the chart's line, which starts at the day's first bar,
  /// matches the bot's once the seed has decayed (a few periods in).
  public static func ema(_ values: [Double], period: Int) -> [Double?] {
    guard period > 0 else { return values.map { _ in nil } }
    let weight = emaSmoothing / Double(period + 1)
    var previous: Double?
    return values.map { value in
      let next = previous.map { $0 + (value - $0) * weight } ?? value
      previous = next
      return next
    }
  }
}
