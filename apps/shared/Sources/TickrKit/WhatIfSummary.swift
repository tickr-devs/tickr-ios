import Foundation

/// What the day's skipped setups would have made had each been entered once: the bot's what-if
/// replay of each group's first signal (a repeat of the same setup is not a second trade).
public struct WhatIfSummary: Equatable, Sendable {
  /// Sum of the replays' results, gross.
  public let resultR: Decimal
  public let resultUsd: Decimal
  public let wins: Int
  public let losses: Int
  /// Setups whose replay could not run (`WhatIfV1.cause`).
  public let notReplayed: Int

  /// Nil when there is no skipped setup.
  public static func make(_ groups: [SkippedGroup]) -> WhatIfSummary? {
    guard !groups.isEmpty else { return nil }
    var resultR: Decimal = 0
    var resultUsd: Decimal = 0
    var wins = 0
    var losses = 0
    var notReplayed = 0
    for group in groups {
      let whatIf = group.first.whatIf
      guard let r = whatIf.resultR?.value, let usd = whatIf.resultGrossUsd?.value else {
        notReplayed += 1
        continue
      }
      resultR += r
      resultUsd += usd
      if usd > 0 { wins += 1 } else if usd < 0 { losses += 1 }
    }
    return WhatIfSummary(resultR: resultR, resultUsd: resultUsd, wins: wins, losses: losses, notReplayed: notReplayed)
  }
}
