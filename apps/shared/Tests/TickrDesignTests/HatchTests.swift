import SwiftUI
import Testing
@testable import TickrDesign

/// The planned stripes drift only while asked to (the screens pass their ornament gate), and stop
/// when the gate closes.
@MainActor
@Suite struct HatchTests {
  @Test func driftsOnlyWhileMoving() {
    let view = HatchLayerView(frame: CGRect(x: 0, y: 0, width: 120, height: 22))
    let environment = EnvironmentValues()
    view.show(HatchLayer(color: Palette.highlight, moving: false), environment: environment)
    #expect(!view.isDrifting)
    view.show(HatchLayer(color: Palette.highlight, moving: true), environment: environment)
    #expect(view.isDrifting)
    view.show(HatchLayer(color: Palette.highlight, moving: false), environment: environment)
    #expect(!view.isDrifting)
  }

  @Test func repeatsOverOneStripeAndGap() {
    // At 45° a stripe and its gap span √2 times their width along a row.
    let expected = 2 * HatchLayerView.stripe * 2.0.squareRoot()
    #expect(abs(HatchLayerView.period - expected) < 0.001)
  }
}
