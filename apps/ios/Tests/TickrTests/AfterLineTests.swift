import Foundation
import SwiftUI
import Testing
@testable import Tickr
import TickrDesign
import TickrKit

/// "after 1m +0.06 · 5m −0.18": the prices after a skipped signal or an exit, each change in its
/// sign's colour and a missing price as a dash.
@MainActor
@Suite struct AfterLineTests {
  private func prices(_ changes: [(Int, String?)]) throws -> [PriceAfterV1] {
    try decode([PriceAfterV1].self, changes.map { minutes, change in
      [
        "minutes": minutes,
        "at": "2026-11-16T15:03:00.000Z",
        "price": change == nil ? NSNull() : "12.44",
        "change_usd": change ?? NSNull(),
        "cause": change == nil ? "no bar" : NSNull(),
        "cause_codes": [Any](),
      ] as [String: Any]
    })
  }

  @Test func readsEveryPointInOrder() throws {
    let line = AfterLine.line(try prices([(1, "0.06"), (5, "-0.18"), (15, nil)]))
    let expected = String(localized: L10n.Activity.after)
      + ChartFormat.space + String(localized: L10n.Activity.minutesAfter(1)) + ChartFormat.space
      + Money.signed(Decimal(string: "0.06")!)
      + Format.separator + String(localized: L10n.Activity.minutesAfter(5)) + ChartFormat.space
      + Money.signed(Decimal(string: "-0.18")!)
      + Format.separator + String(localized: L10n.Activity.minutesAfter(15)) + ChartFormat.space
      + Format.missing
    #expect(String(line.characters) == expected)
  }

  @Test func changesAreColouredBySign() throws {
    let line = AfterLine.line(try prices([(1, "0.06"), (5, "-0.18"), (15, nil)]))
    let gain = try #require(line.range(of: Money.signed(Decimal(string: "0.06")!)))
    let loss = try #require(line.range(of: Money.signed(Decimal(string: "-0.18")!)))
    let missing = try #require(line.range(of: Format.missing))
    #expect(line[gain].swiftUI.foregroundColor == Palette.result(Decimal(string: "0.06")!))
    #expect(line[loss].swiftUI.foregroundColor == Palette.result(Decimal(string: "-0.18")!))
    #expect(line[missing].swiftUI.foregroundColor == Palette.textQuaternary)
  }

  @Test func noPricesIsJustTheLead() throws {
    #expect(String(AfterLine.line([]).characters) == String(localized: L10n.Activity.after))
  }
}
