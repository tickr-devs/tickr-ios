import Foundation
import Testing
@testable import TickrKit

/// The repository's contract fixtures (tests/api/fixtures), generated from the Python contract.
let repoRoot = URL(fileURLWithPath: #filePath)
  .deletingLastPathComponent()  // TickrKitTests
  .deletingLastPathComponent()  // Tests
  .deletingLastPathComponent()  // shared
  .deletingLastPathComponent()  // apps
  .deletingLastPathComponent()  // repository root
let fixturesDir = repoRoot.appendingPathComponent("tests/api/fixtures")

func fixture(_ name: String) throws -> Data {
  try Data(contentsOf: fixturesDir.appendingPathComponent(name))
}

/// Decode with the Swift model, encode again, and compare as JSON values.
/// Equality proves every key and value of the fixture is modelled, including nulls.
func roundTrip<T: Codable>(_ type: T.Type, _ data: Data) throws -> (Any, Any) {
  let decoded = try Wire.decoder().decode(T.self, from: data)
  let encoded = try Wire.encoder().encode(decoded)
  return (try JSONSerialization.jsonObject(with: data), try JSONSerialization.jsonObject(with: encoded))
}

@Suite struct ContractTests {
  @Test func everyFixtureRoundTrips() throws {
    let names = try FileManager.default.contentsOfDirectory(atPath: fixturesDir.path)
      .filter { $0.hasSuffix(".json") }
      .sorted()
    #expect(!names.isEmpty, "no fixtures found in \(fixturesDir.path)")
    let types: [String: (Data) throws -> (Any, Any)] = [
      "status-v1": { try roundTrip(StatusV1.self, $0) },
      "status-response-v1": { try roundTrip(StatusResponseV1.self, $0) },
      "command-v1": { try roundTrip(CommandV1.self, $0) },
      "command-accepted-v1": { try roundTrip(CommandAcceptedV1.self, $0) },
      "bot-start-v1": { try roundTrip(BotStartV1.self, $0) },
      "paired-v1": { try roundTrip(PairedV1.self, $0) },
      "pending-commands-v1": { try roundTrip(PendingCommandsV1.self, $0) },
      "error-v1": { try roundTrip(ErrorV1.self, $0) },
      "days-v1": { try roundTrip(DaysV1.self, $0) },
      "day-v1": { try roundTrip(DayV1.self, $0) },
      "bars-v1": { try roundTrip(BarsV1.self, $0) },
      "settings-v1": { try roundTrip(SettingsV1.self, $0) },
      "config-v1": { try roundTrip(ConfigV1.self, $0) },
      "explain-v1": { try roundTrip(ExplainV1.self, $0) },
      "observers-v1": { try roundTrip(ObserversV1.self, $0) },
      "decisions-v1": { try roundTrip(DecisionsV1.self, $0) },
      "skipped-v1": { try roundTrip(SkippedV1.self, $0) },
      "performance-v1": { try roundTrip(PerformanceV1.self, $0) },
      "flow-v1": { try roundTrip(FlowV1.self, $0) },
      "watching-v1": { try roundTrip(WatchingV1.self, $0) },
      "symbols-v1": { try roundTrip(SymbolsV1.self, $0) },
      "movers-v1": { try roundTrip(MoversV1.self, $0) },
      "account-v1": { try roundTrip(AccountV1.self, $0) },
      "account-response-v1": { try roundTrip(AccountResponseV1.self, $0) },
      "chart-v1": { try roundTrip(ChartV1.self, $0) },
      "jobs-v1": { try roundTrip(JobsV1.self, $0) },
      "journal-v1": { try roundTrip(JournalV1.self, $0) },
      "advisor-runs-v1": { try roundTrip(AdvisorRunsV1.self, $0) },
      "lab-replay-v1": { try roundTrip(LabReplayV1.self, $0) },
      "trade-whatif-v1": { try roundTrip(TradeWhatIfV1.self, $0) },
    ]
    for name in names {
      let schema = String(name.prefix { $0 != "." })
      let check = try #require(types[schema], "\(name): no Swift model for schema \(schema)")
      let (original, again) = try check(try fixture(name))
      #expect(original as? NSDictionary == again as? NSDictionary, "\(name)")
    }
  }

  @Test func everySchemaHasASwiftModel() throws {
    let schemaDir = repoRoot.appendingPathComponent("src/tickr/api/schema")
    let names = try FileManager.default.contentsOfDirectory(atPath: schemaDir.path)
      .filter { $0.hasSuffix(".schema.json") }
      .map { String($0.dropLast(".schema.json".count)) }
    #expect(Set(names) == ["status-v1", "command-v1", "status-response-v1",
      "command-accepted-v1", "paired-v1", "pending-commands-v1", "error-v1",
      "days-v1", "day-v1", "bars-v1", "settings-v1", "explain-v1",
      "observers-v1", "decisions-v1", "skipped-v1", "performance-v1",
      "flow-v1", "watching-v1", "symbols-v1", "movers-v1", "account-v1", "account-response-v1",
      "chart-v1", "jobs-v1", "journal-v1", "lab-replay-v1", "bot-start-v1", "config-v1", "trade-whatif-v1",
      "advisor-runs-v1"])
  }

  @Test func flowStagesChipsAndCauses() throws {
    let flow = try Wire.decoder().decode(FlowV1.self, from: fixture("flow-v1.json"))
    #expect(flow.stages.map(\.stage) == FlowStage.allCases)
    #expect(flow.chips.first?.sources == [.gainers, .topActives])
    #expect(flow.chips.first { $0.symbol == "SPY" }?.excludedCause?.hasPrefix("SECURITY_TYPE_NOT_ALLOWED") == true)
    #expect(flow.reconcile.agreement == .match)
    #expect(flow.stops.map(\.state) == [.verified, .neverVerified, .pending])
    let empty = try Wire.decoder().decode(FlowV1.self, from: fixture("flow-v1.empty.json"))
    #expect(empty.reconcile.agreement == nil)
    #expect(empty.reconcile.agreementCause != nil)
  }

  @Test func watchingRowsAndDecisiveChecks() throws {
    let watching = try Wire.decoder().decode(WatchingV1.self, from: fixture("watching-v1.json"))
    #expect(watching.rows.map(\.symbol) == ["ABCD", "WXYZ", "EFGH"])
    #expect(watching.rows.first?.decisiveCheck?.rule == "ask_above_trigger")
    #expect(watching.rows.last?.closeness == nil)
    #expect(watching.rows.last?.closenessCause != nil)
  }

  @Test func watchingLatestSize() throws {
    let room = try Wire.decoder().decode(WatchingV1.self, from: fixture("watching-v1.daily-room.json"))
    let size = try #require(room.latestSize)
    #expect(size.symbol == "QRST")
    #expect(size.verdict == .watch)
    #expect(size.binding == .dailyRoom)
    #expect(size.bindingCause == nil)
    let empty = try Wire.decoder().decode(WatchingV1.self, from: fixture("watching-v1.empty.json"))
    #expect(empty.latestSize == nil)
  }

  @Test func chartBarsAndCause() throws {
    let chart = try Wire.decoder().decode(ChartV1.self, from: fixture("chart-v1.json"))
    #expect(chart.interval == .m5)
    #expect(chart.range == .oneDay)
    #expect(chart.bars.map(\.extended) == [true, true, false])
    #expect(chart.bars.last?.close.text == "12.47")
    #expect(chart.cause == nil)
    let empty = try Wire.decoder().decode(ChartV1.self, from: fixture("chart-v1.empty.json"))
    #expect(empty.bars.isEmpty)
    #expect(empty.cause != nil)
  }

  @Test func cleanDayVerdicts() throws {
    let days = try Wire.decoder().decode(DaysV1.self, from: fixture("days-v1.json"))
    #expect(Set(days.days.map(\.clean.verdict)) == [.clean, .notClean, .unknown])
    let dirty = try #require(days.days.first { $0.clean.verdict == .notClean })
    #expect(dirty.clean.causes.first?.kind == .reconcileMismatch)
    #expect(dirty.clean.causes.first?.journalSeqs == [8410, 8411])
    let open = try #require(days.days.first { $0.clean.verdict == .unknown })
    #expect(open.clean.cause != nil)
    #expect(open.clean.dayEndSeq == nil)
  }

  @Test func wireDateArithmetic() throws {
    #expect(try WireDate("2026-11-16").adding(days: -29) == WireDate("2026-10-18"))
    #expect(try WireDate("2026-03-08").adding(days: 1) == WireDate("2026-03-09"))
  }

  @Test func performanceFiguresAndCauses() throws {
    let performance = try Wire.decoder().decode(PerformanceV1.self, from: fixture("performance-v1.json"))
    #expect(performance.winRate.value?.value == Decimal(string: "0.4"))
    #expect(performance.winRate.cause == nil)
    #expect(performance.days.last?.cumulativeGrossR.value == 2)
    let empty = try Wire.decoder().decode(PerformanceV1.self, from: fixture("performance-v1.empty.json"))
    #expect(empty.profitFactorGross.value == nil)
    #expect(empty.profitFactorGross.cause == "no counted trades in the range")
  }

  @Test func entrySendRecords() throws {
    let status = try Wire.decoder().decode(StatusV1.self, from: fixture("status-v1.example.json"))
    #expect(status.position?.entry.sendOutcome == .acknowledged)
    #expect(status.position?.entry.sentOtherThanOnce == false)
    #expect(status.tradesToday.first?.entry.sendOutcome == .unknown)
    #expect(status.tradesToday.first?.entry.latestOutcome == .acknowledged)
    let day = try Wire.decoder().decode(DayV1.self, from: fixture("day-v1.json"))
    #expect(day.trades.first?.entry.sends == 1)
    #expect(day.trades.last?.entry.sends == nil)
    #expect(day.trades.last?.entryCause != nil)
  }

  @Test func skippedSignalsAndAdmissions() throws {
    let skipped = try Wire.decoder().decode(SkippedV1.self, from: fixture("skipped-v1.json"))
    #expect(skipped.signals.map(\.admission) == [.refused, .refused, .notEvaluated])
    #expect(skipped.signals.first?.refusalCause?.hasPrefix("POSITION_LIMIT_REACHED") == true)
    #expect(skipped.signals.first?.refusal?.code == "POSITION_LIMIT_REACHED")
    let cooldown = try #require(skipped.signals.first { $0.refusal?.code == "SYMBOL_COOLDOWN" }?.refusal)
    #expect(cooldown.since != nil && cooldown.until != nil)
    #expect(skipped.signals.last?.refusal == nil)
    #expect(skipped.signals.last?.entryPrice == nil)
    let decisions = try Wire.decoder().decode(DecisionsV1.self, from: fixture("decisions-v1.json"))
    #expect(decisions.decisions.map(\.admission) == [.notApplicable, .notEvaluated, .refused])
    let observers = try Wire.decoder().decode(ObserversV1.self, from: fixture("observers-v1.json"))
    #expect(observers.observers.first?.resultGrossUSD?.text == "-12.4000")
    #expect(observers.observers.last?.resultCause == "no captured bars for 2026-11-16")
  }

  @Test func tradeMetrics() throws {
    let response = try Wire.decoder().decode(StatusResponseV1.self, from: fixture("status-response-v1.json"))
    let trade = try #require(response.status?.tradesToday.first)
    #expect(trade.plannedLossUsd.text == "50")
    #expect(trade.stopConfirmedAfterSeconds?.text == "1.250")
    let day = try Wire.decoder().decode(DayV1.self, from: fixture("day-v1.json"))
    #expect(day.trades.first?.maeUsd?.text == "-2.20")
    #expect(day.trades.first?.mfeUsd?.text == "0.80")
    #expect(day.trades.last?.stopConfirmedAfterSeconds == nil)
    #expect(day.trades.last?.maeUsd == nil)
  }

  @Test func fullStatusValues() throws {
    let response = try Wire.decoder().decode(StatusResponseV1.self, from: fixture("status-response-v1.json"))
    let status = try #require(response.status)
    #expect(status.botState == .running)
    #expect(status.position?.stop.state == .verified)
    #expect(status.position?.stop.price?.text == "11.90")
    #expect(status.resultTodayGrossUsd.text == "-1.60")
    #expect(status.resultTodayGrossUsd.value == Decimal(string: "-1.6"))
    #expect(status.freshness.lastQuoteAt == nil)
    #expect(status.recentCommands.first?.kind == .entryStopOn)
    #expect(response.summary == status.entryBlock?.text)
    #expect(abs(status.writtenAt.date.timeIntervalSince1970 - 1_794_841_200.123) < 0.0005)
  }

  @Test func unavailableStatus() throws {
    let response = try Wire.decoder().decode(StatusResponseV1.self,
      from: fixture("status-response-v1.unavailable.json"))
    #expect(response.status == nil)
    #expect(response.ageSeconds == nil)
    #expect(response.unavailableCause == "the bot has not written a status file")
  }

  /// Refuse, never guess: documents that break the wire rules do not decode.
  @Test(arguments: [
    "future schema version", "decimal as number", "time without milliseconds", "time with offset",
    "unknown enum value", "missing nullable key", "missing key",
  ])
  func refusesBrokenDocument(label: String) throws {
    let mutations: [String: (inout [String: Any]) -> Void] = [
      "future schema version": { $0["schema_version"] = 2 },
      "decimal as number": { $0["result_today_gross_usd"] = 1.5 },
      "time without milliseconds": { $0["written_at"] = "2026-11-16T15:00:00Z" },
      "time with offset": { $0["written_at"] = "2026-11-16T15:00:00.000+00:00" },
      "unknown enum value": { $0["bot_state"] = "sleeping" },
      "missing nullable key": { $0.removeValue(forKey: "position") },
      "missing key": { $0.removeValue(forKey: "environment") },
    ]
    var raw = try #require(JSONSerialization.jsonObject(with: fixture("status-v1.example.json")) as? [String: Any])
    let mutate = try #require(mutations[label])
    mutate(&raw)
    let data = try JSONSerialization.data(withJSONObject: raw)
    #expect(throws: (any Error).self) { try Wire.decoder().decode(StatusV1.self, from: data) }
  }

  @Test func historyValues() throws {
    let day = try Wire.decoder().decode(DayV1.self, from: fixture("day-v1.json"))
    #expect(day.day.text == "2026-11-16")
    #expect(day.trades.first?.stopPrice?.text == "5.02")
    #expect(day.trades.last?.stopPrice == nil)
    #expect(day.trades.last?.resultR == Decimal(string: "0.082"))
    #expect(day.barSymbols == ["ABCD", "WXYZ"])
    let days = try Wire.decoder().decode(DaysV1.self, from: fixture("days-v1.json"))
    #expect(days.days.map(\.hasBars) == [true, false, true, true])
    #expect(days.days.map(\.clean.verdict) == [.unknown, .clean, .notClean, .unknown])
  }

  @Test func dailyMoneyAndPositionsValues() throws {
    let status = try Wire.decoder().decode(StatusV1.self, from: fixture("status-v1.example.json"))
    #expect(status.realizedLossTodayUsd?.text == "1.60")
    #expect(status.openReservationsUsd?.text == "50")
    #expect(status.dailyRoomUsd?.text == "248.40")
    #expect(status.positions.map(\.symbol) == ["ABCD"])
    let settings = try Wire.decoder().decode(SettingsV1.self, from: fixture("settings-v1.json"))
    #expect(settings.risk.minDailyRoomUsd.text == "10")
  }

  @Test func settingsValues() throws {
    let settings = try Wire.decoder().decode(SettingsV1.self, from: fixture("settings-v1.json"))
    #expect(settings.risk.maxDailyLossUsd.text == "300")
    #expect(settings.risk.maxOpenPositions == 1)
    #expect(settings.session.lastEntryMinutesBeforeClose == 15)
  }

  @Test func wireDate() throws {
    #expect(try WireDate("2026-11-16").month == 11)
    // 01:30 UTC on Nov 17 is still Nov 16 in New York.
    let late = try WireTime("2026-11-17T01:30:00.000Z")
    #expect(WireDate(newYorkDateOf: late.date).text == "2026-11-16")
  }

  @Test(arguments: ["2026-1-16", "2026-13-01", "16.11.2026", "", "2026-11-16T00:00:00.000Z"])
  func refusesBadWireDate(text: String) {
    #expect(throws: ContractError.self) { try WireDate(text) }
  }

  @Test func decimalStringAcceptsDecimals() throws {
    _ = try DecimalString("0")
    _ = try DecimalString("-12.340")
  }

  @Test(arguments: ["", "1.", ".5", "1e3", "NaN", "+1", "1,5"])
  func refusesBadDecimal(text: String) {
    #expect(throws: ContractError.self) { try DecimalString(text) }
  }
}

