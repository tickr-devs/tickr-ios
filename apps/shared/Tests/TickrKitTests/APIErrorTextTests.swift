import Foundation
import Testing
@testable import TickrKit

/// An answer the app cannot read is an app and a bot from different releases: the person reads
/// that and what to do, never the field path or the word "contract". Tests read the English
/// default values.
@Suite struct APIErrorTextTests {
  @Test func unreadableAnswerSaysReinstallNotTheField() {
    let data = Data("{\"api_version\": 2}".utf8)
    do {
      _ = try Wire.decoder().decode(StatusResponseV1.self, from: data)
      Issue.record("a newer API version decoded")
    } catch {
      let detail = Wire.detail(error)
      #expect(detail.contains("api_version"))
      let text = ErrorText.text(APIError.unreadable(detail))
      #expect(text.contains("different releases"))
      #expect(!text.contains("api_version"))
      #expect(!text.contains("contract"))
    }
  }
}
