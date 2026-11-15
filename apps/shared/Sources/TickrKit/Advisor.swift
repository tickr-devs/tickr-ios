import Foundation

// Swift mirror of advisor-runs-v1 (GET /advisor) in src/tickr/api/contract.py: the AI
// advisor's runs with their proposals, ideas, hold-out verdicts and the owner's decision.
// Read-only; nothing here applies or deploys a strategy. Every number is SIMULATED.

/// What one advisor run produced.
public enum AdvisorRunStatus: String, Codable, Sendable, CaseIterable {
  case proposed, idea
  case noChange = "no_change"
  case refused
}

/// Where the advisor's evidence came from: recorded trading days or a SIMULATED backtest.
public enum AdvisorMode: String, Codable, Sendable, CaseIterable {
  case live, backtest
}

/// What the bootstrap interval of mean R says on the withheld hold-out.
public enum HoldoutVerdict: String, Codable, Sendable, CaseIterable {
  case edge
  case negativeEdge = "negative_edge"
  case noEvidence = "no_evidence"
  case tooFew = "too_few"
}

/// The owner's review of a run: a note only, never a deployment.
public enum OwnerVerdict: String, Codable, Sendable, CaseIterable {
  case accepted, rejected
}

/// One changed strategy.toml value; `now` and `proposed` are the values as text.
public struct AdvisorChangeV1: Codable, Hashable, Sendable {
  public let section: String
  public let key: String
  public let now: String
  public let proposed: String
  public let reason: String
  public let evidence: String
}

/// A new strategy idea: text for a developer, never code.
public struct AdvisorIdeaV1: Codable, Hashable, Sendable {
  public let name: String
  public let hypothesis: String
  public let entryRule: String
  public let exitRule: String
  public let filters: String
  public let evidence: String
  public let testPlan: String

  enum CodingKeys: String, CodingKey {
    case name, hypothesis, filters, evidence
    case entryRule = "entry_rule"
    case exitRule = "exit_rule"
    case testPlan = "test_plan"
  }
}

/// SIMULATED backtest numbers of one period; nil = not computed.
public struct AdvisorStatsV1: Codable, Hashable, Sendable {
  public let trades: Int?
  public let winRatePercent: DecimalString?
  public let meanR: DecimalString?
  public let medianR: DecimalString?
  public let totalR: DecimalString?
  public let profitFactor: DecimalString?
  public let meanRIntervalLow: DecimalString?
  public let meanRIntervalHigh: DecimalString?

  enum CodingKeys: String, CodingKey {
    case trades
    case winRatePercent = "win_rate_percent"
    case meanR = "mean_r"
    case medianR = "median_r"
    case totalR = "total_r"
    case profitFactor = "profit_factor"
    case meanRIntervalLow = "mean_r_interval_low"
    case meanRIntervalHigh = "mean_r_interval_high"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    trades = try c.decodeNullable(Int.self, forKey: .trades)
    winRatePercent = try c.decodeNullable(DecimalString.self, forKey: .winRatePercent)
    meanR = try c.decodeNullable(DecimalString.self, forKey: .meanR)
    medianR = try c.decodeNullable(DecimalString.self, forKey: .medianR)
    totalR = try c.decodeNullable(DecimalString.self, forKey: .totalR)
    profitFactor = try c.decodeNullable(DecimalString.self, forKey: .profitFactor)
    meanRIntervalLow = try c.decodeNullable(DecimalString.self, forKey: .meanRIntervalLow)
    meanRIntervalHigh = try c.decodeNullable(DecimalString.self, forKey: .meanRIntervalHigh)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encodeNullable(trades, forKey: .trades)
    try c.encodeNullable(winRatePercent, forKey: .winRatePercent)
    try c.encodeNullable(meanR, forKey: .meanR)
    try c.encodeNullable(medianR, forKey: .medianR)
    try c.encodeNullable(totalR, forKey: .totalR)
    try c.encodeNullable(profitFactor, forKey: .profitFactor)
    try c.encodeNullable(meanRIntervalLow, forKey: .meanRIntervalLow)
    try c.encodeNullable(meanRIntervalHigh, forKey: .meanRIntervalHigh)
  }
}

/// One judge result: a candidate against the base on the hold-out the advisor never saw. Only
/// `holdout` and `baseHoldout` are evidence; `fitting` is where the candidate was tuned.
public struct AdvisorJudgeV1: Codable, Hashable, Sendable {
  public let candidate: String
  public let base: String
  public let holdoutStarts: WireDate
  public let verdict: HoldoutVerdict
  public let baseVerdict: HoldoutVerdict
  public let holdout: AdvisorStatsV1?
  public let baseHoldout: AdvisorStatsV1?
  public let fitting: AdvisorStatsV1?

  enum CodingKeys: String, CodingKey {
    case candidate, base, verdict, holdout, fitting
    case holdoutStarts = "holdout_starts"
    case baseVerdict = "base_verdict"
    case baseHoldout = "base_holdout"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    candidate = try c.decode(String.self, forKey: .candidate)
    base = try c.decode(String.self, forKey: .base)
    holdoutStarts = try c.decode(WireDate.self, forKey: .holdoutStarts)
    verdict = try c.decode(HoldoutVerdict.self, forKey: .verdict)
    baseVerdict = try c.decode(HoldoutVerdict.self, forKey: .baseVerdict)
    holdout = try c.decodeNullable(AdvisorStatsV1.self, forKey: .holdout)
    baseHoldout = try c.decodeNullable(AdvisorStatsV1.self, forKey: .baseHoldout)
    fitting = try c.decodeNullable(AdvisorStatsV1.self, forKey: .fitting)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(candidate, forKey: .candidate)
    try c.encode(base, forKey: .base)
    try c.encode(holdoutStarts, forKey: .holdoutStarts)
    try c.encode(verdict, forKey: .verdict)
    try c.encode(baseVerdict, forKey: .baseVerdict)
    try c.encodeNullable(holdout, forKey: .holdout)
    try c.encodeNullable(baseHoldout, forKey: .baseHoldout)
    try c.encodeNullable(fitting, forKey: .fitting)
  }
}

