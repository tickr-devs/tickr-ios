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
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.commandInFlight) private var inFlight
  @State private var hovered = false
  let configuration: ButtonStyleConfiguration
  let kind: ActionButtonStyle.Kind
  let size: ActionButtonStyle.Size

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
    label
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
      .touchReach()
      .opacity(enabled ? 1 : Tokens.Opacity.faint)
      .scaleEffect(configuration.isPressed ? Tokens.Motion.pressScale : 1)
      // Under the pointer an enabled button lifts a point, as the design's buttons do.
      .offset(y: lifted ? -Tokens.Motion.hoverLift : 0)
      .animation(Tokens.Motion.quick, value: configuration.isPressed)
      .animation(Tokens.Motion.quick, value: hovered)
      .onHover { hovered = $0 }
      .inFlightBehaviour(inFlight)
  }

  /// In flight a button is off but drawn as on: the spinner in it says why nothing answers.
  private var enabled: Bool { isEnabled || inFlight != nil }

  /// The button's label; in flight the spinner and the in-progress words in its place, whatever
  /// the label was (a `Label` or a title alone), the button keeping at least the label's size.
  @ViewBuilder private var label: some View {
    if let inFlight {
      ZStack {
        configuration.label.labelStyle(ControlLabelStyle()).hidden()
        HStack(spacing: Tokens.Space.xs) {
          Spinner()
          inFlight
        }
      }
    } else {
      configuration.label.labelStyle(ControlLabelStyle())
    }
  }

  private var active: Bool { enabled && (hovered || configuration.isPressed) }
  private var lifted: Bool { enabled && hovered && !configuration.isPressed }

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
/// accessibility label (a `Label` whose title is read by VoiceOver and hidden on screen). On iOS
/// it answers taps over `Size.touchTarget` around the circle.
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
      #if os(iOS)
      // The circle stays its size; the touch target around it is the HIG's 44 points.
      .frame(minWidth: Tokens.Size.touchTarget, minHeight: Tokens.Size.touchTarget)
      .contentShape(Rectangle())
      #else
      .contentShape(Circle())
      #endif
      .opacity(enabled ? 1 : Tokens.Opacity.faint)
      .scaleEffect(configuration.isPressed ? Tokens.Motion.pressScale : 1)
      .animation(Tokens.Motion.quick, value: configuration.isPressed)
      .animation(Tokens.Motion.quick, value: hovered)
      .onHover { hovered = $0 }
  }
}

/// The apps' one chip, as the boards' shared spec draws it (`.u-chip`): `chipTitle` (13 pt bold
/// mono) in `textSecondary` on `surfaceSunken` with a `separatorStrong` hairline, `Radius.chip`
/// (6 pt) corners, `Space.xs` × `Space.s` padding; the chosen one in `textPrimary`, outlined in its
/// tone and washed with it (`Opacity.wash`). `small` is `.u-chip.sm` (a symbol's sources):
/// `chipSmallTitle` (11 pt), `Space.xxs` × `ChipFace.smallSide` padding. Every chip of both apps
/// draws this face: a choice button (`.buttonStyle(.chip(selected:))`), an on/off chip
/// (`.toggleStyle(.chip)`), a menu's label (`.chipFace(selected:)`) and a chip showing data
/// (`.chipFace(selected: false, small: true)`). On iOS a regular chip is at least `minHeight`
/// (32 pt) tall and answers taps over `Size.touchTarget` (`touchTarget()`).
///
/// Under the Mac's pointer an enabled regular chip lights its outline in its full tone
/// (`.u-chip:hover`), its words in `textPrimary`; the fill and size stay, so the chosen chip (the
/// same outline plus the tone's wash) still reads apart and nothing moves (owner 2026-11-19: a
/// softer outline did not read as lit). A small chip shows data and does not answer the pointer.
public struct ChipFace: ViewModifier {
  @Environment(\.isEnabled) private var enabled
  @State private var hovered = false
  let selected: Bool
  let tone: Tone
  let small: Bool

