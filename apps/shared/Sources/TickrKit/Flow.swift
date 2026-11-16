import Foundation

// Swift mirrors of flow-v1 and watching-v1 in src/tickr/api/contract.py: the Overview's live
// flow (screeners to stop) and the symbols the strategy is watching closely.

/// A screener that put a symbol on the board.
public enum ScreenerSource: String, Codable, Sendable {
  case gainers = "GAINERS"
  case losers = "LOSERS"
  case topActives = "TOP_ACTIVES"
}

/// One symbol the screeners returned on the day.
public struct FlowChipV1: Codable, Hashable, Sendable {
  public let symbol: String
  public let sources: [ScreenerSource]
  /// Change from the previous close, in percent; nil with `changeCause` when it cannot be computed.
  public let changePct: DecimalString?
  public let changeCause: String?
  /// The codes of `changeCause` (added after version 1 shipped: empty from an older API).
  public let changeCauseCodes: [ReasonV1]
  /// Why the universe left the symbol out; nil when it was admitted.
  public let excludedCause: String?
  /// The codes of `excludedCause` (added after version 1 shipped: empty from an older API).
  public let excludedCauseCodes: [ReasonV1]
  /// Each screener's rank of the symbol in its latest list, in `sources` order; empty from a bot
  /// that does not send it yet.
  public let ranks: [SymbolSourceV1]
  /// The price in the latest captured row that listed it; nil when that row has none, or from a
  /// bot that does not send it yet.
  public let price: DecimalString?

  enum CodingKeys: String, CodingKey {
    case symbol, sources, ranks, price
    case changePct = "change_pct"
    case changeCause = "change_cause"
    case excludedCause = "excluded_cause"
    case changeCauseCodes = "change_cause_codes"
    case excludedCauseCodes = "excluded_cause_codes"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    symbol = try c.decode(String.self, forKey: .symbol)
    sources = try c.decode([ScreenerSource].self, forKey: .sources)
    changePct = try c.decodeNullable(DecimalString.self, forKey: .changePct)
    changeCause = try c.decodeNullable(String.self, forKey: .changeCause)
    changeCauseCodes = try c.decodeIfPresent([ReasonV1].self, forKey: .changeCauseCodes) ?? []
    excludedCause = try c.decodeNullable(String.self, forKey: .excludedCause)
    excludedCauseCodes = try c.decodeIfPresent([ReasonV1].self, forKey: .excludedCauseCodes) ?? []
    ranks = try c.decodeIfPresent([SymbolSourceV1].self, forKey: .ranks) ?? []
    price = try c.decodeIfPresent(DecimalString.self, forKey: .price)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(symbol, forKey: .symbol)
    try c.encode(sources, forKey: .sources)
    try c.encodeNullable(changePct, forKey: .changePct)
    try c.encodeNullable(changeCause, forKey: .changeCause)
    try c.encode(changeCauseCodes, forKey: .changeCauseCodes)
    try c.encodeNullable(excludedCause, forKey: .excludedCause)
    try c.encode(excludedCauseCodes, forKey: .excludedCauseCodes)
    try c.encode(ranks, forKey: .ranks)
    try c.encodeNullable(price, forKey: .price)
  }

  /// Why the change cannot be computed, in the person's language (the bot's words for an unknown code).
  public var changeCauseText: String? { ApiText.prose(changeCauseCodes, text: changeCause) }

  /// Why the universe filter left the symbol out, in the person's language (the bot's words for an unknown code).
  public var excludedCauseText: String? { ApiText.prose(excludedCauseCodes, text: excludedCause) }
}

/// A stage of the flow, in the order a symbol passes them.
public enum FlowStage: String, Codable, Sendable, CaseIterable {
  case screeners, universe, strategy, risk, order, stop
}

/// How many symbols reached a stage on the day, and which.
public struct FlowStageV1: Codable, Hashable, Sendable {
  public let stage: FlowStage
  public let count: Int
  public let symbols: [String]
}

/// What the flow knows about a trade's broker-side stop: confirmed by the broker, waiting for
/// confirmation, never confirmed before the trade ended, or not known.
public enum FlowStopState: String, Codable, Sendable {
  case verified, pending
  case neverVerified = "never_verified"
  case unknown
}

/// One trade of the day and the state of its broker-side stop.
public struct FlowStopV1: Codable, Hashable, Sendable {
  public let tradeId: String
  public let symbol: String
  public let state: FlowStopState

  enum CodingKeys: String, CodingKey {
    case symbol, state
    case tradeId = "trade_id"
  }
}

public enum Agreement: String, Codable, Sendable {
  case match, mismatch
}

/// The latest reconciliation with the broker and the fences it left; each part nil with its cause
/// when the bot does not keep it for the day.
public struct FlowReconcileV1: Codable, Hashable, Sendable {
  public let agreement: Agreement?
  public let agreementCause: String?
  /// The codes of `agreementCause` (added after version 1 shipped: empty from an older API).
  public let agreementCauseCodes: [ReasonV1]
  public let readAt: WireTime?
  public let mismatch: String?
  public let fences: [Fence]?
  public let fencesCause: String?
  /// The codes of `fencesCause` (added after version 1 shipped: empty from an older API).
  public let fencesCauseCodes: [ReasonV1]

