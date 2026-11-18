import SwiftUI

/// A horizontal gauge: a track and a glowing fill up to `fraction` (0...1), with optional figures
/// under its start, middle and end ("129.80 · 132.46 · 134.10").
public struct MeterBar: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var drawn = false
  let fraction: Double
  let tone: Tone
  let marks: [MeterMark]

  public init(fraction: Double, tone: Tone, marks: [MeterMark] = []) {
    self.fraction = min(max(fraction, 0), 1)
    self.tone = tone
    self.marks = marks
  }

  public var body: some View {
    VStack(spacing: Tokens.Space.xs) {
      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Capsule().fill(Palette.surfaceSunken)
          Capsule().strokeBorder(Palette.separator, lineWidth: Tokens.Stroke.thin)
          Capsule()
            .fill(LinearGradient(colors: [tone.fill.opacity(Tokens.Opacity.medium), tone.fill],
              startPoint: .leading, endPoint: .trailing))
            .frame(width: proxy.size.width * (drawn ? fraction : 0))
            .shadow(color: tone.fill.opacity(Tokens.Opacity.border), radius: Tokens.Space.xs)
        }
      }
      .frame(height: Tokens.Size.bar)
      // Only the fill glides; the figures under it change at once (a cross-fade left a ghost of
      // the old last digit over the new one: owner report 2026-11-18, "38.73").
      .animation(reduceMotion ? nil : Tokens.Motion.fill, value: fraction)
      if !marks.isEmpty {
        HStack {
          ForEach(marks.indices, id: \.self) { index in
            if index > 0 { Spacer(minLength: Tokens.Space.xs) }
            Text(verbatim: marks[index].text)
              .font(Tokens.Typography.annotationBold)
              .foregroundStyle(marks[index].tone?.text ?? Palette.textQuaternary)
          }
        }
      }
    }
    .onAppear { withAnimation(reduceMotion ? nil : Tokens.Motion.fill) { drawn = true } }
  }
}

/// A figure under a `MeterBar`, coloured by an optional tone.
public struct MeterMark: Hashable, Sendable {
  public let text: String
  public let tone: Tone?

  public init(_ text: String, tone: Tone? = nil) {
    self.text = text
    self.tone = tone
  }
}

/// A small ring filled to `fraction` (0...1) with a short figure inside: room used, progress.
public struct MiniRing: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var drawn = false
  /// The ring's side: `Tokens.Size.miniRing`, scaled with Dynamic Type.
  @ScaledMetric(relativeTo: .caption) private var side = Tokens.Size.miniRing
  let fraction: Double
  let tone: Tone
  let text: String

  public init(fraction: Double, tone: Tone, text: String) {
    self.fraction = min(max(fraction, 0), 1)
    self.tone = tone
    self.text = text
  }

  public var body: some View {
    ZStack {
      Circle().stroke(Palette.separator, lineWidth: Tokens.Stroke.gauge)
      Circle()
        .trim(from: 0, to: drawn ? fraction : 0)
        .stroke(tone.fill, style: StrokeStyle(lineWidth: Tokens.Stroke.gauge, lineCap: .round))
        .rotationEffect(RingGeometry.startAngle)
        .shadow(color: tone.fill.opacity(Tokens.Opacity.border), radius: Tokens.Space.xs)
      Text(verbatim: text)
        .font(Tokens.Typography.annotationBold)
        .foregroundStyle(Palette.textPrimary)
        .fixedSize()
        .padding(Tokens.Stroke.gauge)
    }
    .padding(Tokens.Stroke.gauge / 2)
    // The ring grows with the text size, and never cuts its figure.
    .frame(minWidth: side, minHeight: side)
    .onAppear { withAnimation(reduceMotion ? nil : Tokens.Motion.fill) { drawn = true } }
  }
}
