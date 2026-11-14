@testable import ApertureKit
import Foundation
import Testing

/// The repository's contract fixtures (tests/api/fixtures), generated from the Python contract.
let repoRoot = URL(fileURLWithPath: #filePath)
  .deletingLastPathComponent()  // ApertureKitTests
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
      "pending-commands-v1": { try roundTrip(PendingCommandsV1.self, $0) },
      "error-v1": { try roundTrip(ErrorV1.self, $0) },
      "days-v1": { try roundTrip(DaysV1.self, $0) },
      "day-v1": { try roundTrip(DayV1.self, $0) },
      "bars-v1": { try roundTrip(BarsV1.self, $0) },
      "settings-v1": { try roundTrip(SettingsV1.self, $0) },
    ]
    for name in names {
      let schema = String(name.prefix { $0 != "." })
      let check = try #require(types[schema], "\(name): no Swift model for schema \(schema)")
      let (original, again) = try check(try fixture(name))
      #expect(original as? NSDictionary == again as? NSDictionary, "\(name)")
    }
  }

  @Test func everySchemaHasASwiftModel() throws {
    let schemaDir = repoRoot.appendingPathComponent("src/aperture/api/schema")
    let names = try FileManager.default.contentsOfDirectory(atPath: schemaDir.path)
      .filter { $0.hasSuffix(".schema.json") }
      .map { String($0.dropLast(".schema.json".count)) }
    #expect(Set(names) == ["status-v1", "command-v1", "status-response-v1",
      "command-accepted-v1", "pending-commands-v1", "error-v1",
      "days-v1", "day-v1", "bars-v1", "settings-v1"])
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
    #expect(days.days.map(\.hasBars) == [true, false])
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

  @Test func blockedIsAttention() throws {
    let headline = Headline.make(response: try response("status-response-v1.json"), fetchError: nil)
    #expect(headline.severity == .attention)
    #expect(headline.text == "One position is already open (limit 1).")
  }

  @Test func allowedIsOK() throws {
    let headline = Headline.make(response: try response("status-response-v1.minimal.json"), fetchError: nil)
    #expect(headline == Headline(text: "Entries allowed.", severity: .ok))
  }

  @Test(arguments: ["status-response-v1.stale.json", "status-response-v1.unavailable.json"])
  func staleAndUnavailableAreAlarms(name: String) throws {
    #expect(Headline.make(response: try response(name), fetchError: nil).severity == .alarm)
  }

  @Test func fetchErrorWinsOverOldResponse() throws {
    let headline = Headline.make(response: try response("status-response-v1.minimal.json"),
      fetchError: "Local API not reachable: refused")
    #expect(headline.severity == .alarm)
    #expect(headline.text.hasPrefix("Local API not reachable"))
  }
}
