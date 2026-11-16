import Foundation

// Swift mirrors of symbols-v1 and movers-v1 in src/tickr/api/contract.py: every symbol of a day
// through the pipeline with where and why it stands now, and the day's fast movers.

/// A screener that listed a symbol, with its rank in the latest such list.
public struct SymbolSourceV1: Codable, Hashable, Sendable {
  public let kind: ScreenerSource
  public let rank: Int
}

/// The pipeline a screened symbol goes through, in order.
public enum SymbolStage: String, Codable, Sendable, CaseIterable {
  case screeners, universe, quote, bars, strategy, risk, order, stop
}

/// Where a symbol stands now at its current stage.
public enum SymbolState: String, Codable, Sendable, CaseIterable {
  /// Through the last stage: in a trade whose broker stop was seen working.
  case passed
  /// Nothing failed; the next stage has not happened yet.
  case waiting
  /// Refused at this stage; the cause and the check or detail say why.
  case dropped
  /// The latest discovery pass stopped before deciding it.
  case notReached = "not_reached"
}

/// When a symbol first got to a stage; nil where no record says (the order and stop stages).
public struct SymbolReachV1: Codable, Hashable, Sendable {
  public let stage: SymbolStage
  public let at: WireTime?

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    stage = try c.decode(SymbolStage.self, forKey: .stage)
    at = try c.decodeNullable(WireTime.self, forKey: .at)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(stage, forKey: .stage)
    try c.encodeNullable(at, forKey: .at)
  }

  enum CodingKeys: String, CodingKey { case stage, at }
}

/// One symbol seen on the day: its furthest stage, and where and why it stands now.
public struct SymbolRowV1: Codable, Hashable, Sendable {
  public let symbol: String
  public let sources: [SymbolSourceV1]
  public let changePct: DecimalString?
  public let firstSeen: WireTime?
  public let furthest: SymbolStage
  public let stage: SymbolStage
  public let state: SymbolState
  /// The code of why it was dropped or not reached; nil otherwise.
  public let cause: String?
  /// The failed strategy check, when a rule dropped it.
  public let check: CheckV1?
  /// The measured value against the threshold of a platform cause, or the admission's text.
  public let detail: String?
  public let verdict: Verdict?
  public let setup: String?
  public let at: WireTime?
  // Added after v1 shipped: absent from older documents (nil or empty then).
  /// The price in the latest screener row that listed it.
  public let price: DecimalString?
  /// Each stage up to `furthest`, in pipeline order, with when it was first reached.
  public let reached: [SymbolReachV1]
  /// The time of the active strategy's latest decision on it.
  public let decidedAt: WireTime?
  /// That decision's strategy, `name@version`.
  public let strategy: String?
  /// That decision's checks, in the strategy's order.
  public let checks: [CheckV1]

  enum CodingKeys: String, CodingKey {
    case symbol, sources, furthest, stage, state, cause, check, detail, verdict, setup, at
    case price, reached, strategy, checks
    case changePct = "change_pct"
    case firstSeen = "first_seen"
    case decidedAt = "decided_at"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    symbol = try c.decode(String.self, forKey: .symbol)
    sources = try c.decode([SymbolSourceV1].self, forKey: .sources)
    changePct = try c.decodeNullable(DecimalString.self, forKey: .changePct)
    firstSeen = try c.decodeNullable(WireTime.self, forKey: .firstSeen)
    furthest = try c.decode(SymbolStage.self, forKey: .furthest)
    stage = try c.decode(SymbolStage.self, forKey: .stage)
    state = try c.decode(SymbolState.self, forKey: .state)
    cause = try c.decodeNullable(String.self, forKey: .cause)
    check = try c.decodeNullable(CheckV1.self, forKey: .check)
    detail = try c.decodeNullable(String.self, forKey: .detail)
    verdict = try c.decodeNullable(Verdict.self, forKey: .verdict)
    setup = try c.decodeNullable(String.self, forKey: .setup)
    at = try c.decodeNullable(WireTime.self, forKey: .at)
    price = try c.decodeIfPresent(DecimalString.self, forKey: .price)
    reached = try c.decodeIfPresent([SymbolReachV1].self, forKey: .reached) ?? []
    decidedAt = try c.decodeIfPresent(WireTime.self, forKey: .decidedAt)
    strategy = try c.decodeIfPresent(String.self, forKey: .strategy)
    checks = try c.decodeIfPresent([CheckV1].self, forKey: .checks) ?? []
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(symbol, forKey: .symbol)
    try c.encode(sources, forKey: .sources)
    try c.encodeNullable(changePct, forKey: .changePct)
    try c.encodeNullable(firstSeen, forKey: .firstSeen)
    try c.encode(furthest, forKey: .furthest)
    try c.encode(stage, forKey: .stage)
    try c.encode(state, forKey: .state)
    try c.encodeNullable(cause, forKey: .cause)
    try c.encodeNullable(check, forKey: .check)
    try c.encodeNullable(detail, forKey: .detail)
    try c.encodeNullable(verdict, forKey: .verdict)
    try c.encodeNullable(setup, forKey: .setup)
    try c.encodeNullable(at, forKey: .at)
    try c.encodeNullable(price, forKey: .price)
    try c.encode(reached, forKey: .reached)
    try c.encodeNullable(decidedAt, forKey: .decidedAt)
    try c.encodeNullable(strategy, forKey: .strategy)
    try c.encode(checks, forKey: .checks)
  }
}

