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

  @Test("A cubic curve bends where its control points pull: the broker stop's shield reaches its tip")
  func shieldCurvesReachTheTip() {
    // M12+3l7+3v6c0+4.5-3+7.5-7+9: the right side curves from (19, 12) down to the tip at (12, 21).
    let bounds = SVGPath.parse(DesignGlyph.brokerStopPath).boundingRect
    #expect(bounds == CGRect(x: 5, y: 3, width: 14, height: 18))
  }

  @Test("A shape scales its grid into any square, centred")
  func shapeScalesToItsRect() {
    let path = DesignGlyphShape(.home).path(in: CGRect(x: 0, y: 0, width: 48, height: 48))
    #expect(path.boundingRect == CGRect(x: 8, y: 8, width: 32, height: 32))
  }

  @Test("The settings gear is the design's: its tooth tops on the 9.3 circle round the centre")
  func settingsGearSpansItsTeeth() {
    // Each tooth top is an arc of radius 9.3 about (12, 12) between points 2.87 from the edge, so
    // the arcs bulge out to 12 ± 9.3 = 2.7...21.3 (chords cut that by under a tenth).
    let bounds = SVGPath.parse(DesignGlyph.settingsPath).boundingRect
    #expect(abs(bounds.minX - 2.7) < 0.1 && abs(bounds.maxX - 21.3) < 0.1)
    #expect(abs(bounds.minY - 2.7) < 0.1 && abs(bounds.maxY - 21.3) < 0.1)
    #expect(DesignGlyph.settings.gridStroke == Tokens.Stroke.gear)
  }
}
