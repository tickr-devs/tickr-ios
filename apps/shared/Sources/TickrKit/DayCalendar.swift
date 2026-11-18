import Foundation

/// The trading-day calendar the apps pick a recorded day from: one month as weeks of Monday to
/// Friday, each weekday with the bot's summary of that day when it has records. New York dates;
/// weekends are left out because the bot never trades them.
public enum DayCalendar {
  /// Gregorian weekday numbers (Sunday = 1) of the first and the last trading weekday.
  public static let monday = 2
  public static let friday = 6
  /// Columns of a week: Monday to Friday.
  public static let columns = friday - monday + 1

  /// One calendar month.
  public struct Month: Hashable, Comparable, Sendable, Identifiable {
    public let year: Int
    public let month: Int

    public init(year: Int, month: Int) {
      self.year = year
      self.month = month
    }

    /// The month `day` falls in.
    public init(_ day: WireDate) {
      self.init(year: day.year, month: day.month)
    }

    public var id: Self { self }

    /// Noon in New York on the month's first day: an anchor for formatting the month's name.
    public var firstDay: Date? {
      WireDate.newYork.date(from: DateComponents(year: year, month: month, day: 1, hour: WireDate.anchorHour))
    }

    public static func < (a: Month, b: Month) -> Bool {
      (a.year, a.month) < (b.year, b.month)
    }
  }

  /// One weekday of a month and the bot's summary of it, nil when the bot recorded nothing.
  public struct Cell: Hashable, Sendable, Identifiable {
    public let day: WireDate
    public let summary: DaySummary?

    public var id: WireDate { day }
  }

  /// The sum of `month`'s recorded day results (each day's `resultUsd`); nil when the bot
  /// recorded no day of it. Both apps show it beside the calendar's month.
  public static func total(of month: Month, days: [DaySummary]) -> Decimal? {
    let results = days.filter { Month($0.day) == month }.map(\.resultUsd.value)
    return results.isEmpty ? nil : results.reduce(0, +)
  }

  /// The weeks of `month`, Monday to Friday. A week starts on its Monday; the slots before the
  /// month's first weekday and after its last are nil.
  public static func weeks(of month: Month, days: [DaySummary]) -> [[Cell?]] {
    let calendar = WireDate.newYork
    guard let first = month.firstDay, let length = calendar.range(of: .day, in: .month, for: first) else {
      return []
    }
    let summaries = Dictionary(days.map { ($0.day, $0) }, uniquingKeysWith: { kept, _ in kept })
    let empty = [Cell?](repeating: nil, count: columns)
    var weeks: [[Cell?]] = []
    var week = empty
    var filled = false
    for offset in 0..<length.count {
      guard let date = calendar.date(byAdding: .day, value: offset, to: first) else { continue }
      let column = calendar.component(.weekday, from: date) - monday
      guard (0..<columns).contains(column) else { continue }
      if column == 0 && filled {
        weeks.append(week)
        week = empty
      }
      let day = WireDate(newYorkDateOf: date)
      week[column] = Cell(day: day, summary: summaries[day])
      filled = true
    }
    if filled { weeks.append(week) }
    return weeks
  }

  /// The months that hold a recorded day, and the month of `today`, newest first.
  public static func months(_ days: [DaySummary], including today: WireDate) -> [Month] {
    Set(days.map { Month($0.day) } + [Month(today)]).sorted(by: >)
  }
}
