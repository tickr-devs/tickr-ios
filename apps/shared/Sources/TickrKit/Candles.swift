import Foundation

// Chart data built from the M1 bars of GET /bars: candles in a chosen timeframe and the indicator
// lines drawn over them. The API serves M1 only; clients aggregate and compute indicators
// themselves (docs/api.md, "History"). Indicator lines follow the bot's own definitions in
// src/tickr/strategy/indicators.py: they are computed on the M1 bars and each candle shows the
// value at its last M1 bar, so a line reads the same in every timeframe and matches what the
// strategy saw. Values are `Double` because they are only drawn, never sent or added up as money.

/// Candle length, named as chart-v1 names its `interval`: minutes or an hour inside a session, or
/// one calendar day, week or month. The app makes the intraday lengths itself from GET /bars M1
/// bars; GET /chart serves every length already merged.
public enum Timeframe: String, Codable, CaseIterable, Identifiable, Sendable {
  case m1 = "1m"
  case m5 = "5m"
  case m30 = "30m"
  case h1 = "1h"
  case d1 = "1d"
  case w1 = "1w"
  case mo1 = "1mo"

  public var id: String { rawValue }

  /// Minutes in one M5 and one M30 candle.
  static let fiveMinutes = 5
  static let thirtyMinutes = 30

  /// Seconds in one minute (unit factor).
  static let secondsPerMinute = 60

  /// Minutes in one hour (unit factor).
  static let minutesPerHour = 60

  /// Minutes in one day (unit factor).
  static let minutesPerDay = 1_440

  /// Days in one weekly candle, and the nominal days of a monthly one. Only for a candle's slot
  /// width; a monthly candle's dates come from the calendar (`Candles.end`).
  static let daysPerWeek = 7
  static let nominalDaysPerMonth = 30

  /// Minutes in one candle inside a session; nil for a daily, weekly or monthly candle.
  public var minutes: Int? {
    switch self {
    case .m1: 1
    case .m5: Self.fiveMinutes
    case .m30: Self.thirtyMinutes
    case .h1: Self.minutesPerHour
    case .d1, .w1, .mo1: nil
    }
  }

  /// Whether candles of this length lie inside one session (not daily, weekly or monthly).
  public var isIntraday: Bool { minutes != nil }

  /// Whole hours in one candle, or nil when the length is not a whole number of hours (1h reads
  /// better than 60m) or is not intraday.
  public var hours: Int? {
    minutes.flatMap { $0 % Self.minutesPerHour == 0 ? $0 / Self.minutesPerHour : nil }
  }

  /// Length of one candle in seconds; nominal for a monthly candle (see `nominalDaysPerMonth`).
  public var seconds: TimeInterval {
    let minutes: Int =
      switch self {
      case .d1: Self.minutesPerDay
      case .w1: Self.minutesPerDay * Self.daysPerWeek
      case .mo1: Self.minutesPerDay * Self.nominalDaysPerMonth
      default: self.minutes ?? Self.minutesPerDay
      }
    return TimeInterval(minutes * Self.secondsPerMinute)
  }
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
  /// Whether the candle lies outside the regular session (chart-v1's `extended`; GET /bars
  /// candles leave it false).
  public let extended: Bool
  /// The part of the day the candle lies in (chart-v1's `session`); nil for daily, weekly and
  /// monthly candles, and for an extended candle of an API too old to say which part.
  public let session: ChartSession?

  public var id: Date { start }
  /// Whether the candle closed at or above its open.
  public var isUp: Bool { close >= open }

  public init(
    start: Date, end: Date, open: Double, high: Double, low: Double, close: Double, volume: Double,
    extended: Bool = false, session: ChartSession? = nil
  ) {
    self.extended = extended
    self.session = session
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

  /// Candles and lines of a chart-v1 answer, one candle per bar: the bot has already merged them
  /// into `chart.interval`. With no M1 bars, the lines run over the candles: VWAP restarts each
  /// New York day and is nil for daily, weekly and monthly candles (a VWAP across sessions means
  /// nothing), and the EMAs use the candles' closes.
  public init(chart: ChartV1) {
    self.init(chartBars: chart.bars, interval: chart.interval)
  }

  /// Candles and lines of chart-v1 bars in `interval` (see `init(chart:)`).
  init(chartBars: [ChartBarV1], interval: Timeframe) {
    let candles = chartBars.map { bar in
      let start = bar.start.date
      return Candle(
        start: start, end: Candles.end(of: start, timeframe: interval), open: Candles.double(bar.open),
        high: Candles.double(bar.high), low: Candles.double(bar.low), close: Candles.double(bar.close),
        volume: Candles.double(bar.volume), extended: bar.extended,
        session: bar.session ?? (interval.isIntraday && !bar.extended ? .regular : nil))
    }
    let closes = candles.map(\.close)
    timeframe = interval
    self.candles = candles
    vwap = interval.isIntraday ? Indicators.sessionVWAP(candles) : candles.map { _ in nil }
    fastEMA = Indicators.ema(closes, period: Indicators.fastEMAPeriod)
    slowEMA = Indicators.ema(closes, period: Indicators.slowEMAPeriod)
  }

  private init(timeframe: Timeframe, candles: [Candle], vwap: [Double?], fastEMA: [Double?], slowEMA: [Double?]) {
    self.timeframe = timeframe
    self.candles = candles
    self.vwap = vwap
    self.fastEMA = fastEMA
    self.slowEMA = slowEMA
  }

  /// The candles and lines from index `first` on: a series computed over earlier candles too
  /// (a warm-up), cut to the candles shown.
  public func dropping(_ first: Int) -> ChartSeries {
    ChartSeries(
      timeframe: timeframe, candles: Array(candles.dropFirst(first)), vwap: Array(vwap.dropFirst(first)),
      fastEMA: Array(fastEMA.dropFirst(first)), slowEMA: Array(slowEMA.dropFirst(first)))
  }

  /// The same candles back to back from the first one's start, one length each, every value
  /// kept: a chart over several sessions or months then draws no overnight, weekend or holiday
  /// gaps. Candle `i` keeps its index, so its real start is the original series' `candles[i]`.
  public func gapless() -> ChartSeries {
    guard let origin = candles.first?.start else { return self }
    let length = timeframe.seconds
    let moved = candles.enumerated().map { index, candle in
      let start = origin.addingTimeInterval(TimeInterval(index) * length)
      return Candle(
        start: start, end: start.addingTimeInterval(length), open: candle.open, high: candle.high,
        low: candle.low, close: candle.close, volume: candle.volume, extended: candle.extended,
        session: candle.session)
    }
    return ChartSeries(timeframe: timeframe, candles: moved, vwap: vwap, fastEMA: fastEMA, slowEMA: slowEMA)
  }
}

public enum Candles {
  /// Starts of the session parts in New York, as (hour, minute): pre-market, the regular
  /// session, after-hours. Candles are counted from the start of the part a bar is in, as the
  /// bot's /chart does, so no candle mixes two parts. Half days (a 13:00 close) are not known
  /// here: their after-hours bars stay in the regular part.
  static let sessionParts = [(4, 0), (9, 30), (16, 0)]

