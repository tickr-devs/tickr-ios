import CoreGraphics
import Testing
@testable import TickrDesign

@Suite struct TextMeasureTests {
  typealias PlatformFont = TextMeasure.PlatformFont

  static func font(_ size: CGFloat = Tokens.Typography.annotationSize) -> PlatformFont {
    PlatformFont.monospacedSystemFont(ofSize: size, weight: .regular)
  }

  @Test func widthGrowsWithTheTextAndItsTracking() {
    let short = TextMeasure.width("Stop", font: Self.font())
    let long = TextMeasure.width("Stop ✓", font: Self.font())
    let tracked = TextMeasure.width("Stop", font: Self.font(), kern: Tokens.Typography.labelTracking)
    #expect(short > 0)
    #expect(long > short)
    #expect(tracked > short)
    #expect(short == short.rounded(.up))
    #expect(TextMeasure.width("", font: Self.font()) == 0)
  }

  /// The two line heights the Mac's Chart screen is sized by (`ChartView.leastHeight`), as
  /// measured on macOS 27.
  @Test func lineHeightIsTheDrawnLine() {
    let symbol = PlatformFont.monospacedSystemFont(ofSize: Tokens.Typography.metricSize, weight: .bold)
    let chip = PlatformFont.monospacedSystemFont(ofSize: Tokens.Typography.labelSize, weight: .semibold)
    #expect(TextMeasure.lineHeight(symbol) == 29)
    #expect(TextMeasure.lineHeight(chip) == 14)
  }

  /// The Overview's stage cells are measured while other threads lay out text: every thread
  /// measures the same widths and none throws (string drawing threw here, 2026-11-19).
  @Test func measuresTheSameFromManyThreadsAtOnce() async {
    let words = ["SCREENERS", "RECONCILE", "412", "seen", "Stop", "✓", "—", "verificados"]
    let expected = words.map { TextMeasure.width($0, font: Self.font()) }
    let rounds = 2_000
    let threads = 4
    let results = await withTaskGroup(of: Bool.self) { group in
      for _ in 0..<threads {
        group.addTask {
          (0..<rounds).allSatisfy { _ in words.map { TextMeasure.width($0, font: Self.font()) } == expected }
        }
      }
      return await group.reduce(into: [Bool]()) { $0.append($1) }
    }
    #expect(results == Array(repeating: true, count: threads))
  }
}
