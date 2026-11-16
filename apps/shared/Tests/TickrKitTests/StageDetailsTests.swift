import Foundation
import Testing

@testable import TickrKit

@Suite("Stage details")
struct StageDetailsTests {
  struct Fixtures {
    let flow: FlowV1
    let skipped: SkippedV1
    let watching: WatchingV1
    let status: StatusV1
    let settings: SettingsV1

    init() throws {
      let decoder = Wire.decoder()
      flow = try decoder.decode(FlowV1.self, from: fixture("flow-v1.json"))
      skipped = try decoder.decode(SkippedV1.self, from: fixture("skipped-v1.json"))
      watching = try decoder.decode(WatchingV1.self, from: fixture("watching-v1.json"))
      status = try #require(try decoder.decode(StatusResponseV1.self, from: fixture("status-response-v1.json")).status)
      settings = try decoder.decode(SettingsV1.self, from: fixture("settings-v1.json"))
    }

    /// Today, live: every source.
    var live: StageSources {
      StageSources(flow: flow, skipped: skipped, watching: watching, status: status, settings: settings)
    }

    /// A recorded day: the day's flow and signals, no status.
    var recorded: StageSources {
      StageSources(flow: flow, skipped: skipped, watching: nil, status: nil, settings: settings)
    }
  }

  func value(_ detail: StageDetail, _ label: LocalizedStringResource) -> String? {
    (detail.facts + detail.footer).first { $0.label == String(localized: label) }?.value
  }

  func group(_ detail: StageDetail, _ title: LocalizedStringResource) -> StageDetail.Group? {
    detail.groups.first { $0.title == String(localized: title) }
  }

  @Test("Screeners: each screener's count, the total and the strongest movers each way")
  func screeners() throws {
    let detail = StageDetail.make(.screeners, from: try Fixtures().live)
    #expect(value(detail, L10n.stageGainers) == "2")
    #expect(value(detail, L10n.stageLosers) == "1")
    #expect(value(detail, L10n.stageActives) == "2")
    #expect(value(detail, L10n.stageListed) == "4")
    // WXYZ has no change and is left out of the movers; SPY's +0.31 counts though it was skipped.
    #expect(group(detail, L10n.stageTopGainers)?.rows.map(\.symbol) == ["ABCD", "SPY"])
    #expect(group(detail, L10n.stageTopGainers)?.rows.first?.text == String(localized: L10n.stageChange("+12.40")))
    #expect(group(detail, L10n.stageTopLosers)?.rows.map(\.symbol) == ["EFGH"])
    #expect(group(detail, L10n.stageTopLosers)?.rows.first?.tone == .red)
  }

  @Test("Universe: admitted of listed, the left-out symbols under their cause in words")
  func universe() throws {
    let detail = StageDetail.make(.universe, from: try Fixtures().recorded)
    #expect(value(detail, L10n.stageAdmitted) == String(localized: L10n.stageCountOf(3, 4)))
    #expect(detail.groups.map(\.title) == [String(localized: L10n.universeType("ETF"))])
    #expect(detail.groups.first?.rows.map(\.symbol) == ["SPY"])
  }

  @Test("Strategy: the live strategy, today's decisions and the closest watched symbols")
  func strategy() throws {
    let fixtures = try Fixtures()
    let detail = StageDetail.make(.strategy, from: fixtures.live)
    #expect(value(detail, L10n.stageActiveStrategy) == String(localized: L10n.stageStrategy("price-action-v1", "1")))
    #expect(value(detail, L10n.stageDecided) == "3")
    let closest = try #require(group(detail, L10n.stageClosest))
    #expect(closest.rows.map(\.symbol) == ["ABCD", "WXYZ", "EFGH"])
    // The deciding check, measured against its threshold, then the closeness in whole percents.
    let abcd = try #require(closest.rows.first?.text)
    // 0.9983 is not there yet: rounded down, never shown as 100.
    #expect(abcd.hasSuffix(String(localized: L10n.stageCloseness("99"))))
    #expect(abcd.contains("12.33 > 12.35"))
    // A side the bot did not measure is a dash; no closeness, no closeness text.
    #expect(closest.rows.last?.text?.contains("— is —") == true)
    #expect(closest.rows.last?.text?.contains(String(localized: L10n.stageCloseness("0"))) == false)
    // A recorded day has no live status: no strategy line.
    #expect(value(StageDetail.make(.strategy, from: fixtures.recorded), L10n.stageActiveStrategy) == nil)
  }

