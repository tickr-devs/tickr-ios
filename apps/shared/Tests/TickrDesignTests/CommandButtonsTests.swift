import CoreGraphics
import Testing
@testable import TickrDesign

@Suite struct CommandButtonsTests {
  /// Equal columns only while every title fits on one line in its column; one per row otherwise.
  @Test(arguments: [
    (columns: 2, widest: 140.0, count: 2, width: 300.0, fit: 2),
    (columns: 2, widest: 150.0, count: 2, width: 300.0, fit: 1),
    (columns: 3, widest: 100.0, count: 3, width: 300.0, fit: 2),
    (columns: 3, widest: 90.0, count: 3, width: 300.0, fit: 3),
    (columns: 2, widest: 90.0, count: 1, width: 300.0, fit: 1),
    (columns: 2, widest: 900.0, count: 4, width: 300.0, fit: 1),
  ])
  func columnsFitTheirTitles(columns: Int, widest: Double, count: Int, width: Double, fit: Int) {
    #expect(CommandColumns.fitting(columns, widest: widest, count: count, in: width, spacing: 8) == fit)
  }

  /// The design's press-and-hold lasts 1.5 s.
  @Test func holdLastsTheDesignsTime() {
    #expect(Tokens.Command.holdSeconds == 1.5)
    #expect(EmergencyButton.Hold(prompt: .init(verbatim: ""), holding: .init(verbatim: ""),
      accessibilityHint: .init(verbatim: "")).seconds == Tokens.Command.holdSeconds)
  }

  /// The hold's sweep is empty before a press and covers the whole button once held to the end.
  @Test func sweepGrowsFromNothingToTheWholeButton() {
    let rect = CGRect(x: 0, y: 0, width: 300, height: 40)
    #expect(HoldSweep(progress: 0, center: 21).path(in: rect).isEmpty)
    let half = HoldSweep(progress: 0.5, center: 21).path(in: rect)
    #expect(half.contains(CGPoint(x: 290, y: 20)))
    #expect(!half.contains(CGPoint(x: 5, y: 20)))
    let full = HoldSweep(progress: 1, center: 21).path(in: rect)
    for point in [CGPoint(x: 1, y: 1), CGPoint(x: 299, y: 39), CGPoint(x: 5, y: 20), CGPoint(x: 290, y: 20)] {
      #expect(full.contains(point))
    }
  }
}
