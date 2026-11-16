import Foundation

// "Watching closely" rows on both apps: the deciding check in words that stay true whether it
// passed or not, and the bar of how far the measured value has come. Pure functions over a row of
// GET /watching (WatchingV1).

/// How prices read in these sentences. The apps pass `PriceText.money` (TickrDesign's `Money`;
/// TickrKit does not import the design module), so every price here goes through the one price
/// rule.
public struct PriceText: Sendable {
  /// A price to its tick ("57.11", "0.4567").
  public let price: @Sendable (Decimal) -> String
  /// A distance between two prices, in the decimals of the price it is measured at, never shown
  /// as zero when it is not.
  public let distance: @Sendable (_ distance: Decimal, _ at: Decimal) -> String

  public init(
    price: @escaping @Sendable (Decimal) -> String,
    distance: @escaping @Sendable (_ distance: Decimal, _ at: Decimal) -> String
  ) {
    self.price = price
    self.distance = distance
  }
}

/// Which side of its threshold a check needs the measured value on, from the operator it
/// recorded; nil for an operator without a direction (a yes/no check's "is").
public enum CheckSide: Sendable, Equatable {
  /// `>` or `>=`: passes once measured rises to the threshold.
  case above
  /// `<` or `<=`: passes once measured falls to the threshold.
  case below

  public init?(operator op: String) {
    switch op {
    case ">", ">=": self = .above
    case "<", "<=": self = .below
    default: return nil
    }
  }
}

/// A watched row's deciding check as both apps show it.
public enum WatchingCheck {
  /// The condition's name ("Ask above trigger"); nil when no check failed.
  public static func title(_ row: WatchingRowV1) -> String? {
    row.decisiveCheck.map { ApiText.rule($0.rule) }
  }

  /// Where the check stands, true whether it passed or not:
  /// - against the trigger, unmet: "57.10 · trigger 57.11 · 0.01 to go" (at the trigger of a
  ///   strict check: "57.11 · at the trigger, needs above");
  /// - against the trigger, met: "57.12 · above trigger 57.11";
  /// - any other check: `CheckV1.valueText`;
  /// - no failed check: what the record holds and lacks (`nothingFailed`).
  /// The side comes from the recorded operator, never assumed.
  public static func state(_ row: WatchingRowV1, prices: PriceText) -> String {
    guard let check = row.decisiveCheck else { return nothingFailed(row, prices: prices) }
    guard row.againstTrigger, let measured = check.measured?.value, let trigger = check.threshold?.value,
      let side = CheckSide(operator: check.operator)
    else { return check.valueText }
    let m = prices.price(measured)
    let t = prices.price(trigger)
    if check.passed {
      if measured == trigger { return String(localized: L10n.watchingAtTrigger(m, t)) }
      return String(localized: side == .above ? L10n.watchingAboveTrigger(m, t) : L10n.watchingBelowTrigger(m, t))
    }
    let gap = side == .above ? trigger - measured : measured - trigger
    if gap > 0 {
      return String(localized: L10n.watchingToGo(m, t, prices.distance(gap, trigger)))
    }
    if gap == 0 {
      return String(localized: side == .above ? L10n.watchingAtTriggerNeedsAbove(m) : L10n.watchingAtTriggerNeedsBelow(m))
    }
    // Recorded as failed but already on the needed side: the record contradicts itself, so it
    // is shown as recorded rather than turned into a claim.
    return check.valueText
  }

  /// A WATCH with no failed check: every recorded check passed and the record holds no quote
  /// check (the strategy decided without a quote), so there is no distance to measure. Names the
  /// recorded trigger when there is one.
  public static func nothingFailed(_ row: WatchingRowV1, prices: PriceText) -> String {
    guard let trigger = row.trigger?.value else { return String(localized: L10n.watchingNothingToMeasure) }
    return String(localized: L10n.watchingNoQuoteCheck(prices.price(trigger)))
  }

  /// The bar's share, 0 to 1, as the bot measured it (`closeness`); nil hides the bar: there is
  /// nothing measured to draw, and the row says why instead.
  public static func progress(_ row: WatchingRowV1) -> Double? {
    row.closeness.map { min(max(NSDecimalNumber(decimal: $0.value).doubleValue, 0), 1) }
  }

  /// Why the bar is hidden, when a check failed but the bot could not measure it (a yes/no check,
  /// a level missing): the bot's cause in the person's language. Nil when the bar shows, or when
  /// no check failed (`state` already says why).
  public static func unmeasured(_ row: WatchingRowV1) -> String? {
    guard row.closeness == nil, row.decisiveCheck != nil else { return nil }
    return ApiText.prose(row.closenessCauseCodes, text: row.closenessCause)
  }

  /// What the bar's ends mean: "Empty at the invalidation 56.80, full at the trigger 57.11" for a
  /// check against the trigger; nil for a check measured from zero.
  public static func scale(_ row: WatchingRowV1, prices: PriceText) -> String? {
    guard row.againstTrigger, row.closeness != nil, let trigger = row.trigger?.value,
      let invalidation = row.invalidation?.value
    else { return nil }
    return String(localized: L10n.watchingScale(prices.price(invalidation), prices.price(trigger)))
  }
}
