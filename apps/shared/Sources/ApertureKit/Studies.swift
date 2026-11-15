import Foundation

// Chart studies drawn on the candles of the shown timeframe: moving averages, Bollinger bands,
// MACD, RSI and the slow stochastic. Unlike VWAP, the EMAs and ATR (Candles.swift, ATR.swift),
// which follow the bot's M1 definitions, these are the usual charting studies: they read the
// candles on screen, so a 5-minute chart shows a 5-minute RSI. No strategy reads them; they are
// only drawn. Values are nil where a study has too few candles to be defined.

/// Middle, upper and lower line of a Bollinger band at one candle.
public struct BollingerPoint: Hashable, Sendable {
  public let middle: Double
  public let upper: Double
  public let lower: Double
}

/// MACD line, its signal line and their difference (the histogram) at one candle.
public struct MACDPoint: Hashable, Sendable {
  public let macd: Double
  public let signal: Double
  public var histogram: Double { macd - signal }
}

/// %K and %D of the slow stochastic at one candle.
public struct StochasticPoint: Hashable, Sendable {
  public let k: Double
  public let d: Double
}

public enum Studies {
  /// Periods of the moving-average lines, in candles (short, medium, long).
  public static let movingAveragePeriods = [5, 10, 20]
  /// Period of the Bollinger middle line, in candles.
  public static let bollingerPeriod = 20
  /// Distance of the Bollinger lines from the middle, in standard deviations.
  public static let bollingerWidth = 2.0
  /// Fast and slow EMA periods of the MACD line, and the EMA period of its signal line, in candles.
  public static let macdFast = 12
  public static let macdSlow = 26
  public static let macdSignal = 9
  /// Period of the RSI, in candles (Wilder smoothing).
  public static let rsiPeriod = 14
  /// RSI levels drawn as bands: above `rsiHigh` reads overbought, below `rsiLow` oversold.
  public static let rsiHigh = 70.0
  public static let rsiLow = 30.0
  /// Look-back of the slow stochastic in candles, and the moving average that smooths %K and %D.
  public static let stochasticPeriod = 14
  public static let stochasticSmoothing = 3
  /// Stochastic levels drawn as bands.
  public static let stochasticHigh = 80.0
  public static let stochasticLow = 20.0
  /// Top of the RSI and stochastic scales (they run from 0 to 100).
  public static let oscillatorScale = 100.0

  /// Simple moving average: the mean of the last `period` values, from the `period`-th value on.
  public static func sma(_ values: [Double], period: Int) -> [Double?] {
    guard period > 0 else { return values.map { _ in nil } }
    var sum = 0.0
    return values.indices.map { index in
      sum += values[index]
      if index >= period { sum -= values[index - period] }
      return index + 1 >= period ? sum / Double(period) : nil
    }
  }

  /// SMA over values that start undefined (nil) and stay defined once they begin.
  static func sma(_ values: [Double?], period: Int) -> [Double?] {
    guard let first = values.firstIndex(where: { $0 != nil }) else { return values }
    let tail = sma(values[first...].compactMap { $0 }, period: period)
    return Array(repeating: nil, count: first) + tail
  }

  /// EMA seeded the charting way: undefined for the first `period - 1` values, the SMA of the first
  /// `period` values at the `period`-th, then `ema = prev + (value - prev) * 2 / (period + 1)`.
  /// The bot's own EMA (`Indicators.ema`, seeded with the first value) is a different definition.
  public static func ema(_ values: [Double], period: Int) -> [Double?] {
    guard period > 0, values.count >= period else { return values.map { _ in nil } }
    let weight = Indicators.emaSmoothing / Double(period + 1)
    var previous = values[..<period].reduce(0, +) / Double(period)
    var line: [Double?] = Array(repeating: nil, count: period - 1)
    line.append(previous)
    for value in values[period...] {
      previous += (value - previous) * weight
      line.append(previous)
    }
    return line
  }

  /// Bollinger bands: the SMA of the closes, and lines `width` population standard deviations
  /// above and below it.
  public static func bollinger(_ closes: [Double], period: Int, width: Double) -> [BollingerPoint?] {
    let middles = sma(closes, period: period)
    return closes.indices.map { index in
      guard let middle = middles[index] else { return nil }
      let window = closes[(index + 1 - period)...index]
      let variance = window.reduce(0) { $0 + ($1 - middle) * ($1 - middle) } / Double(period)
      let spread = variance.squareRoot() * width
      return BollingerPoint(middle: middle, upper: middle + spread, lower: middle - spread)
    }
  }

  /// MACD: fast EMA minus slow EMA of the closes (both SMA-seeded, `ema`), with an SMA-seeded EMA
  /// of that line as the signal. The MACD line is defined from the `slow`-th candle, the signal
  /// `signal - 1` candles later.
  public static func macd(_ closes: [Double], fast: Int, slow: Int, signal: Int) -> [MACDPoint?] {
    let fastLine = ema(closes, period: fast)
    let slowLine = ema(closes, period: slow)
    let macdLine: [Double?] = closes.indices.map { index in
      guard let fastValue = fastLine[index], let slowValue = slowLine[index] else { return nil }
      return fastValue - slowValue
    }
    guard let first = macdLine.firstIndex(where: { $0 != nil }) else { return macdLine.map { _ in nil } }
    let signalLine = ema(macdLine[first...].compactMap { $0 }, period: signal)
    return macdLine.indices.map { index in
      guard index >= first, let value = macdLine[index], let signalValue = signalLine[index - first] else { return nil }
      return MACDPoint(macd: value, signal: signalValue)
    }
  }

