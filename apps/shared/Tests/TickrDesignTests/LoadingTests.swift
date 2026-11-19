import QuartzCore
import SwiftUI
import Testing
@testable import TickrDesign

/// Loading (mockup v102, v121): the skeleton's breath, the button spinner, the progress line.
@MainActor
@Suite struct LoadingTests {
  @Test("A breath goes from full to breathLow and back, smoothly, with no jump at its end")
  func breathIsSmooth() {
    let seconds = Tokens.Loading.breathSeconds
    let start = Date(timeIntervalSinceReferenceDate: 1_000 * seconds)
    #expect(abs(Skeleton<EmptyView>.breath(at: start) - 1) < 1e-9)
    let middle = start.addingTimeInterval(seconds / 2)
    #expect(abs(Skeleton<EmptyView>.breath(at: middle) - Tokens.Loading.breathLow) < 1e-9)
    // Sampled finely across three breaths: always within [breathLow, 1], and no step between two
    // samples bigger than the curve's own slope allows, so it never jumps (the old band did).
    let steps = 3_000
    let step = 3 * seconds / Double(steps)
    let slope = (1 - Tokens.Loading.breathLow) * .pi / seconds
    var previous = Skeleton<EmptyView>.breath(at: start)
    for index in 1...steps {
      let value = Skeleton<EmptyView>.breath(at: start.addingTimeInterval(Double(index) * step))
      #expect(value >= Tokens.Loading.breathLow - 1e-9 && value <= 1 + 1e-9)
      #expect(abs(value - previous) <= slope * step + 1e-9)
      previous = value
    }
  }

  @Test("Every skeleton breathes on one clock: built apart, they are at the same point")
  func sharedBreathClock() {
    let date = Date(timeIntervalSinceReferenceDate: 1_000.25)
    let later = date.addingTimeInterval(7 * Tokens.Loading.breathSeconds)
    #expect(abs(Skeleton<EmptyView>.breath(at: date) - Skeleton<EmptyView>.breath(at: later)) < 1e-9)
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
    #expect(SkeletonBlock(.fill).height == nil)
    #expect(SkeletonBlock(.fill).radius == Tokens.Loading.pillRadius)
  }

  #if canImport(AppKit)
  @Test("A view standing for itself as skeleton keeps its own size")
  func skeletonKeepsSize() {
    let text = Text(verbatim: Money.price(SkeletonSample.price)).font(Tokens.Typography.quote)
    let shown = NSHostingView(rootView: text).fittingSize
    let loading = NSHostingView(rootView: text.skeleton(true, .value)).fittingSize
    #expect(loading == shown)
  }

  @Test("A loading slot's swap keeps the place's size when the skeleton is the content's size")
  func slotKeepsSize() {
    let size = CGSize(width: 120, height: 48)
    func slot(_ value: Int?) -> some View {
      LoadingSlot(value) { _ in
        Color.clear.frame(width: size.width, height: size.height)
      } placeholder: {
        Skeleton(nil) { SkeletonBlock(.fill) }.frame(width: size.width, height: size.height)
      }
    }
    #expect(NSHostingView(rootView: slot(nil)).fittingSize == size)
    #expect(NSHostingView(rootView: slot(1)).fittingSize == size)
  }
  #endif

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
