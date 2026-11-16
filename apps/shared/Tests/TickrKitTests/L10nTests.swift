import Foundation
import Testing
@testable import TickrKit

/// Entries read through the package's String Catalog, with their arguments filled in. The Russian
/// translations are checked by apps/scripts/check_swift_rules.py (rule `catalog`): `swift build`
/// copies a String Catalog into the bundle instead of compiling it, so a `swift test` run can
/// only read the English default values.
@Suite struct L10nTests {
  @Test func entriesResolve() {
    #expect(String(localized: L10n.commandFlatten) == "Close all")
    #expect(String(localized: L10n.tagEnter) == "ENTER")
  }

  @Test func argumentsFillTheText() {
    #expect(String(localized: L10n.apiRefused(409, "busy", "later")) == "API refused (409 busy): later")
    #expect(String(localized: L10n.headlineNoVerifiedStop("ABCD", "missing"))
      == "Position ABCD has no verified stop (missing). ")
  }

  /// An error with a description shows it; one without shows a plain sentence, never Swift's
  /// debug form of the error.
  @Test func errorText() {
    #expect(ErrorText.describe(APIError.unreachable("down")) == "Local API not reachable: down")
    #expect(ErrorText.describe(CancellationError()) == nil)
    #expect(ErrorText.text(CancellationError()) == "unexpected error in the app")
  }
}
