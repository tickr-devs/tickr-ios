import Foundation
import Testing
@testable import TickrScreens

@MainActor
@Suite("Menu bar position scale")
struct MenuPositionTests {
  @Test("The stop is the left end, the scale end the right, clamped beyond both")
  func scale() throws {
    #expect(MenuPosition.progress(resultR: -1) == 0)
    #expect(MenuPosition.progress(resultR: MenuPosition.scaleEndR) == 1)
    #expect(MenuPosition.progress(resultR: -3) == 0)
    #expect(MenuPosition.progress(resultR: 9) == 1)
    let middle = try #require(MenuPosition.progress(resultR: 0.5))
    #expect(abs(middle - 0.5) < 1e-9)
  }

  @Test("An unknown result has no place on the scale")
  func unknown() {
    #expect(MenuPosition.progress(resultR: nil) == nil)
  }
}
