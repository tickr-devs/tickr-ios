import Foundation
import Testing
@testable import TickrDesign
import TickrKit

/// The System card's notes appear only on rows that need a look (mockup v134): an all-good card is
/// values only, a card with problems says what is wrong under each such row.
@Suite struct SystemPanelNotesTests {
  /// The contract fixtures (tests/api/fixtures) from this file's place in the repository.
  static let fixtures = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // TickrDesignTests
    .deletingLastPathComponent()  // Tests
    .deletingLastPathComponent()  // shared
    .deletingLastPathComponent()  // apps
    .deletingLastPathComponent()  // repository root
    .appendingPathComponent("tests/api/fixtures")

  func system(_ name: String) throws -> SystemV1 {
    try Wire.decoder().decode(SystemV1.self, from: Data(contentsOf: Self.fixtures.appendingPathComponent(name)))
  }

  @Test func allGoodRowsHaveNoNotes() throws {
    let system = try system("system-v1.json")
    #expect(SystemPanel.linkNote(system.brokerLink, SystemCard.link(system)) == nil)
    #expect(SystemPanel.morningNote(system.morningCheck, SystemCard.morningCheck(system)) == nil)
    #expect(try SystemPanel.lastCheck(#require(system.mac).watchdog) == nil)
  }

  @Test func rowsNeedingALookSayWhy() throws {
    let system = try system("system-v1.attention.json")
    // A stale link blocks entries, today's failed check stops the start, and the watchdog's last
    // check found a trade left open.
    #expect(SystemPanel.linkNote(system.brokerLink, SystemCard.link(system)) != nil)
    #expect(SystemPanel.morningNote(system.morningCheck, SystemCard.morningCheck(system)) != nil)
    #expect(try SystemPanel.lastCheck(#require(system.mac).watchdog) != nil)
  }
}