  @Test("Risk: counts, the entry block, the limits, the room and each refusal with its time")
  func risk() throws {
    let fixtures = try Fixtures()
    let detail = StageDetail.make(.risk, from: fixtures.live)
    #expect(value(detail, L10n.stagePassed) == "3")
    #expect(value(detail, L10n.stageRefused) == "2")
    #expect(value(detail, L10n.stageNotEvaluated) == "1")
    #expect(value(detail, L10n.stageEntries) == ApiText.entryBlock(try #require(fixtures.status.entryBlock)))
    #expect(value(detail, L10n.stagePlannedLoss) == String(localized: L10n.stageUSD("50")))
    // Live: the room of the daily limit and the slots in use stand for the bare limits.
    #expect(value(detail, L10n.stageMaxDailyLoss) == nil)
    #expect(value(detail, L10n.stageMaxPositions) == nil)
    #expect(value(detail, L10n.stageRoomLeft) == String(localized: L10n.stageUSDOf("248.40", "300")))
    #expect(value(detail, L10n.stagePositionsUsed) == String(localized: L10n.stageCountOf(1, 1)))
    #expect(value(detail, L10n.stageLatestSize) == String(localized: L10n.stageSize("QRST", "200")))
    // The refusals come before the limits: the limits are the footer, newest refusal first.
    let refused = try #require(group(detail, L10n.stageRefusedSignals))
    #expect(refused.rows.map(\.symbol) == ["ZNTH", "ABCD"])
    #expect(refused.rows.last?.text?.hasPrefix("10:02") == true)
    #expect(detail.footer.first?.label == String(localized: L10n.stagePlannedLoss))
    // A recorded day: the day's counts and refusals, nothing from the live status.
    let recorded = StageDetail.make(.risk, from: fixtures.recorded)
    #expect(value(recorded, L10n.stageEntries) == nil)
    #expect(value(recorded, L10n.stageRoomLeft) == nil)
    #expect(value(recorded, L10n.stageMaxDailyLoss) == String(localized: L10n.stageUSD("300")))
    #expect(value(recorded, L10n.stageMaxPositions) == "1")
    #expect(group(recorded, L10n.stageRefusedSignals)?.rows.count == 2)
  }

