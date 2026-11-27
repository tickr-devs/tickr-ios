import SwiftUI

/// "‹ Home": the face of the way back from a pushed screen, as on the Controls board (`.bk`): a
/// glass capsule `Size.iconButton` tall holding the chevron and the name of the screen under it,
/// both in `textPrimary` (the chevron takes the label's colour, not blue). Pressed, it shrinks to
/// `Motion.backPressScale` and its chevron and name dim to `Opacity.medium`. A long name wraps onto
/// more lines rather than being cut. The iPhone's pushed screens use it (`BackButton`); the Mac's
/// Symbols screen can take it for its "‹ Overview". Use it as a button's label with
/// `.buttonStyle(.backCapsule)`.
public struct BackCapsule: View {
  let title: Text

  public init(_ title: LocalizedStringResource) {
    self.title = Text(title)
  }

  public var body: some View {
    HStack(spacing: Tokens.Space.xs) {
      Image(systemName: Symbols.previous)
        .font(Tokens.Typography.backChevron)
        .accessibilityHidden(true)
      title
        .font(Tokens.Typography.backTitle)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
    }
    .foregroundStyle(Palette.textPrimary)
  }
}

/// The look of `BackCapsule`: the glass capsule (rounded to half its one-line height, so a wrapped
/// name keeps round ends), pressed in and dimmed while held. On iOS its touch target covers
/// `Size.touchTarget` (Apple HIG).
public struct BackCapsuleStyle: ButtonStyle {
  #if os(iOS)
  /// Half the one-line height, growing with the text size as the capsule does.
  @ScaledMetric(relativeTo: .subheadline) private var radius = Tokens.Size.iconButton / 2
  #else
  private let radius = Tokens.Size.iconButton / 2
  #endif

  public init() {}

  public func makeBody(configuration: Configuration) -> some View {
    let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
    configuration.label
      .opacity(configuration.isPressed ? Tokens.Opacity.medium : 1)
      .padding(.leading, Tokens.Space.s + Tokens.Space.xxs)
      .padding(.trailing, Tokens.Space.m + Tokens.Space.xxs)
      .padding(.vertical, Tokens.Space.xs)
      .frame(minHeight: Tokens.Size.iconButton)
      .glassSurface(in: shape)
      #if os(iOS)
      .frame(minHeight: Tokens.Size.touchTarget)
      #endif
      .contentShape(Rectangle())
      .scaleEffect(configuration.isPressed ? Tokens.Motion.backPressScale : 1)
      .animation(Tokens.Motion.quick, value: configuration.isPressed)
  }
}

public extension ButtonStyle where Self == BackCapsuleStyle {
  /// The back capsule's glass, pressed in and dimmed while held (`BackCapsule`).
  static var backCapsule: BackCapsuleStyle { BackCapsuleStyle() }
}

public extension View {
  /// The design's glass for a header's controls (the boards' `.gbtn` and `.bk`): the system's
  /// Liquid Glass in `shape`, which bends and lights what is under it and answers a touch.
  func glassSurface(in shape: some Shape) -> some View {
    glassEffect(.regular.interactive(), in: shape)
  }
}
