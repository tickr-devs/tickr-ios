import Foundation

/// Texts of the System card on both apps (GET /system, mockup v120).
public enum SystemText {
  static var bundle: LocalizedStringResource.BundleDescription { L10n.bundle }

  public static var title: LocalizedStringResource {
    LocalizedStringResource("kit.system.title", defaultValue: "System", bundle: bundle)
  }
  /// The card's pill when nothing needs a look.
  public static var allGood: LocalizedStringResource {
    LocalizedStringResource("kit.system.allGood", defaultValue: "All good", bundle: bundle)
  }
  /// The card's pill: how many rows need a look.
  public static func needALook(_ count: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.system.needALook", defaultValue: "Needs a look: \(count)", bundle: bundle)
  }
  /// Heading of the Mac-only rows.
  public static var thisMac: LocalizedStringResource {
    LocalizedStringResource("kit.system.thisMac", defaultValue: "This Mac", bundle: bundle)
  }
  /// A part of the card that cannot be judged now.
  public static var unknown: LocalizedStringResource {
    LocalizedStringResource("kit.system.unknown", defaultValue: "Unknown", bundle: bundle)
  }
  /// The card could not be read.
  public static var readFailed: LocalizedStringResource {
    LocalizedStringResource("kit.system.readFailed", defaultValue: "System state could not be read", bundle: bundle)
  }

  // MARK: ages

  public static func secondsAgo(_ value: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.system.secondsAgo", defaultValue: "\(value) s ago", bundle: bundle)
  }
  public static func minutesAgo(_ value: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.system.minutesAgo", defaultValue: "\(value) min ago", bundle: bundle)
  }
  public static func hoursAgo(_ value: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.system.hoursAgo", defaultValue: "\(value) h ago", bundle: bundle)
  }
  public static func ago(_ age: SystemCard.Age) -> LocalizedStringResource {
    switch age {
    case .seconds(let value): return secondsAgo(value)
    case .minutes(let value): return minutesAgo(value)
    case .hours(let value): return hoursAgo(value)
    }
  }

  // MARK: Webull link

