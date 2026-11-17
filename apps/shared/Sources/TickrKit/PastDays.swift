import Foundation

/// The documents of the past days last shown, so a day picked again shows at once (Mac Trades and
/// iPhone Activity). A past day's files no longer change once it is over, so what was read stays
/// right; the screen still reads the day again behind it and replaces what it holds. Only the
/// `capacity` days shown last are kept; today is never kept (it is still being written).
public struct PastDays<Parts: Sendable>: Sendable {
  public let capacity: Int
  private var parts: [WireDate: Parts] = [:]
  /// The kept days, the one used longest ago first.
  private var order: [WireDate] = []

  public init(capacity: Int = PastDaysKept.count) {
    self.capacity = capacity
  }

  /// What is kept of `day`, nil if nothing.
  public func parts(of day: WireDate) -> Parts? { parts[day] }

  /// Keeps `update` applied to what is kept of past day `day` (or to `empty` when nothing is);
  /// nothing when `day` is `today`. The day becomes the newest kept; the oldest goes past
  /// `capacity`.
  public mutating func keep(_ day: WireDate, today: WireDate, empty: Parts, _ update: (inout Parts) -> Void) {
    guard day != today else { return }
    var kept = parts[day] ?? empty
    update(&kept)
    parts[day] = kept
    order.removeAll { $0 == day }
    order.append(day)
    while order.count > capacity { parts[order.removeFirst()] = nil }
  }

  /// The days kept, the one used longest ago first.
  public var days: [WireDate] { order }
}

/// How many past days the apps keep (`PastDays`).
public enum PastDaysKept {
  /// A week of sessions to step through with the day arrows.
  public static let count = 5
}
