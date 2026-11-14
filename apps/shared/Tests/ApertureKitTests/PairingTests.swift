@testable import ApertureKit
import Foundation
import Testing

@Suite struct PairingTests {
  @Test func parsesThePrintedLink() throws {
    let pairing = try #require(Pairing.parse(
      "  aperture://pair?url=https%3A%2F%2Fmac.tail-net.ts.net&token=Ab_9-xY\n"))
    #expect(pairing.url.absoluteString == "https://mac.tail-net.ts.net")
    #expect(pairing.token == "Ab_9-xY")
  }

  @Test(arguments: [
    "",
    "https://mac.ts.net",
    "aperture://pair?url=http%3A%2F%2Fmac.ts.net&token=abc",
    "aperture://pair?url=https%3A%2F%2Fmac.ts.net",
    "aperture://pair?url=https%3A%2F%2Fmac.ts.net&token=",
    "aperture://pair?url=https%3A%2F%2Fmac.ts.net&token=a%20b",
    "aperture://pair?url=https%3A%2F%2Fmac.ts.net%2Fx&token=abc",
    "aperture://pair?url=https%3A%2F%2Fu%3Ap%40mac.ts.net&token=abc",
    "aperture://other?url=https%3A%2F%2Fmac.ts.net&token=abc",
    "aperture://pair?url=https%3A%2F%2Fmac.ts.net&token=abc&extra=1",
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
