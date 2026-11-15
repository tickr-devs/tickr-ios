#if os(macOS)
@testable import ApertureDesign
import SwiftUI
import Testing

@Suite struct BrandOpeningTests {
  @Test("The opening starts once its window is in front, key or merely active")
  func startsInFront() {
    #expect(BrandOpening.inFront(.key))
    #expect(BrandOpening.inFront(.active))
  }

  @Test("A window opened in the background waits, until the fallback timer plays the opening anyway")
  func backgroundWindowWaitsBriefly() {
    #expect(!BrandOpening.inFront(.inactive))
    #expect(Tokens.Motion.openingWaitSeconds > 0)
  }
}
#endif
