import Foundation

/// Texts of the "Last entry size" block of the Risk room card (`EntrySizing`, mockup v115).
extension L10n {
  /// The block's title.
  static var sizingTitle: LocalizedStringResource {
    LocalizedStringResource("kit.sizing.title", defaultValue: "Last entry size", bundle: bundle)
  }
  /// The symbol and minute of the latest sized decision: "IQ · 10:31".
  static func sizingMeta(_ symbol: String, _ time: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.sizing.meta", defaultValue: "\(symbol) · \(time)", bundle: bundle)
  }
  /// What was sized: "IQ · 3,521 shares · $2,499.91 at $0.7100".
  static func sizingLine(_ symbol: String, _ shares: String, _ amount: String, _ price: String)
    -> LocalizedStringResource {
    LocalizedStringResource("kit.sizing.line", defaultValue: "\(symbol) · \(shares) shares · \(amount) at \(price)",
      bundle: bundle)
  }
  /// What was sized when the record holds no price: "IQ · 3,521 shares".
  static func sizingLineNoPrice(_ symbol: String, _ shares: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.sizing.lineNoPrice", defaultValue: "\(symbol) · \(shares) shares", bundle: bundle)
  }
  /// No decision of the day was sized.
  static var sizingNone: LocalizedStringResource {
    LocalizedStringResource("kit.sizing.none", defaultValue: "No entry sized today", bundle: bundle)
  }
  /// Above the limits of a sized decision.
  static var sizingLead: LocalizedStringResource {
    LocalizedStringResource("kit.sizing.lead", defaultValue: "Each limit allows:", bundle: bundle)
  }
  /// Above the limits worked out for an example stock, when nothing was sized today.
  static func sizingExampleLead(_ price: String, _ stop: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.sizing.exampleLead",
      defaultValue: "A \(price) stock with a \(stop) stop · each limit allows:", bundle: bundle)
  }
  /// The planned-loss limit: the planned loss over the risk per share.
  static func sizingRowPlannedLoss(_ amount: String, _ risk: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.sizing.row.plannedLoss", defaultValue: "Planned loss \(amount) ÷ risk \(risk)",
      bundle: bundle)
  }
  /// The notional cap over the price per share.
  static func sizingRowNotionalCap(_ amount: String, _ price: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.sizing.row.notionalCap", defaultValue: "Notional cap \(amount) ÷ \(price)",
      bundle: bundle)
  }
  /// The daily room over the risk per share.
  static func sizingRowDailyRoom(_ amount: String, _ risk: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.sizing.row.dailyRoom", defaultValue: "Risk room left \(amount) ÷ risk \(risk)",
      bundle: bundle)
  }
  /// How many shares a limit allows: "4,166 sh".
  static func sizingShares(_ shares: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.sizing.shares", defaultValue: "\(shares) sh", bundle: bundle)
  }
  /// The planned-loss limit inside a sentence.
  static var sizingNamePlannedLoss: LocalizedStringResource {
    LocalizedStringResource("kit.sizing.name.plannedLoss", defaultValue: "planned loss", bundle: bundle)
  }
  /// The notional cap inside a sentence.
  static var sizingNameNotionalCap: LocalizedStringResource {
    LocalizedStringResource("kit.sizing.name.notionalCap", defaultValue: "notional cap", bundle: bundle)
  }
  /// The daily room inside a sentence.
  static var sizingNameDailyRoom: LocalizedStringResource {
    LocalizedStringResource("kit.sizing.name.dailyRoom", defaultValue: "risk room left", bundle: bundle)
  }
  /// The limit that set the size, with its amount: "Size set by: notional cap $2,500.00".
  static func sizingSetBy(_ limit: String, _ amount: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.sizing.setBy", defaultValue: "Size set by: \(limit) \(amount)", bundle: bundle)
  }
  /// The limit that set the size, from an older record without the amounts.
  static func sizingSetByNoAmount(_ limit: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.sizing.setByNoAmount", defaultValue: "Size set by: \(limit)", bundle: bundle)
  }
  /// The limit that would set the example's size: "Would be set by: planned loss $50.00 · 200 sh".
  static func sizingWouldBeSetBy(_ limit: String, _ amount: String, _ shares: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.sizing.wouldBeSetBy",
      defaultValue: "Would be set by: \(limit) \(amount) · \(shares) sh", bundle: bundle)
  }
  /// The Risk screens' headline of an entry: "3,521 shares".
  static func sizingSharesLine(_ shares: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.sizing.sharesLine", defaultValue: "\(shares) shares", bundle: bundle)
  }
  /// Where and when the entry was sized, on the Risk screens: "IQ at $0.7100 · 10:31 ET".
  static func sizingPlace(_ symbol: String, _ price: String, _ time: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.sizing.place", defaultValue: "\(symbol) at \(price) · \(time) ET", bundle: bundle)
  }
  /// The same from a record without a price: "IQ · 10:31 ET".
  static func sizingPlaceNoPrice(_ symbol: String, _ time: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.sizing.placeNoPrice", defaultValue: "\(symbol) · \(time) ET", bundle: bundle)
  }
  /// The Risk screens' planned-loss limit, without a formula: the planned loss and how far the
  /// stop was: "Planned loss $50.00 · stop $0.0120 away".
  static func sizingPlainPlannedLoss(_ amount: String, _ distance: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.sizing.plain.plannedLoss", defaultValue: "Planned loss \(amount) · stop \(distance) away",
      bundle: bundle)
  }
  /// The Risk screens' notional cap: "Position size cap $2,500.00".
  static func sizingPlainNotionalCap(_ amount: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.sizing.plain.notionalCap", defaultValue: "Position size cap \(amount)", bundle: bundle)
  }
  /// The Risk screens' daily room: "Room left $292.00".
  static func sizingPlainDailyRoom(_ amount: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.sizing.plain.dailyRoom", defaultValue: "Room left \(amount)", bundle: bundle)
  }
  /// The Risk screens' caption when the planned loss sized the entry.
  static var sizingSetByPlannedLoss: LocalizedStringResource {
    LocalizedStringResource("kit.sizing.setByPlannedLoss", defaultValue: "Set by the planned loss", bundle: bundle)
  }
  /// The Risk screens' caption when another limit held the size down: "Limited by: position size cap".
  static func sizingLimitedBy(_ limit: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.sizing.limitedBy", defaultValue: "Limited by: \(limit)", bundle: bundle)
  }
  /// The notional cap inside the Risk screens' caption.
  static var sizingPlainNameNotionalCap: LocalizedStringResource {
    LocalizedStringResource("kit.sizing.plainName.notionalCap", defaultValue: "position size cap", bundle: bundle)
  }
  /// The daily room inside the Risk screens' caption.
  static var sizingPlainNameDailyRoom: LocalizedStringResource {
    LocalizedStringResource("kit.sizing.plainName.dailyRoom", defaultValue: "room left", bundle: bundle)
  }
}

