import SwiftUI

// MARK: - buttons

/// The apps' text button. `primary` is the one main action of a view (an accent fill with a soft
/// glow), `secondary` an ordinary command on a sunken surface, `ghost` a quiet link-like action in
/// the accent colour, `destructive` an action that closes positions or stops the bot. A
/// `secondary` button given `role: .destructive` draws as `destructive`.
public struct ActionButtonStyle: ButtonStyle {
  public enum Kind: Sendable, Hashable, CaseIterable {
    case primary, secondary, ghost, destructive
  }

  public enum Size: Sendable, Hashable, CaseIterable {
    /// Inline in a row or a card header.
    case compact
    /// A panel's one main action, between compact and regular (the menu-bar panel's Open Tickr).
    case medium
    /// The default.
    case regular
    /// Full-width actions of a sheet or a panel on the phone: at least a touch target tall.
    case large
  }

  let kind: Kind
  let size: Size

  public init(_ kind: Kind = .secondary, size: Size = .regular) {
    self.kind = kind
    self.size = size
  }

  public func makeBody(configuration: Configuration) -> some View {
    let drawn: Kind = configuration.role == .destructive && kind == .secondary ? .destructive : kind
    ActionButtonBody(configuration: configuration, kind: drawn, size: size)
  }
}

private struct ActionButtonBody: View {
  @Environment(\.isEnabled) private var enabled
  @State private var hovered = false
  let configuration: ButtonStyleConfiguration
  let kind: ActionButtonStyle.Kind
  let size: ActionButtonStyle.Size

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
    configuration.label
      .labelStyle(ControlLabelStyle())
      .font(size == .compact || size == .medium ? Tokens.Typography.buttonCompact : Tokens.Typography.button)
      .foregroundStyle(foreground)
      .padding(.horizontal, horizontalPadding)
      .padding(.vertical, verticalPadding)
      .frame(minHeight: size == .large ? Tokens.Size.touchTarget : nil)
      .background { fill(shape) }
      .overlay { shape.strokeBorder(border, lineWidth: Tokens.Stroke.thin) }
      .shadow(color: kind == .primary && enabled ? Palette.accent.opacity(Tokens.Opacity.faint) : .clear,
        radius: Tokens.Size.glowRadius, y: Tokens.Space.xxs)
      .contentShape(shape)
      .opacity(enabled ? 1 : Tokens.Opacity.faint)
      .scaleEffect(configuration.isPressed ? Tokens.Motion.pressScale : 1)
      .animation(Tokens.Motion.quick, value: configuration.isPressed)
      .animation(Tokens.Motion.quick, value: hovered)
      .onHover { hovered = $0 }
  }

  private var active: Bool { enabled && (hovered || configuration.isPressed) }

  @ViewBuilder private func fill(_ shape: RoundedRectangle) -> some View {
    switch kind {
    case .primary:
      shape.fill(Palette.accentFill)
        .overlay(shape.fill(LinearGradient(
          colors: [Palette.sheen.opacity(active ? Tokens.Opacity.glow : Tokens.Opacity.wash), .clear],
          startPoint: .top, endPoint: .bottom)))
    case .secondary:
      shape.fill(Palette.surfaceSunken)
    case .ghost:
      shape.fill(active ? Palette.accent.opacity(Tokens.Opacity.wash) : .clear)
    case .destructive:
      shape.fill(Palette.loss.opacity(active ? Tokens.Opacity.glow : Tokens.Opacity.wash))
    }
  }

  private var foreground: Color {
    switch kind {
    case .primary: return Palette.onAccent
    case .secondary: return Palette.textPrimary
    case .ghost: return Palette.accentText
    case .destructive: return Palette.lossText
    }
  }

  private var border: Color {
    switch kind {
    case .primary: return Palette.accentFill
    case .secondary: return active ? Palette.accent.opacity(Tokens.Opacity.border) : Palette.separatorStrong
    case .ghost: return .clear
    case .destructive: return Palette.loss.opacity(Tokens.Opacity.border)
    }
  }

  private var horizontalPadding: CGFloat {
    switch size {
    case .compact: return Tokens.Space.s
    case .medium: return Tokens.Space.s + Tokens.Space.xxs
    case .regular: return Tokens.Space.m
    case .large: return Tokens.Space.l
    }
  }

  private var verticalPadding: CGFloat {
    switch size {
    case .compact: return Tokens.Space.xs
    case .medium: return Tokens.Space.xs + Tokens.Space.xxs
    case .regular: return Tokens.Space.s
    case .large: return Tokens.Space.m
    }
  }
}

/// A round button holding one SF Symbol: refresh, settings, close, an alarm action. Give it an
/// accessibility label (a `Label` whose title is read by VoiceOver and hidden on screen).
public struct IconButtonStyle: ButtonStyle {
  let tone: Tone
  let compact: Bool

  public init(_ tone: Tone = .neutral, compact: Bool = false) {
    self.tone = tone
    self.compact = compact
  }

  public func makeBody(configuration: Configuration) -> some View {
    IconButtonBody(configuration: configuration, tone: tone, compact: compact)
  }
}

