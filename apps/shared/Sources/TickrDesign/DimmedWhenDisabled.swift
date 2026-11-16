import SwiftUI

/// Dims a control's label while the control is disabled. A label given its own colour
/// (`foregroundStyle`) keeps that colour when its button is disabled, so a control that does
/// nothing in its state looked as if it would act: this fades it as the system's own disabled
/// controls fade.
public struct DimmedWhenDisabled: ViewModifier {
  @Environment(\.isEnabled) private var isEnabled

  public init() {}

  public func body(content: Content) -> some View {
    content.opacity(isEnabled ? 1 : Tokens.Opacity.faint)
  }
}

public extension View {
  /// Fades the view while the control around it is disabled (`.disabled(true)`).
  func dimmedWhenDisabled() -> some View { modifier(DimmedWhenDisabled()) }
}
