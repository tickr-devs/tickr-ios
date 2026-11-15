import ApertureDesign
import ApertureKit
import SwiftUI

/// The app's opening: it starts exactly as the system's launch screen (the window background with
/// the mark centred in the safe area, Support/Info.plist `UILaunchScreen`), flashes the spark once,
/// then flies the mark into Home's title while the background fades and the screen shows through.
/// Under Reduce Motion it only cross-fades. Design: the "Бренд Tickr" board.
struct LaunchHandoff: View {
  /// Height of the navigation bar's row: where the Home mark sits until it has reported its place.
  static let navigationBarHeight: CGFloat = 44

  @Environment(AppModel.self) private var model
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var flashing = false
  @State private var flown = false
  @State private var faded = false
  /// Where the mark lands, in this view's coordinates: read once, as the flight starts.
  @State private var target: CGPoint?
  /// This view's origin on screen, to bring Home's mark into its coordinates.
  @State private var origin = CGPoint.zero
  /// Called when the opening is over and the overlay can go.
  let finished: () -> Void

  var body: some View {
    GeometryReader { geometry in
      let centre = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
      let estimate = CGPoint(x: Tokens.Space.l + Tokens.Size.logoSmall / 2, y: Self.navigationBarHeight / 2)
      let spark = BrandMark.breakout
      ZStack(alignment: .topLeading) {
        Image(.launchMark)
          .overlay(alignment: .topLeading) {
            Circle()
              .fill(Palette.profit)
              .frame(width: Tokens.Size.launchMark * BrandMark.sparkDiameter)
              .scaleEffect(flashing ? Tokens.Motion.pulseScale : 1)
              .opacity(flashing ? 0 : Tokens.Opacity.faint)
              .position(x: spark.x * Tokens.Size.launchMark, y: spark.y * Tokens.Size.launchMark)
          }
          .scaleEffect(flown ? Tokens.Size.logoSmall / Tokens.Size.launchMark : 1)
          .position(flown ? target ?? estimate : centre)
      }
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
      withAnimation(.easeOut(duration: Tokens.Motion.launchFadeSeconds)) { faded = true } completion: { finished() }
    } else {
      withAnimation(.easeOut(duration: Tokens.Motion.launchHoldSeconds)) { flashing = true }
      try? await Task.sleep(for: .seconds(Tokens.Motion.launchHoldSeconds))
      if let mark = model.homeMarkCentre {
        target = CGPoint(x: mark.x - origin.x, y: mark.y - origin.y)
      }
      withAnimation(Tokens.Motion.launchFly) { flown = true }
      // The mark lands on Home's own mark, then gives way to it.
      try? await Task.sleep(for: .seconds(Tokens.Motion.launchFlySeconds))
      withAnimation(Tokens.Motion.quick) { faded = true } completion: { finished() }
    }
  }
}

#Preview {
  Color.clear.overlay { LaunchHandoff {} }
    .environment(Container.shared.appModel())
}
