import Foundation

/// What the System card says about each of its rows (GET /system), apart from how it looks: the
/// same judgement on the Mac and the phone. Red (`danger`) only when the bot cannot start or a
/// restart of a down bot failed today; anything that needs a look but is not dangerous is
/// `attention`; a state that is expected now (the bot not running, a weekend) is `idle`.
public enum SystemCard {
  public enum Health: Sendable, Hashable { case good, attention, danger, idle, unknown }

  /// The Webull link: judged only while the bot runs (an old read is expected otherwise).
  public static func link(_ system: SystemV1) -> Health {
    switch system.brokerLink.state {
    case .unknown: return .unknown
    case _ where !system.botRunning: return .idle
    case .fresh: return .good
    case .aging, .stale: return .attention
    }
  }

  /// The latest preflight: a result of an earlier day is history (idle), today's says whether
  /// the bot could start.
  public static func morningCheck(_ system: SystemV1) -> Health {
    guard let check = system.morningCheck else {
      return system.morningCheckCauseCodes.contains { $0.code == ProseReason.noPreflightRecord.rawValue }
        ? .idle : .unknown
    }
    guard check.day == today(system) else { return .idle }
    switch check.outcome {
    case .ready: return .good
    case .noSession: return .idle
    case .configInvalid: return .danger
    case .failed: return check.blocksStart ? .danger : .attention
    }
  }

  /// Model training: nothing reporting is idle, a failed job needs a look.
  public static func training(_ system: SystemV1) -> Health {
    guard let training = system.training else {
      return system.trainingCauseCodes.contains { $0.code == ProseReason.noTrainingJob.rawValue }
        ? .idle : .unknown
    }
    return training.state == .failed ? .attention : .good
  }

  /// The watchdog: today's restart that failed is dangerous, one refused needs a look; started
  /// today is good, otherwise it simply has not run today.
  public static func watchdog(_ host: HostV1, today: WireDate) -> Health {
    let watchdog = host.watchdog
    guard watchdog.cause == nil else { return .unknown }
    if let latest = watchdog.restarts.first, WireDate(newYorkDateOf: latest.at.date) == today {
      switch latest.outcome {
      case .failed: return .danger
      case .refused: return .attention
      case .started: break
      }
    }
    return watchdog.startedDay == today ? .good : .idle
  }

  /// The no-sleep hold: missing while the bot runs needs a look.
  public static func sleep(_ host: HostV1, botRunning: Bool) -> Health {
    switch host.sleep.state {
    case .unknown: return .unknown
    case .held: return .good
    case .notHeld: return botRunning ? .attention : .idle
    }
  }

  /// Every row's health, Mac rows only when the API reports a Mac.
  public static func all(_ system: SystemV1) -> [Health] {
    var rows = [link(system), morningCheck(system), training(system)]
    if let mac = system.mac {
      rows += [watchdog(mac, today: today(system)), sleep(mac, botRunning: system.botRunning)]
    }
    return rows
  }

  /// Rows that need a look (attention, danger, or a state that cannot be judged), for the card's
  /// pill: "All good" only when every row says so or is idle.
  public static func needingALook(_ system: SystemV1) -> Int {
    all(system).filter { $0 == .attention || $0 == .danger || $0 == .unknown }.count
  }

  /// The New York date the document was served on.
  public static func today(_ system: SystemV1) -> WireDate {
    WireDate(newYorkDateOf: system.servedAt.date)
  }

  /// The ages the card writes, in whole units: under a minute in seconds, under an hour in
  /// minutes, then hours.
  public enum Age: Sendable, Hashable {
    case seconds(Int), minutes(Int), hours(Int)

    /// Seconds in a minute and in an hour.
    static let minute = 60
    static let hour = 3600

    public init(since date: Date, now: Date) {
      let seconds = max(0, Int(now.timeIntervalSince(date)))
      if seconds < Self.minute {
        self = .seconds(seconds)
      } else if seconds < Self.hour {
        self = .minutes(seconds / Self.minute)
      } else {
        self = .hours(seconds / Self.hour)
      }
    }
  }
}

public extension SystemV1 {
  /// Whether the bot runs now by a status that is not stale.
  var botRunning: Bool { botState == .running && !statusStale }
  var morningCheckCauseText: String? { ApiText.prose(morningCheckCauseCodes, text: morningCheckCause) }
  var trainingCauseText: String? { ApiText.prose(trainingCauseCodes, text: trainingCause) }
  /// The Mac's services when the API reports a kind this app knows.
  var mac: HostV1? { host.flatMap { $0.kind == HostV1.mac ? $0 : nil } }
}

/// The preflight's check codes (`PreflightCheckV1.name`).
public enum PreflightCheckName: String, Sendable {
  case config, disk, calendar, credentials, token, strategy, database
  case codeVersion = "code-version"
  case alertChannel = "alert-channel"
  case alertRecipient = "alert-recipient"
  case tokenDir = "token-dir"
  case stopMarker = "stop-marker"
}
