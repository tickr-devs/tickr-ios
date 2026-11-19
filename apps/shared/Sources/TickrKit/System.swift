import Foundation

// Swift mirror of system-v1 (GET /system) in src/tickr/api/contract.py: the System card. The
// portable parts (the Webull link, the latest preflight, model training) come first; `host`
// holds the machine's own services (on a Mac the watchdog and the no-sleep hold), nil on a
// machine without them, so the rest of the card stays when the bot runs elsewhere.

/// How old the bot's last broker read is against the warning and block ages.
public enum LinkState: String, Codable, Sendable { case fresh, aging, stale, unknown }

/// The link to Webull: the bot's last successful broker read and the quote stream's health.
public struct BrokerLinkV1: Codable, Hashable, Sendable {
  public let lastReadAt: WireTime?
  public let warnSeconds: DecimalString
  public let maxAgeSeconds: DecimalString
  public let state: LinkState
  public let stream: StreamHealth?
  public let cause: String?
  public let causeCodes: [ReasonV1]

  enum CodingKeys: String, CodingKey {
    case state, stream, cause
    case lastReadAt = "last_read_at"
    case warnSeconds = "warn_seconds"
    case maxAgeSeconds = "max_age_seconds"
    case causeCodes = "cause_codes"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    lastReadAt = try c.decodeNullable(WireTime.self, forKey: .lastReadAt)
    warnSeconds = try c.decode(DecimalString.self, forKey: .warnSeconds)
    maxAgeSeconds = try c.decode(DecimalString.self, forKey: .maxAgeSeconds)
    state = try c.decode(LinkState.self, forKey: .state)
    stream = try c.decodeNullable(StreamHealth.self, forKey: .stream)
    cause = try c.decodeNullable(String.self, forKey: .cause)
    causeCodes = try c.decodeIfPresent([ReasonV1].self, forKey: .causeCodes) ?? []
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encodeNullable(lastReadAt, forKey: .lastReadAt)
    try c.encode(warnSeconds, forKey: .warnSeconds)
    try c.encode(maxAgeSeconds, forKey: .maxAgeSeconds)
    try c.encode(state, forKey: .state)
    try c.encodeNullable(stream, forKey: .stream)
    try c.encodeNullable(cause, forKey: .cause)
    try c.encode(causeCodes, forKey: .causeCodes)
  }

  /// Why the link's state is unknown, in the person's language (the bot's words for an unknown code).
  public var causeText: String? { ApiText.prose(causeCodes, text: cause) }
}

public enum PreflightOutcome: String, Codable, Sendable {
  case ready, failed
  case configInvalid = "config-invalid"
  case noSession = "no-session"
}

/// Which launchd job ran the preflight: the morning job, or the bot job's own before it starts.
public enum PreflightJobName: String, Codable, Sendable {
  case preflight
  case botStart = "bot-start"
}

/// One preflight check: a check code and, when it failed, its cause code.
public struct PreflightCheckV1: Codable, Hashable, Sendable {
  public let name: String
  public let passed: Bool
  public let cause: String?

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(name, forKey: .name)
    try c.encode(passed, forKey: .passed)
    try c.encodeNullable(cause, forKey: .cause)
  }
}

/// The latest preflight, as its record file says.
public struct MorningCheckV1: Codable, Hashable, Sendable {
  public let job: PreflightJobName
  public let startedAt: WireTime
  public let finishedAt: WireTime
  /// The New York date it ran on.
  public let day: WireDate
  public let outcome: PreflightOutcome
  /// The bot does not start on this result.
  public let blocksStart: Bool
  /// The first failed check's cause code.
  public let cause: String?
  public let checks: [PreflightCheckV1]

