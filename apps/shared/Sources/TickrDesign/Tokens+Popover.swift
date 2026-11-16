import CoreGraphics

// Sizes of popovers (docs/design-system.md, Sizes); in their own file because Tokens.swift is at
// SwiftLint's file length limit.
extension Tokens.Size {
  /// Widest a detail popover grows (the live flow's stage details); narrower where the screen is.
  public static let popover: CGFloat = 340
}