@Suite struct HeadlineTests {
  func response(_ name: String) throws -> StatusResponseV1 {
    try Wire.decoder().decode(StatusResponseV1.self, from: fixture(name))
  }

  @Test("An open, protected position is calm, and the headline says what the bot holds, not the refusal")
  func ordinaryBlockIsCalm() throws {
    let headline = Headline.make(response: try response("status-response-v1.json"), readFailed: false)
    #expect(headline.severity == .ok)
    #expect(headline.text == "Holding 1 position")
    #expect(headline.detail == "stop verified")
  }

  @Test func blockNeedingTheOperatorIsAttention() throws {
    let calm = try fixture("status-response-v1.json")
    let text = try #require(String(data: calm, encoding: .utf8))
      .replacingOccurrences(of: "\"attention\": false", with: "\"attention\": true")
    let response = try Wire.decoder().decode(StatusResponseV1.self, from: Data(text.utf8))
    #expect(response.status?.entryBlock?.attention == true)
    let headline = Headline.make(response: response, readFailed: false)
    #expect(headline.severity == .attention)
    #expect(headline.detail == "1 open · 1 protected by a verified broker stop")
  }

  @Test func allowedIsOK() throws {
    let headline = Headline.make(response: try response("status-response-v1.minimal.json"), readFailed: false)
    #expect(headline == Headline(text: "Entries allowed.", severity: .ok, detail: "No open position"))
  }