  enum CodingKeys: String, CodingKey {
    case job, day, outcome, cause, checks
    case startedAt = "started_at"
    case finishedAt = "finished_at"
    case blocksStart = "blocks_start"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    job = try c.decode(PreflightJobName.self, forKey: .job)
    startedAt = try c.decode(WireTime.self, forKey: .startedAt)
    finishedAt = try c.decode(WireTime.self, forKey: .finishedAt)
    day = try c.decode(WireDate.self, forKey: .day)
    outcome = try c.decode(PreflightOutcome.self, forKey: .outcome)
    blocksStart = try c.decode(Bool.self, forKey: .blocksStart)
    cause = try c.decodeNullable(String.self, forKey: .cause)
    checks = try c.decode([PreflightCheckV1].self, forKey: .checks)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(job, forKey: .job)
    try c.encode(startedAt, forKey: .startedAt)
    try c.encode(finishedAt, forKey: .finishedAt)
    try c.encode(day, forKey: .day)
    try c.encode(outcome, forKey: .outcome)
    try c.encode(blocksStart, forKey: .blocksStart)
    try c.encodeNullable(cause, forKey: .cause)
    try c.encode(checks, forKey: .checks)
  }

  /// The first failed check, the one `cause` names.
  public var failedCheck: PreflightCheckV1? { checks.first { !$0.passed } }
}

public enum TrainingState: String, Codable, Sendable { case running, done, failed }

/// The model training job's own progress: `done` of `total` steps.
public struct TrainingV1: Codable, Hashable, Sendable {
  /// The name the job gives itself, shown as written.
  public let job: String
  public let state: TrainingState
  public let done: Int
  public let total: Int
  public let startedAt: WireTime
  public let updatedAt: WireTime
  public let cause: String?
  public let causeCodes: [ReasonV1]

  enum CodingKeys: String, CodingKey {
    case job, state, done, total, cause
    case startedAt = "started_at"
    case updatedAt = "updated_at"
    case causeCodes = "cause_codes"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    job = try c.decode(String.self, forKey: .job)
    state = try c.decode(TrainingState.self, forKey: .state)
    done = try c.decode(Int.self, forKey: .done)
    total = try c.decode(Int.self, forKey: .total)
    startedAt = try c.decode(WireTime.self, forKey: .startedAt)
    updatedAt = try c.decode(WireTime.self, forKey: .updatedAt)
    cause = try c.decodeNullable(String.self, forKey: .cause)
    causeCodes = try c.decodeIfPresent([ReasonV1].self, forKey: .causeCodes) ?? []
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(job, forKey: .job)
    try c.encode(state, forKey: .state)
    try c.encode(done, forKey: .done)
    try c.encode(total, forKey: .total)
    try c.encode(startedAt, forKey: .startedAt)
    try c.encode(updatedAt, forKey: .updatedAt)
    try c.encodeNullable(cause, forKey: .cause)
    try c.encode(causeCodes, forKey: .causeCodes)
  }

  /// Share of the steps done, 0...1; 0 for a job with no steps.
  public var fraction: Double { total > 0 ? Double(done) / Double(total) : 0 }

  /// Why it failed, in the person's language (the job's words for an unknown code).
  public var causeText: String? { ApiText.prose(causeCodes, text: cause) }
}

public enum RestartOutcome: String, Codable, Sendable { case started, failed, refused }

/// One watchdog attempt to start a down bot job.
public struct WatchdogRestartV1: Codable, Hashable, Sendable {
  public let at: WireTime
  public let outcome: RestartOutcome
  /// The restart for an entry resting while the bot was down (before the flatten restart time).
  public let early: Bool
  /// Nil on a refusal.
  public let openTrades: Int?
  public let cause: String?
  public let causeCodes: [ReasonV1]

