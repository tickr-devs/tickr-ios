import Testing
@testable import TickrKit

/// The name the bot lists a device under (SignIn.swift).
@Suite struct DeviceNameTests {
  @Test func theDeviceNameKeepsWhatTheBotTakes() {
    #expect(DeviceName.of("Valentyn\u{2019}s iPhone") == "Valentyns iPhone")
    #expect(DeviceName.of(" -MacBook Pro (2) ") == "MacBook Pro 2")
    #expect(DeviceName.of("\u{1F4F1}") == "device")
  }
}
