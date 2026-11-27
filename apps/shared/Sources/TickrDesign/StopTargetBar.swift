import SwiftUI

/// A track from the stop toward the target, filled red to amber to teal up to a knob at the last
/// price, which glides as it moves: the Mac menu bar's positions and the Live Activity's rows.
/// Without a progress (no last price) only the track shows.
public struct StopTargetBar: View {
  /// Diameter of the knob, and of the knob with its 4-point accent ring, in points (menu bar).
  public static let knob: CGFloat = 15
  public static let knobWithRing: CGFloat = 23

  let progress: Double?
  /// The position is as of an older bar: greyed like its figure.
  let muted: Bool
  let barHeight: CGFloat
  let knob: CGFloat
  /// The knob with its accent ring; nil draws no ring.
  let ring: CGFloat?

  /// `progress`: where the last price sits from the stop (0) to the target (1).
  public init(
    progress: Double?, muted: Bool = false, barHeight: CGFloat = Tokens.Size.bar, knob: CGFloat = StopTargetBar.knob,
    ring: CGFloat? = StopTargetBar.knobWithRing
  ) {
    self.progress = progress
    self.muted = muted
    self.barHeight = barHeight
    self.knob = knob
    self.ring = ring
  }

  public var body: some View {
    GeometryReader { proxy in
      let filled = proxy.size.width * (progress ?? 0)
      ZStack(alignment: .leading) {
        Capsule()
          .fill(Palette.separator)
          .frame(height: barHeight)
        if progress != nil {
          Capsule()
            .fill(LinearGradient(colors: [Palette.loss, Palette.warning, Palette.accent], startPoint: .leading,
              endPoint: .trailing))
            .frame(width: filled, height: barHeight)
          Circle()
            .fill(Palette.textPrimary)
            .frame(width: knob, height: knob)
            .background {
              if let ring {
                Circle()
                  .fill(Palette.accent.opacity(Tokens.Opacity.faint))
                  .frame(width: ring, height: ring)
              }
            }
            .offset(x: filled - knob / 2)
        }
      }
      .frame(maxHeight: .infinity)
      .saturation(muted ? 0 : 1)
      .opacity(muted ? Tokens.Opacity.medium : 1)
    }
    .frame(height: ring ?? knob)
    .animation(Tokens.Motion.live, value: progress)
  }
}
