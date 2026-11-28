import SwiftUI
import TickrDesign
import TickrKit

/// The app's opening (mockup v189, page p-logo option B): it starts exactly as the system's launch
/// screen (the window background with the wordmark's "t" centred in the safe area, Support/
/// Info.plist `UILaunchScreen`), slides "ickr" out of the mark, then flies the wordmark into Home's
/// title (or onto the sign-in's wordmark, when the phone has no sign-in) while the background fades
/// and the screen shows through. Home's cards rise right after it lands (the board's `lrise` after
/// `lfly`). Under Reduce Motion it only cross-fades.
struct LaunchHandoff: View {
  /// Height of the navigation bar's row: where Home's wordmark sits until it has reported its place.
  static let navigationBarHeight: CGFloat = 44

  @Environment(AppModel.self) private var model
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var revealed = false
  @State private var flown = false
  @State private var faded = false
  /// Where the wordmark lands, in this view's coordinates: read once, as the flight starts.
  @State private var target: CGPoint?
  /// This view's origin on screen, to bring Home's wordmark into its coordinates.
  @State private var origin = CGPoint.zero
  /// Called when the wordmark has landed on Home's (at once under Reduce Motion): the screen below
  /// may assemble.
  let landed: () -> Void
  /// Called when the opening is over and the overlay can go.
  let finished: () -> Void

  var body: some View {
    GeometryReader { geometry in
      let centre = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
      let estimate = CGPoint(x: Tokens.Space.l + Wordmark.markWidth(height: model.homeMarkHeight),
        y: Self.navigationBarHeight / 2)
      Wordmark(height: Tokens.Size.wordmarkLaunch, rest: revealed ? 1 : .zero)
        .scaleEffect(flown ? model.homeMarkHeight / Tokens.Size.wordmarkLaunch : 1)
        .position(flown ? target ?? estimate : centre)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { Palette.background.opacity(flown ? 0 : 1).ignoresSafeArea() }
        .opacity(faded ? 0 : 1)
    }
    .onGeometryChange(for: CGPoint.self) { $0.frame(in: .global).origin } action: { origin = $0 }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
    .task { await play() }
  }

  private func play() async {
    if reduceMotion {
      landed()
      withAnimation(.easeOut(duration: Tokens.Motion.launchFadeSeconds)) { faded = true } completion: { finished() }
    } else {
      withAnimation(Tokens.Motion.wordmarkReveal) { revealed = true }
      try? await Task.sleep(for: .seconds(Tokens.Motion.wordmarkRevealSeconds + Tokens.Motion.launchHoldSeconds))
      if let mark = model.homeMarkCentre {
        target = CGPoint(x: mark.x - origin.x, y: mark.y - origin.y)
      }
      withAnimation(Tokens.Motion.launchFly) { flown = true }
      // The wordmark lands on Home's own, then gives way to it.
      try? await Task.sleep(for: .seconds(Tokens.Motion.launchFlySeconds))
      landed()
      withAnimation(Tokens.Motion.quick) { faded = true } completion: { finished() }
    }
  }
}

#Preview {
  Color.clear.overlay { LaunchHandoff {} finished: {} }
    .environment(Container.shared.appModel())
}
