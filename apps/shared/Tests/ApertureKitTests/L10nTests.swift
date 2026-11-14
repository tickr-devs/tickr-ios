@testable import ApertureKit
import XCTest

/// Entries read through the package's String Catalog, with their arguments filled in. The Russian
/// translations are checked by apps/scripts/check_swift_rules.py (rule `catalog`): `swift build`
/// copies a String Catalog into the bundle instead of compiling it, so a `swift test` run can
/// only read the English default values.
final class L10nTests: XCTestCase {
  func testEntriesResolve() {
    XCTAssertEqual(String(localized: L10n.commandFlatten), "Flatten")
    XCTAssertEqual(String(localized: L10n.tagEnter), "ENTER")
  }

  func testArgumentsFillTheText() {
    XCTAssertEqual(String(localized: L10n.apiRefused(409, "busy", "later")), "API refused (409 busy): later")
    XCTAssertEqual(String(localized: L10n.headlineNoVerifiedStop("ABCD", "missing")),
      "Position ABCD has no verified stop (missing). ")
  }
}
