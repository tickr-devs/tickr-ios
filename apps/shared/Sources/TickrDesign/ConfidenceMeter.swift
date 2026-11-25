import SwiftUI
import TickrKit

/// What a `ConfidenceMeter` shows, worked out from the entry model's numbers: the confidence and
/// cutoff within 0...1, which side of the cutoff it is on, its tone and its texts.
public struct ConfidenceReading: Equatable, Sendable {
  /// The confidence within 0...1; nil when the model gave no finite number (shown as "—").
  public let confidence: Double?
  /// The model's cutoff within 0...1; nil when there is none (or it is not a finite number).
  public let cutoff: Double?

  /// - Parameters:
  ///   - confidence: the entry model's score, 0...1 (outside it is drawn at the nearest end).
  ///   - cutoff: the score the model needs to enter, 0...1, or nil.
  public init(confidence: Double, cutoff: Double?) {
    self.confidence = Self.clamped(confidence)
    self.cutoff = cutoff.flatMap(Self.clamped)
  }

  /// A finite fraction within 0...1; nil for NaN or infinity.
  static func clamped(_ value: Double) -> Double? {
    value.isFinite ? min(max(value, 0), 1) : nil
  }

  /// Whether the confidence reached the cutoff (at or above it); nil without both numbers.
  public var reached: Bool? {
    guard let confidence, let cutoff else { return nil }
    return confidence >= cutoff
  }

  /// Reached the accent (as an ENTER verdict), below it info (as WATCH: closest to entry),
  /// neutral when there is nothing to compare.
  public var tone: Tone {
    switch reached {
    case true?: return .accent
    case false?: return .info
    case nil: return .neutral
    }
  }

  /// "74%", or the missing dash.
  public var confidenceText: String { confidence.map(Self.percent) ?? Money.missing }
  /// "70%", or nil without a cutoff.
  public var cutoffText: String? { cutoff.map(Self.percent) }

  /// What VoiceOver reads as the meter's value: "74%, cutoff 70%", or "74%" without a cutoff.
  public var spokenValue: String {
    guard let cutoffText else { return confidenceText }
    return String(localized: ModelText.confidence(confidenceText, cutoff: cutoffText))
  }

  /// A fraction in whole percents, rounded down: the shown confidence and cutoff keep the order
  /// of the model's numbers, so a 69.9% never reads "70%" beside a 70% cutoff.
  static func percent(_ fraction: Double) -> String {
    var points = Money.decimal(fraction) * Percent.pointsPerWhole
    var down = Decimal()
    NSDecimalRound(&down, &points, StatDigits.percent, .down)
    return Percent.plain(points: down)
  }
}

/// The entry model's confidence (docs/design-system.md): a horizontal bar filled to the
/// confidence with a tick at the model's cutoff, and the percent beside it. Accent once the
/// cutoff is reached, info below it; the same on both apps. Pure values in, no model types.
public struct ConfidenceMeter: View {
  let reading: ConfidenceReading

  /// - Parameters:
  ///   - confidence: the entry model's score, 0...1.
  ///   - cutoff: the score the model needs to enter, 0...1, or nil.
  public init(confidence: Double, cutoff: Double?) {
    reading = ConfidenceReading(confidence: confidence, cutoff: cutoff)
  }

  public var body: some View {
    HStack(spacing: Tokens.Space.s) {
      bar
      Text(verbatim: reading.confidenceText)
        .font(Tokens.Typography.calloutMono)
        .fontWeight(.bold)
        .foregroundStyle(reading.tone.text)
        .fixedSize()
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(ModelText.confidence))
    .accessibilityValue(Text(verbatim: reading.spokenValue))
  }

  /// The track, the fill and the cutoff tick.
  var bar: some View {
    let fill = reading.tone.fill
    return GeometryReader { proxy in
      let width = proxy.size.width
      ZStack(alignment: .leading) {
        Capsule()
          .fill(fill.opacity(Tokens.Model.trackOpacity))
          .frame(height: Tokens.Model.barHeight)
        Capsule()
          .fill(fill)
          .frame(width: width * (reading.confidence ?? 0), height: Tokens.Model.barHeight)
        if let cutoff = reading.cutoff {
          Capsule()
            .fill(Palette.textPrimary)
            .frame(width: Tokens.Model.tickWidth, height: Tokens.Model.tickHeight)
            .offset(x: min(max(width * cutoff - Tokens.Model.tickWidth / 2, 0), width - Tokens.Model.tickWidth))
        }
      }
      .frame(width: width, height: proxy.size.height)
    }
    .frame(minWidth: Tokens.Model.barMinWidth)
    .frame(height: Tokens.Model.tickHeight)
  }
}

/// Example numbers of the previews.
private enum PreviewValues {
  /// A confidence that reached the cutoff, one below it, and the cutoff.
  static let reached = 0.74
  static let below = 0.64
  static let cutoff = 0.70
}

#Preview {
  VStack(alignment: .leading, spacing: Tokens.Space.m) {
    ConfidenceMeter(confidence: PreviewValues.reached, cutoff: PreviewValues.cutoff)
    ConfidenceMeter(confidence: PreviewValues.below, cutoff: PreviewValues.cutoff)
    ConfidenceMeter(confidence: PreviewValues.below, cutoff: nil)
    ConfidenceMeter(confidence: .nan, cutoff: PreviewValues.cutoff)
  }
  .padding()
  .background(Palette.surface)
}