  /// Candles of `timeframe` from M1 bars (oldest first). Candles are counted from the start of
  /// the session part (09:35, 09:40 for M5; 09:30, 10:30 … 15:30 for H1, as brokers draw them,
  /// not clock hours), end where the part ends at the latest, and hold the bars that start
  /// inside them; a candle without bars is not made, so gaps stay gaps.
  public static func make(_ bars: [BarV1], timeframe: Timeframe) -> [Candle] {
    groups(bars, timeframe: timeframe).map(\.candle)
  }

  /// Each candle with the index of its last M1 bar in `bars`.
  static func groups(_ bars: [BarV1], timeframe: Timeframe) -> [(candle: Candle, lastBar: Int)] {
    var groups: [(candle: Candle, lastBar: Int)] = []
    let length = timeframe.seconds
    for (index, bar) in bars.enumerated() {
      let (start, end) = candleSpan(bar.start.date, length: length)
      let high = double(bar.high)
      let low = double(bar.low)
      let close = double(bar.close)
      let volume = double(bar.volume)
      if let last = groups.last?.candle, last.start == start {
        let merged = Candle(
          start: start, end: last.end, open: last.open, high: max(last.high, high),
          low: min(last.low, low), close: close, volume: last.volume + volume, session: last.session)
        groups[groups.count - 1] = (merged, index)
      } else {
        // The bot captures the regular session only (its discovery reads M1 bars then).
        let candle = Candle(
          start: start, end: end, open: double(bar.open), high: high,
          low: low, close: close, volume: volume, session: .regular)
        groups.append((candle, index))
      }
    }
    return groups
  }

  /// Where the candle of `timeframe` that opens at `start` ends: one length later inside a
  /// session, cut where the session part ends (as chart-v1 cuts a part's last candle); the next
  /// New York calendar day, week or month for the longer ones.
  static func end(of start: Date, timeframe: Timeframe) -> Date {
    let component: Calendar.Component
    var count = 1
    switch timeframe {
    case .d1: component = .day
    case .w1:
      component = .day
      count = Timeframe.daysPerWeek
    case .mo1: component = .month
    default: return candleSpan(start, length: timeframe.seconds).end
    }
    return WireDate.newYork.date(byAdding: component, value: count, to: start) ?? start.addingTimeInterval(timeframe.seconds)
  }

  /// Start and end of the candle of `length` seconds holding `date`: whole lengths from the
  /// start of its session part, cut at the next part's start (the 15:30 H1 candle ends at 16:00).
  /// Before 04:00 the day's first part is the calendar day's start.
  static func candleSpan(_ date: Date, length: TimeInterval) -> (start: Date, end: Date) {
    let calendar = WireDate.newYork
    let day = calendar.startOfDay(for: date)
    let starts = [day] + sessionParts.compactMap { part in
      calendar.date(bySettingHour: part.0, minute: part.1, second: 0, of: date)
    }
    let anchor = starts.last { $0 <= date } ?? day
    let next = starts.first { $0 > date } ?? calendar.date(byAdding: .day, value: 1, to: day) ?? date
    let start = anchor.addingTimeInterval((date.timeIntervalSince(anchor) / length).rounded(.down) * length)
    return (start, min(start.addingTimeInterval(length), next))
  }

  static func double(_ value: DecimalString) -> Double {
    NSDecimalNumber(decimal: value.value).doubleValue
  }
}

/// The bot's indicator definitions (src/tickr/strategy/indicators.py), one value per M1 bar.
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

  /// Session VWAP of the candles' typical price, restarting at each New York day, for candles
  /// already merged by the bot (chart-v1) where no M1 bars are at hand. Nil while the session's
  /// volume is zero.
  public static func sessionVWAP(_ candles: [Candle]) -> [Double?] {
    let calendar = WireDate.newYork
    var priceVolume = 0.0
    var volume = 0.0
    var session: Date?
    return candles.map { candle in
      let day = calendar.startOfDay(for: candle.start)
      if day != session {
        session = day
        priceVolume = 0
        volume = 0
      }
      priceVolume += (candle.high + candle.low + candle.close) / typicalPriceParts * candle.volume
      volume += candle.volume
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
