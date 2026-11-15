import SwiftUI
import Testing
@testable import TickrDesign

@Suite struct DesignGlyphTests {
  @Test("Every glyph's path data parses into a drawing inside the 24-point grid")
  func everyGlyphDrawsInsideTheGrid() {
    for glyph in DesignGlyph.allCases {
      let bounds = SVGPath.parse(glyph.pathData).boundingRect
      #expect(!bounds.isEmpty, "\(glyph) draws nothing")
      #expect(bounds.minX >= 0 && bounds.minY >= 0, "\(glyph) starts off the grid")
      #expect(bounds.maxX <= 24.01 && bounds.maxY <= 24.01, "\(glyph) runs off the grid")
    }
  }

  @Test("Horizontal, vertical and relative commands land where the design's SVG puts them")
  func homePanelsMatchTheDesign() {
    // M4+13h6V4H4z: the tall left panel spans x 4...10, y 4...13; the short right one ends at 20.
    let bounds = SVGPath.parse(DesignGlyph.homePath).boundingRect
    #expect(bounds == CGRect(x: 4, y: 4, width: 16, height: 16))
  }

  @Test("An arc goes the way its flags say: the power ring opens at the top and closes at the bottom")
  func powerArcRunsRoundTheBottom() {
    // a8+8+0+1+0+11+0 from (6.5, 6.5): the large arc, counter-clockwise, reaching y ≈ 12.31 + 8
    // (the arc is drawn as short chords, which cut its extremes by under a tenth of a point).
    let bounds = SVGPath.parse(DesignGlyph.powerPath).boundingRect
    #expect(abs(bounds.maxY - 20.31) < 0.1)
    #expect(abs(bounds.minX - 4) < 0.1 && abs(bounds.maxX - 20) < 0.1)
    #expect(bounds.minY == 3)
  }

  @Test("A shape scales its grid into any square, centred")
  func shapeScalesToItsRect() {
    let path = DesignGlyphShape(.home).path(in: CGRect(x: 0, y: 0, width: 48, height: 48))
    #expect(path.boundingRect == CGRect(x: 8, y: 8, width: 32, height: 32))
  }
}
