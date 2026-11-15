import SwiftUI

/// The macOS app's opening (macOS has no launch screen): the first window of a launch opens on the
/// plain background with the mark in its centre, the line draws itself, then the mark flies to the
/// header's mark (`target`, on screen) over the still plain background; only then does the
/// background fade and the screen show through, the mark giving way to the header's own. The mark
/// follows the header's mark wherever it moves until the opening is over, so it never lands beside it. It starts
/// when the window is on screen and in front (key or active), or after `openingWaitSeconds` at the
/// latest, so a window opened in the background is never left covered. Under Reduce Motion it only
/// cross-fades. Design: the "Бренд Tickr" board, "macOS opening".
public struct BrandOpening: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  #if os(macOS)
  @Environment(\.controlActiveState) private var activeState
  #endif
  /// The window is ready for the opening (in front, or waited long enough); set once, never undone.
  @State private var ready = false
  /// The mark is on stage (and starts drawing).
  @State private var started = false
  @State private var flown = false
  @State private var faded = false
  /// This view's origin on screen, to bring the target into its coordinates.
  @State private var origin = CGPoint.zero
  /// The header mark's centre on screen; nil (not on screen yet) keeps the mark in the centre.
  let target: CGPoint?
  /// The size the mark lands at.
  let targetSize: CGFloat
  /// Called when the opening is over and the overlay can go.
  let finished: () -> Void

  public init(
    target: CGPoint?,
    targetSize: CGFloat = Tokens.Size.logo,
    finished: @escaping () -> Void
  ) {
    self.target = target
    self.targetSize = targetSize
    self.finished = finished
  }

  public var body: some View {
    GeometryReader { geometry in
      let centre = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
      let landing = target.map { CGPoint(x: $0.x - origin.x, y: $0.y - origin.y) }
      ZStack {
        if started {
          BrandMark(size: Tokens.Size.openingMark, live: false, tone: .brand,
            drawing: .easeOut(duration: Tokens.Motion.openingDrawSeconds).delay(Tokens.Motion.openingDelaySeconds))
            .scaleEffect(flown ? targetSize / Tokens.Size.openingMark : 1)
            .position(flown ? landing ?? centre : centre)
            // The header settles while its data arrives: glide after it rather than jump.
            .animation(Tokens.Motion.quick, value: landing)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Palette.background)
      .opacity(faded ? 0 : 1)
    }
    .onGeometryChange(for: CGPoint.self) { $0.frame(in: .global).origin } action: { origin = $0 }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
    #if os(macOS)
    .onChange(of: activeState, initial: true) { _, state in
      if Self.inFront(state) { ready = true }
    }
    #else
    .onAppear { ready = true }
    #endif
    .task {
      try? await Task.sleep(for: .seconds(Tokens.Motion.openingWaitSeconds))
      ready = true
    }
    // `ready` only ever turns true, so this runs the opening once and is never cancelled midway.
    .task(id: ready) {
      guard ready, !started else { return }
      await play()
    }
  }

  #if os(macOS)
  /// Whether a window in this state is in front, so the opening is seen from its first frame.
  static func inFront(_ state: ControlActiveState) -> Bool {
    state == .key || state == .active
  }
  #endif

  private func play() async {
    started = true
    if reduceMotion {
      withAnimation(.easeOut(duration: Tokens.Motion.launchFadeSeconds)) { faded = true } completion: { finished() }
      return
    }
    try? await Task.sleep(for: .seconds(Tokens.Motion.openingDelaySeconds + Tokens.Motion.openingDrawSeconds))
    withAnimation(Tokens.Motion.openingFly) { flown = true }
    try? await Task.sleep(for: .seconds(Tokens.Motion.openingFlySeconds))
    withAnimation(.easeOut(duration: Tokens.Motion.launchFadeSeconds)) { faded = true } completion: { finished() }
  }
}

#Preview {
  Color.clear.overlay { BrandOpening(target: nil, finished: {}) }
}
