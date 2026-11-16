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

/// How far a symbol got: one dot per stage in `colors` (each stage's colour up to the furthest,
/// red where it was dropped, a hairline colour beyond), then the furthest stage's name. VoiceOver
/// reads the name.
public struct StageTrack: View {
  let colors: [Color]
  let title: Text

  public init(colors: [Color], title: LocalizedStringResource) {
    self.colors = colors
    self.title = Text(title)
  }

  public var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
      HStack(spacing: Tokens.Space.xxs) {
        ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
          Circle()
            .fill(color)
            .frame(width: Tokens.Size.flowMark, height: Tokens.Size.flowMark)
        }
      }
      title
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textTertiary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(title)
  }
}
