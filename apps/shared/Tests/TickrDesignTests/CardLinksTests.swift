import SwiftUI
import Testing
@testable import TickrDesign

/// Card links: the footer row is one target of the platform's size, the header capsule fits its
/// touch target.
@MainActor
@Suite struct CardLinksTests {
  @Test("A footer link's whole row is at least the platform's target: 44 pt on iOS, the board's 36 on the Mac")
  func footerRowHeight() {
    #if os(iOS)
    #expect(CardFooterLink.rowHeight >= Tokens.Size.touchTarget)
    #else
    #expect(CardFooterLink.rowHeight == Tokens.Size.footerLink)
    #endif
    #expect(CardFooterLink.rowHeight > Tokens.Size.footerChip)
  }

  @Test("A header link's capsule is never taller than its touch target")
  func headerLinkFitsTarget() {
    #expect(Tokens.Size.headerLink <= Tokens.Size.touchTarget)
  }
}
