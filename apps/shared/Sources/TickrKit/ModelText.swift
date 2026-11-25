import Foundation

/// The texts of the entry model's shared pieces (`ConfidenceMeter`, `SignedReasonList` in
/// TickrDesign, which has no String Catalog of its own).
public enum ModelText {
  /// The confidence meter's name for VoiceOver.
  public static var confidence: LocalizedStringResource { L10n.modelConfidence }
  /// The confidence meter's value with the model's cutoff: "74%, cutoff 70%".
  public static func confidence(_ confidence: String, cutoff: String) -> LocalizedStringResource {
    L10n.modelConfidenceWithCutoff(confidence, cutoff)
  }
  /// The sign of a reason that raised the model's confidence, for VoiceOver.
  public static var helps: LocalizedStringResource { L10n.modelReasonHelps }
  /// The sign of a reason that lowered the model's confidence, for VoiceOver.
  public static var hurts: LocalizedStringResource { L10n.modelReasonHurts }

  /// Example reasons for previews and tests, until the API carries the model's reasons.
  public enum Sample {
    /// Helps: the volume.
    public static var volume: LocalizedStringResource { L10n.modelSampleVolume }
    /// Helps: the time of day.
    public static var early: LocalizedStringResource { L10n.modelSampleEarly }
    /// Hurts: the price against VWAP.
    public static var aboveVWAP: LocalizedStringResource { L10n.modelSampleAboveVWAP }
  }
}
