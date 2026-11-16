import SwiftUI

/// A band of light that passes across a title, again and again, as the design's shine on the AI
/// advisor's title: the title keeps its own colour and the band, in `color`, is drawn only inside
/// its letters. Ornament: it runs only while `moving` (the caller's `OrnamentGate`) and never with
/// Reduce Motion; still, the title is plain.
public struct Shine: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let moving: Bool
  let color: Color

  public func body(content: Content) -> some View {
    content.overlay {
      if moving && !reduceMotion {
        ShineBand(color: color)
          .mask(content)
          .allowsHitTesting(false)
          .accessibilityHidden(true)
      }
    }
  }
}

/// The band itself, as wide as the title, sweeping from before its start to past its end. It
/// starts as it appears and ends with it, so the loop runs only while `Shine` shows it.
private struct ShineBand: View {
  @State private var swept = false
  let color: Color

  var body: some View {
    LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: color, location: ShineBand.middle),
      .init(color: .clear, location: 1)], startPoint: .leading, endPoint: .trailing)
      // Moved when drawing, not in layout, so each frame of the loop redraws the band alone.
      .visualEffect { [swept] effect, proxy in
        effect.offset(x: swept ? proxy.size.width : -proxy.size.width)
      }
      .onAppear {
        // decorative: the advisor title's shine is ornament (owner wants the design's motion, 2026-11-16).
        withAnimation(.linear(duration: Tokens.Motion.shineSeconds).repeatForever(autoreverses: false)) {
          swept = true
        }
      }
  }

  /// Where the band is brightest, as a share of its width.
  static let middle = 0.5
}

public extension View {
  /// A band of light in `color` passing across the view while `moving` (see `Shine`).
  func shine(moving: Bool, color: Color) -> some View { modifier(Shine(moving: moving, color: color)) }
}

public extension EnvironmentValues {
  /// Section headers below it pass a light across their title (`Shine`): the Lab's AI advisor
  /// card sets it while its ornament may move (`OrnamentGate`); its content resets it.
  @Entry var titleShines = false
}
