import Foundation

extension StatusV1 {
  /// Today's result as shown: the bot's own trades after the broker's fees (each trade's settled
  /// cash once proven, so exact for sub-dollar fills too), the figure the daily loss rule reads
  /// and the sum of the trade rows; before the fees are read, the result before them
  /// (`resultBeforeFees`). Never the broker's whole-account figure (`resultTodayBrokerUsd`),
  /// which counts manual and probe trades the rows and the room do not.
  public var resultTodayUsd: DecimalString { resultTodayNetUsd ?? resultTodayGrossUsd }

  /// The result shown does not count the broker's fees yet (trades closed, nothing read).
  public var resultBeforeFees: Bool {
    resultTodayNetUsd == nil && !tradesToday.isEmpty
  }
}
