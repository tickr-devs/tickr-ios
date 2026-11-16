import Foundation

extension StatusV1 {
  /// Today's result as shown: the broker's own realized result once a balance read after the
  /// last close has it (exact where order rows round sub-dollar fill prices), else the bot's
  /// result after the broker's fees once read, else before them (`resultBeforeFees`).
  public var resultTodayUsd: DecimalString { resultTodayBrokerUsd ?? resultTodayNetUsd ?? resultTodayGrossUsd }

  /// The result shown does not count the broker's fees yet (trades closed, nothing read).
  public var resultBeforeFees: Bool {
    resultTodayBrokerUsd == nil && resultTodayNetUsd == nil && !tradesToday.isEmpty
  }
}
