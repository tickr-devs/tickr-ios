import Foundation
import Testing
@testable import TickrKit

@Suite("A strategy's readable name")
struct StrategyNameTests {
  @Test("The bot's price-action ids read as Price action, whatever their generation")
  func known() {
    let title = String(localized: L10n.strategyPriceAction)
    #expect(StrategyName.title("price-action-v1") == title)
    #expect(StrategyName.title("price-action-v3") == title)
    #expect(StrategyName.title("price-action") == title)
  }

  @Test("An id the app does not know reads as the bot sent it")
  func unknown() {
    #expect(StrategyName.title("l2-2026-12-01a") == "l2-2026-12-01a")
    #expect(StrategyName.title("momentum-vx") == "momentum-vx")
  }
}