/// How many symbols reached a stage on the day.
public struct SymbolStageCountV1: Codable, Hashable, Sendable {
  public let stage: SymbolStage
  public let count: Int
}

/// GET /symbols: every symbol the bot looked at on a day.
public struct SymbolsV1: Codable, Hashable, Sendable {
  public let day: WireDate
  /// The end of the latest discovery pass; nil with `asOfCause`.
  public let asOf: WireTime?
  public let asOfCause: String?
  public let stages: [SymbolStageCountV1]
  public let rows: [SymbolRowV1]
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case day, stages, rows
    case asOf = "as_of"
    case asOfCause = "as_of_cause"
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    day = try c.decode(WireDate.self, forKey: .day)
    asOf = try c.decodeNullable(WireTime.self, forKey: .asOf)
    asOfCause = try c.decodeNullable(String.self, forKey: .asOfCause)
    stages = try c.decode([SymbolStageCountV1].self, forKey: .stages)
    rows = try c.decode([SymbolRowV1].self, forKey: .rows)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(day, forKey: .day)
    try c.encodeNullable(asOf, forKey: .asOf)
    try c.encodeNullable(asOfCause, forKey: .asOfCause)
    try c.encode(stages, forKey: .stages)
    try c.encode(rows, forKey: .rows)
    try c.encode(apiVersion, forKey: .apiVersion)
  }
}

/// The active strategy's fast-mover thresholds.
public struct FastMoverRulesV1: Codable, Hashable, Sendable {
  public let lookbackBars: Int
  public let minVolumeRatio: DecimalString
  public let minMoveAtr: DecimalString
  public let minDollarVolumeRatio: DecimalString
  public let minBarDollarVolumeUsd: DecimalString

  enum CodingKeys: String, CodingKey {
    case lookbackBars = "lookback_bars"
    case minVolumeRatio = "min_volume_ratio"
    case minMoveAtr = "min_move_atr"
    case minDollarVolumeRatio = "min_dollar_volume_ratio"
    case minBarDollarVolumeUsd = "min_bar_dollar_volume_usd"
  }
}

/// The latest bar of the day that made a symbol a fast mover.
public struct FastMoverV1: Codable, Hashable, Sendable {
  public let symbol: String
  /// The bar's start.
  public let at: WireTime
  public let close: DecimalString
  public let barDollarVolume: DecimalString
  public let volumeRatio: DecimalString
  /// Signed: above 0 the bar closed up.
  public let moveAtr: DecimalString
  public let dollarVolumeRatio: DecimalString
  /// The signals that reached their thresholds.
  public let fired: [String]
  public let spikeUp: Bool
  /// The strategy's latest decision of the day is WATCH.
  public let watching: Bool

  enum CodingKeys: String, CodingKey {
    case symbol, at, close, fired, watching
    case barDollarVolume = "bar_dollar_volume"
    case volumeRatio = "volume_ratio"
    case moveAtr = "move_atr"
    case dollarVolumeRatio = "dollar_volume_ratio"
    case spikeUp = "spike_up"
  }
}

/// GET /movers: every fast mover of a day, newest first.
public struct MoversV1: Codable, Hashable, Sendable {
  public let day: WireDate
  /// Nil with `rulesCause` when the active strategy defines no fast movers.
  public let rules: FastMoverRulesV1?
  public let rulesCause: String?
  public let movers: [FastMoverV1]
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case day, rules, movers
    case rulesCause = "rules_cause"
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    day = try c.decode(WireDate.self, forKey: .day)
    rules = try c.decodeNullable(FastMoverRulesV1.self, forKey: .rules)
    rulesCause = try c.decodeNullable(String.self, forKey: .rulesCause)
    movers = try c.decode([FastMoverV1].self, forKey: .movers)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(day, forKey: .day)
    try c.encodeNullable(rules, forKey: .rules)
    try c.encodeNullable(rulesCause, forKey: .rulesCause)
    try c.encode(movers, forKey: .movers)
    try c.encode(apiVersion, forKey: .apiVersion)
  }
}
