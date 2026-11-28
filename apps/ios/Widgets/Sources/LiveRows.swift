import SwiftUI
import TickrDesign
import TickrKit

/// One open position: its symbol, the bar from its stop to its target with a knob at the last
/// price, and its unrealized result. Without a target the bar gives way to "stop $X"; without a
/// last price the knob goes and the result reads "—"; without a stop the row is tinted red.
struct LiveRow: View {
  let position: ActivityPosition
  /// The alarm's position, or one without a stop.
  let alarmed: Bool

  var body: some View {
    HStack(spacing: Tokens.Space.m) {
      Text(position.symbol)
        .font(Tokens.LiveActivity.symbol)
        .foregroundStyle(alarmed ? Palette.lossText : Palette.textPrimary)
        .fixedSize()
        .frame(minWidth: Tokens.LiveActivity.symbolColumn, alignment: .leading)
      middle
        .frame(maxWidth: .infinity, alignment: .leading)
      Text(position.unrealized.map(Money.signedUSD) ?? ApiText.missing)
        .font(Tokens.LiveActivity.figure)
        .monospacedDigit()
        .foregroundStyle(position.unrealized.map(Palette.result) ?? Palette.textQuaternary)
        .fixedSize()
        .frame(minWidth: Tokens.LiveActivity.figureColumn, alignment: .trailing)
    }
  }

  /// The bar while the position has a stop below a target; "stop $X" while it has a stop only.
  @ViewBuilder private var middle: some View {
    if let stop = position.stop, let target = position.target, target > stop {
      StopTargetBar(progress: position.progress, barHeight: Tokens.LiveActivity.barHeight,
        knob: Tokens.LiveActivity.knob, ring: nil)
    } else if let stop = position.stop {
      Text(L10n.stopAt(Money.usdPrice(stop)))
        .font(Tokens.LiveActivity.figure)
        .foregroundStyle(Palette.textTertiary)
        .fixedSize()
    }
  }
}

/// Every open position's row, in the bot's order.
struct LiveRows: View {
  let state: TickrActivityAttributes.ContentState

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      ForEach(state.positions, id: \.symbol) { position in
        LiveRow(position: position, alarmed: state.alarmed(position))
      }
    }
  }
}

/// The coloured line of a paused, alarmed or flat activity, behind the state's dot.
struct LiveStateLine: View {
  let state: TickrActivityAttributes.ContentState

  var body: some View {
    if let line = state.stateLine {
      HStack(spacing: Tokens.Space.s) {
        LiveDot(tone: state.state.tone, ringed: state.state.ringed)
        Text(line)
          .font(Tokens.LiveActivity.line)
          .foregroundStyle(state.state.tone.text)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}