  public static var link: LocalizedStringResource {
    LocalizedStringResource("kit.system.link", defaultValue: "Webull link", bundle: bundle)
  }
  /// Under the link: the last broker read and the age past which entries are blocked.
  public static func linkNote(_ seconds: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.system.linkNote",
      defaultValue: "Last broker read · new entries need it under \(seconds) s", bundle: bundle)
  }
  public static var streamFresh: LocalizedStringResource {
    LocalizedStringResource("kit.system.streamFresh", defaultValue: "Quotes live", bundle: bundle)
  }
  public static var streamQuiet: LocalizedStringResource {
    LocalizedStringResource("kit.system.streamQuiet", defaultValue: "Quotes quiet", bundle: bundle)
  }
  public static var streamLost: LocalizedStringResource {
    LocalizedStringResource("kit.system.streamLost", defaultValue: "Quotes lost", bundle: bundle)
  }
  public static var streamOff: LocalizedStringResource {
    LocalizedStringResource("kit.system.streamOff", defaultValue: "No quote stream", bundle: bundle)
  }

  // MARK: morning check

  public static var morningCheck: LocalizedStringResource {
    LocalizedStringResource("kit.system.morningCheck", defaultValue: "Morning check", bundle: bundle)
  }
  public static func passed(_ time: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.system.passed", defaultValue: "Passed \(time)", bundle: bundle)
  }
  public static func failed(_ check: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.system.failed", defaultValue: "Failed: \(check)", bundle: bundle)
  }
  public static var noSession: LocalizedStringResource {
    LocalizedStringResource("kit.system.noSession", defaultValue: "No session that day", bundle: bundle)
  }
  public static var configInvalid: LocalizedStringResource {
    LocalizedStringResource("kit.system.configInvalid", defaultValue: "Config invalid", bundle: bundle)
  }
  /// Under the check: which job ran it, on which day and at what time (New York).
  public static func ranByMorningJob(_ day: String, _ time: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.system.ranByMorningJob", defaultValue: "Morning job · \(day) · \(time) ET", bundle: bundle)
  }
  public static func ranByBotStart(_ day: String, _ time: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.system.ranByBotStart", defaultValue: "Before the bot started · \(day) · \(time) ET",
      bundle: bundle)
  }
  /// Beside a failed check that stops the bot from starting.
  public static var botWillNotStart: LocalizedStringResource {
    LocalizedStringResource("kit.system.botWillNotStart", defaultValue: "The bot does not start on this result",
      bundle: bundle)
  }

  /// A preflight check's name in the person's language; an unknown one reads "Another check".
  public static func check(_ name: String) -> LocalizedStringResource {
    let other = LocalizedStringResource("kit.system.check.other", defaultValue: "Another check", bundle: bundle)
    guard let check = PreflightCheckName(rawValue: name) else { return other }
    return setupCheck(check) ?? runCheck(check) ?? other
  }

  /// The names of the checks of the machine and its setup; nil for a check of the run itself.
  private static func setupCheck(_ check: PreflightCheckName) -> LocalizedStringResource? {
    switch check {
    case .config: return LocalizedStringResource("kit.system.check.config", defaultValue: "Configuration", bundle: bundle)
    case .codeVersion:
      return LocalizedStringResource("kit.system.check.codeVersion", defaultValue: "Code version", bundle: bundle)
    case .disk: return LocalizedStringResource("kit.system.check.disk", defaultValue: "Disk space", bundle: bundle)
    case .calendar:
      return LocalizedStringResource("kit.system.check.calendar", defaultValue: "Trading calendar", bundle: bundle)
    case .credentials:
      return LocalizedStringResource("kit.system.check.credentials", defaultValue: "Broker credentials", bundle: bundle)
    case .database: return LocalizedStringResource("kit.system.check.database", defaultValue: "Database", bundle: bundle)
    case .alertChannel, .alertRecipient, .tokenDir, .token, .strategy, .stopMarker: return nil
    }
  }

  /// The names of the checks of the run itself (token, alerts, strategy, stop); nil for a setup check.
  private static func runCheck(_ check: PreflightCheckName) -> LocalizedStringResource? {
    switch check {
    case .alertChannel:
      return LocalizedStringResource("kit.system.check.alertChannel", defaultValue: "Alert channel", bundle: bundle)
    case .alertRecipient:
      return LocalizedStringResource("kit.system.check.alertRecipient", defaultValue: "Alert recipient", bundle: bundle)
    case .tokenDir: return LocalizedStringResource("kit.system.check.tokenDir", defaultValue: "Token folder", bundle: bundle)
    case .token: return LocalizedStringResource("kit.system.check.token", defaultValue: "Webull token", bundle: bundle)
    case .strategy: return LocalizedStringResource("kit.system.check.strategy", defaultValue: "Strategy", bundle: bundle)
    case .stopMarker:
      return LocalizedStringResource("kit.system.check.stopMarker", defaultValue: "Stopped by you", bundle: bundle)
    case .config, .codeVersion, .disk, .calendar, .credentials, .database: return nil
    }
  }

  // MARK: training

  public static var training: LocalizedStringResource {
    LocalizedStringResource("kit.system.training", defaultValue: "Model training", bundle: bundle)
  }
  /// Under the bar: the job's own name, its steps and when it last reported.
  public static func trainingNote(_ job: String, _ done: Int, _ total: Int, _ updated: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.system.trainingNote", defaultValue: "\(job) · \(done) of \(total) · updated \(updated)",
      bundle: bundle)
  }
  public static var trainingDone: LocalizedStringResource {
    LocalizedStringResource("kit.system.trainingDone", defaultValue: "Done", bundle: bundle)
  }
  public static var trainingFailed: LocalizedStringResource {
    LocalizedStringResource("kit.system.trainingFailed", defaultValue: "Stopped", bundle: bundle)
  }
  public static var idle: LocalizedStringResource {
    LocalizedStringResource("kit.system.idle", defaultValue: "Idle", bundle: bundle)
  }

  // MARK: watchdog

  public static var watchdog: LocalizedStringResource {
    LocalizedStringResource("kit.system.watchdog", defaultValue: "Watchdog", bundle: bundle)
  }
  public static var startedToday: LocalizedStringResource {
    LocalizedStringResource("kit.system.startedToday", defaultValue: "Started today", bundle: bundle)
  }
  public static var notStartedToday: LocalizedStringResource {
    LocalizedStringResource("kit.system.notStartedToday", defaultValue: "Not started today", bundle: bundle)
  }
  /// Its latest broker check after the flatten time.
  public static func lastCheckFlat(_ time: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.system.lastCheckFlat", defaultValue: "Last check \(time) ET · nothing open", bundle: bundle)
  }
  public static func lastCheckOpen(_ time: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.system.lastCheckOpen", defaultValue: "Last check \(time) ET · something left open",
      bundle: bundle)
  }
  public static func lastCheckFailed(_ time: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.system.lastCheckFailed", defaultValue: "Last check \(time) ET · broker read failed",
      bundle: bundle)
  }
  public static var noCheckYet: LocalizedStringResource {
    LocalizedStringResource("kit.system.noCheckYet", defaultValue: "No broker check recorded yet", bundle: bundle)
  }
  public static var restarts: LocalizedStringResource {
    LocalizedStringResource("kit.system.restarts", defaultValue: "Watchdog restarts", bundle: bundle)
  }
  public static var noRestarts: LocalizedStringResource {
    LocalizedStringResource("kit.system.noRestarts",
      defaultValue: "None yet: the bot was never found down with an open trade", bundle: bundle)
  }
  public static var restartStarted: LocalizedStringResource {
    LocalizedStringResource("kit.system.restartStarted", defaultValue: "Started", bundle: bundle)
  }
  public static var restartFailed: LocalizedStringResource {
    LocalizedStringResource("kit.system.restartFailed", defaultValue: "Failed", bundle: bundle)
  }
  public static var restartRefused: LocalizedStringResource {
    LocalizedStringResource("kit.system.restartRefused", defaultValue: "Refused", bundle: bundle)
  }
  /// Why the watchdog started the bot: it was down with open trades.
  public static func restartDown(_ trades: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.system.restartDown", defaultValue: "Bot down · open trades: \(trades)", bundle: bundle)
  }
  /// The early restart for an entry resting while the bot was down.
  public static var restartEarly: LocalizedStringResource {
    LocalizedStringResource("kit.system.restartEarly", defaultValue: "Bot down with an entry resting", bundle: bundle)
  }

  // MARK: sleep

  public static var sleep: LocalizedStringResource {
    LocalizedStringResource("kit.system.sleep", defaultValue: "Sleep prevention", bundle: bundle)
  }
  public static var keptAwake: LocalizedStringResource {
    LocalizedStringResource("kit.system.keptAwake", defaultValue: "Kept awake", bundle: bundle)
  }
  public static var maySleep: LocalizedStringResource {
    LocalizedStringResource("kit.system.maySleep", defaultValue: "Mac may sleep", bundle: bundle)
  }
  /// Under the hold: how many caffeinate processes hold it.
  public static func holds(_ count: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.system.holds", defaultValue: "caffeinate holds: \(count)", bundle: bundle)
  }
  public static var notNeededNow: LocalizedStringResource {
    LocalizedStringResource("kit.system.notNeededNow", defaultValue: "Not needed while the bot is not running",
      bundle: bundle)
  }
}
