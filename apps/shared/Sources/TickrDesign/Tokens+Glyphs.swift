import SwiftUI

// Tokens of the design's settings gear (`DesignGlyph.settings`, mockup v94); in their own file
// because Tokens.swift is at SwiftLint's file length limit.

extension Tokens.Stroke {
  /// The settings gear's stroke on its 24-point grid; at small sizes (the 13-point menu bar) it
  /// takes `glyphHeavy`, as the design draws it.
  public static let gear: CGFloat = 1.9
}

extension Tokens.Size {
  /// A glyph among the macOS menu-bar panel's footer icons (the settings gear).
  public static let menuGlyph: CGFloat = 13
}
