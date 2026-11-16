import Foundation
import Testing
@testable import TickrKit

@Suite("Demo day address and day")
struct DemoDayTests {
  @Test("On, every request goes to the demo day the app carries; off, the address is untouched",
    arguments: ["http://127.0.0.1:8766", "https://mac.tailnet.ts.net"])
  func address(real: String) throws {
    let url = try #require(URL(string: real))
    #expect(DemoDay.address(url, demo: false) == url)
    #expect(DemoDay.address(url, demo: true) == DemoDay.address)
    #expect(DemoDay.isDemo(DemoDay.address(url, demo: true)))
    #expect(!DemoDay.isDemo(url))
    // No host of any network: the token of a pairing can never go there.
    #expect(DemoDay.address.scheme != "http" && DemoDay.address.scheme != "https")
  }

  @Test("On, only the demo day (the API's today) can be shown")
  func dayLock() throws {
    let past = try WireDate("2026-11-12")
    #expect(DemoDay.day(past, demo: true) == nil)
    #expect(DemoDay.day(nil, demo: true) == nil)
    #expect(DemoDay.day(past, demo: false) == past)
  }
}
