import SwiftUI

// The pieces of a symbol's row and detail on the Symbols screen and the Fast movers card (mockups
// v89, MacSymbols), drawn the same on both apps: a fast mover's figure, the stage track, the
// detail's headline, its disclosures and path steps. They take plain texts and colours; each app
// maps the API's rows onto them.

/// One figure of a fast mover ("vol 6.4×", "+2.1 ATR", "$vol 4.1×"). The criterion the row met
/// is amber, bold and lightly tinted with a thin amber border; an unmet one is quiet (mockup
/// v101). Wraps rather than being cut.
public struct MoverFigure: View {
  let text: String
  let fired: Bool

  public init(text: String, fired: Bool) {
    self.text = text
    self.fired = fired
  }

  public var body: some View {
    Text(verbatim: text)
      .font(Tokens.Typography.captionMono)
      .fontWeight(fired ? .bold : .regular)
      .foregroundStyle(fired ? Palette.warningText : Palette.textQuaternary)
      // On one line always: a narrow column broke "8.0×" into "8.0" over "×" (owner, 2026-11-18).
      .fixedSize()
      .padding(.horizontal, Tokens.Space.xs)
      .background(fired ? Palette.warning.opacity(Tokens.Opacity.wash) : .clear, in: Capsule())
      .overlay {
        if fired {
          Capsule().strokeBorder(Palette.warning.opacity(Tokens.Opacity.border), lineWidth: Tokens.Stroke.thin)
        }
      }
  }
}

/// How far a symbol got (mockup v101): one small segment per stage in `colors` (passed teal,
/// waiting blue, dropped neutral, not reached a hairline), then the furthest stage's name on the
/// same line. VoiceOver reads the name.
public struct StageTrack: View {
  let colors: [Color]
  let title: Text
  let titleColor: Color

  /// A segment's size and the gap between segments, in points (the design's 5×10, 1.5).
  static let segment = CGSize(width: 5, height: 10)
  static let gap: CGFloat = 1.5

  public init(colors: [Color], title: LocalizedStringResource, titleColor: Color = Palette.textSecondary) {
    self.colors = colors
    self.title = Text(title)
    self.titleColor = titleColor
  }

  public var body: some View {
    HStack(alignment: .center, spacing: Tokens.Space.s) {
      HStack(spacing: Self.gap) {
        ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
          RoundedRectangle(cornerRadius: Self.gap)
            .fill(color)
            .frame(width: Self.segment.width, height: Self.segment.height)
        }
      }
      title
        .font(Tokens.Typography.annotation)
        .foregroundStyle(titleColor)
        .fixedSize(horizontal: false, vertical: true)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(title)
  }
}

/// A tab drawn as text with an underline (mockup v101's funnel tabs): the name, then its count;
/// muted until selected, then the normal text colour with a blue underline and a blue count.
/// Put it in a `Button` with the plain style.
public struct UnderlineTab: View {
  let title: Text
  let count: String
  let selected: Bool
  let systemImage: String?

  /// Height of a tab on the Mac and on the iPhone, in points (the design's 34 and 44).
  public static let macHeight: CGFloat = 34
  public static let phoneHeight: CGFloat = 44

  public init(_ title: LocalizedStringResource, count: String, selected: Bool, systemImage: String? = nil) {
    self.title = Text(title)
    self.count = count
    self.selected = selected
    self.systemImage = systemImage
  }

  public var body: some View {
    HStack(spacing: Tokens.Space.xs) {
      if let systemImage {
        Image(systemName: systemImage).foregroundStyle(Palette.warningText)
      }
      title
        .fontWeight(.semibold)
        .foregroundStyle(selected ? Palette.textPrimary : Palette.textTertiary)
      Text(verbatim: count)
        .font(Tokens.Typography.annotationBold)
        .foregroundStyle(selected ? Palette.infoText : Palette.textQuaternary)
    }
    .padding(.horizontal, Tokens.Space.s)
    .frame(maxHeight: .infinity)
    .overlay(alignment: .bottom) {
      Rectangle().fill(selected ? Palette.info : .clear).frame(height: Tokens.Stroke.bold)
    }
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
  }
}

/// What happened to a symbol, in the detail's head (mockup MacSymbols): one word in its tone
/// ("Entered", "Skipped") and one caption under it. Both wrap, never cut.
public struct SymbolHeadline: View {
  let title: Text
  let caption: String
  let color: Color