/// Texts of the Risk room card both apps share (mockup v115): the room's line and its four facts.
public enum RiskRoomText {
  /// Beside the room left: "of $300.00 left".
  public static func left(_ limit: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.riskRoom.left", defaultValue: "of \(limit) left", bundle: L10n.bundle)
  }
  /// Today's net result, fees included.
  public static var netResult: LocalizedStringResource {
    LocalizedStringResource("kit.riskRoom.netResult", defaultValue: "Net day result", bundle: L10n.bundle)
  }
  /// What open orders reserve of the daily room.
  public static var reservations: LocalizedStringResource {
    LocalizedStringResource("kit.riskRoom.reservations", defaultValue: "Open reservations", bundle: L10n.bundle)
  }
  /// Open positions against the most allowed.
  public static var positions: LocalizedStringResource {
    LocalizedStringResource("kit.riskRoom.positions", defaultValue: "Positions", bundle: L10n.bundle)
  }
  /// The Risk room card's link to every sizing limit of the last entry, and its popover's title.
  public static var limits: LocalizedStringResource {
    LocalizedStringResource("kit.riskRoom.limits", defaultValue: "Limits", bundle: L10n.bundle)
  }
  /// Whether the bot's records agree with the broker.
  public static var recordsAgree: LocalizedStringResource {
    LocalizedStringResource("kit.riskRoom.recordsAgree", defaultValue: "Records agree", bundle: L10n.bundle)
  }
}

extension RiskRoomText {
  /// The bot's records and the broker's agreed at the latest reconciliation.
  static var match: LocalizedStringResource {
    LocalizedStringResource("kit.riskRoom.match", defaultValue: "match", bundle: L10n.bundle)
  }
  /// They did not.
  static var mismatch: LocalizedStringResource {
    LocalizedStringResource("kit.riskRoom.mismatch", defaultValue: "mismatch", bundle: L10n.bundle)
  }
  /// Fences are up now: "fences: 2".
  static func fences(_ count: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.riskRoom.fences", defaultValue: "fences: \(count)", bundle: L10n.bundle)
  }
}

/// The Risk room card's "Records agree" fact on both apps: live fences first (the status is newer
/// than any reconciliation), then the latest reconciliation's match or mismatch; without one, no
/// value (never read as fine), with the bot's cause.
public struct RecordsAgreement: Equatable, Sendable {
  /// "match", "mismatch", "fences: 2"; nil when nothing says.
  public let value: String?
  /// True only on a match without fences; nil when nothing says.
  public let agrees: Bool?
  /// Why nothing says, in the person's language.
  public let note: String?

  public init(fences: [Fence], latest: FlowReconcileV1?) {
    if !fences.isEmpty {
      value = String(localized: RiskRoomText.fences(fences.count))
      agrees = false
      note = nil
      return
    }
    switch latest?.agreement {
    case .match:
      value = String(localized: RiskRoomText.match)
      agrees = true
      note = nil
    case .mismatch:
      value = String(localized: RiskRoomText.mismatch)
      agrees = false
      note = nil
    case nil:
      value = nil
      agrees = nil
      note = latest?.agreementCauseText
    }
  }
}
