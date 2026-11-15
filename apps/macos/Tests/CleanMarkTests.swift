@testable import ApertureMac
import ApertureKit
import Foundation
import Testing

@Suite("Clean-day mark on the Trades calendar and day list")
struct CleanMarkTests {
  func days() throws -> [DaySummary] {
    let data = try Data(contentsOf: fixturesDir.appendingPathComponent("days-v1.json"))
    return try Wire.decoder().decode(DaysV1.self, from: data).days
  }

  @Test("A not-clean day lists every cause; an unknown one says why")
  func text() throws {
    let days = try days()
    let dirty = try #require(days.first { $0.clean.verdict == .notClean })
    let text = CleanMark.text(dirty.clean)
    for cause in dirty.clean.causes {
      #expect(text.contains(cause.text))
    }
    let open = try #require(days.first { $0.clean.verdict == .unknown })
    #expect(CleanMark.text(open.clean).contains(try #require(open.clean.cause)))
    let clean = try #require(days.first { $0.clean.verdict == .clean })
    #expect(CleanMark.text(clean.clean) == String(localized: L10n.Trades.cleanDay))
  }
}
