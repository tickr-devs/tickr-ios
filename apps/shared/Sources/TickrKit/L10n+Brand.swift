import Foundation

extension L10n {
  /// The wordmark's letters after the mark's "t" (the brand, the same in every language).
  static var wordmarkRest: LocalizedStringResource {
    LocalizedStringResource("kit.brand.wordmarkRest", defaultValue: "ickr", bundle: bundle)
  }
  /// The wordmark's domain after "ickr" (the brand, the same in every language).
  static var wordmarkDomain: LocalizedStringResource {
    LocalizedStringResource("kit.brand.wordmarkDomain", defaultValue: ".bot", bundle: bundle)
  }
  /// The wordmark as VoiceOver reads it.
  static var wordmarkName: LocalizedStringResource {
    LocalizedStringResource("kit.brand.wordmarkName", defaultValue: "tickr.bot", bundle: bundle)
  }
}

/// The wordmark's texts (`Wordmark` in TickrDesign).
public enum BrandText {
  /// "ickr", drawn after the mark's "t".
  public static var rest: LocalizedStringResource { L10n.wordmarkRest }
  /// ".bot", drawn after "ickr" lighter and muted.
  public static var domain: LocalizedStringResource { L10n.wordmarkDomain }
  /// "tickr.bot", for VoiceOver.
  public static var name: LocalizedStringResource { L10n.wordmarkName }
}
