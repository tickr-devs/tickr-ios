import QuartzCore
import SwiftUI
import Testing
@testable import TickrDesign

/// Loading (mockup v102, loader E): the running bar, the chart's build, the button spinner, the
/// progress line.
@MainActor
@Suite struct LoadingTests {
  @Test("The running bar's segment crosses its track once a run, eased, with no jump inside a run")
  func barRuns() {
    let seconds = Tokens.Loading.barSeconds
    let share = Tokens.Loading.barShare
    let start = Date(timeIntervalSinceReferenceDate: 1_000 * seconds)
    // A run starts a segment's width before the track and ends at the track's end, so the
    // segment comes in from the left and leaves at the right: it is off the track at both ends.
    #expect(abs(RunningBar.offset(at: start) + share) < 1e-9)
    #expect(abs(RunningBar.offset(at: start.addingTimeInterval(seconds / 2)) - (1 - share) / 2) < 1e-6)
    // Sampled finely inside one run: it only moves right, within its range, by small steps.
    let steps = 2_000
    var previous = RunningBar.offset(at: start)
    for index in 1..<steps {
      let value = RunningBar.offset(at: start.addingTimeInterval(seconds * Double(index) / Double(steps)))
      #expect(value >= previous - 1e-9 && value <= 1 + 1e-9)
      #expect(value - previous < 0.01)
      previous = value
    }
  }

  @Test("Every running bar runs on one clock, and stands still in the middle under Reduce Motion")
  func sharedBarClock() {
    let date = Date(timeIntervalSinceReferenceDate: 1_000.25)
    let later = date.addingTimeInterval(7 * Tokens.Loading.barSeconds)
    #expect(abs(RunningBar.offset(at: date) - RunningBar.offset(at: later)) < 1e-9)
    #expect(abs(RunningBar.restOffset * 2 + Tokens.Loading.barShare - 1) < 1e-9)
  }

  @Test("The chart's candles build left to right, hold together, then fade out together")
  func candleBuild() {
    let count = 60
    // Before its start a candle is clear; the first rises before the last.
    #expect(SkeletonCandles.build(0, of: count, at: 0).opacity == 0)
    let early = Tokens.Loading.buildStart + Tokens.Loading.buildRise
    #expect(SkeletonCandles.build(0, of: count, at: early).opacity == 1)
    #expect(SkeletonCandles.build(count - 1, of: count, at: early).opacity == 0)
    // On the hold (the frame Reduce Motion shows) every candle is whole.
    for index in 0..<count {
      let look = SkeletonCandles.build(index, of: count, at: Tokens.Loading.buildRestPhase)
      #expect(look.opacity == 1 && look.scale == 1)
    }
    // Fading, all at the same opacity; gone by the fade's end, so the cycle restarts unseen.
    let fading = (Tokens.Loading.buildHoldEnd + Tokens.Loading.buildFadeEnd) / 2
    let first = SkeletonCandles.build(0, of: count, at: fading).opacity
    #expect(first > 0 && first < 1)
    #expect(SkeletonCandles.build(count - 1, of: count, at: fading).opacity == first)
    #expect(SkeletonCandles.build(0, of: count, at: Tokens.Loading.buildFadeEnd).opacity == 0)
    // Rising, a candle's opacity and height only grow, from the low scale to whole.
    var previous = SkeletonCandles.build(count / 2, of: count, at: 0)
    #expect(previous.scale == Tokens.Loading.buildLowScale)
    for step in 1...1_000 {
      let look = SkeletonCandles.build(count / 2, of: count, at: Tokens.Loading.buildHoldEnd * Double(step) / 1_000)
      #expect(look.opacity >= previous.opacity - 1e-9 && look.scale >= previous.scale - 1e-9)
      previous = look
    }
  }

  @Test("A build runs on the wall clock: built apart, two charts are at the same point")
  func sharedBuildClock() {
    let date = Date(timeIntervalSinceReferenceDate: 1_000.25)
    let later = date.addingTimeInterval(3 * Tokens.Loading.buildSeconds)
    #expect(abs(SkeletonCandles.phase(at: date) - SkeletonCandles.phase(at: later)) < 1e-9)
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