  public init(_ title: LocalizedStringResource, caption: String, color: Color) {
    self.title = Text(title)
    self.caption = caption
    self.color = color
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
      title
        .font(Tokens.Typography.figure)
        .foregroundStyle(color)
        .accessibilityAddTraits(.isHeader)
      Text(verbatim: caption)
        .font(Tokens.Typography.caption)
        .foregroundStyle(Palette.textTertiary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

/// A section of a detail that opens in place (mockups MacSymbols, MacChart, "Steps today ▾"):
/// its label, a short summary on the right and a chevron that turns; the content shows under it
/// while open. A real button, the whole row its touch target; `id` names it for the UI tests.
public struct DetailDisclosure<Content: View>: View {
  let title: Text
  let summary: String?
  @Binding var isOpen: Bool
  let id: String?
  let content: Content

  public init(
    _ title: LocalizedStringResource, summary: String?, isOpen: Binding<Bool>, id: String? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.title = Text(title)
    self.summary = summary
    _isOpen = isOpen
    self.id = id
    self.content = content()
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      Button {
        withAnimation(Tokens.Motion.quick) { isOpen.toggle() }
      } label: {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
          title
            .textCase(.uppercase)
            .font(Tokens.Typography.label)
            .tracking(Tokens.Typography.labelTracking)
            .foregroundStyle(Palette.textQuaternary)
          Spacer(minLength: Tokens.Space.s)
          if let summary {
            Text(verbatim: summary)
              .font(Tokens.Typography.annotation)
              .foregroundStyle(Palette.textTertiary)
          }
          Image(systemName: Symbols.next)
            .font(Tokens.Typography.chevron)
            .foregroundStyle(Palette.textQuaternary)
            .rotationEffect(isOpen ? .degrees(DisclosureLook.openDegrees) : .zero)
        }
        .frame(minHeight: Tokens.Size.footerLink)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityAddTraits(isOpen ? .isSelected : [])
      .accessibilityIdentifier(id ?? "")
      if isOpen { content }
    }
  }
}

/// The look of `DetailDisclosure` (a generic type keeps no stored constants).
private enum DisclosureLook {
  /// How far the chevron turns when open, in degrees: from pointing on to pointing down.
  static let openDegrees: Double = 90
}

/// One stage of a symbol's path today in the detail (mockup v101): a small icon in the step's
/// colour, the stage's name and time, and under them what was measured or why it stopped. A
/// stage not reached is dimmed.
public struct SymbolPathStep: View {
  let systemImage: String
  let color: Color
  let title: Text
  let time: String
  let detail: String?
  let detailColor: Color
  let reached: Bool

  /// Size of the step's icon, in points (the design's 16).
  static let icon: CGFloat = 16

  public init(
    systemImage: String, color: Color, title: LocalizedStringResource, time: String, detail: String?,
    detailColor: Color, reached: Bool
  ) {
    self.systemImage = systemImage
    self.color = color
    self.title = Text(title)
    self.time = time
    self.detail = detail
    self.detailColor = detailColor
    self.reached = reached
  }

  public var body: some View {
    let shape = RoundedRectangle(cornerRadius: Tokens.Radius.small)
    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
      Image(systemName: systemImage)
        .font(Tokens.Typography.chevron)
        .foregroundStyle(color)
        .frame(width: Self.icon, height: Self.icon)
        .background(color.opacity(Tokens.Opacity.wash), in: shape)
        .overlay { shape.strokeBorder(color.opacity(Tokens.Opacity.border), lineWidth: Tokens.Stroke.thin) }
        .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] }
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        HStack(alignment: .firstTextBaseline) {
          title
            .font(Tokens.Typography.caption)
            .fontWeight(.semibold)
            .foregroundStyle(Palette.textPrimary)
          Spacer(minLength: Tokens.Space.s)
          Text(verbatim: time)
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textQuaternary)
        }
        if let detail {
          Text(verbatim: detail)
            .font(Tokens.Typography.annotation)
            .foregroundStyle(detailColor)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .padding(.vertical, Tokens.Space.xs)
    .opacity(reached ? 1 : Tokens.Opacity.muted)
    .accessibilityElement(children: .combine)
  }
}

/// A ticker ("BILL"), the same everywhere on both apps: always on one line at its full width, never
/// wrapped ("BIL / L") or cut, however narrow its row; the row's other parts give way instead. The
/// caller sets its font and colour.
public struct SymbolText: View {
  let symbol: String

  public init(_ symbol: String) {
    self.symbol = symbol
  }

  public var body: some View {
    Text(verbatim: symbol)
      .fixedSize()
      .layoutPriority(1)
  }
}