  enum CodingKeys: String, CodingKey {
    case at, outcome, early, cause
    case openTrades = "open_trades"
    case causeCodes = "cause_codes"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    at = try c.decode(WireTime.self, forKey: .at)
    outcome = try c.decode(RestartOutcome.self, forKey: .outcome)
    early = try c.decode(Bool.self, forKey: .early)
    openTrades = try c.decodeNullable(Int.self, forKey: .openTrades)
    cause = try c.decodeNullable(String.self, forKey: .cause)
    causeCodes = try c.decodeIfPresent([ReasonV1].self, forKey: .causeCodes) ?? []
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(at, forKey: .at)
    try c.encode(outcome, forKey: .outcome)
    try c.encode(early, forKey: .early)
    try c.encodeNullable(openTrades, forKey: .openTrades)
    try c.encodeNullable(cause, forKey: .cause)
    try c.encode(causeCodes, forKey: .causeCodes)
  }

  /// Why it failed or was refused, in the person's language (the bot's words for an unknown code).
  public var causeText: String? { ApiText.prose(causeCodes, text: cause) }
}

/// The watchdog launchd job, from its journal.
public struct WatchdogV1: Codable, Hashable, Sendable {
  /// New York date of its latest start.
  public let startedDay: WireDate?
  public let lastCheckAt: WireTime?
  public let lastCheckRead: Bool?
  public let lastCheckFlat: Bool?
  /// Newest first; at most the API's row limit of `restartCount`.
  public let restarts: [WatchdogRestartV1]
  public let restartCount: Int
  public let cause: String?
  public let causeCodes: [ReasonV1]

  enum CodingKeys: String, CodingKey {
    case restarts, cause
    case startedDay = "started_day"
    case lastCheckAt = "last_check_at"
    case lastCheckRead = "last_check_read"
    case lastCheckFlat = "last_check_flat"
    case restartCount = "restart_count"
    case causeCodes = "cause_codes"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    startedDay = try c.decodeNullable(WireDate.self, forKey: .startedDay)
    lastCheckAt = try c.decodeNullable(WireTime.self, forKey: .lastCheckAt)
    lastCheckRead = try c.decodeNullable(Bool.self, forKey: .lastCheckRead)
    lastCheckFlat = try c.decodeNullable(Bool.self, forKey: .lastCheckFlat)
    restarts = try c.decode([WatchdogRestartV1].self, forKey: .restarts)
    restartCount = try c.decode(Int.self, forKey: .restartCount)
    cause = try c.decodeNullable(String.self, forKey: .cause)
    causeCodes = try c.decodeIfPresent([ReasonV1].self, forKey: .causeCodes) ?? []
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encodeNullable(startedDay, forKey: .startedDay)
    try c.encodeNullable(lastCheckAt, forKey: .lastCheckAt)
    try c.encodeNullable(lastCheckRead, forKey: .lastCheckRead)
    try c.encodeNullable(lastCheckFlat, forKey: .lastCheckFlat)
    try c.encode(restarts, forKey: .restarts)
    try c.encode(restartCount, forKey: .restartCount)
    try c.encodeNullable(cause, forKey: .cause)
    try c.encode(causeCodes, forKey: .causeCodes)
  }

  /// Why the journal cannot be read, in the person's language.
  public var causeText: String? { ApiText.prose(causeCodes, text: cause) }
}

public enum SleepState: String, Codable, Sendable {
  case held
  case notHeld = "not_held"
  case unknown
}

/// The Mac's no-sleep hold (caffeinate beside the bot and watchdog jobs).
public struct SleepV1: Codable, Hashable, Sendable {
  public let state: SleepState
  public let holds: Int?
  public let cause: String?
  public let causeCodes: [ReasonV1]

  enum CodingKeys: String, CodingKey {
    case state, holds, cause
    case causeCodes = "cause_codes"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    state = try c.decode(SleepState.self, forKey: .state)
    holds = try c.decodeNullable(Int.self, forKey: .holds)
    cause = try c.decodeNullable(String.self, forKey: .cause)
    causeCodes = try c.decodeIfPresent([ReasonV1].self, forKey: .causeCodes) ?? []
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(state, forKey: .state)
    try c.encodeNullable(holds, forKey: .holds)
    try c.encodeNullable(cause, forKey: .cause)
    try c.encode(causeCodes, forKey: .causeCodes)
  }

