import Foundation
import Testing
@testable import TickrKit

@Suite("Demo day address and day")
struct DemoDayTests {
  @Test("On, every request goes under /demo of the very same address; off, the address is untouched",
    arguments: [
      ("http://127.0.0.1:8766", "http://127.0.0.1:8766/demo", "http://127.0.0.1:8766/demo/status"),
      ("http://127.0.0.1:8766/", "http://127.0.0.1:8766/demo", "http://127.0.0.1:8766/demo/status"),
      ("https://mac.tailnet.ts.net", "https://mac.tailnet.ts.net/demo", "https://mac.tailnet.ts.net/demo/status"),
    ])
  func address(real: String, demo: String, status: String) throws {
    let url = try #require(URL(string: real))
    #expect(DemoDay.address(url, demo: false) == url)
    let shown = DemoDay.address(url, demo: true)
    #expect(shown.absoluteString == demo)
    // The API client puts each route after the base path, as it does for every request.
    #expect(shown.appendingPathComponent("status").absoluteString == status)
    // Same scheme, host and port: the phone's token may only go where it already went.
    #expect(shown.scheme == url.scheme && shown.host() == url.host() && shown.port == url.port)
  }

  @Test("On, only the demo day (the API's today) can be shown")
  func dayLock() throws {
    let past = try WireDate("2026-11-12")
    #expect(DemoDay.day(past, demo: true) == nil)
    #expect(DemoDay.day(nil, demo: true) == nil)
    #expect(DemoDay.day(past, demo: false) == past)
  }
}