  @Test("Order: the day's fills, closed trades with their result and the open positions")
  func order() throws {
    let detail = StageDetail.make(.order, from: try Fixtures().live)
    #expect(value(detail, L10n.stageFilled) == "3")
    #expect(value(detail, L10n.stageClosed) == "1")
    #expect(value(detail, L10n.stageOpen) == "1")
    let closed = try #require(group(detail, L10n.stageClosedTrades)?.rows.first)
    #expect(closed.symbol == "WXYZ")
    #expect(closed.text == String(localized: L10n.stageTrade("20", "5.10", "5.02", "-1.60")))
    #expect(group(detail, L10n.stageOpenPositions)?.rows.first?.text
      == String(localized: L10n.stagePosition("10", "12.34")))
  }

  @Test("Broker stop: each trade's stop, its confirmation time when known, the open stops now")
  func stop() throws {
    let detail = StageDetail.make(.stop, from: try Fixtures().live)
    // Verified of the day's stops, from the stops themselves (not the symbols at the stage).
    #expect(value(detail, L10n.stageVerified) == String(localized: L10n.stageCountOf(1, 3)))
    #expect(detail.facts.first?.tone == .red)
    let trades = try #require(group(detail, L10n.stageTradeStops))
    #expect(trades.rows.map(\.symbol) == ["WXYZ", "EFGH", "ABCD"])
    #expect(trades.rows.map(\.tone) == [.green, .red, .amber])
    // Seconds without the wire's trailing zeros.
    #expect(trades.rows[0].text?.contains(String(localized: L10n.stageConfirmedAfter("1.25"))) == true)
    #expect(trades.rows[1].text == String(localized: L10n.stageNeverVerified))
    let open = try #require(group(detail, L10n.stageOpenPositions)?.rows.first)
    #expect(open.text?.contains("11.90") == true)
  }

  @Test("Reconcile: agreement, read time and fences, the live status's fences first")
  func reconcile() throws {
    let fixtures = try Fixtures()
    let detail = StageDetail.make(.reconcile, from: fixtures.live)
    #expect(value(detail, L10n.stageRecords) == String(localized: L10n.stageMatch))
    #expect(value(detail, L10n.stageReadAt) == "10:00")
    #expect(value(detail, L10n.stageFences) == "1")
    let fence = try #require(group(detail, L10n.stageFenceList)?.rows.first)
    #expect(fence.text == ApiText.fenceWithDetail(fixtures.status.fences[0]))
  }

  @Test("A stage with nothing reported says so in one line")
  func empty() {
    let none = StageSources(flow: nil, skipped: nil, watching: nil, status: nil, settings: nil)
    for stage in PipelineStage.allCases {
      #expect(StageDetail.make(stage, from: none).empty == String(localized: L10n.stageNothing))
    }
  }

  @Test("Another day's signals and watching rows never describe the shown day")
  func otherDay() throws {
    let fixtures = try Fixtures()
    var raw = try #require(try JSONSerialization.jsonObject(with: fixture("skipped-v1.json")) as? [String: Any])
    raw["day"] = "2026-11-13"
    let old = try Wire.decoder().decode(SkippedV1.self, from: JSONSerialization.data(withJSONObject: raw))
    let sources = StageSources(flow: fixtures.flow, skipped: old, watching: nil, status: nil, settings: nil)
    #expect(sources.skipped == nil)
  }

  @Test("A group lists at most its cap of rows and counts the rest")
  func cap() {
    let rows = (0...StageDetail.rowCap).map { StageDetail.Row(id: "\($0)", symbol: "\($0)", text: nil, tone: .muted) }
    let group = StageDetail.group(L10n.stageRefusedSignals, rows)
    #expect(group.rows.count == StageDetail.rowCap)
    #expect(group.more == 1)
  }

  @Test("Two fences of one kind are two rows with their own ids")
  func fencesOfOneKind() throws {
    let json = #"{"kind":"foreign_position","since":"2026-11-16T15:00:00.123Z","text":"t","code":"x","params":{}}"#
    let fence = try Wire.decoder().decode(Fence.self, from: Data(json.utf8))
    let rows = StageDetail.fences([fence, fence], status: nil).rows
    #expect(rows.count == 2)
    #expect(Set(rows.map(\.id)).count == 2)
  }

  /// `skipped-v1.json` with its first signal (ABCD, refused) repeated at `minutes` past 15:00 UTC.
  func repeated(_ minutes: [Int]) throws -> SkippedV1 {
    var raw = try #require(try JSONSerialization.jsonObject(with: fixture("skipped-v1.json")) as? [String: Any])
    var signals = try #require(raw["signals"] as? [[String: Any]])
    let first = signals[0]
    signals = minutes.map { minute in
      var signal = first
      signal["at"] = "2026-11-16T15:\(String(format: "%02d", minute)):00.000Z"
      return signal
    }
    raw["signals"] = signals
    return try Wire.decoder().decode(SkippedV1.self, from: JSONSerialization.data(withJSONObject: raw))
  }

  @Test("Identical refusals in a row on one symbol are one row with their times and count")
  func refusalRuns() throws {
    let fixtures = try Fixtures()
    let sources = StageSources(flow: fixtures.flow, skipped: try repeated([2, 3, 4, 5, 6]), watching: nil,
      status: nil, settings: nil)
    let detail = StageDetail.make(.risk, from: sources)
    let rows = try #require(group(detail, L10n.stageRefusedSignals)?.rows)
    #expect(rows.count == 1)
    #expect(rows[0].text?.hasPrefix(String(localized: L10n.stageRun("10:02", "10:06", 5))) == true)
    #expect(value(detail, L10n.stageRefused) == "5")
  }

  @Test("Closeness rounds down: 100 % only when the check is there")
  func closenessRoundsDown() {
    #expect(StageDetail.whole(Decimal(string: "99.83") ?? 0) == "99")
    #expect(StageDetail.whole(100) == "100")
    #expect(StageDetail.whole(Decimal(string: "0.4") ?? 0) == "0")
  }

  @Test("Seconds read without trailing zeros")
  func seconds() {
    #expect(DurationText.number(Decimal(string: "3.000") ?? 0) == "3")
    #expect(DurationText.number(Decimal(string: "1.250") ?? 0) == "1.25")
  }

  @Test("An operator entry stop reads in words, not as the bot's English")
  func entryStopRefusal() {
    #expect(ApiText.refusalDetail(code: "ENTRY_STOP_SET", params: [:])
      == String(localized: L10n.refusalReasonEntryStopSet))
  }
}
