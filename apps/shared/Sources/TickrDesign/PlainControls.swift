import SwiftUI

// The apps' quiet buttons, whose label is their own face: a glyph button, a pressed stage of the
// live flow, the Mac title bar's buttons and the way back to today. Every button look of both
// apps lives in TickrDesign (check_swift_rules.py, rule `styles`); the system's bordered,
// borderless and link looks are never used (rule `system-buttons`).

public extension View {
  /// A control's tap area: on iOS at least `Size.touchTarget` tall (Apple HIG), on the Mac its
  /// own frame; either way the whole rectangle answers, not only the drawn parts.
  func touchTarget() -> some View {
    #if os(iOS)
    frame(minHeight: Tokens.Size.touchTarget).contentShape(Rectangle())
    #else
    contentShape(Rectangle())
    #endif
  }

  /// A small drawn control's tap area: on iOS it reaches past the drawing up to
  /// `Size.touchTarget` each way (Apple HIG) while the layout keeps the drawn size, so a Mac-sized
  /// control on the iPad is as easy to hit as the phone's; the Mac clicks the drawing only.
  @ViewBuilder
  func touchReach() -> some View {
    #if os(iOS)
    modifier(TouchReach())
    #else
    self
    #endif
  }
}

#if os(iOS)
/// The tap area of `touchReach()`: the drawn size measured, padded out to a touch target for the
/// hit shape only, and the padding taken back for the layout.
private struct TouchReach: ViewModifier {
  @State private var drawn = CGSize.zero

  func body(content: Content) -> some View {
    let vertical = max(Tokens.Size.touchTarget - drawn.height, 0) / 2
    let horizontal = max(Tokens.Size.touchTarget - drawn.width, 0) / 2
    content
      .onGeometryChange(for: CGSize.self) { $0.size } action: { drawn = $0 }
      .padding(.vertical, vertical)
      .padding(.horizontal, horizontal)
      .contentShape(Rectangle())
      .padding(.vertical, -vertical)
      .padding(.horizontal, -horizontal)
  }
}
#endif

/// A button whose label is its own face: a header icon (`HeaderIcon`), a bare symbol in a row,
/// a calendar's month arrows. No chrome and no colour of its own (the label keeps the one it is
/// given), pressed in to `Motion.pressScale` and dimmed to `Opacity.medium` while held. A label
/// that should fade while disabled takes `dimmedWhenDisabled()`.
public struct GlyphButtonStyle: ButtonStyle {
  public init() {}

  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .contentShape(Rectangle())
      .touchReach()
      .opacity(configuration.isPressed ? Tokens.Opacity.medium : 1)
      .scaleEffect(configuration.isPressed ? Tokens.Motion.pressScale : 1)
      .animation(Tokens.Motion.quick, value: configuration.isPressed)
  }
}

public extension ButtonStyle where Self == GlyphButtonStyle {
  /// `.buttonStyle(.glyph)`: a button whose label is its own face (`GlyphButtonStyle`).
  static var glyph: GlyphButtonStyle { GlyphButtonStyle() }
}

/// A tile that opens its details while a finger or the pointer holds it: its own colour as a
/// wash behind it and the press scale, so a tap reads before the details open (the live flow's
/// stages). Under Reduce Motion it does not scale.
public struct WashPressStyle: ButtonStyle {
  let color: Color

  public init(_ color: Color) {
    self.color = color
  }

  public func makeBody(configuration: Configuration) -> some View {
    WashPressBody(configuration: configuration, color: color)
  }
}

private struct WashPressBody: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let configuration: ButtonStyleConfiguration
  let color: Color

  var body: some View {
    configuration.label
      .background {
        RoundedRectangle(cornerRadius: Tokens.Radius.medium)
          .fill(color.opacity(configuration.isPressed ? Tokens.Opacity.wash : 0))
      }
      .scaleEffect(configuration.isPressed && !reduceMotion ? Tokens.Motion.pressScale : 1)
      .animation(reduceMotion ? nil : Tokens.Motion.quick, value: configuration.isPressed)
  }
}

public extension ButtonStyle where Self == WashPressStyle {
  /// `.buttonStyle(.washPress(stage.color))` (`WashPressStyle`).
  static func washPress(_ color: Color) -> WashPressStyle { WashPressStyle(color) }
}

/// The Mac title bar's small bordered buttons (the sidebar, ‹ › and Today), as on every Mac board
/// (`.tbtn`): the chip fill, a strong hairline and the label in `textTertiary`. One size for every
/// title-bar button: an icon-only button `width` × `height`, a titled one as tall with side
/// padding. Built on iOS too, for the Mac screens an iPad shows in regular width (TickrScreens);
/// the iPad's own navigation bar uses system buttons.
public struct TitleBarButtonStyle: ButtonStyle {
  /// An icon-only button of the fixed size; otherwise the title with side padding.
  let square: Bool

  /// Size of an icon-only button, in points: at least macOS's regular control height, 28 points
  /// (Apple HIG), so the title bar's buttons are as easy to hit as the system's toolbar items.
  public static let width: CGFloat = 32
  public static let height: CGFloat = 28
  /// Corner radius of the button, in points.
  public static let radius: CGFloat = 7

  public init(square: Bool) {
    self.square = square
  }

  public func makeBody(configuration: Configuration) -> some View {
    TitleBarButtonBody(configuration: configuration, square: square)
  }
}

private struct TitleBarButtonBody: View {
  @Environment(\.isEnabled) private var isEnabled
  let configuration: ButtonStyleConfiguration
  let square: Bool

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: TitleBarButtonStyle.radius, style: .continuous)
    configuration.label
      .labelStyle(.iconOnly)
      // An icon-only button's symbol at a toolbar symbol's size; a title in the compact button font.
      .font(square ? Tokens.Typography.headerSymbol : Tokens.Typography.buttonCompact)
      .foregroundStyle(Palette.textTertiary)
      .padding(.horizontal, square ? 0 : Tokens.Space.s)
      .frame(minWidth: TitleBarButtonStyle.width, minHeight: TitleBarButtonStyle.height)
      .background(shape.fill(Palette.chipFill))
      .overlay(shape.strokeBorder(Palette.separatorStrong, lineWidth: Tokens.Stroke.thin))
      .contentShape(shape)
      .touchReach()
      .opacity(isEnabled ? 1 : Tokens.Opacity.faint)
      .scaleEffect(configuration.isPressed ? Tokens.Motion.pressScale : 1)
  }
}

public extension ButtonStyle where Self == TitleBarButtonStyle {
  /// `.buttonStyle(.titleBar(square: true))` (`TitleBarButtonStyle`).
  static func titleBar(square: Bool) -> TitleBarButtonStyle { TitleBarButtonStyle(square: square) }
}

/// The way back to today from another day, the same control wherever a day can be changed: the
/// Mac title bar's Today (a titled `TitleBarButtonStyle`, as on the boards) and the iPhone's
/// Activity calendar (a compact ghost button); the iPhone's `DaySwitch` has its own Today row. The app passes its own words.
public struct TodayButton: View {
  let title: Text
  let action: () -> Void

  public init(_ title: LocalizedStringResource, action: @escaping () -> Void) {
    self.title = Text(title)
    self.action = action
  }

  public var body: some View {
    Button(action: action) { title }
      #if os(macOS)
      .buttonStyle(.titleBar(square: false))
      #else
      .buttonStyle(.action(.ghost, size: .compact))
      #endif
  }
}
