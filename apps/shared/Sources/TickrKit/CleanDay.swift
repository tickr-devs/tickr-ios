import Foundation

// The clean-day verdict of days-v1 (docs/api.md, "Clean day").

/// The clean-day verdict of one date.
public enum CleanVerdict: String, Codable, Sendable {
  case clean
  case notClean = "not_clean"
  /// The journal cannot tell yet (the day is not over) or at all; `CleanDay.cause` says why.
  case unknown
}

/// What made a day not clean.
public enum CleanCauseKind: String, Codable, Sendable {
  case reconcileMismatch = "reconcile_mismatch"
  case unknownOrderOutcome = "unknown_order_outcome"
  case unprotectedPosition = "unprotected_position"
  case safetyExit = "safety_exit"
  case dayEndNotClean = "day_end_not_clean"
}

/// One reason a day was not clean, with the journal entries that show it.
public struct CleanCause: Codable, Hashable, Sendable {
  public let kind: CleanCauseKind
  public let text: String
  public let journalSeqs: [Int]
  /// `text` as codes (docs/api.md, "Reason codes").
  public let textCodes: [ReasonV1]

  enum CodingKeys: String, CodingKey {
    case kind, text
    case journalSeqs = "journal_seqs"
    case textCodes = "text_codes"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    kind = try c.decode(CleanCauseKind.self, forKey: .kind)
    text = try c.decode(String.self, forKey: .text)
    journalSeqs = try c.decode([Int].self, forKey: .journalSeqs)
    textCodes = try c.decodeIfPresent([ReasonV1].self, forKey: .textCodes) ?? []
  }
}

/// A date's clean-day verdict and the reconciliation it rests on.
public struct CleanDay: Codable, Hashable, Sendable {
  public let verdict: CleanVerdict
  /// Why the verdict is unknown; nil otherwise.
  public let cause: String?
  /// Every reason the day was not clean; empty unless `verdict` is `notClean`.
  public let causes: [CleanCause]
  /// Reconciliation passes recorded on the date.
  public let reconcileRows: Int
  public let firstReconcileAt: WireTime?
  public let lastReconcileAt: WireTime?
  /// Journal entry of the day-end record; nil when there is none.
  public let dayEndSeq: Int?
  /// `cause` as codes (docs/api.md, "Reason codes"); empty when there is none.
  public let causeCodes: [ReasonV1]

  enum CodingKeys: String, CodingKey {
    case verdict, cause, causes
    case reconcileRows = "reconcile_rows"
    case firstReconcileAt = "first_reconcile_at"
    case lastReconcileAt = "last_reconcile_at"
    case dayEndSeq = "day_end_seq"
    case causeCodes = "cause_codes"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    verdict = try c.decode(CleanVerdict.self, forKey: .verdict)
    cause = try c.decodeNullable(String.self, forKey: .cause)
    causes = try c.decode([CleanCause].self, forKey: .causes)
    reconcileRows = try c.decode(Int.self, forKey: .reconcileRows)
    firstReconcileAt = try c.decodeNullable(WireTime.self, forKey: .firstReconcileAt)
    lastReconcileAt = try c.decodeNullable(WireTime.self, forKey: .lastReconcileAt)
    dayEndSeq = try c.decodeNullable(Int.self, forKey: .dayEndSeq)
    causeCodes = try c.decodeIfPresent([ReasonV1].self, forKey: .causeCodes) ?? []
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(verdict, forKey: .verdict)
    try c.encodeNullable(cause, forKey: .cause)
    try c.encode(causes, forKey: .causes)
    try c.encode(reconcileRows, forKey: .reconcileRows)
    try c.encodeNullable(firstReconcileAt, forKey: .firstReconcileAt)
    try c.encodeNullable(lastReconcileAt, forKey: .lastReconcileAt)
    try c.encodeNullable(dayEndSeq, forKey: .dayEndSeq)
    try c.encode(causeCodes, forKey: .causeCodes)
  }
}