  /// Why the hold is unknown, in the person's language.
  public var causeText: String? { ApiText.prose(causeCodes, text: cause) }
}

/// The machine's own services; `kind` "mac" is the only kind this app shows.
public struct HostV1: Codable, Hashable, Sendable {
  /// The one host kind this app knows (`[api] system_services`).
  public static let mac = "mac"

  public let kind: String
  public let watchdog: WatchdogV1
  public let sleep: SleepV1
}

/// GET /system: the System card.
public struct SystemV1: Codable, Hashable, Sendable {
  public let servedAt: WireTime
  public let botState: BotState?
  public let statusStale: Bool
  public let brokerLink: BrokerLinkV1
  public let morningCheck: MorningCheckV1?
  public let morningCheckCause: String?
  public let training: TrainingV1?
  public let trainingCause: String?
  public let host: HostV1?
  public let hostCause: String?
  public let apiVersion: Int
  public let morningCheckCauseCodes: [ReasonV1]
  public let trainingCauseCodes: [ReasonV1]
  public let hostCauseCodes: [ReasonV1]

  enum CodingKeys: String, CodingKey {
    case training, host
    case servedAt = "served_at"
    case botState = "bot_state"
    case statusStale = "status_stale"
    case brokerLink = "broker_link"
    case morningCheck = "morning_check"
    case morningCheckCause = "morning_check_cause"
    case trainingCause = "training_cause"
    case hostCause = "host_cause"
    case apiVersion = "api_version"
    case morningCheckCauseCodes = "morning_check_cause_codes"
    case trainingCauseCodes = "training_cause_codes"
    case hostCauseCodes = "host_cause_codes"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    servedAt = try c.decode(WireTime.self, forKey: .servedAt)
    botState = try c.decodeNullable(BotState.self, forKey: .botState)
    statusStale = try c.decode(Bool.self, forKey: .statusStale)
    brokerLink = try c.decode(BrokerLinkV1.self, forKey: .brokerLink)
    morningCheck = try c.decodeNullable(MorningCheckV1.self, forKey: .morningCheck)
    morningCheckCause = try c.decodeNullable(String.self, forKey: .morningCheckCause)
    training = try c.decodeNullable(TrainingV1.self, forKey: .training)
    trainingCause = try c.decodeNullable(String.self, forKey: .trainingCause)
    host = try c.decodeNullable(HostV1.self, forKey: .host)
    hostCause = try c.decodeNullable(String.self, forKey: .hostCause)
    morningCheckCauseCodes = try c.decodeIfPresent([ReasonV1].self, forKey: .morningCheckCauseCodes) ?? []
    trainingCauseCodes = try c.decodeIfPresent([ReasonV1].self, forKey: .trainingCauseCodes) ?? []
    hostCauseCodes = try c.decodeIfPresent([ReasonV1].self, forKey: .hostCauseCodes) ?? []
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(servedAt, forKey: .servedAt)
    try c.encodeNullable(botState, forKey: .botState)
    try c.encode(statusStale, forKey: .statusStale)
    try c.encode(brokerLink, forKey: .brokerLink)
    try c.encodeNullable(morningCheck, forKey: .morningCheck)
    try c.encodeNullable(morningCheckCause, forKey: .morningCheckCause)
    try c.encodeNullable(training, forKey: .training)
    try c.encodeNullable(trainingCause, forKey: .trainingCause)
    try c.encodeNullable(host, forKey: .host)
    try c.encodeNullable(hostCause, forKey: .hostCause)
    try c.encode(apiVersion, forKey: .apiVersion)
    try c.encode(morningCheckCauseCodes, forKey: .morningCheckCauseCodes)
    try c.encode(trainingCauseCodes, forKey: .trainingCauseCodes)
    try c.encode(hostCauseCodes, forKey: .hostCauseCodes)
  }
}
