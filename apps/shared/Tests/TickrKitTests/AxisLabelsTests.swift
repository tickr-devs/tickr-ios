import Testing
@testable import TickrKit

@Suite("The price axis's labels give way to the level tags")
struct AxisLabelsTests {
  /// A 300-point axis showing 11.00 to 13.00, labels 13 points and tags 17 points tall: a label
  /// closer than 15 points (0.10) to a tag would overlap it.
  static let clearance = AxisLabels.clearance(labelHeight: 13, tagHeight: 17, span: 2, height: 300)

  @Test("Half a label and half a tag, in the axis's units")
  func clearanceInUnits() {
    #expect(abs(Self.clearance - 0.1) < 1e-9)
    #expect(AxisLabels.clearance(labelHeight: 13, tagHeight: 17, span: 2, height: 0) == 0)
  }

  @Test("A label a tag would overlap is hidden: 11.80 under L 11.78")
  func overlapHides() {
    #expect(!AxisLabels.shows(11.80, tags: [11.78], clearance: Self.clearance))
    #expect(!AxisLabels.shows(12.40, tags: [13.1, 12.45], clearance: Self.clearance))
  }

  @Test("A label near a tag but clear of it stays")
  func nearButClearShows() {
    #expect(AxisLabels.shows(12.00, tags: [11.78], clearance: Self.clearance))
    #expect(AxisLabels.shows(11.80, tags: [11.69], clearance: Self.clearance))
    #expect(AxisLabels.shows(11.80, tags: [], clearance: Self.clearance))
  }

  @Test("Plates keep apart top to bottom; a plain high or low near a plate is left out")
  func placement() {
    let tags = [
      AxisLabels.Tag(y: 100, plain: false), AxisLabels.Tag(y: 90, plain: false),
      AxisLabels.Tag(y: 104, plain: true), AxisLabels.Tag(y: 200, plain: true),
    ]
    #expect(AxisLabels.placed(tags, spacing: 18) == [108, 90, nil, 200])
  }
}
