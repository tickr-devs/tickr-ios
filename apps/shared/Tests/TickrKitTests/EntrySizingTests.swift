import Foundation
import Testing

@testable import TickrKit

@Suite("Last entry size")
struct EntrySizingTests {
  /// Plain figures, so the expectations read the numbers the bot sent.
  static let text = SizeText(usd: { "$\($0)" }, price: { "$\($0)" }, shares: { "\($0)" })

  static func latest(_ name: String) throws -> LatestSizeV1 {
    try #require(try Wire.decoder().decode(WatchingV1.self, from: fixture(name)).latestSize)
  }

  @Test func decodesEachLimitTheBotWorkedOut() throws {
    let size = try Self.latest("watching-v1.notional-cap.json")
    #expect(size.binding == .notionalCap)
    #expect(size.price?.value == Decimal(string: "0.71"))
    #expect(size.limits.map(\.limit) == [.plannedLoss, .notionalCap, .dailyRoom])
    #expect(size.limits.map(\.shares.value) == [4166, 3521, 24333])
  }

  @Test func theLimitThatSetTheSizeIsFullAndNamed() throws {
    let sizing = EntrySizing(size: try Self.latest("watching-v1.notional-cap.json"), configured: nil, text: Self.text)
    #expect(sizing.line == String(localized: L10n.sizingLine("IQ", "3521", "$2499.91", "$0.71")))
    #expect(sizing.lead == String(localized: L10n.sizingLead))
    #expect(sizing.limits.map(\.binds) == [false, true, false])
    #expect(sizing.limits[1].used == 1)
    #expect(sizing.limits[0].used < 1)
    #expect(sizing.limits[1].label == String(localized: L10n.sizingRowNotionalCap("$2500", "$0.71")))
    #expect(sizing.caption == String(localized: L10n.sizingSetBy(String(localized: L10n.sizingNameNotionalCap), "$2500")))
    #expect(sizing.tone == .bound)
  }

  @Test func theRiskScreensSayEachLimitWithoutAFormula() throws {
    let sizing = EntrySizing(size: try Self.latest("watching-v1.notional-cap.json"), configured: nil, text: Self.text)
    #expect(sizing.shares == String(localized: L10n.sizingSharesLine("3521")))
    #expect(sizing.place?.hasPrefix("IQ") == true)
    #expect(sizing.limits[1].plain == String(localized: L10n.sizingPlainNotionalCap("$2500")))
    #expect(sizing.limitedBy == String(localized: L10n.sizingLimitedBy(String(localized: L10n.sizingPlainNameNotionalCap))))
    // Nothing sized today: no headline, the line says so.
    let none = EntrySizing(size: nil, configured: nil, text: Self.text)
    #expect(none.shares == nil && none.place == nil && none.limitedBy == nil)
  }

  @Test func anOlderRecordShowsNoLimitsAndTheBotsCause() throws {
    let sizing = EntrySizing(size: try Self.latest("watching-v1.json"), configured: nil, text: Self.text)
    #expect(sizing.limits.isEmpty)
    #expect(sizing.lead == nil)
    #expect(sizing.tone == .unproven)
    #expect(sizing.caption != nil)
    let room = EntrySizing(size: try Self.latest("watching-v1.daily-room.json"), configured: nil, text: Self.text)
    #expect(room.caption == String(localized: L10n.sizingSetByNoAmount(String(localized: L10n.sizingNameDailyRoom))))
  }

  @Test func withoutAnEntryTheExampleStockIsSizedWithTheConfiguredLimits() {
    // $50 / $0.25 = 200, $2,500 / $10 = 250, $292 / $0.25 = 1,168: the planned loss sets it.
    let sizing = EntrySizing(size: nil, configured: SizingLimits(plannedLossUsd: 50, notionalCapUsd: 2500,
      dailyRoomUsd: 292), text: Self.text)
    #expect(sizing.line == String(localized: L10n.sizingNone))
    #expect(sizing.meta == nil)
    #expect(sizing.limits.map(\.binds) == [true, false, false])
    #expect(sizing.limits.map(\.allows) == ["200", "250", "1168"].map { String(localized: L10n.sizingShares($0)) })
    #expect(sizing.tone == .example)
    // Near the daily ceiling the room sets it: $20 / $0.25 = 80.
    let near = EntrySizing(size: nil, configured: SizingLimits(plannedLossUsd: 50, notionalCapUsd: 2500,
      dailyRoomUsd: 20), text: Self.text)
    #expect(near.limits.map(\.binds) == [false, false, true])
    // Without the limits, only the line.
    let bare = EntrySizing(size: nil, configured: nil, text: Self.text)
    #expect(bare.limits.isEmpty && bare.caption == nil)
  }

  @Test func recordsAgreeOnlyOnAMatchWithoutFences() throws {
    let flow = try Wire.decoder().decode(FlowV1.self, from: fixture("flow-v1.json"))
    let match = RecordsAgreement(fences: [], latest: flow.reconcile)
    #expect(match.agrees == true)
    let unknown = RecordsAgreement(fences: [], latest: nil)
    #expect(unknown.value == nil && unknown.agrees == nil)
  }
}
