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

  /// A short explanation of this view: the system tooltip under the Mac's pointer; on a touch
  /// screen, which has no pointer to rest, a long press shows it (`hint`, a context menu that
  /// never fires the button it explains), so nothing is said only on hover.
  @ViewBuilder
  func tip(_ text: Text) -> some View {
    #if os(macOS)
    help(text)
    #else
    hint(text)
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
