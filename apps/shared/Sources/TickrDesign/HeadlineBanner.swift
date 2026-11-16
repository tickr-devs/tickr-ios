import SwiftUI

/// The status headline, the first line a person reads (Mac Overview, the Mac menu-bar panel, iOS
/// Home): a dot in the tone's fill that pulses once per new headline, the title in the tone's text
/// colour (`Typography.statusLine`) and an optional detail in `callout` `textTertiary`. `framed`
/// (the Main and MacMenuBar boards) sets it on the tone's wash with a hairline in the tone,
/// `Radius.medium`; IOSHome draws it bare. The tone comes from `Headline.tone` (or `.highlight`
/// for a recorded day), never from the screen.
public struct HeadlineBanner: View {
  let title: String
  let detail: String?
  let tone: Tone
  let pulse: AnyHashable?
  let framed: Bool

  /// `pulse`: what a new pulse marks (`Headline.pulse`); nil for a headline that never pulses (a
  /// recorded day, a past view).
  public init(_ title: String, detail: String? = nil, tone: Tone, pulse: AnyHashable? = nil, framed: Bool = true) {
    self.title = title
    self.detail = detail
    self.tone = tone
    self.pulse = pulse
    self.framed = framed
  }

  public var body: some View {
    let shape = RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
    HStack(spacing: Tokens.Space.s) {
      PulseDot(tone.fill, pulsing: pulse != nil, event: pulse)
      Text(verbatim: title)
        .font(Tokens.Typography.statusLine)
        .foregroundStyle(tone.text)
        .fixedSize(horizontal: false, vertical: true)
      if let detail {
        // Wraps to as many lines as it needs: a narrow window cut the cause of a block mid-sentence.
        Text(verbatim: detail)
          .font(Tokens.Typography.callout)
          .foregroundStyle(Palette.textTertiary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
    .padding(framed ? Tokens.Space.m : 0)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(framed ? tone.fill.opacity(Tokens.Opacity.wash) : .clear, in: shape)
    .overlay(shape.strokeBorder(framed ? tone.fill.opacity(Tokens.Opacity.border) : .clear, lineWidth: Tokens.Stroke.thin))
    // The colour follows the tone, so a change of severity animates even under the same words.
    .animation(Tokens.Motion.standard, value: tone)
    .accessibilityElement(children: .combine)
  }
}
