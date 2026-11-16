import Foundation
import Testing
@testable import TickrMac

/// The menu bar's Close all says how many positions it closes, as the design's "2 positions".
@MainActor
@Suite struct PositionCountTests {
  @Test func onlyCloseAllWithPositionsShowsTheCount() throws {
    let detail = try #require(BotControls.detail(.flattenAll, positions: 2))
    #expect(detail.key == "bot.positionCount")
    // `swift test` reads the English default value only; the plural forms are checked below.
    #expect(String(localized: detail) == "2 positions")
    #expect(BotControls.detail(.flattenAll, positions: 0) == nil)
    #expect(BotControls.detail(.cancelOrders, positions: 2) == nil)
    #expect(BotControls.detail(.flatten(symbol: "ABCD"), positions: 2) == nil)
  }

  /// The String Catalog counts in each language's plural forms: English one and other, Russian
  /// one, few, many and other ("1 позиция", "2 позиции", "5 позиций").
  @Test func catalogHasEveryPluralForm() throws {
    let url = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
      .appending(path: "Tickr/Localizable.xcstrings")
    let catalog = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    let strings = try #require(catalog["strings"] as? [String: Any])
    let entry = try #require(strings["bot.positionCount"] as? [String: Any])
    let localizations = try #require(entry["localizations"] as? [String: Any])
    func forms(_ language: String) throws -> [String: String] {
      let localization = try #require(localizations[language] as? [String: Any])
      let variations = try #require(localization["variations"] as? [String: Any])
      let plural = try #require(variations["plural"] as? [String: [String: [String: String]]])
      return plural.compactMapValues { $0["stringUnit"]?["value"] }
    }
    #expect(try forms("en") == ["one": "%lld position", "other": "%lld positions"])
    #expect(try forms("ru") == ["one": "%lld позиция", "few": "%lld позиции", "many": "%lld позиций",
      "other": "%lld позиции"])
  }
}
