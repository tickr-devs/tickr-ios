import SwiftUI
import TickrDesign
import TickrKit

/// Words for the bot's what-if replays and the prices after an exit or a skipped signal.
enum WhatIfText {
  /// How a replay ended.
  static func exit(_ reason: WhatIfExit) -> String {
    switch reason {
    case .stop: String(localized: L10n.Trades.exitStop)
    case .strategyExit: String(localized: L10n.Trades.exitStrategy)
    case .flatten: String(localized: L10n.Trades.exitFlatten)
    case .endOfData: String(localized: L10n.Trades.exitEndOfData)
    }
  }

  /// "If entered: −1.0 R · −$6.20 · stop" in the result's colour, or why the replay could not run.
  static func result(_ whatIf: WhatIfV1) -> (text: String, color: Color) {
    guard let r = whatIf.resultR?.value, let usd = whatIf.resultGrossUsd?.value, let reason = whatIf.exitReason
    else {
      let cause = ApiText.prose(whatIf.causeCodes, text: whatIf.cause) ?? Format.missing
      return (String(localized: L10n.Trades.whatIfNoResult(cause)), Palette.textTertiary)
    }
    return (String(localized: L10n.Trades.whatIfResult(Risk.text(r), Money.signedUSD(usd), exit(reason))),
      Palette.result(usd))
  }

  /// "Price after: 1 min +0.06 · 5 min +0.14 · 15 min −0.18 · 60 min —"; nil when none was
  /// captured. Changes are per share, in the price's own tick.
  static func after(_ prices: [PriceAfterV1]) -> String? {
    guard !prices.isEmpty else { return nil }
    let items = prices.map { point in
      let change = point.changeUsd.map { Money.priceChange($0.value, at: point.price?.value) }
      return String(localized: L10n.Trades.afterMinutes(point.minutes, change ?? Format.missing))
    }
    return String(localized: L10n.Trades.afterPrices(items.joined(separator: Format.itemSeparator)))
  }
}
