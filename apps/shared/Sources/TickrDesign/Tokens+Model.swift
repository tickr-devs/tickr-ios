import SwiftUI

// Tokens of the entry model's pieces (`ConfidenceMeter`, `SignedReasonList`); in their own file
// because Tokens.swift is at SwiftLint's file length limit.

extension Tokens {
  /// The entry model's confidence meter and its reasons.
  public enum Model {
    /// The meter's track and fill height, in points.
    public static let barHeight: CGFloat = 6
    /// The cutoff tick's height, in points: taller than the bar so it reads past the fill.
    public static let tickHeight: CGFloat = 14
    /// The cutoff tick's width, in points.
    public static let tickWidth: CGFloat = Tokens.Stroke.bold
    /// The least width of the meter's bar, in points, so the tick and the fill stay readable.
    public static let barMinWidth: CGFloat = 80
    /// The track behind the fill: the fill's colour at this opacity.
    public static let trackOpacity = 0.18
    /// Most reasons a decision shows (the model's top reasons, strongest first).
    public static let reasonRows = 5
  }
}
