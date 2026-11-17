import Foundation

/// The parts of the day on a Day or 5D chart whose candles are drawn back to back (mockup v113,
/// "Continuous all-session chart"): one slot per candle, pre-market, regular session and
/// after-hours following each other with no hole for a night, a weekend or a minute without
/// trades. On today's Day chart the rest of the day is reserved as empty slots up to the extended
/// close, so the scale never jumps as the day goes on. Both apps draw the bands, the dashed
/// boundaries and the time axis from this.
public struct SessionAxis: Equatable, Sendable {
  /// A run of slots in one part of one New York day.
  public struct Segment: Equatable, Sendable {
    /// First and last slot, both included.
    public let first: Int
    public let last: Int
    /// The part of the day; nil for an extended candle of an API too old to say which part.
    public let session: ChartSession?
    /// Real time of the first slot.
    public let realStart: Date
    /// The first segment of a New York day.
    public let newDay: Bool
    /// Slots reserved for the rest of today, without candles yet.
    public let future: Bool

    /// Whether the segment is drawn on a band: the pre-market and the after-hours.
    public var extended: Bool { session != .regular }
  }

  /// What a time-axis label says.
  public enum LabelKind: Equatable, Sendable {
    /// Where a part of the day begins: "Pre 04:00" at the left edge, "09:30", "16:00".
    case sessionStart(ChartSession?, Date, atEdge: Bool)
    /// Where the day's sessions end, at the right edge: "After 20:00".
    case end(Date)
    /// A New York day's first slot over five days: "Tue 10".
    case day(Date)
    /// A round clock time between the session labels.
    case hour(Date)
  }

  /// A label at slot `slot`'s start, hung as `anchor`.
  public struct Label: Equatable, Sendable {
    public let slot: Int
    public let kind: LabelKind
    public let anchor: ChartAxis.Anchor
  }

  public let segments: [Segment]
  /// Slots of candles, then reserved slots.
  public let slots: Int
  /// Slots that hold candles.
  public let candleSlots: Int
  /// Length of one slot in seconds (the candles' timeframe).
  public let length: TimeInterval
  /// The reserved runs, one per part of the day, for the real time of a reserved slot (a run
  /// that continues the last candle's part is merged into its segment above).
  let reserved: [Segment]

  /// Minutes between round clock labels a Day axis may use, smallest first (mockup v113).
  public static let hourStepMinutes = [15, 30, 60, 120, 180, 240]

  /// The segments of `candles` (real times, oldest first) in `timeframe`; with `today`, the
  /// calendar's session of the day the last candle is in, the rest of that day is reserved (the
  /// Day range of the current session only): the pre-market and the regular session to their
  /// end, the after-hours as many slots as the session before had (`afterSlots`: its prints are
  /// sparse, so the whole 16:00-20:00 would leave a wide empty band; mockup v113), or to the
  /// extended close when that is not known.
  public init(candles: [Candle], timeframe: Timeframe, today: SessionSpan? = nil, afterSlots: Int? = nil) {
    length = timeframe.seconds
    var segments = Self.segments(candles)
    candleSlots = candles.count
    var slot = candles.count
    var reserved: [Segment] = []
    for part in Self.reserve(candles, length: length, today: today, afterSlots: afterSlots) {
      reserved.append(Segment(
        first: slot, last: slot + part.count - 1, session: part.session, realStart: part.begin, newDay: false,
        future: true))
      if let last = segments.last, last.session == part.session {
        segments[segments.count - 1] = Segment(
          first: last.first, last: last.last + part.count, session: part.session, realStart: last.realStart,
          newDay: last.newDay, future: last.future)
      } else {
        segments.append(reserved[reserved.count - 1])
      }
      slot += part.count
    }
    self.segments = segments
    self.reserved = reserved
    slots = slot
  }

  /// Runs of candles in one part of one New York day.
  private static func segments(_ candles: [Candle]) -> [Segment] {
    var segments: [Segment] = []
    let calendar = WireDate.newYork
    for (index, candle) in candles.enumerated() {
      let day = calendar.startOfDay(for: candle.start)
      let previous = index > 0 ? candles[index - 1] : nil
      let sameDay = previous.map { calendar.startOfDay(for: $0.start) == day } ?? false
      if let last = segments.last, sameDay, previous?.session == candle.session {
        segments[segments.count - 1] = Segment(
          first: last.first, last: index, session: last.session, realStart: last.realStart, newDay: last.newDay,
          future: false)
      } else {
        segments.append(Segment(
          first: index, last: index, session: candle.session, realStart: candle.start, newDay: !sameDay, future: false))
      }
    }
    return segments
  }

