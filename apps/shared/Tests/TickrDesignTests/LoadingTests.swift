import QuartzCore
import SwiftUI
import Testing
@testable import TickrDesign

/// Loading (mockup v102): the skeleton's shimmer, the button spinner, the progress line.
@MainActor
@Suite struct LoadingTests {
  @Test("Reduce Motion turns the sweep into a pulse")
  func reduceMotionPulses() {
    #expect(Skeleton<EmptyView>.motion(reduceMotion: false) == .sweep)
    #expect(Skeleton<EmptyView>.motion(reduceMotion: true) == .pulse)
  }

  @Test("Skeleton blocks take the board's heights and radii")
  func blocks() {
    #expect(SkeletonBlock(.line).height == Tokens.Loading.lineHeight)
    #expect(SkeletonBlock(.line).radius == Tokens.Loading.lineRadius)
    #expect(SkeletonBlock(.value).height == Tokens.Loading.valueHeight)
    #expect(SkeletonBlock(.value).radius == Tokens.Loading.blockRadius)
    #expect(SkeletonBlock(.pill).height == Tokens.Loading.pillHeight)
    #expect(SkeletonBlock(.pill).radius == Tokens.Loading.pillRadius)
    #expect(SkeletonBlock(.block(height: 4)).radius == 2)
  }

  @Test("The band sweeps as CSS background-position 120% to -20% over a 250% image")
  func shimmerOffsets() {
    // (width - 2.5 × width) × share: −1.8 × width at 120%, +0.3 × width at −20%.
    #expect(abs(ShimmerBandView.offset(width: 100, share: Tokens.Loading.shimmerFrom) - -180) < 1e-9)
    #expect(abs(ShimmerBandView.offset(width: 100, share: Tokens.Loading.shimmerTo) - 30) < 1e-9)
  }

  @Test("Every skeleton sweeps on one clock: two started apart are at the same point of the sweep")
  func sharedSweepClock() {
    let seconds = Tokens.Loading.shimmerSeconds
    let first = ShimmerBandView.sweepPhase(at: 1_000.25)
    let later = ShimmerBandView.sweepPhase(at: 1_000.25 + 3 * seconds)
    #expect(abs(first - later) < 1e-6)
    #expect(first >= 0 && first < seconds)
  }

  @Test("A 90° gradient runs left to right across the middle; 110° leans down to the right")
  func gradientPoints() {
    let flat = ShimmerBandView.gradientPoints(size: CGSize(width: 200, height: 50), degrees: 90)
    #expect(abs(flat.start.x) < 1e-9 && abs(flat.end.x - 1) < 1e-9)
    #expect(abs(flat.start.y - 0.5) < 1e-9 && abs(flat.end.y - 0.5) < 1e-9)
    let leaning = ShimmerBandView.gradientPoints(size: CGSize(width: 200, height: 50), degrees: 110)
    #expect(leaning.end.x > leaning.start.x)
    #expect(leaning.end.y > leaning.start.y)
  }

  @Test("The spinner turns once every 0.9 s at an even pace; under Reduce Motion it pulses")
  func spinnerMotion() {
    let turn = SpinnerRingView.turn()
    #expect(turn.keyPath == SpinnerRingView.rotationPath)
    #expect(turn.duration == Tokens.Loading.spinnerTurnSeconds)
    #expect(turn.repeatCount == .infinity)
    let pulse = SpinnerRingView.pulse()
    #expect(pulse.keyPath == SpinnerRingView.opacityPath)
    #expect(pulse.autoreverses)
    #expect(pulse.duration * 2 == Tokens.Loading.pulseSeconds)
    #expect(pulse.toValue as? Double == Tokens.Loading.pulseLow)
  }

  @Test("The skeleton's candles follow a fixed wave inside the plot")
  func candleWave() {
    for index in 0..<120 {
      let wave = SkeletonCandles.wave(index)
      #expect(wave > 0 && wave < 1)
    }
    #expect(SkeletonCandles.wave(7) == SkeletonCandles.wave(7))
  }
}

#if os(macOS)
@MainActor
@Suite struct SpinnerRingViewTests {
  private func ring(_ motion: SkeletonMotion) -> SpinnerRingView {
    let view = SpinnerRingView(frame: CGRect(x: 0, y: 0, width: Tokens.Loading.spinner, height: Tokens.Loading.spinner))
    view.show(SpinnerRing(motion: motion, color: Palette.textTertiary, active: true), environment: EnvironmentValues())
    view.layout()
    return view
  }

  @Test("Turning, the arc covers a quarter of the ring and turns; nothing pulses")
  func turning() {
    let view = ring(.sweep)
    #expect(Double(view.arc.strokeEnd) == Tokens.Loading.spinnerArc)
    #expect(view.arc.animation(forKey: SpinnerRingView.turnKey) != nil)
    #expect(view.layer?.animation(forKey: SpinnerRingView.pulseKey) == nil)
  }

  @Test("Turning Reduce Motion on stops the turn and starts the pulse")
  func switchesMotion() {
    let view = ring(.sweep)
    view.show(SpinnerRing(motion: .pulse, color: Palette.textTertiary, active: true), environment: EnvironmentValues())
    #expect(view.arc.animation(forKey: SpinnerRingView.turnKey) == nil)
    #expect(view.layer?.animation(forKey: SpinnerRingView.pulseKey) != nil)
  }
}
#endif
