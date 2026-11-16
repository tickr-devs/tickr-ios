import QuartzCore
import SwiftUI
import Testing
@testable import TickrDesign

/// The loader: a turning beam with a pinging dot, or, under Reduce Motion, rings that pulse.
@MainActor
@Suite struct LoaderMotionTests {
  @Test("Reduce Motion turns the sweep into the rings' pulse")
  func reduceMotionPulses() {
    #expect(TickrLoader.motion(reduceMotion: false) == .sweep)
    #expect(TickrLoader.motion(reduceMotion: true) == .pulse)
  }
}

#if os(macOS)
@MainActor
@Suite struct RadarLoaderViewTests {
  private func loader(_ motion: LoaderMotion) -> RadarLoaderView {
    let view = RadarLoaderView(frame: CGRect(x: 0, y: 0, width: 56, height: 56))
    view.show(
      RadarLoader(motion: motion, dot: Tokens.Size.loaderDotLarge, beam: Palette.accent, rings: Palette.separatorStrong,
        active: true),
      environment: EnvironmentValues())
    view.layout()
    return view
  }

  @Test("Sweeping, the beam turns once per loaderTurnSeconds and the dot pings each turn; the rings stay still")
  func sweepTurnsAndPings() throws {
    let view = loader(.sweep)
    let turn = try #require(view.beamLayer.animation(forKey: RadarLoaderView.turnKey) as? CABasicAnimation)
    #expect(turn.keyPath == RadarLoaderView.rotationPath)
    #expect(turn.duration == Tokens.Motion.loaderTurnSeconds)
    #expect(turn.repeatCount == .infinity)
    let ping = try #require(view.dotLayer.animation(forKey: RadarLoaderView.pingKey))
    #expect(ping.duration == Tokens.Motion.loaderTurnSeconds)
    #expect(view.ringLayers.allSatisfy { $0.animation(forKey: RadarLoaderView.pulseKey) == nil })
    #expect(view.beamLayer.opacity == 1)
  }

  @Test("Under Reduce Motion nothing turns: the beam and dot are hidden and each ring pulses, inner ones later")
  func reduceMotionPulsesRings() throws {
    let view = loader(.pulse)
    #expect(view.beamLayer.animation(forKey: RadarLoaderView.turnKey) == nil)
    #expect(view.dotLayer.animation(forKey: RadarLoaderView.pingKey) == nil)
    #expect(view.beamLayer.opacity == 0)
    #expect(view.dotLayer.opacity == 0)
    let pulses = try view.ringLayers.map {
      try #require($0.animation(forKey: RadarLoaderView.pulseKey) as? CABasicAnimation)
    }
    #expect(pulses.count == RadarLoaderView.ringInsets.count)
    #expect(pulses.allSatisfy { $0.keyPath == RadarLoaderView.opacityPath && $0.autoreverses })
    #expect(pulses.allSatisfy { $0.duration * 2 == Tokens.Motion.loaderPulseSeconds })
    let begins = pulses.map(\.beginTime)
    #expect(begins == begins.sorted())
    #expect(abs(begins[1] - begins[0] - Tokens.Motion.loaderPulseLagSeconds) < 1e-6)
  }

  @Test("Turning Reduce Motion on while loading swaps the sweep for the pulse")
  func switchesMotion() {
    let view = loader(.sweep)
    view.show(
      RadarLoader(motion: .pulse, dot: Tokens.Size.loaderDotLarge, beam: Palette.accent, rings: Palette.separatorStrong,
        active: true),
      environment: EnvironmentValues())
    #expect(view.beamLayer.animation(forKey: RadarLoaderView.turnKey) == nil)
    #expect(view.ringLayers.allSatisfy { $0.animation(forKey: RadarLoaderView.pulseKey) != nil })
  }
}
#endif
