import SwiftUI

/// Pops a view in from nothing after `delay`, overshooting a little (`Motion.pop`, the boards'
/// `pop`), once per appearance: give the view an `.id` of the fact it shows, and it pops again when
/// that fact changes (a protection step proven). Still with Reduce Motion.
public struct PopIn: ViewModifier {
  /// Scale before the pop: not zero, so the transform stays invertible.
  public nonisolated static let hiddenScale: CGFloat = 0.01

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var shown = false
  let delay: Double

  public func body(content: Content) -> some View {
    let isShown = shown || reduceMotion
    content
      .visualEffect { effect, _ in effect.scaleEffect(isShown ? 1 : Self.hiddenScale) }
      .onAppear { withAnimation(Tokens.Motion.pop.delay(delay)) { shown = true } }
  }
}

public extension View {
  /// Pops in after `delay` seconds (see `PopIn`).
  func popIn(delay: Double = 0) -> some View { modifier(PopIn(delay: delay)) }
}