  @Test(arguments: ["status-response-v1.stale.json", "status-response-v1.unavailable.json"])
  func staleAndUnavailableAreAlarms(name: String) throws {
    #expect(Headline.make(response: try response(name), readFailed: false).severity == .alarm)
  }

  @Test func failedReadWinsOverOldResponse() throws {
    let headline = Headline.make(response: try response("status-response-v1.minimal.json"), readFailed: true)
    #expect(headline.severity == .alarm)
    #expect(headline.text == String(localized: L10n.headlineNoConnection))
  }

  @Test("A failed read's headline is plain words: no address, port or system error in it")
  func failedReadHeadlineHasNoTechnicalDetail() {
    let headline = Headline.make(response: nil, readFailed: true)
    #expect(headline.text == "Can't reach the bot. Entry status unknown.")
  }

  /// A stale status read again is older but no new state: its pulse key stays, though its text
  /// counts the age.
  @Test func staleStatusReadAgainKeepsItsPulse() throws {
    let older = try #require(String(data: try fixture("status-response-v1.stale.json"), encoding: .utf8))
      .replacingOccurrences(of: "\"age_seconds\": \"42.500\"", with: "\"age_seconds\": \"43.500\"")
    let first = Headline.make(response: try response("status-response-v1.stale.json"), readFailed: false)
    let second = Headline.make(
      response: try Wire.decoder().decode(StatusResponseV1.self, from: Data(older.utf8)), readFailed: false)
    #expect(first.text != second.text)
    #expect(first.pulse == .stale)
    #expect(second.pulse == first.pulse)
  }

  @Test func freshHeadlinePulsesOnItsText() throws {
    let headline = Headline.make(response: try response("status-response-v1.minimal.json"), readFailed: false)
    #expect(headline.pulse == .text(headline.text))
  }
}
