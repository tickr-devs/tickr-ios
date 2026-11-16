import SwiftUI

// The pieces of a symbol's row on the Symbols screen and the Fast movers card (mockup v89), drawn
// the same on both apps: a fast mover's figure, the screener chips and the stage track. They take
// plain texts and colours; each app maps the API's rows onto them.

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
      .fixedSize(horizontal: false, vertical: true)
      .padding(.horizontal, Tokens.Space.xs)
      .background(fired ? Palette.warning.opacity(Tokens.Opacity.wash) : .clear, in: Capsule())
      .overlay {
        if fired {
          Capsule().strokeBorder(Palette.warning.opacity(Tokens.Opacity.border), lineWidth: Tokens.Stroke.thin)
        }
      }
  }
}

/// A symbol's screeners as small chips ("Gainers #3 +18.2%"): each chip's words, then an optional
/// change in its own colour.
public struct SourceChips: View {
  /// One chip: the screener and rank, and the symbol's change with its colour (on one chip only).
  public struct Item: Hashable {
    public let text: String
    public let change: String?
    public let changeColor: Color

    public init(text: String, change: String? = nil, changeColor: Color = Palette.textSecondary) {
      self.text = text
      self.change = change
      self.changeColor = changeColor
    }
  }

  let items: [Item]

  public init(_ items: [Item]) {
    self.items = items
  }

  public var body: some View {
    let shape = RoundedRectangle(cornerRadius: Tokens.Radius.small)
    ChipFlow(spacing: Tokens.Space.xs) {
      ForEach(Array(items.enumerated()), id: \.offset) { _, item in
        HStack(spacing: Tokens.Space.xs) {
          Text(verbatim: item.text)
          if let change = item.change {
            Text(verbatim: change).foregroundStyle(item.changeColor)
          }
        }
        .font(Tokens.Typography.annotationBold)
        .foregroundStyle(Palette.textSecondary)
        .padding(.horizontal, Tokens.Space.xs)
        .padding(.vertical, Tokens.Space.xxs)
        .background(Palette.chipFill, in: shape)
        .overlay { shape.strokeBorder(Palette.separatorStrong, lineWidth: Tokens.Stroke.thin) }
      }
    }
  }
}

/// How far a symbol got (mockup v101): one small segment per stage in `colors` (passed teal,
/// waiting blue, dropped pink, not reached a hairline), then the furthest stage's name on the
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

/// One fast mover figure in the symbol detail (mockup v101): the name, the value, and whether it
/// met its threshold ("met ≥ 5.0×" or "< 5.0×"). A met one is amber on a light amber wash.
public struct MoverStat: View {
  let title: Text
  let value: String
  let note: String
  let met: Bool

  public init(_ title: LocalizedStringResource, value: String, note: String, met: Bool) {
    self.title = Text(title)
    self.value = value
    self.note = note
    self.met = met
  }

  public var body: some View {
    let shape = RoundedRectangle(cornerRadius: Tokens.Radius.chip)
    VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
      title
        .textCase(.uppercase)
        .font(Tokens.Typography.label)
        .foregroundStyle(Palette.textQuaternary)
      Text(verbatim: value)
        .font(Tokens.Typography.figure)
        .foregroundStyle(met ? Palette.warningText : Palette.textQuaternary)
      Text(verbatim: note)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(Tokens.Space.s)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(met ? Palette.warning.opacity(Tokens.Opacity.wash) : Palette.surfaceSunken, in: shape)
    .overlay {
      shape.strokeBorder(met ? Palette.warning.opacity(Tokens.Opacity.border) : Palette.separator,
        lineWidth: Tokens.Stroke.thin)
    }
    .accessibilityElement(children: .combine)
  }
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
