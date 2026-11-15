import SwiftUI

// MARK: - values

/// A figure with its label on a sunken chip, a coloured rail on its leading edge naming what it is
/// (entry, stop, result). Used in rows of two to four.
public struct MetricChip<Value: View>: View {
  let label: Text
  let tone: Tone?
  let value: Value

  public init(_ label: LocalizedStringResource, tone: Tone? = nil, @ViewBuilder value: () -> Value) {
    self.label = Text(label)
    self.tone = tone
    self.value = value()
  }

  public var body: some View {
    let shape = RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
    VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
      label
        .textCase(.uppercase)
        .font(Tokens.Typography.label)
        .tracking(Tokens.Typography.labelTracking)
        .foregroundStyle(Palette.textQuaternary)
        .lineLimit(1)
      value
        .font(Tokens.Typography.chipValue)
        .foregroundStyle(Palette.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(Tokens.Shrink.standard)
        .contentTransition(.numericText())
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.leading, Tokens.Space.m)
    .padding(.trailing, Tokens.Space.s)
    .padding(.vertical, Tokens.Space.s)
    .background(Palette.surfaceSunken, in: shape)
    .overlay(shape.strokeBorder(Palette.separator, lineWidth: Tokens.Stroke.thin))
    .overlay(alignment: .leading) {
      Capsule()
        .fill(tone?.fill ?? Palette.separatorStrong)
        .frame(width: Tokens.Stroke.bold)
        .padding(.vertical, Tokens.Space.s)
        .padding(.leading, Tokens.Space.xxs)
    }
    .accessibilityElement(children: .combine)
  }
}

public extension MetricChip where Value == MetricValue {
  /// A chip whose value is data ("131.42") with an optional unit ("USD") in a quieter type.
  init(_ label: LocalizedStringResource, value: String, unit: String? = nil, tone: Tone? = nil, color: Color? = nil) {
    self.init(label, tone: tone) { MetricValue(value: value, unit: unit, color: color ?? Palette.textPrimary) }
  }
}

/// The value of a `MetricChip`: digits, then a unit in a smaller, quieter type.
public struct MetricValue: View {
  let value: String
  let unit: String?
  let color: Color

  public var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.xs) {
      Text(verbatim: value).foregroundStyle(color)
      if let unit {
        Text(verbatim: unit)
          .font(Tokens.Typography.captionMono)
          .foregroundStyle(Palette.textQuaternary)
      }
    }
  }
}

/// "◷ Label ........ value" on one line: an optional SF Symbol, the label, then the value at the
/// trailing edge in mono. The value may be any view (a pill, a money figure).
public struct ValueRow<Value: View>: View {
  let label: Text
  let systemImage: String?
  let value: Value

  public init(_ label: LocalizedStringResource, systemImage: String? = nil, @ViewBuilder value: () -> Value) {
    self.init(Text(label), systemImage: systemImage, value: value)
  }

  public init(_ label: Text, systemImage: String? = nil, @ViewBuilder value: () -> Value) {
    self.label = label
    self.systemImage = systemImage
    self.value = value()
  }

  public var body: some View {
    HStack(spacing: Tokens.Space.s) {
      if let systemImage {
        Image(systemName: systemImage)
          .font(Tokens.Typography.caption)
          .foregroundStyle(Palette.textQuaternary)
          .frame(width: Tokens.Size.rowSymbol)
          .accessibilityHidden(true)
      }
      label
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textTertiary)
      Spacer(minLength: Tokens.Space.m)
      value
        .font(Tokens.Typography.bodyMono)
        .foregroundStyle(Palette.textPrimary)
        .contentTransition(.numericText())
    }
    .accessibilityElement(children: .combine)
  }
}

public extension ValueRow where Value == Text {
  /// A row whose value is data or an already localized word.
  init(_ label: LocalizedStringResource, systemImage: String? = nil, value: String, color: Color? = nil) {
    self.init(label, systemImage: systemImage) { Text(verbatim: value).foregroundStyle(color ?? Palette.textPrimary) }
  }
}

/// A figure with a symbol in front instead of a label: "→| 131.42", "⛨ 129.80". The label is the
/// tooltip and what VoiceOver reads. `compact` draws it as a small chip that fits its content, for
/// a row of figures under a list item.
public struct IconMetric: View {
  let systemImage: String
  let label: Text
  let value: String
  let tone: Tone?
  let color: Color
  let compact: Bool

  public init(
    _ systemImage: String, label: LocalizedStringResource, value: String, tone: Tone? = nil, color: Color? = nil,
    compact: Bool = false
  ) {
    self.systemImage = systemImage
    self.label = Text(label)
    self.value = value
    self.tone = tone
    self.color = color ?? Palette.textPrimary
    self.compact = compact
  }

  public var body: some View {
    let shape = RoundedRectangle(cornerRadius: compact ? Tokens.Radius.small : Tokens.Radius.medium, style: .continuous)
    HStack(spacing: compact ? Tokens.Space.xs : Tokens.Space.s) {
      Image(systemName: systemImage)
        .font((compact ? Tokens.Typography.annotation : Tokens.Typography.caption).weight(.semibold))
        .foregroundStyle(tone?.fill ?? Palette.textQuaternary)
        .accessibilityHidden(true)
      Text(verbatim: value)
        .font(compact ? Tokens.Typography.captionMono : Tokens.Typography.chipValue)
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(Tokens.Shrink.standard)
        .contentTransition(.numericText())
    }
    .frame(maxWidth: compact ? nil : .infinity, alignment: .leading)
    .padding(.horizontal, compact ? Tokens.Space.xs + Tokens.Space.xxs : Tokens.Space.s)
    .padding(.vertical, compact ? Tokens.Space.xxs : Tokens.Space.s)
    .background(Palette.surfaceSunken, in: shape)
    .overlay(shape.strokeBorder(Palette.separator, lineWidth: Tokens.Stroke.thin))
    .hint(label)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label)
    .accessibilityValue(Text(verbatim: value))
  }
}

/// A money change with its direction: a small triangle and the signed figure on a washed tag,
/// green up, red down.
public struct DeltaTag: View {
  /// Symbols of a rise and a fall.
  static let upSymbol = "arrowtriangle.up.fill"
  static let downSymbol = "arrowtriangle.down.fill"

  let value: Decimal
  let text: String
  let large: Bool

  /// `text` is the formatted figure ("+42.10"); `value` decides the colour and the arrow.
  public init(_ value: Decimal, text: String, large: Bool = false) {
    self.value = value
    self.text = text
    self.large = large
  }

  public var body: some View {
    let tone = Tone.result(value)
    HStack(spacing: Tokens.Space.xs) {
      if value != 0 {
        Image(systemName: value > 0 ? Self.upSymbol : Self.downSymbol)
          .font(Tokens.Typography.chevron)
          .accessibilityHidden(true)
      }
      Text(verbatim: text)
        .font(large ? Tokens.Typography.chipValue : Tokens.Typography.chip)
        .contentTransition(.numericText(value: NSDecimalNumber(decimal: value).doubleValue))
    }
    .foregroundStyle(tone.text)
    .padding(.horizontal, Tokens.Space.s)
    .padding(.vertical, Tokens.Space.xs)
    .background(tone.fill.opacity(Tokens.Opacity.glow), in: RoundedRectangle(cornerRadius: Tokens.Radius.small))
    .fixedSize()
    .animation(Tokens.Motion.quick, value: value)
  }
}
