import Foundation
import Testing
@testable import TickrDesign
import TickrKit

@Suite struct SteadyFiguresTests {
  /// The longest shape among all of `texts` (a monospaced font draws it widest).
  static func longest(_ texts: [String]) -> Int {
    FigureShapes.shapes(texts).map(\.count).max() ?? 0
  }

  @Test func shapesWriteEveryDigitAsOneAndDropRepeats() {
    #expect(FigureShapes.shapes(["97.41", "97.52", "101.3K", "91.3K", "+0.08%", "\u{2212}0.07%"])
      == ["00.00", "000.0K", "00.0K", "+0.00%", "\u{2212}0.00%"])
  }

  /// Figures with fixed decimals (prices, changes): the ends of each bucket hold the widest. The
  /// owner's screenshots: the change lost its plus.
  @Test func bucketsHoldTheWidestFigureOfFixedDecimals() {
    let prices: [Double] = [97.41, 97.52, 0.9871, 1_002.5, 9.996, 12]
    let changes: [Double] = [0.0008, -0.0007, 0, -0.1234, 0.000_04]
    for (values, format) in [
      (prices, Money.price),
      (changes, { Percent.signed(fraction: $0) }),
    ] as [([Double], (Double) -> String)] {
      let all = values.map(format)
      #expect(Self.longest(FigureShapes.of(values, format)) == Self.longest(all))
    }
  }

  /// A compact volume drops its ".0": the readout writes every volume of the chart, so a round
  /// smallest and largest of a power of ten never hide a wider figure between them (review of #725).
  @Test(arguments: [[100_020, 123_400, 980_010], [1_000_000, 1_250_000, 9_000_000]] as [[Double]])
  func readoutVolumesHoldTheWidestBetweenRoundEnds(_ volumes: [Double]) {
    let candles = volumes.enumerated().map { offset, volume in
      let start = Date(timeIntervalSince1970: Double(offset) * 60)
      return Candle(start: start, end: start.addingTimeInterval(60), open: 10, high: 11, low: 9, close: 10,
        volume: volume)
    }
    let shapes = ReadoutShapes(candles)
    #expect(Self.longest(shapes.volume) == Self.longest(volumes.map(Volume.compact)))
    #expect(shapes.volume.contains(FigureShapes.shapes([Volume.compact(volumes[1])])[0]))
  }

  @Test func valuesThatAreNotFiniteAreLeftOut() {
    #expect(FigureShapes.of([Double.nan, .infinity], Money.price).isEmpty)
    #expect(FigureShapes.of([Double](), Money.price).isEmpty)
  }
}
