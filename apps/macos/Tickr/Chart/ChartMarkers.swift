import Foundation
import SwiftUI
import TickrDesign
import TickrKit

/// A trade's entry or exit, drawn as a triangle at its time and price.
struct ChartMark: Identifiable {
  enum Kind: Hashable {
    case entry, exitWin, exitLoss
  }

  struct ID: Hashable {
    let trade: String
    let kind: Kind
  }

  let id: ID
  let time: Date
  let price: Double
  let label: LocalizedStringResource

  var kind: Kind { id.kind }

  /// What a redraw compares (the label follows from these).
  var key: [AnyHashable] { [id, time, price] }

  var color: Color {
    switch kind {
    case .entry: Palette.info
    case .exitWin: Palette.profit
    case .exitLoss: Palette.loss
    }
  }

  var textColor: Color {
    switch kind {
    case .entry: Palette.infoText
    case .exitWin: Palette.profitText
    case .exitLoss: Palette.lossText
    }
  }
}

/// A price level of the open position: its entry, and its broker-side stop.
struct ChartLevel: Identifiable {
  enum Kind: Hashable {
    case entry, stop, stopUnverified
  }

  let kind: Kind
  let price: Double
  let since: Date
  let label: LocalizedStringResource

  var id: Kind { kind }

  /// What a redraw compares (the label follows from these).
  var key: [AnyHashable] { [kind, price, since] }

  var color: Color {
    switch kind {
    case .entry: Palette.info
    case .stop: Palette.loss
    case .stopUnverified: Palette.warning
    }
  }

  var textColor: Color {
    switch kind {
    case .entry: Palette.infoText
    case .stop: Palette.lossText
    case .stopUnverified: Palette.warningText
    }
  }
}

/// A strategy's ENTER or EXIT decision, drawn as a diamond at its time: filled for one the
/// trading strategy acted on, hollow for an observer's (a shadow strategy that never trades) or a
/// skipped ENTER (refused, so never bought), which is also drawn muted.
struct DecisionMark: Identifiable {
  /// Position in the day's decision list.
  let id: Int
  let time: Date
  let price: Double
  let action: Verdict
  let observer: Bool
  /// An ENTER that was not taken: the API gives an entry price only for those (docs/api.md).
  let skipped: Bool
  let label: LocalizedStringResource

  /// What a redraw compares (the label follows from these).
  var key: [AnyHashable] { [id, time, price, action, observer, skipped] }

  /// Hollow for anything that did not trade.
  var hollow: Bool { observer || skipped }
  var color: Color { observer || !skipped ? action.color : Palette.textTertiary }
}

/// Builds the marks and levels the chart draws from the bot's trades and open position.
enum ChartMarkers {
  /// An entry and an exit mark per closed trade.
  static func marks(trades: [DayTrade]) -> [ChartMark] {
    trades.flatMap { trade -> [ChartMark] in
      let result = trade.resultGrossUsd.value
      let exitKind: ChartMark.Kind = result < 0 ? .exitLoss : .exitWin
      return [
        ChartMark(
          id: ChartMark.ID(trade: trade.tradeId, kind: .entry), time: trade.openedAt.date,
          price: double(trade.entryPrice.value),
          label: L10n.Chart.buyMark(Format.quantity(trade.quantity.value))),
        ChartMark(
          id: ChartMark.ID(trade: trade.tradeId, kind: exitKind), time: trade.closedAt.date,
          price: double(trade.exitPrice.value),
          label: L10n.Chart.exitMark(Money.signedUSD(result))),
      ]
    }
  }

  /// The open position's entry and stop, if it has one on this symbol.
  static func levels(position row: PositionRow?) -> [ChartLevel] {
    guard let row else { return [] }
    let since = row.position.openedAt.date
    var levels = [
      ChartLevel(
        kind: .entry, price: double(row.entry), since: since,
        label: L10n.Chart.entryLevel(Format.price(row.entry)))
    ]
    if let stop = row.stop {
      let verified = row.position.stop.state == .verified
      levels.append(
        ChartLevel(
          kind: verified ? .stop : .stopUnverified, price: double(stop), since: since,
          label: verified ? L10n.Chart.stopLevel(Format.price(stop)) : L10n.Chart.stopUnverified(Format.price(stop))))
    }
    return levels
  }

  /// A mark per ENTER or EXIT decision. A skipped ENTER sits at its what-if entry; otherwise a
  /// mark sits at the close of the candle it was made in. A decision outside every candle has no
  /// mark.
  static func decisionMarks(decisions: [DecisionV1], candles: [Candle]) -> [DecisionMark] {
    decisions.enumerated().compactMap { index, decision in
      guard decision.action == .enter || decision.action == .exit else { return nil }
      let at = decision.at.date
      let candle = candles.last { $0.start <= at && at < $0.end }
      guard let price = decision.entryPrice.map({ double($0.value) }) ?? candle?.close else { return nil }
      let title = String(localized: decision.action.title)
      let skipped = decision.entryPrice != nil
      let label = decision.observer ? L10n.Chart.observerMark(title)
        : skipped ? L10n.Chart.skippedMark(title) : decision.action.title
      return DecisionMark(
        id: index, time: at, price: price, action: decision.action, observer: decision.observer,
        skipped: skipped, label: label)
    }
  }

  static func double(_ value: Decimal) -> Double {
    NSDecimalNumber(decimal: value).doubleValue
  }
}
