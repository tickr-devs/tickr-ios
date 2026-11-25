import SwiftUI
import TickrKit

/// One reason behind an entry model's decision: whether it raised or lowered the confidence, and
/// its text, already localized by the caller.
public struct SignedReason: Sendable {
  /// Which way a reason pushed the confidence.
  public enum Sign: Sendable, CaseIterable {
    /// It raised the confidence.
    case helps
    /// It lowered the confidence.
    case hurts

    /// A reason that helps: a plus in a circle.
    public static let helpsSymbol = "plus.circle.fill"
    /// A reason that hurts: a minus in a circle.
    public static let hurtsSymbol = "minus.circle.fill"

    /// The sign's symbol: its shape says the sign, never the colour alone.
    public var symbol: String {
      switch self {
      case .helps: return Self.helpsSymbol
      case .hurts: return Self.hurtsSymbol
      }
    }

    /// Helps in profit green, hurts in the series pink (a loss that is not a danger).
    public var tone: Tone {
      switch self {
      case .helps: return .profit
      case .hurts: return .series
      }
    }

    /// The sign's name for VoiceOver ("Helps", "Hurts").
    public var label: LocalizedStringResource {
      switch self {
      case .helps: return ModelText.helps
      case .hurts: return ModelText.hurts
      }
    }
  }

  /// A reason's text: a catalog entry or text the caller already localized.
  enum Words: Sendable {
    case resource(LocalizedStringResource)
    case verbatim(String)
  }

  public let sign: Sign
  let words: Words

  /// A reason whose text is a String Catalog entry.
  public init(_ sign: Sign, _ text: LocalizedStringResource) {
    self.sign = sign
    words = .resource(text)
  }

  /// A reason whose text was localized elsewhere (the bot's prose, say).
  public init(_ sign: Sign, verbatim text: String) {
    self.sign = sign
    words = .verbatim(text)
  }

  /// The reason's text as a view's text.
  var text: Text {
    switch words {
    case .resource(let resource): return Text(resource)
    case .verbatim(let string): return Text(verbatim: string)
    }
  }
}

/// The top reasons behind an entry model's decision, strongest first as given: each row a sign
/// (plus or minus symbol in its tone) and the reason's text, wrapped, never cut. At most `limit`
/// rows; the caller passes the model's top reasons.
public struct SignedReasonList: View {
  let reasons: [SignedReason]

  /// - Parameters:
  ///   - reasons: the reasons, strongest first.
  ///   - limit: most rows drawn (`Tokens.Model.reasonRows` by default).
  public init(_ reasons: [SignedReason], limit: Int = Tokens.Model.reasonRows) {
    self.reasons = Self.shown(reasons, limit: limit)
  }

  /// The first `limit` reasons (none for a limit below one).
  static func shown(_ reasons: [SignedReason], limit: Int) -> [SignedReason] {
    Array(reasons.prefix(max(limit, 0)))
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      ForEach(reasons.indices, id: \.self) { index in
        row(reasons[index])
      }
    }
  }

  /// One reason: its sign, then its text.
  func row(_ reason: SignedReason) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
      Image(systemName: reason.sign.symbol)
        .font(Tokens.Typography.caption)
        .foregroundStyle(reason.sign.tone.text)
        .accessibilityLabel(Text(reason.sign.label))
      reason.text
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityElement(children: .combine)
  }
}

#Preview {
  SignedReasonList([
    SignedReason(.helps, ModelText.Sample.volume),
    SignedReason(.helps, ModelText.Sample.early),
    SignedReason(.hurts, ModelText.Sample.aboveVWAP),
  ])
  .padding()
  .background(Palette.surface)
}
