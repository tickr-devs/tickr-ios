import Foundation
import Testing
import TickrKit
@testable import TickrScreens

/// The Settings window's derived states: the morning check's big line and whether new entries are
/// allowed.
@MainActor
@Suite("Settings states")
struct SettingsStatesTests {
  @Test("The morning check says every check passed, or how many failed of all")
  func morningSummary() throws {
    let passed = try #require(try fixture(SystemV1.self, "system-v1.json").morningCheck)
    #expect(MorningCheckSection.summary(passed).key == "settings.morningAllPassed")
    let failed = try #require(try fixture(SystemV1.self, "system-v1.attention.json").morningCheck)
    #expect(MorningCheckSection.summary(failed).key == "settings.morningFailed")
    #expect(String(localized: MorningCheckSection.summary(failed)) == "Failed: 1 of 2")
  }

  @Test("A failure the record pins on no check says only that it failed")
  func morningFailureWithoutCheck() throws {
    let check = try morningCheck { check in
      check["outcome"] = "failed"
    }
    #expect(MorningCheckSection.summary(check).key == "kit.system.failed")
  }

  @Test("No session and an invalid config say so, whatever the checks")
  func morningOtherOutcomes() throws {
    #expect(MorningCheckSection.summary(try morningCheck { $0["outcome"] = "no-session" }).key == "kit.system.noSession")
    #expect(MorningCheckSection.summary(try morningCheck { $0["outcome"] = "config-invalid" }).key
      == "kit.system.configInvalid")
  }

  @Test("New entries are off with the gate closed, paused by the entry-stop, else allowed")
  func newEntries() throws {
    #expect(NewEntries.of(try status { _ in }) == .allowed)
    #expect(NewEntries.of(try status { $0["entry_stop"] = true }) == .paused)
    let closed = try status { object in
      var gate = object["trading_gate"] as? [String: Any] ?? [:]
      gate["open"] = false
      object["trading_gate"] = gate
      object["entry_stop"] = true
    }
    #expect(NewEntries.of(closed) == .off)
  }

  /// The passing morning check of `system-v1.json`, changed by `edit`.
  private func morningCheck(_ edit: (inout [String: Any]) -> Void) throws -> MorningCheckV1 {
    var object = try json("system-v1.json")
    var check = try #require(object["morning_check"] as? [String: Any])
    edit(&check)
    object["morning_check"] = check
    let system = try Wire.decoder().decode(SystemV1.self, from: JSONSerialization.data(withJSONObject: object))
    return try #require(system.morningCheck)
  }

  /// The example status, changed by `edit`.
  private func status(_ edit: (inout [String: Any]) -> Void) throws -> StatusV1 {
    var object = try json("status-v1.example.json")
    edit(&object)
    return try Wire.decoder().decode(StatusV1.self, from: JSONSerialization.data(withJSONObject: object))
  }

  private func json(_ name: String) throws -> [String: Any] {
    try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: fixturesDir.appendingPathComponent(name)))
      as? [String: Any])
  }
}