  /// Side padding of a small chip, in points (`.u-chip.sm`).
  public static let smallSide: CGFloat = 6
  #if os(iOS)
  /// Least drawn height of a regular chip on iOS, in points (`.u-chip.ios`).
  public static let minHeight: CGFloat = 32
  #else
  /// Least drawn height of a regular chip on the Mac: its content's.
  public static let minHeight: CGFloat = 0
  #endif

  public init(selected: Bool, tone: Tone = .info, small: Bool = false) {
    self.selected = selected
    self.tone = tone
    self.small = small
  }

  /// Under the pointer: only a regular, enabled chip answers it.
  private var lit: Bool { hovered && enabled && !small }

  private var outline: Color {
    selected || lit ? tone.fill : Palette.separatorStrong
  }

  @ViewBuilder public func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: Tokens.Radius.chip, style: .continuous)
    let face = content
      .labelStyle(ControlLabelStyle())
      .font(small ? Tokens.Typography.chipSmallTitle : Tokens.Typography.chipTitle)
      .foregroundStyle(selected || lit ? Palette.textPrimary : Palette.textSecondary)
      .padding(.horizontal, small ? Self.smallSide : Tokens.Space.s)
      .padding(.vertical, small ? Tokens.Space.xxs : Tokens.Space.xs)
      .frame(minHeight: small ? nil : Self.minHeight)
      .background(selected ? tone.fill.opacity(Tokens.Opacity.wash) : Palette.surfaceSunken, in: shape)
      .overlay(shape.strokeBorder(outline, lineWidth: Tokens.Stroke.thin))
      .animation(Tokens.Motion.quick, value: selected)
      .animation(Tokens.Motion.quick, value: lit)
      .onHover { hovered = $0 }
    if small {
      face
    } else {
      face.touchTarget()
    }
  }
}

public extension View {
  /// The chip's face on a label that is not a chip button itself (a `Menu`'s label), or on data
  /// shown as a chip (`small`: a symbol's sources).
  func chipFace(selected: Bool, tone: Tone = .info, small: Bool = false) -> some View {
    modifier(ChipFace(selected: selected, tone: tone, small: small))
  }
}

/// A selectable chip: one of a few choices shown side by side (a position's tab, a range, an
/// interval). The `ChipFace` (which lights under the pointer), pressed.
public struct ChipButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var enabled
  let selected: Bool
  let tone: Tone

  public init(selected: Bool, tone: Tone = .info) {
    self.selected = selected
    self.tone = tone
  }

  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .modifier(ChipFace(selected: selected, tone: tone))
      .opacity(enabled ? 1 : Tokens.Opacity.faint)
      .scaleEffect(configuration.isPressed ? Tokens.Motion.pressScale : 1)
      .animation(Tokens.Motion.quick, value: configuration.isPressed)
      .accessibilityAddTraits(selected ? .isSelected : [])
  }
}

/// An on/off chip (a chart study, the trade marks), uppercase: on is the chosen `ChipFace`, off
/// the plain one, so an on/off chip looks like every other chip.
public struct ChipToggleStyle: ToggleStyle {
  public init() {}

  public func makeBody(configuration: Configuration) -> some View {
    Button {
      configuration.isOn.toggle()
    } label: {
      configuration.label.textCase(.uppercase)
    }
    .buttonStyle(ChipButtonStyle(selected: configuration.isOn))
  }
}

public extension ToggleStyle where Self == ChipToggleStyle {
  /// `.toggleStyle(.chip)`.
  static var chip: ChipToggleStyle { ChipToggleStyle() }
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

extension View {
  /// A command button in flight: a second click or tap does nothing, and VoiceOver reads the
  /// in-progress words as the button's name, updating as they change.
  @ViewBuilder func inFlightBehaviour(_ inFlight: Text?) -> some View {
    if let inFlight {
      self
        .allowsHitTesting(false)
        .accessibilityLabel(inFlight)
        .accessibilityAddTraits(.updatesFrequently)
    } else {
      self
    }
  }
}

/// A trailing chevron after a ghost button's title: "Open chart ›".
public struct Chevron: View {
  public init() {}

  public var body: some View {
    Image(systemName: Symbols.next)
      .font(Tokens.Typography.chevron)
      .accessibilityHidden(true)
  }
}
