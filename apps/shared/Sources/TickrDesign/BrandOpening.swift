import SwiftUI

/// The macOS app's opening (macOS has no launch screen; mockup v189, page p-logo option B, and
/// v191, page p-machead): the first window of a launch opens on the plain background with the
/// wordmark's "t" in its centre, "ickr.bot" slides out of it, then the wordmark flies to the header's
/// (`target`, on screen) while the background fades and the screen shows through under it; as it
/// lands the header's own wordmark (hidden until then) takes its place. It follows the header's
/// wordmark wherever it moves until the opening is over, so it never lands beside it. It starts
/// when the window is on screen and in front (key or active), or after `openingWaitSeconds` at the
/// latest, so a window opened in the background is never left covered. Under Reduce Motion it only
/// cross-fades.
public struct BrandOpening: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  #if os(macOS)
  @Environment(\.controlActiveState) private var activeState
  #endif
  /// The window is ready for the opening (in front, or waited long enough); set once, never undone.
  @State private var ready = false
  /// The "t" is on stage.
  @State private var started = false
  @State private var revealed = false
  @State private var flown = false
  @State private var faded = false
  /// This view's origin on screen, to bring the target into its coordinates.
  @State private var origin = CGPoint.zero
  /// The header wordmark's centre on screen; nil (not on screen yet) keeps the wordmark in the centre.
  let target: CGPoint?
  /// The height the wordmark lands at.
  let targetHeight: CGFloat
  /// Called as the wordmark leaves for the header (or the fade starts under Reduce Motion): the
  /// screen under it shows from then on, so its cards can rise.
  let flying: () -> Void
  /// Called when the opening is over and the overlay can go.
  let finished: () -> Void

  public init(
    target: CGPoint?,
    targetHeight: CGFloat = Tokens.Size.wordmark,
    flying: @escaping () -> Void = {},
    finished: @escaping () -> Void
  ) {
    self.target = target
    self.targetHeight = targetHeight
    self.flying = flying
    self.finished = finished
  }

  public var body: some View {
    GeometryReader { geometry in
      let centre = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
      let landing = target.map { CGPoint(x: $0.x - origin.x, y: $0.y - origin.y) }
      ZStack {
        Wordmark(height: Tokens.Size.wordmarkLaunch, rest: revealed ? 1 : .zero)
          .opacity(started ? 1 : 0)
          .scaleEffect(started ? 1 : Self.startScale)
          .scaleEffect(flown ? targetHeight / Tokens.Size.wordmarkLaunch : 1)
          .position(flown ? landing ?? centre : centre)
          // The header settles while its data arrives: glide after it rather than jump.
          .animation(Tokens.Motion.quick, value: landing)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      // The screen fades in under the wordmark while it flies.
      .background(Palette.background.opacity(flown ? 0 : 1))
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
    // Played in a task of its own, not the view's: the window's first moments rebuild this view's
    // tasks, and the opening must run to its end once started (`ready` only ever turns true).
    .onChange(of: ready) { _, now in
      guard now, !started else { return }
      Task { await play() }
    }
  }

  /// How much smaller the "t" starts as it fades in (the board's `lbw`).
  static let startScale = 0.92

  #if os(macOS)
  /// Whether a window in this state is in front, so the opening is seen from its first frame.
  static func inFront(_ state: ControlActiveState) -> Bool {
    state == .key || state == .active
  }
  #endif

  private func play() async {
    if reduceMotion {
      started = true
      revealed = true
      flying()
      withAnimation(.easeOut(duration: Tokens.Motion.launchFadeSeconds)) { faded = true } completion: { finished() }
      return
    }
    // A cut-short wait must not rush the rest through in one frame: the opening then just goes.
    do {
      withAnimation(.easeOut(duration: Tokens.Motion.openingDrawSeconds).delay(Tokens.Motion.openingDelaySeconds)) {
        started = true
      }
      try await Task.sleep(for: .seconds(Tokens.Motion.openingDelaySeconds + Tokens.Motion.openingDrawSeconds))
      withAnimation(Tokens.Motion.wordmarkReveal) { revealed = true }
      try await Task.sleep(for: .seconds(Tokens.Motion.wordmarkRevealSeconds))
      flying()
      withAnimation(Tokens.Motion.openingFly) { flown = true }
      try await Task.sleep(for: .seconds(Tokens.Motion.openingFlySeconds))
    } catch {
      flying()
      finished()
      return
    }
    // Landed on the header's wordmark, which shows from this frame on (it stays hidden while the
    // opening plays), so there is never a second one. With no header on screen it fades out.
    if target == nil {
      withAnimation(.easeOut(duration: Tokens.Motion.launchFadeSeconds)) { faded = true } completion: { finished() }
    } else {
      finished()
    }
  }
}

#Preview {
  Color.clear.overlay { BrandOpening(target: nil, finished: {}) }
}