  /// The slots reserved after the last candle on today's Day chart, part by part (see `init`).
  private static func reserve(_ candles: [Candle], length: TimeInterval, today: SessionSpan?, afterSlots: Int?)
    -> [(session: ChartSession, begin: Date, count: Int)] {
    let calendar = WireDate.newYork
    guard let today, let lastCandle = candles.last,
      calendar.startOfDay(for: lastCandle.start) == calendar.startOfDay(for: today.start) else { return [] }
    var from = lastCandle.end
    var parts: [(session: ChartSession, begin: Date, count: Int)] = []
    let spans: [(ChartSession, Date, Date)] = [
      (.pre, today.start, today.regularOpen), (.regular, today.regularOpen, today.regularClose),
      (.after, today.regularClose, today.end),
    ]
    for (session, start, end) in spans where from < end {
      let begin = max(from, start)
      let byTime = Int((end.timeIntervalSince(begin) / length).rounded(.up))
      // Into the after-hours already: what is left of yesterday's count.
      let afterSoFar = candles.filter { $0.session == .after && $0.start >= start }.count
      let afterLeft = afterSlots.map { max($0 - afterSoFar, 0) }
      let count = session == .after ? (afterLeft ?? byTime) : byTime
      from = end
      if count > 0 { parts.append((session, begin, count)) }
    }
    return parts
  }

  /// Slots where a boundary is drawn: every segment's first but the chart's left edge (a segment
  /// is a part of one day, so each starts a new part or a new day).
  public var boundaries: [Int] { segments.dropFirst().map(\.first) }

  /// Segments drawn on a band (pre-market, after-hours), as (first slot, slots after the last).
  public var bands: [(segment: Segment, end: Int)] {
    segments.filter(\.extended).map { ($0, $0.last + 1) }
  }

  /// The real time of slot `slot`: a candle's start, or for a reserved slot the time it will
  /// open at.
  public func realTime(ofSlot slot: Int, candles: [Candle]) -> Date? {
    if candles.indices.contains(slot) { return candles[slot].start }
    guard let segment = reserved.last(where: { $0.first <= slot }), slot <= segment.last else { return nil }
    return segment.realStart.addingTimeInterval(Double(slot - segment.first) * length)
  }

  /// The labels a Day axis or a 5D axis may carry, in the order they are placed (mockup v113,
  /// "Time-axis labels"): the session labels, then the end, then round clock times
  /// `hourStep` minutes apart at slots that open on one.
  public func labels(range: ChartRange, candles: [Candle], extendedClose: Date?, hourStep: Int?) -> [Label] {
    var labels: [Label] = []
    if range == .fiveDays {
      for segment in segments where segment.newDay {
        labels.append(Label(slot: segment.first, kind: .day(segment.realStart), anchor: .leading))
      }
      return labels
    }
    for segment in segments where segment.first == 0 || !segment.newDay {
      let atEdge = segment.first == 0
      labels.append(Label(
        slot: segment.first, kind: .sessionStart(segment.session, segment.realStart, atEdge: atEdge),
        anchor: atEdge ? .leading : .centre))
    }
    if let extendedClose, let last = segments.last, last.session == .after {
      labels.append(Label(slot: slots, kind: .end(extendedClose), anchor: .trailing))
    }
    guard let hourStep, hourStep > 0 else { return labels }
    let step = TimeInterval(hourStep * Timeframe.secondsPerMinute)
    let starts = Set(segments.map(\.first))
    for slot in 0..<slots where !starts.contains(slot) {
      guard let time = realTime(ofSlot: slot, candles: candles) else { continue }
      let midnight = WireDate.newYork.startOfDay(for: time)
      if time.timeIntervalSince(midnight).truncatingRemainder(dividingBy: step) == 0 {
        labels.append(Label(slot: slot, kind: .hour(time), anchor: .centre))
      }
    }
    return labels
  }

  /// The smallest round step (`hourStepMinutes`) that is a whole number of candles and puts at
  /// least `least` points between two labels at `pointsPerSlot`; the largest when none does.
  public static func hourStep(timeframe: Timeframe, pointsPerSlot: Double, least: Double) -> Int? {
    guard let minutes = timeframe.minutes, minutes > 0 else { return nil }
    let steps = hourStepMinutes.filter { $0 % minutes == 0 }
    return steps.first { Double($0 / minutes) * pointsPerSlot >= least } ?? steps.last
  }
}

