import Foundation

/// A symbol's change today as Webull shows it: from the previous regular-session close, at the
/// price shown now (the live bid where there is one). One calculation for every place on both apps
/// that shows a day's change next to a current price.
public enum DayChange {
  /// The previous close behind the screeners' latest row of `symbol` today (its price and change
  /// come from one provider row, `pre_close` on the bot's side); nil when no screener listed it.
  public static func previousClose(_ symbol: String, flow: FlowV1?) -> Decimal? {
    guard let chip = flow?.chips.first(where: { $0.symbol == symbol }) else { return nil }
    return SymbolDayLine.previousClose(price: chip.price, changePct: chip.changePct)
  }

  /// (price − previous close) / previous close, as a fraction (0.25 is +25%); nil without a
  /// previous close above zero.
  public static func fraction(price: Decimal, previousClose: Decimal?) -> Decimal? {
    guard let previousClose, previousClose > 0 else { return nil }
    return (price - previousClose) / previousClose
  }
}
