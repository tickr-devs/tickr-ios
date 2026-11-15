import SwiftUI

/// The macOS app's opening (macOS has no launch screen): the first window of a launch opens on the
/// plain background with the mark in its centre, the line draws itself, then the mark flies to the
/// header's mark (`target`, on screen) while the background fades and the screen shows through.
/// Under Reduce Motion it only cross-fades. Design: the "Бренд Tickr" board, "macOS opening".
public struct BrandOpening: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var flown = false
  @State private var faded = false
  /// This view's origin on screen, to bring the target into its coordinates.
  @State private var origin = CGPoint.zero
  /// Where the mark lands, in this view's coordinates: read once, as the flight starts.
  @State private var landing: CGPoint?
  /// The header mark's centre on screen when the flight starts; nil (not on screen) fades in place.
  let target: () -> CGPoint?
  /// The size the mark lands at.
  let targetSize: CGFloat
  /// Called when the opening is over and the overlay can go.
  let finished: () -> Void

  public init(
    target: @escaping () -> CGPoint?,
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
      BrandMark(size: Tokens.Size.openingMark, live: false, tone: .brand,
        drawing: .easeOut(duration: Tokens.Motion.openingDrawSeconds).delay(BrandMark.drawDelay))
        .scaleEffect(flown ? targetSize / Tokens.Size.openingMark : 1)
        .position(flown ? landing ?? centre : centre)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { Palette.background.opacity(flown ? 0 : 1) }
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
      return
    }
    try? await Task.sleep(for: .seconds(BrandMark.drawDelay + Tokens.Motion.openingDrawSeconds))
    if let mark = target() {
      landing = CGPoint(x: mark.x - origin.x, y: mark.y - origin.y)
    }
    withAnimation(Tokens.Motion.openingFly) { flown = true }
    // The mark lands on the header's own mark, then gives way to it.
    try? await Task.sleep(for: .seconds(Tokens.Motion.openingFlySeconds))
    withAnimation(Tokens.Motion.quick) { faded = true } completion: { finished() }
  }
}

#Preview {
  Color.clear.overlay { BrandOpening(target: { nil }, finished: {}) }
}
