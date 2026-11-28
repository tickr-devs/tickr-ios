import Testing
@testable import TickrKit

@Suite("Weekend days")
struct WireDateWeekendTests {
  @Test("Saturday and Sunday in New York are weekend days; Friday and Monday are not")
  func weekend() throws {
    #expect(try WireDate("2026-11-28").isWeekend)
    #expect(try WireDate("2026-11-29").isWeekend)
    #expect(try !WireDate("2026-11-27").isWeekend)
    #expect(try !WireDate("2026-11-30").isWeekend)
  }
}
