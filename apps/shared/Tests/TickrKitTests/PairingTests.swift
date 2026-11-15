import Foundation
import Testing
@testable import TickrKit

@Suite struct PairingTests {
  @Test func parsesThePrintedLink() throws {
    let pairing = try #require(Pairing.parse(
      "  tickr://pair?url=https%3A%2F%2Fmac.tail-net.ts.net&token=Ab_9-xY\n"))
    #expect(pairing.url.absoluteString == "https://mac.tail-net.ts.net")
    #expect(pairing.token == "Ab_9-xY")
  }

  @Test(arguments: [
    "",
    "https://mac.ts.net",
    "tickr://pair?url=http%3A%2F%2Fmac.ts.net&token=abc",
    "tickr://pair?url=https%3A%2F%2Fmac.ts.net",
    "tickr://pair?url=https%3A%2F%2Fmac.ts.net&token=",
    "tickr://pair?url=https%3A%2F%2Fmac.ts.net&token=a%20b",
    "tickr://pair?url=https%3A%2F%2Fmac.ts.net%2Fx&token=abc",
    "tickr://pair?url=https%3A%2F%2Fu%3Ap%40mac.ts.net&token=abc",
    "tickr://other?url=https%3A%2F%2Fmac.ts.net&token=abc",
    "tickr://pair?url=https%3A%2F%2Fmac.ts.net&token=abc&extra=1",
  ])
  func refusesAnythingElse(text: String) {
    #expect(Pairing.parse(text) == nil)
  }

  @Test func clientSendsBearerOnlyWhenGiven() throws {
    let url = try #require(URL(string: "https://mac.ts.net"))
    #expect(APIClient(baseURL: url, token: "t").request(path: "/status", body: nil)
      .value(forHTTPHeaderField: "Authorization") == "Bearer t")
    #expect(APIClient(baseURL: url).request(path: "/status", body: nil)
      .value(forHTTPHeaderField: "Authorization") == nil)
  }
}
