import Foundation

// "Watching closely" on both apps: the few rows a card shows, and the full list's sort orders. Pure functions over the rows of GET /watching (WatchingV1).

/// How the full "Watching closely" list is ordered.
public enum WatchingSort: String, CaseIterable, Sendable {
  /// Closest to entering first: the API's own order (closeness, unknown last, then symbol).
  case closest
  /// By symbol, A to Z.
  case symbol
  /// Oldest quote first; rows without a recorded quote age last, closest first among equals.
  case quoteAge
  /// Latest decision first, closest first among equals.
  case latest
}

/// The rows of "Watching closely" as the cards and the full list show them.
public enum WatchingList {
  /// Rows a card shows before "Show all" (the design's card holds three without a scroll).
  public static let shown = 3

  /// The `count` rows closest to entering, closest first.
  public static func top(_ rows: [WatchingRowV1], count: Int = shown) -> [WatchingRowV1] {
    Array(sorted(rows, by: .closest).prefix(max(count, 0)))
  }

  /// How many rows, stacked `spacing` apart, fit in `available` points: each row at its measured
  /// height (`heights`, in the card's order), a row not measured yet at the tallest measured one.
  /// At least one row when there is any; `shown` until the card or every row is unmeasured (the
  /// first layout pass). A card sized to its grid cell shows this many, so it fills the cell
  /// with rows and leaves no gap under its footer.
  public static func fitting(_ heights: [Double?], available: Double, spacing: Double) -> Int {
    guard !heights.isEmpty else { return 0 }
    guard available > 0, let tallest = heights.compactMap({ $0 }).max() else { return min(shown, heights.count) }
    var used = 0.0
    var count = 0
    for height in heights {
      let next = used + (count == 0 ? 0 : spacing) + (height ?? tallest)
      if next > available { break }
      used = next
      count += 1
    }
    return max(count, 1)
  }

  /// Whether the card has rows beyond the ones it shows, so "Show all" leads somewhere.
  public static func hasMore(_ rows: [WatchingRowV1], shown count: Int = shown) -> Bool {
    rows.count > count
  }

  /// `rows` in `sort` order; every order ends on the symbol, so it never depends on the input order.
  public static func sorted(_ rows: [WatchingRowV1], by sort: WatchingSort) -> [WatchingRowV1] {
    switch sort {
    case .closest: return rows.sorted(by: closer)
    case .symbol: return rows.sorted { $0.symbol < $1.symbol }
    case .quoteAge:
      return rows.sorted { a, b in
        switch (a.quoteAgeSeconds?.value, b.quoteAgeSeconds?.value) {
        case let (x?, y?) where x != y: return x > y
        case (.some, nil): return true
        case (nil, .some): return false
        default: return closer(a, b)
        }
      }
    case .latest:
      return rows.sorted { a, b in a.at.date == b.at.date ? closer(a, b) : a.at.date > b.at.date }
    }
  }

  /// The API's order: higher closeness first, unknown closeness last, then by symbol.
  static func closer(_ a: WatchingRowV1, _ b: WatchingRowV1) -> Bool {
    switch (a.closeness?.value, b.closeness?.value) {
    case let (x?, y?) where x != y: return x > y
    case (.some, nil): return true
    case (nil, .some): return false
    default: return a.symbol < b.symbol
    }
  }
}
