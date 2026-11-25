import Foundation

/// Texts of the entry model's shared pieces (TickrDesign's `ConfidenceMeter` and
/// `SignedReasonList`), read through `ModelText`.
extension L10n {
  /// The confidence meter's name for VoiceOver.
  static var modelConfidence: LocalizedStringResource {
    LocalizedStringResource("kit.model.confidence", defaultValue: "Confidence", bundle: bundle)
  }
  /// The confidence meter's value with the model's cutoff: "74%, cutoff 70%".
  static func modelConfidenceWithCutoff(_ confidence: String, _ cutoff: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.model.confidenceWithCutoff", defaultValue: "\(confidence), cutoff \(cutoff)",
      bundle: bundle)
  }
  /// The sign of a reason that raised the model's confidence, for VoiceOver.
  static var modelReasonHelps: LocalizedStringResource {
    LocalizedStringResource("kit.model.reasonHelps", defaultValue: "Helps", bundle: bundle)
  }
  /// The sign of a reason that lowered the model's confidence, for VoiceOver.
  static var modelReasonHurts: LocalizedStringResource {
    LocalizedStringResource("kit.model.reasonHurts", defaultValue: "Hurts", bundle: bundle)
  }

  // MARK: Example reasons (previews and tests, until the API carries the model's reasons)

  /// An example reason that helps an entry: the volume.
  static var modelSampleVolume: LocalizedStringResource {
    LocalizedStringResource("kit.model.sample.volume", defaultValue: "Volume well above normal", bundle: bundle)
  }
  /// An example reason that helps an entry: the time of day.
  static var modelSampleEarly: LocalizedStringResource {
    LocalizedStringResource("kit.model.sample.early", defaultValue: "Early in the session", bundle: bundle)
  }
  /// An example reason that hurts an entry: the price against VWAP.
  static var modelSampleAboveVWAP: LocalizedStringResource {
    LocalizedStringResource("kit.model.sample.aboveVWAP", defaultValue: "Price far above VWAP", bundle: bundle)
  }
}
