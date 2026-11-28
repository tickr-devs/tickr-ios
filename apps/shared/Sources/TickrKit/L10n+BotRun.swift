import Foundation

// The words of the bot's run by its schedule (`BotRun`, mockup v190, page p-off).
extension L10n {
  /// Off by the schedule; argument: the next start, an abbreviated weekday and its New York time.
  static func botOffUntil(_ start: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.botRun.offUntil", defaultValue: "Bot is off until \(start) ET", bundle: bundle)
  }
  /// Under `botOffUntil` on a weekend.
  static var botOffWeekend: LocalizedStringResource {
    LocalizedStringResource("kit.botRun.offWeekend", defaultValue: "Weekend. Starts by itself.", bundle: bundle)
  }
  /// Under `botOffUntil` on a weekday (a night, a holiday).
  static var botOffStartsByItself: LocalizedStringResource {
    LocalizedStringResource("kit.botRun.startsByItself", defaultValue: "Starts by itself.", bundle: bundle)
  }
  /// The start less than a quarter of an hour away; argument: whole minutes (at least 1).
  static func botStartsIn(_ minutes: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.botRun.startsIn", defaultValue: "Bot starts in \(minutes) min", bundle: bundle)
  }
  /// The run has started and its first status is on its way.
  static var botStarting: LocalizedStringResource {
    LocalizedStringResource("kit.botRun.starting", defaultValue: "Bot is starting", bundle: bundle)
  }
  /// Under `botStartsIn` and `botStarting`; argument: the start's New York time.
  static func botPremarketOpens(_ time: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.botRun.premarketOpens", defaultValue: "Premarket opens at \(time) ET.", bundle: bundle)
  }
  /// Meant to run, silent past the stale limit.
  static var botNotAnswering: LocalizedStringResource {
    LocalizedStringResource("kit.botRun.notAnswering", defaultValue: "Bot isn’t answering", bundle: bundle)
  }
  /// Under `botNotAnswering`; arguments: the run's start and the last status's time, New York.
  static func botShouldRunSince(_ start: String, _ last: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.botRun.shouldRunSince",
      defaultValue: "It should be running since \(start) ET. Last answer \(last).", bundle: bundle)
  }
  /// Under `botNotAnswering` when the API does not say when the run started; argument: the last
  /// status's New York time.
  static func botShouldRun(_ last: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.botRun.shouldRun", defaultValue: "It should be running now. Last answer \(last).",
      bundle: bundle)
  }
  /// The sidebar's bot state while off by the schedule; argument: the next start, weekday and time.
  static func botOffShort(_ start: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.botRun.offShort", defaultValue: "Off · until \(start)", bundle: bundle)
  }
}