private struct IconButtonBody: View {
  @Environment(\.isEnabled) private var enabled
  @State private var hovered = false
  let configuration: ButtonStyleConfiguration
  let tone: Tone
  let compact: Bool

  var body: some View {
    let side = compact ? Tokens.Size.iconButtonCompact : Tokens.Size.iconButton
    let neutral = tone == .neutral
    let active = enabled && (hovered || configuration.isPressed)
    configuration.label
      .labelStyle(.iconOnly)
      .font(compact ? Tokens.Typography.symbolCompact : Tokens.Typography.symbol)
      .foregroundStyle(neutral ? Palette.textPrimary : tone.text)
      .frame(width: side, height: side)
      .background(Circle().fill(neutral
        ? (active ? Palette.accent.opacity(Tokens.Opacity.wash) : Palette.surfaceSunken)
        : tone.fill.opacity(active ? Tokens.Opacity.glow : Tokens.Opacity.wash)))
      .overlay(Circle().strokeBorder(neutral && !active ? Palette.separatorStrong
        : (neutral ? Palette.accent : tone.fill).opacity(Tokens.Opacity.border), lineWidth: Tokens.Stroke.thin))
      .contentShape(Circle())
      .opacity(enabled ? 1 : Tokens.Opacity.faint)
      .scaleEffect(configuration.isPressed ? Tokens.Motion.pressScale : 1)
      .animation(Tokens.Motion.quick, value: configuration.isPressed)
      .animation(Tokens.Motion.quick, value: hovered)
      .onHover { hovered = $0 }
  }
}

/// A selectable chip: one of a few choices shown side by side (a position's tab, a day, a range).
/// The selected one is outlined and washed in its tone.
public struct ChipButtonStyle: ButtonStyle {
  let selected: Bool
  let tone: Tone

  public init(selected: Bool, tone: Tone = .info) {
    self.selected = selected
    self.tone = tone
  }

  public func makeBody(configuration: Configuration) -> some View {
    let shape = RoundedRectangle(cornerRadius: Tokens.Radius.small, style: .continuous)
    configuration.label
      .labelStyle(ControlLabelStyle())
      .font(Tokens.Typography.chip)
      .foregroundStyle(selected ? Palette.textPrimary : Palette.textSecondary)
      .padding(.horizontal, Tokens.Space.s)
      .padding(.vertical, Tokens.Space.xs)
      .background(selected ? tone.fill.opacity(Tokens.Opacity.wash) : Palette.surfaceSunken, in: shape)
      .overlay(shape.strokeBorder(selected ? tone.fill : Palette.separatorStrong, lineWidth: Tokens.Stroke.thin))
      .contentShape(shape)
      .scaleEffect(configuration.isPressed ? Tokens.Motion.pressScale : 1)
      .animation(Tokens.Motion.quick, value: configuration.isPressed)
      .animation(Tokens.Motion.quick, value: selected)
      .accessibilityAddTraits(selected ? .isSelected : [])
  }
}

public extension ButtonStyle where Self == ActionButtonStyle {
  /// `.buttonStyle(.action(.primary))`, `.buttonStyle(.action(.ghost, size: .compact))`.
  static func action(_ kind: ActionButtonStyle.Kind = .secondary, size: ActionButtonStyle.Size = .regular)
    -> ActionButtonStyle {
    ActionButtonStyle(kind, size: size)
  }
}

public extension ButtonStyle where Self == IconButtonStyle {
  /// `.buttonStyle(.icon())`, `.buttonStyle(.icon(.loss))`.
  static func icon(_ tone: Tone = .neutral, compact: Bool = false) -> IconButtonStyle {
    IconButtonStyle(tone, compact: compact)
  }
}

public extension ButtonStyle where Self == ChipButtonStyle {
  /// `.buttonStyle(.chip(selected: isShown))`.
  static func chip(selected: Bool, tone: Tone = .info) -> ChipButtonStyle {
    ChipButtonStyle(selected: selected, tone: tone)
  }
}

/// A `Label` inside the apps' controls: the symbol close to its title.
public struct ControlLabelStyle: LabelStyle {
  public init() {}

  public func makeBody(configuration: Configuration) -> some View {
    HStack(spacing: Tokens.Space.xs) {
      configuration.icon
      configuration.title
    }
  }
}

/// A trailing chevron after a ghost button's title: "Open chart ›".
public struct Chevron: View {
  /// SF Symbol of the chevron.
  static let symbol = "chevron.right"

  public init() {}

  public var body: some View {
    Image(systemName: Self.symbol)
      .font(Tokens.Typography.chevron)
      .accessibilityHidden(true)
  }
}

/// Icon buttons grouped on one sunken capsule, like a toolbar: the bot's commands.
public struct IconToolbar<Content: View>: View {
  let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    HStack(spacing: Tokens.Space.xs) { content }
      .padding(Tokens.Space.xs)
      .background(Capsule().fill(Palette.surfaceSunken))
      .overlay(Capsule().strokeBorder(Palette.separatorStrong, lineWidth: Tokens.Stroke.thin))
  }
}
