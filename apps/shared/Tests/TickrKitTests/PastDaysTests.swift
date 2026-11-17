import Testing
@testable import TickrKit

struct PastDaysTests {
  static func day(_ text: String) throws -> WireDate { try WireDate(text) }

  @Test func keepsPastDaysNeverToday() throws {
    let today = try Self.day("2026-11-17")
    let past = try Self.day("2026-11-16")
    var kept = PastDays<String>()
    kept.keep(past, today: today, empty: "") { $0 = "trades" }
    kept.keep(today, today: today, empty: "") { $0 = "live" }
    #expect(kept.parts(of: past) == "trades")
    #expect(kept.parts(of: today) == nil)
  }

  @Test func updatesWhatIsKeptOfADay() throws {
    let today = try Self.day("2026-11-17")
    let past = try Self.day("2026-11-16")
    var kept = PastDays<[String]>()
    kept.keep(past, today: today, empty: []) { $0.append("trades") }
    kept.keep(past, today: today, empty: []) { $0.append("skipped") }
    #expect(kept.parts(of: past) == ["trades", "skipped"])
  }

  @Test func dropsTheDayUsedLongestAgo() throws {
    let today = try Self.day("2026-11-17")
    let (first, second, third) = (try Self.day("2026-11-12"), try Self.day("2026-11-13"), try Self.day("2026-11-16"))
    var kept = PastDays<String>(capacity: 2)
    kept.keep(first, today: today, empty: "") { $0 = "first" }
    kept.keep(second, today: today, empty: "") { $0 = "second" }
    kept.keep(first, today: today, empty: "") { $0 = "first again" }  // used again: newest
    kept.keep(third, today: today, empty: "") { $0 = "third" }
    #expect(kept.days == [first, third])
    #expect(kept.parts(of: second) == nil)
  }
}
