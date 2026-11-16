import SwiftUI

// MARK: - states

/// A state in a capsule: a dot and a short uppercase word. For things that are true now: the bot
/// running, entries paused, a stop verified or missing. While `live`, the dot pulses once each time
/// `event` changes (a new status read); it never loops.
public struct StatusPill: View {
  let title: Text
  let tone: Tone
  let live: Bool
  let event: AnyHashable?
  let systemImage: String?

  public init(_ title: LocalizedStringResource, tone: Tone, live: Bool = false, event: AnyHashable? = nil) {
    self.init(Text(title), tone: tone, live: live, event: event)
  }

  /// A state with a symbol in place of the dot: an exit reason, a refusal.
  public init(verbatim title: String, systemImage: String, tone: Tone) {
    self.init(Text(verbatim: title), tone: tone, systemImage: systemImage)
  }

  public init(_ title: LocalizedStringResource, systemImage: String, tone: Tone) {
    self.init(Text(title), tone: tone, systemImage: systemImage)
  }

  /// A state word that is already localized, or data (an environment name).
  public init(verbatim title: String, tone: Tone, live: Bool = false, event: AnyHashable? = nil) {
    self.init(Text(verbatim: title), tone: tone, live: live, event: event)
  }

  public init(_ title: Text, tone: Tone, live: Bool = false, event: AnyHashable? = nil, systemImage: String? = nil) {
    self.title = title
    self.tone = tone
    self.live = live
    self.event = event
    self.systemImage = systemImage
  }

  public var body: some View {
    HStack(spacing: Tokens.Space.xs) {
      if let systemImage {
        // A live symbol pulses as the dot does: one ring per change of `event`.
        Image(systemName: systemImage).font(Tokens.Typography.badge).accessibilityHidden(true)
          .eventPulse(Circle(), color: tone.fill, scale: Tokens.Motion.pulseScale, event: live ? event : nil)
      } else {
        PulseDot(tone.fill, size: Tokens.Size.dotSmall, pulsing: live, event: event)
      }
      title
        .textCase(.uppercase)
        .font(Tokens.Typography.badge)
        .tracking(Tokens.Typography.badgeTracking)
        // At the largest text sizes a long state ("НЕ ЗАПУСКАЛСЯ") wraps inside the pill
        // instead of widening it past the screen; it is never cut or shrunk.
    }
    .foregroundStyle(tone.text)
    .padding(.horizontal, Tokens.Space.s)
    .padding(.vertical, Tokens.Space.xs)
    .background(Capsule().fill(tone.fill.opacity(Tokens.Opacity.wash)))
    .overlay(Capsule().strokeBorder(tone.fill.opacity(Tokens.Opacity.border), lineWidth: Tokens.Stroke.thin))
    .fixedSize(horizontal: false, vertical: true)
    .layoutPriority(1)
    .accessibilityElement(children: .combine)
    .animation(Tokens.Motion.quick, value: tone)
  }
}

/// A fact in a small tag: an exit reason, a verdict, a version's role, the trading gate, a day's
/// clean-day verdict; the environment is the `EnvironmentBadge`, drawn by this. The apps' one badge
/// (`.u-badge` of the boards' shared spec):
/// `badge` type (10.5 pt bold mono, uppercase, `badgeTracking`), `Radius.small` (6 pt) corners,
/// `Space.xs` × `Space.s` padding, its colour at `Opacity.badgeFill` inside and `Opacity.border` around,
/// the words in the colour's text role. Words only, never a symbol. `planned` draws it dashed
/// (BACKLOG); `dashed` gives the usual wash a dashed edge (the demo day).
public struct Badge: View {
  let text: Text
  let fill: Color
  let color: Color
  let planned: Bool
  /// A dashed edge on the usual wash (the demo day's `EnvironmentBadge`); `planned` drops the wash too.
  let dashed: Bool
  /// Badges are capitals; a value whose case means something (a version, "v1") keeps its own.
  var textCase: Text.Case? = .uppercase

  public init(_ title: LocalizedStringResource, tone: Tone, planned: Bool = false) {
    self.init(Text(title), fill: tone.fill, color: tone.text, planned: planned)
  }

