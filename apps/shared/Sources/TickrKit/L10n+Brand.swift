import Foundation

extension L10n {
  /// The wordmark's letters after the mark's "t" (the brand, the same in every language).
  static var wordmarkRest: LocalizedStringResource {
    LocalizedStringResource("kit.brand.wordmarkRest", defaultValue: "ickr", bundle: bundle)
  }
  /// The wordmark as VoiceOver reads it.
  static var wordmarkName: LocalizedStringResource {
    LocalizedStringResource("kit.brand.wordmarkName", defaultValue: "tickr", bundle: bundle)
  }
}

/// The wordmark's texts (`Wordmark` in TickrDesign).
public enum BrandText {
  /// "ickr", drawn after the mark's "t".
  public static var rest: LocalizedStringResource { L10n.wordmarkRest }
  /// "tickr", for VoiceOver.
  public static var name: LocalizedStringResource { L10n.wordmarkName }
}