/// The owner's recorded review of a run.
public struct AdvisorDecisionV1: Codable, Hashable, Sendable {
  public let verdict: OwnerVerdict
  public let at: WireTime
}

/// One advisor run folder. Texts are the advisor's own; nothing here is applied.
public struct AdvisorRunV1: Codable, Hashable, Sendable, Identifiable {
  /// The run folder's name: "<UTC time>-<strategy>".
  public let id: String
  public let at: WireTime
  public let mode: AdvisorMode
  public let status: AdvisorRunStatus
  /// "price-action-v1 v1".
  public let base: String
  /// The new version when `status` is proposed.
  public let proposed: String?
  public let model: String
  /// What it learned from, one line.
  public let evidence: String
  /// Hold-out rule: results on these days prove nothing.
  public let tunedOn: String
  /// Where it may be judged.
  public let judgeOn: String
  public let summary: String
  public let changes: [AdvisorChangeV1]
  public let expectedEffect: String
  public let risks: [String]
  public let noChangeReason: String
  /// Why the answer was refused; empty otherwise.
  public let cause: String
  public let idea: AdvisorIdeaV1?
  public let judges: [AdvisorJudgeV1]
  /// Nil = awaiting the owner's review.
  public let decision: AdvisorDecisionV1?

  enum CodingKeys: String, CodingKey {
    case id, at, mode, status, base, proposed, model, evidence, summary, changes, risks, cause
    case idea, judges, decision
    case tunedOn = "tuned_on"
    case judgeOn = "judge_on"
    case expectedEffect = "expected_effect"
    case noChangeReason = "no_change_reason"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    at = try c.decode(WireTime.self, forKey: .at)
    mode = try c.decode(AdvisorMode.self, forKey: .mode)
    status = try c.decode(AdvisorRunStatus.self, forKey: .status)
    base = try c.decode(String.self, forKey: .base)
    proposed = try c.decodeNullable(String.self, forKey: .proposed)
    model = try c.decode(String.self, forKey: .model)
    evidence = try c.decode(String.self, forKey: .evidence)
    tunedOn = try c.decode(String.self, forKey: .tunedOn)
    judgeOn = try c.decode(String.self, forKey: .judgeOn)
    summary = try c.decode(String.self, forKey: .summary)
    changes = try c.decode([AdvisorChangeV1].self, forKey: .changes)
    expectedEffect = try c.decode(String.self, forKey: .expectedEffect)
    risks = try c.decode([String].self, forKey: .risks)
    noChangeReason = try c.decode(String.self, forKey: .noChangeReason)
    cause = try c.decode(String.self, forKey: .cause)
    idea = try c.decodeNullable(AdvisorIdeaV1.self, forKey: .idea)
    judges = try c.decode([AdvisorJudgeV1].self, forKey: .judges)
    decision = try c.decodeNullable(AdvisorDecisionV1.self, forKey: .decision)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id, forKey: .id)
    try c.encode(at, forKey: .at)
    try c.encode(mode, forKey: .mode)
    try c.encode(status, forKey: .status)
    try c.encode(base, forKey: .base)
    try c.encodeNullable(proposed, forKey: .proposed)
    try c.encode(model, forKey: .model)
    try c.encode(evidence, forKey: .evidence)
    try c.encode(tunedOn, forKey: .tunedOn)
    try c.encode(judgeOn, forKey: .judgeOn)
    try c.encode(summary, forKey: .summary)
    try c.encode(changes, forKey: .changes)
    try c.encode(expectedEffect, forKey: .expectedEffect)
    try c.encode(risks, forKey: .risks)
    try c.encode(noChangeReason, forKey: .noChangeReason)
    try c.encode(cause, forKey: .cause)
    try c.encodeNullable(idea, forKey: .idea)
    try c.encode(judges, forKey: .judges)
    try c.encodeNullable(decision, forKey: .decision)
  }

  /// A proposal or idea the owner has not reviewed yet (the Overview tag counts these).
  public var awaitingReview: Bool {
    decision == nil && (status == .proposed || status == .idea)
  }
}

/// A run folder the API could not read, with its one cause.
public struct AdvisorUnreadableV1: Codable, Hashable, Sendable {
  public let id: String
  public let cause: String
}

/// GET /advisor.
public struct AdvisorRunsV1: Codable, Hashable, Sendable {
  /// Newest first.
  public let runs: [AdvisorRunV1]
  public let unreadable: [AdvisorUnreadableV1]
  /// Proposals and ideas (of every run, not only the listed) with no owner decision.
  public let awaitingReview: Int
  /// Why there are no runs (no proposals folder yet).
  public let cause: String?
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case runs, unreadable, cause
    case awaitingReview = "awaiting_review"
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    runs = try c.decode([AdvisorRunV1].self, forKey: .runs)
    unreadable = try c.decode([AdvisorUnreadableV1].self, forKey: .unreadable)
    awaitingReview = try c.decode(Int.self, forKey: .awaitingReview)
    cause = try c.decodeNullable(String.self, forKey: .cause)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(runs, forKey: .runs)
    try c.encode(unreadable, forKey: .unreadable)
    try c.encode(awaitingReview, forKey: .awaitingReview)
    try c.encodeNullable(cause, forKey: .cause)
    try c.encode(apiVersion, forKey: .apiVersion)
  }
}