  /// RSI with Wilder smoothing: the first average gain and loss are simple averages of the first
  /// `period` changes, later ones `(prev * (period - 1) + change) / period`. 100 when nothing fell, 50 when
  /// nothing moved at all.
  public static func rsi(_ closes: [Double], period: Int) -> [Double?] {
    guard period > 0, closes.count > period else { return closes.map { _ in nil } }
    var values: [Double?] = Array(repeating: nil, count: period)
    var gain = 0.0
    var loss = 0.0
    for index in 1...period {
      let change = closes[index] - closes[index - 1]
      gain += max(change, 0)
      loss += max(-change, 0)
    }
    gain /= Double(period)
    loss /= Double(period)
    values.append(rsiValue(gain: gain, loss: loss))
    for index in (period + 1)..<closes.count {
      let change = closes[index] - closes[index - 1]
      gain = (gain * Double(period - 1) + max(change, 0)) / Double(period)
      loss = (loss * Double(period - 1) + max(-change, 0)) / Double(period)
      values.append(rsiValue(gain: gain, loss: loss))
    }
    return values
  }

  private static func rsiValue(gain: Double, loss: Double) -> Double {
    guard loss > 0 else { return gain > 0 ? oscillatorScale : oscillatorScale / 2 }
    return oscillatorScale - oscillatorScale / (1 + gain / loss)
  }

  /// Slow stochastic: fast %K is where the close sits in the high-low range of the last `period`
  /// candles (50 when the range is flat); slow %K is its `smoothing`-candle SMA and %D the SMA of
  /// slow %K.
  public static func slowStochastic(_ candles: [Candle], period: Int, smoothing: Int) -> [StochasticPoint?] {
    guard period > 0 else { return candles.map { _ in nil } }
    let fast: [Double?] = candles.indices.map { index in
      guard index + 1 >= period else { return nil }
      let window = candles[(index + 1 - period)...index]
      guard let high = window.map(\.high).max(), let low = window.map(\.low).min() else { return nil }
      guard high > low else { return oscillatorScale / 2 }
      return (candles[index].close - low) / (high - low) * oscillatorScale
    }
    let k = sma(fast, period: smoothing)
    let d = sma(k, period: smoothing)
    return candles.indices.map { index in
      guard let kValue = k[index], let dValue = d[index] else { return nil }
      return StochasticPoint(k: kValue, d: dValue)
    }
  }
}

/// Every study of one candle series, computed once per new candles (a redraw reuses them).
public struct CandleStudies: Hashable, Sendable {
  /// One line per `Studies.movingAveragePeriods` entry, in that order.
  public let movingAverages: [[Double?]]
  public let bollinger: [BollingerPoint?]
  public let macd: [MACDPoint?]
  public let rsi: [Double?]
  public let stochastic: [StochasticPoint?]

  public init(candles: [Candle]) {
    let closes = candles.map(\.close)
    movingAverages = Studies.movingAveragePeriods.map { Studies.sma(closes, period: $0) }
    bollinger = Studies.bollinger(closes, period: Studies.bollingerPeriod, width: Studies.bollingerWidth)
    macd = Studies.macd(closes, fast: Studies.macdFast, slow: Studies.macdSlow, signal: Studies.macdSignal)
    rsi = Studies.rsi(closes, period: Studies.rsiPeriod)
    stochastic = Studies.slowStochastic(
      candles, period: Studies.stochasticPeriod, smoothing: Studies.stochasticSmoothing)
  }
}

/// Change of a candle's close from the close before it, in price and as a share of that close.
public struct CandleChange: Hashable, Sendable {
  public let amount: Double
  /// The change as a share of the earlier close (0.05 is 5 %).
  public let fraction: Double
}

public extension Array where Element == Candle {
  /// Indices of the candle with the highest high and the one with the lowest low within `range`
  /// (the visible candles); the earliest wins a tie. Nil for an empty range.
  func extremes(in range: Range<Int>) -> (high: Int, low: Int)? {
    let range = range.clamped(to: indices)
    guard var high = range.first, var low = range.first else { return nil }
    for index in range {
      if self[index].high > self[high].high { high = index }
      if self[index].low < self[low].low { low = index }
    }
    return (high, low)
  }

  /// Change of the candle at `index` from the previous candle's close; the first candle compares
  /// with its own open. Nil when the earlier price is zero.
  func change(at index: Int) -> CandleChange? {
    guard indices.contains(index) else { return nil }
    let base = index > startIndex ? self[index - 1].close : self[index].open
    guard base != 0 else { return nil }
    let amount = self[index].close - base
    return CandleChange(amount: amount, fraction: amount / base)
  }
}