  enum CodingKeys: String, CodingKey {
    case agreement, mismatch, fences
    case agreementCause = "agreement_cause"
    case readAt = "read_at"
    case fencesCause = "fences_cause"
    case agreementCauseCodes = "agreement_cause_codes"
    case fencesCauseCodes = "fences_cause_codes"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    agreement = try c.decodeNullable(Agreement.self, forKey: .agreement)
    agreementCause = try c.decodeNullable(String.self, forKey: .agreementCause)
    agreementCauseCodes = try c.decodeIfPresent([ReasonV1].self, forKey: .agreementCauseCodes) ?? []
    readAt = try c.decodeNullable(WireTime.self, forKey: .readAt)
    mismatch = try c.decodeNullable(String.self, forKey: .mismatch)
    fences = try c.decodeNullable([Fence].self, forKey: .fences)
    fencesCause = try c.decodeNullable(String.self, forKey: .fencesCause)
    fencesCauseCodes = try c.decodeIfPresent([ReasonV1].self, forKey: .fencesCauseCodes) ?? []
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encodeNullable(agreement, forKey: .agreement)
    try c.encodeNullable(agreementCause, forKey: .agreementCause)
    try c.encode(agreementCauseCodes, forKey: .agreementCauseCodes)
    try c.encodeNullable(readAt, forKey: .readAt)
    try c.encodeNullable(mismatch, forKey: .mismatch)
    try c.encodeNullable(fences, forKey: .fences)
    try c.encodeNullable(fencesCause, forKey: .fencesCause)
    try c.encode(fencesCauseCodes, forKey: .fencesCauseCodes)
  }

  /// Why the agreement is unknown, in the person's language (the bot's words for an unknown code).
  public var agreementCauseText: String? { ApiText.prose(agreementCauseCodes, text: agreementCause) }

  /// Why the fences are unknown, in the person's language (the bot's words for an unknown code).
  public var fencesCauseText: String? { ApiText.prose(fencesCauseCodes, text: fencesCause) }
}

/// The day's flow: screener chips, the six stages in order, the stops and the reconciliation.
public struct FlowV1: Codable, Hashable, Sendable {
  public let environment: String
  public let day: WireDate
  public let chips: [FlowChipV1]
  public let stages: [FlowStageV1]
  public let stops: [FlowStopV1]
  public let reconcile: FlowReconcileV1
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case environment, day, chips, stages, stops, reconcile
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    environment = try c.decode(String.self, forKey: .environment)
    day = try c.decode(WireDate.self, forKey: .day)
    chips = try c.decode([FlowChipV1].self, forKey: .chips)
    stages = try c.decode([FlowStageV1].self, forKey: .stages)
    stops = try c.decode([FlowStopV1].self, forKey: .stops)
    reconcile = try c.decode(FlowReconcileV1.self, forKey: .reconcile)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(environment, forKey: .environment)
    try c.encode(day, forKey: .day)
    try c.encode(chips, forKey: .chips)
    try c.encode(stages, forKey: .stages)
    try c.encode(stops, forKey: .stops)
    try c.encode(reconcile, forKey: .reconcile)
    try c.encode(apiVersion, forKey: .apiVersion)
  }
}

/// A symbol the strategy is watching, with the check that decided its latest verdict.
public struct WatchingRowV1: Codable, Hashable, Sendable {
  public let symbol: String
  public let at: WireTime
  public let strategy: StrategyRefV1
  public let verdict: Verdict
  public let decisiveCheck: CheckV1?
  /// How close the decisive check is to passing, 0 to 1; nil with `closenessCause`.
  public let closeness: DecimalString?
  public let closenessCause: String?
  public let quoteAgeSeconds: DecimalString?
  public let quoteAgeCause: String?
  /// `closeness_cause` as codes (docs/api.md, "Reason codes"); empty when there is none.
  public let closenessCauseCodes: [ReasonV1]
  /// `quote_age_cause` as codes (docs/api.md, "Reason codes"); empty when there is none.
  public let quoteAgeCauseCodes: [ReasonV1]

