@testable import ApertureMac
import ApertureDesign
import Foundation
import Testing

@Suite("Age of the last broker read on the Safety card")
struct BrokerReadAgeTests {
  @Test("Fresh is green, late is a warning, past the entry block or never is red")
  func color() {
    let now = Date()
    #expect(BrokerReadAge.color(since: now, now: now) == Palette.profitText)
    #expect(BrokerReadAge.color(since: now.addingTimeInterval(-BrokerReadAge.freshSeconds), now: now)
      == Palette.profitText)
    #expect(BrokerReadAge.color(since: now.addingTimeInterval(-BrokerReadAge.blockingSeconds), now: now)
      == Palette.warningText)
    #expect(BrokerReadAge.color(since: now.addingTimeInterval(-BrokerReadAge.blockingSeconds - 1), now: now)
      == Palette.lossText)
    #expect(BrokerReadAge.color(since: nil, now: now) == Palette.lossText)
  }
}
