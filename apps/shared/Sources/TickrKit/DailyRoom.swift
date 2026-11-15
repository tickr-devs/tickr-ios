import Foundation

/// Room left under the daily loss limit, counted the way the bot counts it
/// (src/tickr/risk/daily.py): the realized loss is the net day result's loss, so profits
/// offset losses but never raise the room above the limit. Open reservations (planned loss of
/// open trades and working entries) are not served by the API yet, so this is the room before
/// them; screens label it so.
public enum DailyRoom {
  /// The realized loss of a net day result, as a non-negative amount.
  public static func realizedLoss(netResult: Decimal) -> Decimal {
    max(0, -netResult)
  }

  /// `limit` minus the realized loss, never below zero.
  public static func left(limit: Decimal, netResult: Decimal) -> Decimal {
    max(0, limit - realizedLoss(netResult: netResult))
  }
}
