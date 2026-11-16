import QuartzCore
import Testing
@testable import TickrDesign

#if os(macOS)
/// The advisor title's shine runs in Core Animation: one band sweep, repeated, across the title.
@MainActor
@Suite struct ShineTests {
  @Test("Laid out, the band sweeps from before the title to past it in shineSeconds, as a loop")
  func sweepsAcross() throws {
    let view = ShineBandView(frame: CGRect(x: 0, y: 0, width: 120, height: 16))
    view.layout()
    let band = try #require(view.layer?.sublayers?.first)
    let sweep = try #require(band.animation(forKey: ShineBandView.sweepKey) as? CABasicAnimation)
    #expect(sweep.keyPath == ShineBandView.translationPath)
    #expect(sweep.fromValue as? CGFloat == -120)
    #expect(sweep.toValue as? CGFloat == 120)
    #expect(sweep.duration == Tokens.Motion.shineSeconds)
    #expect(sweep.repeatCount == .infinity)
    #expect(band.frame.width == 120)
  }

  @Test("Without a width there is nothing to sweep")
  func noWidthNoSweep() throws {
    let view = ShineBandView(frame: .zero)
    view.layout()
    let band = try #require(view.layer?.sublayers?.first)
    #expect(band.animation(forKey: ShineBandView.sweepKey) == nil)
  }
}
#endif