/// Places time-axis labels so none overlaps another (mockup v113, "Collisions"): in the order
/// given, each takes the first of its texts that fits `gap` away from those already placed and
/// inside `inset` of the edges, or is left out.
public enum AxisLabelPlacer {
  public struct Item: Sendable {
    /// Where the label's time is, from the left edge.
    public let x: Double
    /// Widths of its texts, the preferred first (a session label's short form after it).
    public let widths: [Double]
    public let anchor: ChartAxis.Anchor
    /// A session label: never left out to keep another label's long form.
    public let required: Bool

    public init(x: Double, widths: [Double], anchor: ChartAxis.Anchor, required: Bool = false) {
      self.x = x
      self.widths = widths
      self.anchor = anchor
      self.required = required
    }
  }

  /// A placed label: its item's index, the chosen text's index, and its left edge.
  public struct Placed: Equatable, Sendable {
    public let item: Int
    public let text: Int
    public let left: Double
  }

  /// When a required label finds no room, the labels are placed again with every label in its
  /// short form ("Pre 04:00" gives way to "04:00" so "09:30" stays).
  public static func place(_ items: [Item], width: Double, gap: Double, inset: Double) -> [Placed] {
    let placed = placeOnce(items, width: width, gap: gap, inset: inset)
    let kept = Set(placed.map(\.item))
    let lost = items.indices.contains { items[$0].required && !kept.contains($0) && onAxis(items[$0], width: width) }
    guard lost else { return placed }
    let short = items.map { Item(x: $0.x, widths: $0.widths.suffix(1), anchor: $0.anchor, required: $0.required) }
    return placeOnce(short, width: width, gap: gap, inset: inset).map { found in
      Placed(item: found.item, text: items[found.item].widths.count - 1, left: found.left)
    }
  }

  /// Whether a label's time is on the axis, to the whole point.
  static func onAxis(_ item: Item, width: Double) -> Bool {
    item.x.rounded() >= 0 && item.x.rounded() <= width
  }

  static func placeOnce(_ items: [Item], width: Double, gap: Double, inset: Double) -> [Placed] {
    var taken: [ClosedRange<Double>] = []
    var placed: [Placed] = []
    for (index, item) in items.enumerated() {
      // To the whole point: the end label's time is the right edge itself.
      guard onAxis(item, width: width) else { continue }
      let x = min(max(item.x, 0), width)
      for (text, textWidth) in item.widths.enumerated() {
        var left: Double
        switch item.anchor {
        case .leading: left = x
        case .centre: left = x - textWidth / 2
        case .trailing: left = x - textWidth
        }
        left = min(max(left, inset), width - inset - textWidth)
        let span = left...(left + textWidth)
        if taken.contains(where: { span.lowerBound < $0.upperBound + gap && span.upperBound > $0.lowerBound - gap }) {
          continue
        }
        taken.append(span)
        placed.append(Placed(item: index, text: text, left: left))
        break
      }
    }
    return placed
  }
}

/// The words of the session axis (mockup v113), shared by both apps.
public enum SessionAxisText {
  /// A label's texts, the preferred first: "Pre 04:00" then "04:00" at the left edge, "After
  /// 20:00" then "20:00" at the end, the clock time elsewhere; a day's name (`dayName`) over five
  /// days.
  public static func texts(_ kind: SessionAxis.LabelKind, dayName: (Date) -> String) -> [String] {
    switch kind {
    case .sessionStart(let session, let time, let atEdge):
      let clock = ClockText.minutes(time)
      return atEdge && session == .pre ? [String(localized: ChartSessionWords.preAt(clock)), clock] : [clock]
    case .end(let time):
      let clock = ClockText.minutes(time)
      return [String(localized: ChartSessionWords.afterAt(clock)), clock]
    case .day(let date): return [dayName(date)]
    case .hour(let time): return [ClockText.minutes(time)]
    }
  }

  /// Whether a label names a session, its end or a day (drawn stronger than a round time).
  public static func isSession(_ kind: SessionAxis.LabelKind) -> Bool {
    if case .hour = kind { return false }
    return true
  }

  /// The caption of a band: "PRE" or "AFTER"; none for a part the API did not name.
  public static func caption(_ session: ChartSession?) -> LocalizedStringResource? {
    switch session {
    case .pre: ChartSessionWords.preBand
    case .after: ChartSessionWords.afterBand
    case .regular, nil: nil
    }
  }
}
