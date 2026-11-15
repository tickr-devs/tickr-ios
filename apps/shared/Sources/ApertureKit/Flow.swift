import Foundation

// Swift mirrors of flow-v1 and watching-v1 in src/aperture/api/contract.py: the Overview's live
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
  /// Why the universe left the symbol out; nil when it was admitted.
  public let excludedCause: String?

  enum CodingKeys: String, CodingKey {
    case symbol, sources
    case changePct = "change_pct"
    case changeCause = "change_cause"
    case excludedCause = "excluded_cause"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    symbol = try c.decode(String.self, forKey: .symbol)
    sources = try c.decode([ScreenerSource].self, forKey: .sources)
    changePct = try c.decodeNullable(DecimalString.self, forKey: .changePct)
    changeCause = try c.decodeNullable(String.self, forKey: .changeCause)
    excludedCause = try c.decodeNullable(String.self, forKey: .excludedCause)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(symbol, forKey: .symbol)
    try c.encode(sources, forKey: .sources)
    try c.encodeNullable(changePct, forKey: .changePct)
    try c.encodeNullable(changeCause, forKey: .changeCause)
    try c.encodeNullable(excludedCause, forKey: .excludedCause)
  }
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
  public let readAt: WireTime?
  public let mismatch: String?
  public let fences: [Fence]?
  public let fencesCause: String?

  enum CodingKeys: String, CodingKey {
    case agreement, mismatch, fences
    case agreementCause = "agreement_cause"
    case readAt = "read_at"
    case fencesCause = "fences_cause"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    agreement = try c.decodeNullable(Agreement.self, forKey: .agreement)
    agreementCause = try c.decodeNullable(String.self, forKey: .agreementCause)
    readAt = try c.decodeNullable(WireTime.self, forKey: .readAt)
    mismatch = try c.decodeNullable(String.self, forKey: .mismatch)
    fences = try c.decodeNullable([Fence].self, forKey: .fences)
    fencesCause = try c.decodeNullable(String.self, forKey: .fencesCause)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encodeNullable(agreement, forKey: .agreement)
    try c.encodeNullable(agreementCause, forKey: .agreementCause)
    try c.encodeNullable(readAt, forKey: .readAt)
    try c.encodeNullable(mismatch, forKey: .mismatch)
    try c.encodeNullable(fences, forKey: .fences)
    try c.encodeNullable(fencesCause, forKey: .fencesCause)
  }
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

  enum CodingKeys: String, CodingKey {
    case symbol, at, strategy, verdict, closeness
    case decisiveCheck = "decisive_check"
    case closenessCause = "closeness_cause"
    case quoteAgeSeconds = "quote_age_seconds"
    case quoteAgeCause = "quote_age_cause"
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
  }
}

/// The symbols the strategy is watching closely on the day, closest first; `total` counts them all.
public struct WatchingV1: Codable, Hashable, Sendable {
  public let day: WireDate
  public let total: Int
  public let rows: [WatchingRowV1]
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case day, total, rows
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    day = try c.decode(WireDate.self, forKey: .day)
    total = try c.decode(Int.self, forKey: .total)
    rows = try c.decode([WatchingRowV1].self, forKey: .rows)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(day, forKey: .day)
    try c.encode(total, forKey: .total)
    try c.encode(rows, forKey: .rows)
    try c.encode(apiVersion, forKey: .apiVersion)
  }
}