  /// A badge whose text keeps its case: a version ("v1").
  public init(keepingCase title: LocalizedStringResource, tone: Tone) {
    self.init(Text(title), fill: tone.fill, color: tone.text, planned: false)
    textCase = nil
  }

  /// A badge showing data (a protocol value), not a sentence.
  public init(verbatim text: String, tone: Tone, planned: Bool = false) {
    self.init(Text(verbatim: text), fill: tone.fill, color: tone.text, planned: planned)
  }

  /// A badge in a text colour role (`Palette.warningText`), washed and outlined in the same colour.
  public init(_ title: LocalizedStringResource, color: Color) {
    self.init(Text(title), fill: color, color: color, planned: false)
  }

  /// Data in a text colour role; `keepingCase` keeps a version's own case ("v3", never "V3").
  public init(verbatim text: String, color: Color, keepingCase: Bool = false) {
    self.init(Text(verbatim: text), fill: color, color: color, planned: false)
    if keepingCase { textCase = nil }
  }

  init(_ text: Text, fill: Color, color: Color, planned: Bool, dashed: Bool = false) {
    self.text = text
    self.fill = fill
    self.color = color
    self.planned = planned
    self.dashed = dashed
  }

  public var body: some View {
    let shape = RoundedRectangle(cornerRadius: Tokens.Radius.small, style: .continuous)
    text
      .textCase(textCase)
      .tracking(Tokens.Typography.badgeTracking)
      .font(Tokens.Typography.badge)
      .padding(.horizontal, Tokens.Space.s)
      .padding(.vertical, Tokens.Space.xs)
      .foregroundStyle(color)
      .background(planned ? Color.clear : fill.opacity(Tokens.Opacity.badgeFill), in: shape)
      .overlay(shape.strokeBorder(fill.opacity(planned ? 1 : Tokens.Opacity.border),
        style: StrokeStyle(lineWidth: Tokens.Stroke.thin, dash: planned || dashed ? Tokens.Stroke.dashFine : [])))
      .fixedSize()
  }
}

/// A state drawn as a symbol on a tinted tile, no word on screen: a shield for a verified stop, a
/// pause for paused entries, a waveform for the quote stream. Its `label` is read by VoiceOver and
/// shown as the pointer's tooltip. While `live`, the outline pulses once each time `event` changes
/// (a new read that still finds the stop missing); it never loops.
public struct StateGlyph: View {
  let systemImage: String
  let tone: Tone
  let label: Text
  let live: Bool
  let event: AnyHashable?
  let style: Style

  /// A rounded tile, a circle (the bot's own state), or a small tile inside a row.
  public enum Style: Sendable, Hashable, CaseIterable {
    case tile, round, compact
  }

  public init(
    _ systemImage: String, tone: Tone, label: LocalizedStringResource, live: Bool = false, event: AnyHashable? = nil,
    style: Style = .tile
  ) {
    self.init(systemImage, tone: tone, label: Text(label), live: live, event: event, style: style)
  }

  public init(
    _ systemImage: String, tone: Tone, label: Text, live: Bool = false, event: AnyHashable? = nil, style: Style = .tile
  ) {
    self.systemImage = systemImage
    self.tone = tone
    self.label = label
    self.live = live
    self.event = event
    self.style = style
  }

  public var body: some View {
    let compact = style == .compact
    let side = compact ? Tokens.Size.glyphCompact : Tokens.Size.glyph
    let corner = style == .round ? side / 2 : compact ? Tokens.Radius.small : Tokens.Radius.medium
    let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
    Image(systemName: systemImage)
      .font(compact ? Tokens.Typography.caption.weight(.semibold) : Tokens.Typography.symbol)
      .foregroundStyle(tone.text)
      .frame(width: side, height: side)
      .background(tone.fill.opacity(Tokens.Opacity.glow), in: shape)
      .overlay(shape.strokeBorder(tone.fill.opacity(Tokens.Opacity.border), lineWidth: Tokens.Stroke.thin))
      .eventPulse(shape, color: tone.fill, scale: Tokens.Motion.glyphPulseScale, event: live ? event : nil)
      .animation(Tokens.Motion.quick, value: tone)
      .hint(label)
      .accessibilityElement()
      .accessibilityLabel(label)
  }
}