  enum CodingKeys: String, CodingKey {
    case symbol, at, strategy, verdict, closeness
    case decisiveCheck = "decisive_check"
    case closenessCause = "closeness_cause"
    case quoteAgeSeconds = "quote_age_seconds"
    case quoteAgeCause = "quote_age_cause"
    case closenessCauseCodes = "closeness_cause_codes"
    case quoteAgeCauseCodes = "quote_age_cause_codes"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    symbol = try c.decode(String.self, forKey: .symbol)
    at = try c.decode(WireTime.self, forKey: .at)
    strategy = try c.decode(StrategyRefV1.self, forKey: .strategy)
    verdict = try c.decode(Verdict.self, forKey: .verdict)
    decisiveCheck = try c.decodeNullable(CheckV1.self, forKey: .decisiveCheck)
    closeness = try c.decodeNullable(DecimalString.self, forKey: .closeness)
    closenessCause = try c.decodeNullable(String.self, forKey: .closenessCause)
    quoteAgeSeconds = try c.decodeNullable(DecimalString.self, forKey: .quoteAgeSeconds)
    quoteAgeCause = try c.decodeNullable(String.self, forKey: .quoteAgeCause)
    closenessCauseCodes = try c.decodeIfPresent([ReasonV1].self, forKey: .closenessCauseCodes) ?? []
    quoteAgeCauseCodes = try c.decodeIfPresent([ReasonV1].self, forKey: .quoteAgeCauseCodes) ?? []
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(symbol, forKey: .symbol)
    try c.encode(at, forKey: .at)
    try c.encode(strategy, forKey: .strategy)
    try c.encode(verdict, forKey: .verdict)
    try c.encodeNullable(decisiveCheck, forKey: .decisiveCheck)
    try c.encodeNullable(closeness, forKey: .closeness)
    try c.encodeNullable(closenessCause, forKey: .closenessCause)
    try c.encodeNullable(quoteAgeSeconds, forKey: .quoteAgeSeconds)
    try c.encodeNullable(quoteAgeCause, forKey: .quoteAgeCause)
    try c.encode(closenessCauseCodes, forKey: .closenessCauseCodes)
    try c.encode(quoteAgeCauseCodes, forKey: .quoteAgeCauseCodes)
  }

  /// Why closeness is unknown, in the person's language (the bot's words for an unknown code).
  public var closenessCauseText: String? { ApiText.prose(closenessCauseCodes, text: closenessCause) }

  /// Why the quote age is unknown, in the person's language (the bot's words for an unknown code).
  public var quoteAgeCauseText: String? { ApiText.prose(quoteAgeCauseCodes, text: quoteAgeCause) }
}

/// What can hold the size of an entry below what the strategy asked for.
public enum SizeBinding: String, Codable, Sendable, CaseIterable {
  /// Sized down to fit the room left under the daily loss limit.
  case dailyRoom = "daily_room"
}

/// The latest entry size the bot worked out today: for which symbol and decision, the quantity, and
/// what bound it, if anything did.
public struct LatestSizeV1: Codable, Hashable, Sendable {
  public let symbol: String
  public let at: WireTime
  public let strategy: StrategyId
  public let verdict: Verdict
  public let quantity: DecimalString
  /// Nil when nothing held the size down.
  public let binding: SizeBinding?
  public let bindingCause: String?
  /// The codes of `bindingCause` (added after version 1 shipped: empty from an older API).
  public let bindingCauseCodes: [ReasonV1]

  enum CodingKeys: String, CodingKey {
    case symbol, at, strategy, verdict, quantity, binding
    case bindingCause = "binding_cause"
    case bindingCauseCodes = "binding_cause_codes"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    symbol = try c.decode(String.self, forKey: .symbol)
    at = try c.decode(WireTime.self, forKey: .at)
    strategy = try c.decode(StrategyId.self, forKey: .strategy)
    verdict = try c.decode(Verdict.self, forKey: .verdict)
    quantity = try c.decode(DecimalString.self, forKey: .quantity)
    binding = try c.decodeNullable(SizeBinding.self, forKey: .binding)
    bindingCause = try c.decodeNullable(String.self, forKey: .bindingCause)
    bindingCauseCodes = try c.decodeIfPresent([ReasonV1].self, forKey: .bindingCauseCodes) ?? []
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(symbol, forKey: .symbol)
    try c.encode(at, forKey: .at)
    try c.encode(strategy, forKey: .strategy)
    try c.encode(verdict, forKey: .verdict)
    try c.encode(quantity, forKey: .quantity)
    try c.encodeNullable(binding, forKey: .binding)
    try c.encodeNullable(bindingCause, forKey: .bindingCause)
    try c.encode(bindingCauseCodes, forKey: .bindingCauseCodes)
  }

  /// Why no binding limit is named, in the person's language (the bot's words for an unknown code).
  public var bindingCauseText: String? { ApiText.prose(bindingCauseCodes, text: bindingCause) }
}

/// The symbols the strategy is watching closely on the day, closest first; `total` counts them all.
public struct WatchingV1: Codable, Hashable, Sendable {
  public let day: WireDate
  public let total: Int
  public let rows: [WatchingRowV1]
  /// The latest entry size today, or nil before the first.
  public let latestSize: LatestSizeV1?
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case day, total, rows
    case latestSize = "latest_size"
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    day = try c.decode(WireDate.self, forKey: .day)
    total = try c.decode(Int.self, forKey: .total)
    rows = try c.decode([WatchingRowV1].self, forKey: .rows)
    latestSize = try c.decodeNullable(LatestSizeV1.self, forKey: .latestSize)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(day, forKey: .day)
    try c.encode(total, forKey: .total)
    try c.encode(rows, forKey: .rows)
    try c.encodeNullable(latestSize, forKey: .latestSize)
    try c.encode(apiVersion, forKey: .apiVersion)
  }
}
