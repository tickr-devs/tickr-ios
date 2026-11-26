import SwiftUI
import TickrDesign

// The screens run on the Mac and, in regular width, on iPad and the unfolded iPhone (TickrScreens,
// Package.swift). The few modifiers only the Mac has are wrapped here, so a screen calls one name
// and does the right thing on both.

extension View {
  /// The pointing hand over a link on the Mac; a touch screen has no pointer.
  @ViewBuilder
  func linkPointer() -> some View {
    #if os(macOS)
    pointerStyle(.link)
    #else
    self
    #endif
  }

  /// A menu drawn as its label alone, a plain button, on the Mac; iPadOS draws every menu that way.
  @ViewBuilder
  func buttonMenuStyle() -> some View {
    #if os(macOS)
    menuStyle(.button)
    #else
    self
    #endif
  }
}

/// The platform's font (`NSFont` on the Mac, `UIFont` on iPadOS), for text measured before it is
/// drawn (`TextMeasure`).
typealias PlatformFont = TextMeasure.PlatformFont
