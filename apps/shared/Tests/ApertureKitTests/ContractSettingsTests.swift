@testable import ApertureKit
import Foundation
import Testing

@Suite("Contract: settings-v1")
struct ContractSettingsTests {
  @Test func settingsBrokerReadAges() throws {
    let settings = try Wire.decoder().decode(SettingsV1.self, from: fixture("settings-v1.json"))
    #expect(settings.brokerReadMaxAgeSeconds.text == "30")
    #expect(settings.brokerReadWarnSeconds.text == "15")
  }
}
