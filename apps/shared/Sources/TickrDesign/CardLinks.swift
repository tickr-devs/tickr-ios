import SwiftUI

/// The two ways a card leads somewhere else, as on the Controls board: a light-blue capsule in
/// the card's header (`HeaderLink`: Details, Lab, Open chart, Review) and a full-width row along
/// the card's bottom edge (`CardFooterLink`: Show all). Both end only in the disclosure chevron
/// (owner: chevron only, no arrow).

/// A card header's link: a capsule in its tone (`info`; `highlight` in the advisor's box) holding an
/// optional leading symbol, the title and the chevron. `Size.headerLink` tall; on iOS its touch
/// target is at least `Size.touchTarget`. The title wraps rather than being cut. A link that
/// pushes a screen is a `NavigationLink` with a `HeaderLinkLabel`, styled `.headerLink()`.
public struct HeaderLink: View {
  let label: HeaderLinkLabel
  let tone: Tone
  let action: () -> Void

  public init(
    _ title: LocalizedStringResource, systemImage: String? = nil, tone: Tone = .info, action: @escaping () -> Void
  ) {
    self.label = HeaderLinkLabel(title, systemImage: systemImage)
    self.tone = tone
    self.action = action
  }

  public var body: some View {
    Button(action: action) { label }
      .buttonStyle(.headerLink(tone))
  }
}

/// What a header link says: the optional symbol, the title (wrapping, never cut) and the chevron,
/// in `Typography.link`. The face of a `HeaderLink`, or of a `NavigationLink` styled `.headerLink()`.
public struct HeaderLinkLabel: View {
  let title: Text
  let systemImage: String?

  public init(_ title: LocalizedStringResource, systemImage: String? = nil) {
    self.title = Text(title)
    self.systemImage = systemImage
  }

  public var body: some View {
    HStack(spacing: Tokens.Space.xs) {
      if let systemImage {
        Image(systemName: systemImage).accessibilityHidden(true)
      }
      title
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
      Chevron()
    }
    .font(Tokens.Typography.link)
  }
}

/// The look of a header link: the tinted capsule, darker under the pointer, pressed in while held.
public struct HeaderLinkStyle: ButtonStyle {
  let tone: Tone
  @State private var hovered = false

  public init(_ tone: Tone = .info) {
    self.tone = tone
  }

  public func makeBody(configuration: Configuration) -> some View {
    let shape = Capsule()
    configuration.label
      .foregroundStyle(tone.text)
      .padding(.leading, Tokens.Space.s + Tokens.Space.xxs)
      .padding(.trailing, Tokens.Space.s)
      .padding(.vertical, Tokens.Space.xxs)
      .frame(minHeight: Tokens.Size.headerLink)
      .background(tone.fill.opacity(hovered ? Tokens.Opacity.linkHover : Tokens.Opacity.wash), in: shape)
      .overlay(shape.strokeBorder(tone.fill.opacity(Tokens.Opacity.linkOutline), lineWidth: Tokens.Stroke.thin))
      .touchTarget()
      .scaleEffect(configuration.isPressed ? Tokens.Motion.pressScale : 1)
      .onHover { hovered = $0 }
      .animation(Tokens.Motion.quick, value: hovered)
      .animation(Tokens.Motion.quick, value: configuration.isPressed)
  }
}

public extension ButtonStyle where Self == HeaderLinkStyle {
  /// `.buttonStyle(.headerLink())`: a header link's capsule (`HeaderLink`), for a `NavigationLink`.
  static func headerLink(_ tone: Tone = .info) -> HeaderLinkStyle {
    HeaderLinkStyle(tone)
  }
}

/// A card's footer link ("Show all"): the last row of the card, across its whole width under a
/// hairline: the title and a count capsule on the left, an optional hint ("closest 3 of 7") and a
/// round chevron chip on the right. The whole row is one button, `Size.footerLink` tall (on iOS
/// the touch target, `Size.touchTarget`); VoiceOver reads its title, count and hint as one. Under
/// the pointer the row tints and the chip moves on a little. Place it last in a card padded by
/// `Space.l` (every card is): it reaches the card's edges.
public struct CardFooterLink: View {
  let title: Text
  let count: Int?
  let hint: Text?
  let action: () -> Void

