import SwiftUI
import Testing
@testable import TickrDesign
import TickrKit

/// The funnel drawings: every stage has a glyph of its own, and a light on the rail fades in at the
/// start of its run and out at its end.
@MainActor
@Suite struct FunnelTests {
  @Test("Each of the nine stages draws its own glyph")
  func glyphsAreDistinct() {
    let glyphs = PipelineStage.allCases.map { $0.glyph.pathData }
    #expect(Set(glyphs).count == PipelineStage.allCases.count)
  }

  @Test("A light on the rail is out at both ends of its run and full in the middle")
  func travellerFades() {
    #expect(FunnelRings.fade(0) == 0)
    #expect(FunnelRings.fade(1) == 0)
    #expect(FunnelRings.fade(0.5) == 1)
    #expect(FunnelRings.fade(Tokens.Motion.funnelTravelFade / 2) < 1)
  }

  @Test("The rail's lights run in Core Animation only while moving, never from a SwiftUI frame loop")
  func railLightsRunOnlyWhileMoving() {
    let view = FunnelRailLightsView(frame: CGRect(x: 0, y: 0, width: 300, height: 30))
    let environment = EnvironmentValues()
    let color = PipelineStage.screeners.fill
    view.show(FunnelRailLights(color: color, moving: false), environment: environment)
    #expect(!view.isRunning)
    view.show(FunnelRailLights(color: color, moving: true), environment: environment)
    #expect(view.isRunning)
    view.show(FunnelRailLights(color: color, moving: false), environment: environment)
    #expect(!view.isRunning)
  }
}
