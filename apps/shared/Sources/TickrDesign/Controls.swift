import SwiftUI

// The apps' own controls and labels: buttons, status pills, badges, metric chips, labeled rows,
// section headers and captions (docs/design-system.md, "Controls"). Screens use these instead of
// system-styled buttons and bare text, so every state and every action looks the same on the Mac
// and the phone. Text comes in from the app (its L10n entries or data); nothing here is a word.
// They are split by kind: ControlButtons, ControlStates, ControlValues, ControlGauges, Hint.

// MARK: - tone

/// The meaning a control or label carries, mapped to a colour role: a fill (dots, rails, washes,
/// borders) and a text colour that keeps 4.5:1 contrast on `surface`.
public enum Tone: Sendable, Hashable, CaseIterable {
  /// No particular meaning: stopped, not evaluated, plain facts.
  case neutral
  /// Live, running, the brand.
  case accent
  /// Gains, verified protection, healthy.
  case profit
  /// Losses, missing protection, alarm, destructive.
  case loss
  /// Paused, blocked, stale, environment.
  case warning
  /// Entries, orders, commands in flight, selection.
  case info
  /// Recorded days, observers, planned work.
  case highlight

  /// Strokes, dots, rails and washes.
  public var fill: Color {
    switch self {
    case .neutral: return Palette.textQuaternary
    case .accent: return Palette.accent
    case .profit: return Palette.profit
    case .loss: return Palette.loss
    case .warning: return Palette.warning
    case .info: return Palette.info
    case .highlight: return Palette.highlight
    }
  }

  /// Text and symbols drawn in this tone.
  public var text: Color {
    switch self {
    case .neutral: return Palette.textTertiary
    case .accent: return Palette.accentText
    case .profit: return Palette.profitText
    case .loss: return Palette.lossText
    case .warning: return Palette.warningText
    case .info: return Palette.infoText
    case .highlight: return Palette.highlightText
    }
  }

  /// The tone of a money result: profit above zero, loss below, neutral at zero.
  public static func result(_ value: Decimal) -> Tone {
    value > 0 ? .profit : value < 0 ? .loss : .neutral
  }
}

// MARK: - headings and captions

/// A section's heading: a short glowing tick in its tone, the uppercase label, an optional count
/// in a capsule, and a trailing accessory (a ghost button, a badge).
public struct SectionHeader<Trailing: View>: View {
  let title: Text
  let count: String?
  let tone: Tone
  let trailing: Trailing

  public init(_ title: LocalizedStringResource, count: String? = nil, @ViewBuilder trailing: () -> Trailing) {
    self.init(Text(title), count: count, tone: .accent, trailing: trailing)
  }

  public init(_ title: Text, count: String? = nil, tone: Tone = .accent, @ViewBuilder trailing: () -> Trailing) {
    self.title = title
    self.count = count
    self.tone = tone
    self.trailing = trailing()
  }

  public var body: some View {
    HStack(alignment: .center, spacing: Tokens.Space.s) {
      Capsule()
        .fill(tone.fill)
        .frame(width: Tokens.Stroke.bold + Tokens.Stroke.thin, height: Tokens.Typography.labelSize)
        .shadow(color: tone.fill.opacity(Tokens.Opacity.medium), radius: Tokens.Space.xs)
        .accessibilityHidden(true)
      title
        .textCase(.uppercase)
        .font(Tokens.Typography.label)
        .tracking(Tokens.Typography.labelTracking)
        .foregroundStyle(Palette.textLabel)
        .lineLimit(1)
        .accessibilityAddTraits(.isHeader)
      if let count {
        Text(verbatim: count)
          .font(Tokens.Typography.badge)
          .foregroundStyle(Palette.textTertiary)
          .padding(.horizontal, Tokens.Space.xs)
          .padding(.vertical, Tokens.Space.xxs)
          .background(Capsule().fill(Palette.surfaceSunken))
          .overlay(Capsule().strokeBorder(Palette.separatorStrong, lineWidth: Tokens.Stroke.thin))
          .contentTransition(.numericText())
          .fixedSize()
      }
      Spacer(minLength: Tokens.Space.s)
      trailing
    }
  }
}

public extension SectionHeader where Trailing == EmptyView {
  init(_ title: LocalizedStringResource, count: String? = nil, tone: Tone = .accent) {
    self.init(Text(title), count: count, tone: tone) { EmptyView() }
  }
}

/// A short note with a symbol in front: where a value comes from, why a control is off.
public struct InfoCaption: View {
  /// Symbol of a plain note.
  public static let infoSymbol = "info.circle"

  let text: Text
  let systemImage: String
  let tone: Tone

  public init(_ text: LocalizedStringResource, systemImage: String = InfoCaption.infoSymbol, tone: Tone = .neutral) {
    self.init(Text(text), systemImage: systemImage, tone: tone)
  }

  /// A note that is already localized (an error from the API client).
  public init(verbatim text: String, systemImage: String = InfoCaption.infoSymbol, tone: Tone = .neutral) {
    self.init(Text(verbatim: text), systemImage: systemImage, tone: tone)
  }

  public init(_ text: Text, systemImage: String = InfoCaption.infoSymbol, tone: Tone = .neutral) {
    self.text = text
    self.systemImage = systemImage
    self.tone = tone
  }

  public var body: some View {
    Label {
      text.foregroundStyle(tone == .neutral ? Palette.textQuaternary : tone.text)
    } icon: {
      Image(systemName: systemImage).foregroundStyle(tone == .neutral ? Palette.textQuaternary : tone.fill)
    }
    .labelStyle(ControlLabelStyle())
    .font(Tokens.Typography.caption)
  }
}

/// A standing warning above a screen's content: a symbol and a title in the tone, one line of
/// detail under it, on the tone's wash with its border. For a state that changes where the
/// operator's commands go (the demo day), so it is seen on every command surface.
public struct WarningBanner: View {
  let symbol: String
  let title: Text
  let detail: Text
  let tone: Tone
  @Environment(\.dynamicTypeSize) private var typeSize

  public init(_ title: LocalizedStringResource, detail: LocalizedStringResource, systemImage: String, tone: Tone = .warning) {
    self.symbol = systemImage
    self.title = Text(title)
    self.detail = Text(detail)
    self.tone = tone
  }

  public var body: some View {
    let shape = RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
    HStack(alignment: .top, spacing: Tokens.Space.m) {
      Image(systemName: symbol)
        .font(Tokens.Typography.symbol)
        .foregroundStyle(tone.fill)
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        title
          .font(Tokens.Typography.callout.weight(.semibold))
          .foregroundStyle(tone.text)
        // At accessibility text sizes the title alone says it: the detail took half the screen.
        if !typeSize.isAccessibilitySize {
          detail
            .font(Tokens.Typography.caption)
            .foregroundStyle(Palette.textSecondary)
        }
      }
      .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
    }
    .padding(Tokens.Space.m)
    .background(tone.fill.opacity(Tokens.Opacity.wash), in: shape)
    .overlay(shape.strokeBorder(tone.fill.opacity(Tokens.Opacity.border), lineWidth: Tokens.Stroke.thin))
    .accessibilityElement(children: .combine)
  }
}
