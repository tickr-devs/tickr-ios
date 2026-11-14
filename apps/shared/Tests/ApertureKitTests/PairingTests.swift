@testable import ApertureKit
import XCTest

final class PairingTests: XCTestCase {
  func testParsesThePrintedLink() throws {
    let pairing = try XCTUnwrap(Pairing.parse(
      "  aperture://pair?url=https%3A%2F%2Fmac.tail-net.ts.net&token=Ab_9-xY\n"))
    XCTAssertEqual(pairing.url.absoluteString, "https://mac.tail-net.ts.net")
    XCTAssertEqual(pairing.token, "Ab_9-xY")
  }

  func testRefusesAnythingElse() {
    for text in [
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
    ] {
      XCTAssertNil(Pairing.parse(text), text)
    }
  }

  func testClientSendsBearerOnlyWhenGiven() {
    let url = URL(string: "https://mac.ts.net")!
    XCTAssertEqual(APIClient(baseURL: url, token: "t").request(path: "/status", body: nil)
      .value(forHTTPHeaderField: "Authorization"), "Bearer t")
    XCTAssertNil(APIClient(baseURL: url).request(path: "/status", body: nil)
      .value(forHTTPHeaderField: "Authorization"))
  }
}
