import Foundation

/// Where the time axis of a range beyond one day puts its labels.
public enum ChartAxis {
  /// Months between labels on a year of monthly candles: one label a quarter.
  static let quarterMonths = 3
  /// Months in a year (unit factor).
  static let monthsPerYear = 12
  /// Fewest labels a range's axis should carry: with fewer, the next finer period labels it
  /// (a month of few candles labels its weeks, then its days).
  static let leastLabels = 3

  /// What the labels of a range's time axis mark the start of.
  public enum Period: Sendable, Equatable {
    case day
    case week
    case month
    case quarter
  }

  /// Periods that may label `range` in `timeframe`, coarsest first.
  static func periods(range: ChartRange, timeframe: Timeframe) -> [Period] {
    switch range {
    case .oneDay, .fiveDays: [.day]
    case .oneMonth: [.week, .day]
    case .threeMonths, .oneYear: timeframe == .mo1 ? [.quarter, .month] : [.month, .week, .day]
    }
  }

  /// The labelled period and the indices of the candles that open one, the first candle
  /// included: sessions over five days, weeks over a month, months over three months or a year
  /// (quarters for monthly candles), or a finer period when that gives fewer than `leastLabels`.
  /// `starts` are the candles' real opening times, oldest first.
  public static func labels(_ starts: [Date], range: ChartRange, timeframe: Timeframe) -> (period: Period, indices: [Int]) {
    let candidates = periods(range: range, timeframe: timeframe)
    var found = (period: Period.day, indices: [Int]())
    for period in candidates {
      found = (period, openings(starts, period: period))
      if found.indices.count >= leastLabels { break }
    }
    return found
  }

  /// Indices of the candles that open a labelled period (see `labels`).
  public static func boundaries(_ starts: [Date], range: ChartRange, timeframe: Timeframe) -> [Int] {
    labels(starts, range: range, timeframe: timeframe).indices
  }

  /// Indices of the candles that open a new `period` in New York, the first included.
  static func openings(_ starts: [Date], period: Period) -> [Int] {
    let calendar = WireDate.newYork
    func key(_ date: Date) -> Int {
      switch period {
      case .day: return calendar.ordinality(of: .day, in: .era, for: date) ?? 0
      case .week:
        // The week's Monday-or-Sunday start as a day number: one key per calendar week.
        let week = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        return calendar.ordinality(of: .day, in: .era, for: week) ?? 0
      case .month, .quarter:
        let months = calendar.component(.year, from: date) * monthsPerYear + calendar.component(.month, from: date) - 1
        return period == .quarter ? months / quarterMonths : months
      }
    }
    var indices: [Int] = []
    var previous: Int?
    for (index, start) in starts.enumerated() {
      let current = key(start)
      if current != previous { indices.append(index) }
      previous = current
    }
    return indices
  }

  /// Minutes between clock labels on one day, smallest first: round times a chart reader expects.
  static let clockStepMinutes = [5, 10, 15, 30, 60, 120, 240]
  /// Share of the shown stretch, at each end, in which a label turns inward so it is never cut.
  static let edgeShare = 0.12

  /// Where a time label hangs from its time.
  public enum Anchor: Sendable, Equatable {
    /// Starts at its time and runs right (near the left end of the shown stretch).
    case leading
    /// Centred on its time.
    case centre
    /// Ends at its time (near the right end).
    case trailing
  }

  /// Round New York clock times (every 5, 10, 15, 30 … minutes) inside `domain`, the step the
  /// smallest that puts at most `count` labels in a stretch `shown` seconds long.
  public static func clockMarks(in domain: ClosedRange<Date>, shown: TimeInterval, count: Int) -> [Date] {
    guard count > 0, shown > 0 else { return [] }
    let minute = TimeInterval(Timeframe.secondsPerMinute)
    let stepMinutes = clockStepMinutes.first { shown / (TimeInterval($0) * minute) <= TimeInterval(count) }
      ?? clockStepMinutes[clockStepMinutes.count - 1]
    let step = TimeInterval(stepMinutes) * minute
    let midnight = WireDate.newYork.startOfDay(for: domain.lowerBound)
    var mark = midnight.addingTimeInterval((domain.lowerBound.timeIntervalSince(midnight) / step).rounded(.up) * step)
    var marks: [Date] = []
    while mark <= domain.upperBound {
      marks.append(mark)
      mark = mark.addingTimeInterval(step)
    }
    return marks
  }

  /// How a label at `time` hangs so it stays inside `shown`, the stretch on screen.
  public static func anchor(of time: Date, shown: ClosedRange<Date>) -> Anchor {
    let margin = shown.upperBound.timeIntervalSince(shown.lowerBound) * edgeShare
    if time.timeIntervalSince(shown.lowerBound) < margin { return .leading }
    if shown.upperBound.timeIntervalSince(time) < margin { return .trailing }
    return .centre
  }
}
