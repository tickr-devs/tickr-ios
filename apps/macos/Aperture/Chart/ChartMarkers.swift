import ApertureDesign
import ApertureKit
import Foundation
import SwiftUI

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

  static func double(_ value: Decimal) -> Double {
    NSDecimalNumber(decimal: value).doubleValue
  }
}