  public init(
    _ title: LocalizedStringResource, count: Int? = nil, hint: LocalizedStringResource? = nil,
    action: @escaping () -> Void
  ) {
    self.title = Text(title)
    self.count = count
    self.hint = hint.map { Text($0) }
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      HStack(spacing: Tokens.Space.s) {
        title
          .font(Tokens.Typography.footerLink)
          .foregroundStyle(Palette.textPrimary)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
        if let count {
          Text(count, format: .number)
            .font(Tokens.Typography.annotationBold)
            .foregroundStyle(Palette.textTertiary)
            .padding(.horizontal, Tokens.Space.s - Tokens.Space.xxs / 2)
            .padding(.vertical, Tokens.Space.xxs)
            .background(Palette.surfaceSunken, in: Capsule())
            .overlay(Capsule().strokeBorder(Palette.separator, lineWidth: Tokens.Stroke.thin))
            .fixedSize()
        }
        Spacer(minLength: Tokens.Space.s)
        if let hint {
          hint
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textQuaternary)
            .multilineTextAlignment(.trailing)
            .fixedSize(horizontal: false, vertical: true)
        }
        FooterChevronChip()
      }
    }
    .buttonStyle(CardFooterLinkStyle())
  }

  /// The row's least height on this platform (`Size.footerLink`).
  public static var rowHeight: CGFloat { Tokens.Size.footerLink }
}

/// The round chip at the end of a footer link, holding the chevron in `infoText`.
struct FooterChevronChip: View {
  @Environment(\.footerLinkHovered) private var hovered

  var body: some View {
    Chevron()
      .foregroundStyle(Palette.infoText)
      .frame(width: Tokens.Size.footerChip, height: Tokens.Size.footerChip)
      .background(Palette.info.opacity(Tokens.Opacity.tint), in: Circle())
      .offset(x: hovered ? Tokens.Motion.linkNudge : 0)
  }
}

extension EnvironmentValues {
  /// Whether the pointer is over the footer link around this view (`CardFooterLinkStyle`).
  @Entry var footerLinkHovered = false
  /// A footer link in the middle of a card (a capped list above another section, `CappedList`):
  /// it reaches the card's sides but not its bottom edge.
  @Entry var footerLinkInline = false
}

/// The look of `CardFooterLink`: the row reaching the card's edges under a hairline, tinted under
/// the pointer, pressed in a little while held.
struct CardFooterLinkStyle: ButtonStyle {
  #if os(iOS)
  /// The card's corner radius, which the tint follows along the bottom edge (iOS cards).
  static let cardRadius = Tokens.Radius.card
  #else
  /// The card's corner radius, which the tint follows along the bottom edge (Mac cards).
  static let cardRadius = Tokens.Radius.large
  #endif
  @State private var hovered = false
  @Environment(\.footerLinkInline) private var inline

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .environment(\.footerLinkHovered, hovered)
      .padding(.leading, Tokens.Space.l)
      .padding(.trailing, Tokens.Space.m)
      .padding(.vertical, Tokens.Space.xs)
      .frame(maxWidth: .infinity, minHeight: Tokens.Size.footerLink, alignment: .leading)
      .background(
        Palette.info.opacity(hovered ? Tokens.Opacity.rowHover : 0),
        in: UnevenRoundedRectangle(bottomLeadingRadius: inline ? 0 : Self.cardRadius,
          bottomTrailingRadius: inline ? 0 : Self.cardRadius))
      .overlay(alignment: .top) {
        Rectangle().fill(Palette.separator).frame(height: Tokens.Stroke.thin)
      }
      .contentShape(Rectangle())
      // The card's padding: the row reaches its edges, as on the board.
      .padding(.horizontal, -Tokens.Space.l)
      .padding(.bottom, inline ? 0 : -Tokens.Space.l)
      .scaleEffect(configuration.isPressed ? Tokens.Motion.rowPressScale : 1)
      .onHover { hovered = $0 }
      .animation(Tokens.Motion.quick, value: hovered)
      .animation(Tokens.Motion.quick, value: configuration.isPressed)
  }
}
