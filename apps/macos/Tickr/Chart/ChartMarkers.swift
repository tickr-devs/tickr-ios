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
    case .exitLoss: Tone.series.fill
    }
  }

  var textColor: Color {
    switch kind {
    case .entry: Palette.infoText
    case .exitWin: Palette.profitText
    case .exitLoss: Tone.series.text
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

/// Where the trading strategy began watching a symbol, or its ENTER or EXIT decision, drawn as a
/// diamond at its time: filled for one the trading strategy acted on, hollow and muted for a
/// skipped ENTER (refused, so never bought).
struct DecisionMark: Identifiable {
  /// Position in the day's decision list.
  let id: Int
  let time: Date
  let price: Double
  let action: Verdict
  /// An ENTER that was not taken: the API gives an entry price only for those (docs/api.md).
  let skipped: Bool
  let label: LocalizedStringResource

  /// What a redraw compares (the label follows from these).
  var key: [AnyHashable] { [id, time, price, action, skipped] }

  /// Hollow for anything that did not trade.
  var hollow: Bool { skipped }
  var color: Color { skipped ? Palette.textTertiary : action.color }
}

/// Builds the marks and levels the chart draws from the bot's trades and open position.
enum ChartMarkers {
  /// An entry and an exit mark per closed trade, at their drawn times (`place`: the chart's
  /// candles sit back to back); a time before the first candle has no mark.
  static func marks(trades: [DayTrade], place: (Date) -> Date?) -> [ChartMark] {
    trades.flatMap { trade -> [ChartMark] in
      let result = trade.resultUsd.value
      let exitKind: ChartMark.Kind = result < 0 ? .exitLoss : .exitWin
      var marks: [ChartMark] = []
      if let at = place(trade.openedAt.date) {
        marks.append(ChartMark(
          id: ChartMark.ID(trade: trade.tradeId, kind: .entry), time: at, price: double(trade.entryPrice.value),
          label: L10n.Chart.buyMark(Format.quantity(trade.quantity.value), Format.price(trade.entryPrice.value))))
      }
      if let at = place(trade.closedAt.date) {
        marks.append(ChartMark(
          id: ChartMark.ID(trade: trade.tradeId, kind: exitKind), time: at, price: double(trade.exitPrice.value),
          label: L10n.Chart.exitMark(Money.signedUSD(result))))
      }
      return marks
    }
  }

  /// The open position's entry and stop, if it has one on this symbol, from its entry's drawn
  /// time (`place`; the left edge when it opened before the first candle).
  static func levels(position row: PositionRow?, place: (Date) -> Date?) -> [ChartLevel] {
    guard let row else { return [] }
    let since = place(row.position.openedAt.date) ?? .distantPast
    var levels = [
      ChartLevel(
        kind: .entry, price: double(row.entry), since: since,
        label: L10n.Chart.entryLevel(Format.price(row.entry)))
    ]
    if let stop = row.stop {
      let verified = row.position.stop.state.isProtected
      levels.append(
        ChartLevel(
          kind: verified ? .stop : .stopUnverified, price: double(stop), since: since,
          label: verified ? L10n.Chart.stopLevel(Format.price(stop)) : L10n.Chart.stopUnverified(Format.price(stop))))
    }
    return levels
  }

  /// A mark per ENTER or EXIT decision, and one where the trading strategy began watching (the
  /// first WATCH since the day began or since its last ENTER or EXIT). A shadow strategy's
  /// decisions are left out: it never trades. A skipped ENTER sits at its what-if entry; otherwise
  /// a mark sits at the close of the candle it was made in. A decision outside every candle has no
  /// mark. `real` are the candles at their real times,
  /// `place` gives a real time's drawn time (the chart's candles sit back to back).
  static func decisionMarks(decisions: [DecisionV1], real: [Candle], place: (Date) -> Date?) -> [DecisionMark] {
    // The strategy's own decisions that change something: an IGNORE or HOLD between two WATCH
    // bars does not start a new watch.
    let strategy = decisions.indices.filter {
      !decisions[$0].observer && decisions[$0].action != .ignore && decisions[$0].action != .hold
    }
    let watchStarts = Set(strategy.enumerated().compactMap { position, index -> Int? in
      guard decisions[index].action == .watch else { return nil }
      return position > 0 && decisions[strategy[position - 1]].action == .watch ? nil : index
    })
    return decisions.enumerated().compactMap { index, decision in
      guard !decision.observer,
        decision.action == .enter || decision.action == .exit || watchStarts.contains(index) else { return nil }
      let at = decision.at.date
      let candle = real.last { $0.start <= at && at < $0.end }
      guard let price = decision.entryPrice.map({ double($0.value) }) ?? candle?.close, let drawn = place(at) else {
        return nil
      }
      let title = String(localized: decision.action.title)
      let skipped = decision.entryPrice != nil
      let label = skipped ? L10n.Chart.skippedMark(title) : decision.action.title
      return DecisionMark(id: index, time: drawn, price: price, action: decision.action, skipped: skipped, label: label)
    }
  }

  static func double(_ value: Decimal) -> Double {
    NSDecimalNumber(decimal: value).doubleValue
  }
}
