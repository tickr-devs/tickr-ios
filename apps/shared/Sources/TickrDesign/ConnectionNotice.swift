import SwiftUI

/// Fixed parts of `ConnectionNotice` (a generic type holds no stored constants).
public enum ConnectionNoticeLook {
  /// Symbol of a link that is down or not set up.
  public static let offlineSymbol = "wifi.exclamationmark"
  /// Symbol of the details' disclosure, and its turn when open, in degrees.
  static let chevronSymbol = "chevron.right"
  static let openDegrees: Double = 90
  /// Side of the amber glyph chip, in points (the mockup's 28 px chip).
  static let chipSide = Tokens.Size.iconButtonCompact
  /// Opacity of last known data under the banner: visibly not current (the mockup's 60%).
  public static let lastKnownOpacity = 0.6
  #if os(iOS)
  /// The title: semibold, the mockup's 15 px on the phone.
  static let title = Font.subheadline.weight(.semibold)
  #else
  /// The title: semibold, the mockup's 13 px on the Mac.
  static let title = Font.body.weight(.semibold)
  #endif
}

/// The apps' one way of saying the link to the bot is down or not set up (TickrKit
/// `ConnectionState`), as the mockup's calm connection banner: a neutral card with an amber glyph
/// chip, a short title, one mono line (last data, retry pace, commands off), a small Retry and a
/// Settings link; no red, no pulse. The technical detail (address, port, the API's own cause) is
/// only behind "Details". It never replaces a screen: `banner` stands above the screen's last
/// known data (drawn at `lastKnownOpacity`), `empty` fills the card area when there is no data.
public struct ConnectionNotice<Actions: View>: View {
  public enum Style: Sendable { case banner, empty }

  let style: Style
  let title: Text
  let subtitle: Text
  let detailsLabel: Text
  let details: [String]
  let actions: Actions
  @State private var showsDetails = false

  /// `details` are the technical lines shown under "Details"; none hides the disclosure.
  public init(
    _ style: Style, title: LocalizedStringResource, subtitle: LocalizedStringResource,
    detailsLabel: LocalizedStringResource, details: [String], @ViewBuilder actions: () -> Actions
  ) {
    self.style = style
    self.title = Text(title)
    self.subtitle = Text(subtitle)
    self.detailsLabel = Text(detailsLabel)
    self.details = details
    self.actions = actions()
  }

  public var body: some View {
    VStack(alignment: style == .banner ? .leading : .center, spacing: Tokens.Space.s) {
      switch style {
      case .banner:
        // Text and actions in one row; under each other when the row is too narrow.
        ViewThatFits(in: .horizontal) {
          HStack(spacing: Tokens.Space.m) {
            chip
            words
            Spacer(minLength: 0)
            buttons
          }
          VStack(alignment: .leading, spacing: Tokens.Space.s) {
            HStack(alignment: .top, spacing: Tokens.Space.m) {
              chip
              words
              Spacer(minLength: 0)
            }
            buttons
          }
        }
      case .empty:
        chip
        words.multilineTextAlignment(.center)
        buttons
      }
      disclosure
    }
    .frame(maxWidth: .infinity, alignment: style == .banner ? .leading : .center)
    .padding(style == .banner ? Tokens.Space.m : Tokens.Space.xl)
    .tickrCard(radius: Tokens.Radius.large)
  }

  /// The amber glyph chip.
  private var chip: some View {
    Image(systemName: ConnectionNoticeLook.offlineSymbol)
      .font(Tokens.Typography.symbolCompact)
      .foregroundStyle(Palette.warningText)
      .frame(width: ConnectionNoticeLook.chipSide, height: ConnectionNoticeLook.chipSide)
      .background(Palette.warning.opacity(Tokens.Opacity.glow),
        in: RoundedRectangle(cornerRadius: Tokens.Radius.small, style: .continuous))
      .accessibilityHidden(true)
  }

  private var words: some View {
    VStack(alignment: style == .banner ? .leading : .center, spacing: Tokens.Space.xxs) {
      title
        .font(ConnectionNoticeLook.title)
        .foregroundStyle(Palette.textPrimary)
      subtitle
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textTertiary)
    }
    .fixedSize(horizontal: false, vertical: true)
    .accessibilityElement(children: .combine)
  }

  private var buttons: some View {
    HStack(spacing: Tokens.Space.s) { actions }
      .fixedSize()
  }

  /// "Details" and, opened, the technical lines in mono, selectable.
  @ViewBuilder private var disclosure: some View {
    if !details.isEmpty {
      Button {
        withAnimation(Tokens.Motion.quick) { showsDetails.toggle() }
      } label: {
        HStack(spacing: Tokens.Space.xs) {
          Image(systemName: ConnectionNoticeLook.chevronSymbol)
            .font(Tokens.Typography.chevron)
            .rotationEffect(showsDetails ? .degrees(ConnectionNoticeLook.openDegrees) : .zero)
          detailsLabel
        }
        .font(Tokens.Typography.caption.weight(.semibold))
        .foregroundStyle(Palette.textQuaternary)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .padding(.leading, style == .banner ? ConnectionNoticeLook.chipSide + Tokens.Space.m : 0)
      .accessibilityAddTraits(showsDetails ? [.isSelected] : [])
      if showsDetails {
        VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
          ForEach(details, id: \.self) { line in
            Text(verbatim: line)
          }
        }
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(Palette.textTertiary)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
        .transition(.opacity)
      }
    }
  }
}

public extension View {
  /// Draws data that is the last known, not current, as the connection banner above it says.
  func lastKnown(_ isLastKnown: Bool) -> some View {
    opacity(isLastKnown ? ConnectionNoticeLook.lastKnownOpacity : 1)
  }
}
