import Foundation
import XCTest
@testable import ApertureKit

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

final class ContractTests: XCTestCase {
    func testEveryFixtureRoundTrips() throws {
        let names = try FileManager.default.contentsOfDirectory(atPath: fixturesDir.path)
            .filter { $0.hasSuffix(".json") }
            .sorted()
        XCTAssertFalse(names.isEmpty, "no fixtures found in \(fixturesDir.path)")
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
            let check = try XCTUnwrap(types[schema], "\(name): no Swift model for schema \(schema)")
            let (original, again) = try check(try fixture(name))
            XCTAssertEqual(original as? NSDictionary, again as? NSDictionary, name)
        }
    }

    func testEverySchemaHasASwiftModel() throws {
        let schemaDir = repoRoot.appendingPathComponent("src/aperture/api/schema")
        let names = try FileManager.default.contentsOfDirectory(atPath: schemaDir.path)
            .filter { $0.hasSuffix(".schema.json") }
            .map { String($0.dropLast(".schema.json".count)) }
        XCTAssertEqual(Set(names), ["status-v1", "command-v1", "status-response-v1",
                                    "command-accepted-v1", "pending-commands-v1", "error-v1",
                                    "days-v1", "day-v1", "bars-v1", "settings-v1"])
    }

    func testFullStatusValues() throws {
        let response = try Wire.decoder().decode(StatusResponseV1.self, from: fixture("status-response-v1.json"))
        let status = try XCTUnwrap(response.status)
        XCTAssertEqual(status.botState, .running)
        XCTAssertEqual(status.position?.stop.state, .verified)
        XCTAssertEqual(status.position?.stop.price?.text, "11.90")
        XCTAssertEqual(status.resultTodayGrossUsd.text, "-1.60")
        XCTAssertEqual(status.resultTodayGrossUsd.value, Decimal(string: "-1.6"))
        XCTAssertNil(status.freshness.lastQuoteAt)
        XCTAssertEqual(status.recentCommands.first?.kind, .entryStopOn)
        XCTAssertEqual(response.summary, status.entryBlock?.text)
        XCTAssertEqual(status.writtenAt.date.timeIntervalSince1970, 1_794_841_200.123, accuracy: 0.0005)
    }

    func testUnavailableStatus() throws {
        let response = try Wire.decoder().decode(StatusResponseV1.self,
                                                 from: fixture("status-response-v1.unavailable.json"))
        XCTAssertNil(response.status)
        XCTAssertNil(response.ageSeconds)
        XCTAssertEqual(response.unavailableCause, "the bot has not written a status file")
    }

    // Refuse, never guess: documents that break the wire rules do not decode.
    func testRefusesBrokenDocuments() throws {
        let base = try JSONSerialization.jsonObject(with: fixture("status-v1.example.json")) as! [String: Any]
        let mutations: [(String, (inout [String: Any]) -> Void)] = [
            ("future schema version", { $0["schema_version"] = 2 }),
            ("decimal as number", { $0["result_today_gross_usd"] = 1.5 }),
            ("time without milliseconds", { $0["written_at"] = "2026-11-16T15:00:00Z" }),
            ("time with offset", { $0["written_at"] = "2026-11-16T15:00:00.000+00:00" }),
            ("unknown enum value", { $0["bot_state"] = "sleeping" }),
            ("missing nullable key", { $0.removeValue(forKey: "position") }),
            ("missing key", { $0.removeValue(forKey: "environment") }),
        ]
        for (label, mutate) in mutations {
            var raw = base
            mutate(&raw)
            let data = try JSONSerialization.data(withJSONObject: raw)
            XCTAssertThrowsError(try Wire.decoder().decode(StatusV1.self, from: data), label)
        }
    }

    func testHistoryValues() throws {
        let day = try Wire.decoder().decode(DayV1.self, from: fixture("day-v1.json"))
        XCTAssertEqual(day.day.text, "2026-11-16")
        XCTAssertEqual(day.trades.first?.stopPrice?.text, "5.02")
        XCTAssertNil(day.trades.last?.stopPrice)
        XCTAssertEqual(day.trades.last?.resultR, Decimal(string: "0.082"))
        XCTAssertEqual(day.barSymbols, ["ABCD", "WXYZ"])
        let days = try Wire.decoder().decode(DaysV1.self, from: fixture("days-v1.json"))
        XCTAssertEqual(days.days.map(\.hasBars), [true, false])
    }

    func testSettingsValues() throws {
        let settings = try Wire.decoder().decode(SettingsV1.self, from: fixture("settings-v1.json"))
        XCTAssertEqual(settings.risk.maxDailyLossUsd.text, "300")
        XCTAssertEqual(settings.risk.maxOpenPositions, 1)
        XCTAssertEqual(settings.session.lastEntryMinutesBeforeClose, 15)
    }

    func testWireDate() throws {
        XCTAssertEqual(try WireDate("2026-11-16").month, 11)
        for bad in ["2026-1-16", "2026-13-01", "16.11.2026", "", "2026-11-16T00:00:00.000Z"] {
            XCTAssertThrowsError(try WireDate(bad), bad)
        }
        // 01:30 UTC on Nov 17 is still Nov 16 in New York.
        let late = try WireTime("2026-11-17T01:30:00.000Z")
        XCTAssertEqual(WireDate(newYorkDateOf: late.date).text, "2026-11-16")
    }

    func testDecimalStringValidation() {
        XCTAssertNoThrow(try DecimalString("0"))
        XCTAssertNoThrow(try DecimalString("-12.340"))
        for bad in ["", "1.", ".5", "1e3", "NaN", "+1", "1,5"] {
            XCTAssertThrowsError(try DecimalString(bad), bad)
        }
    }
}

final class HeadlineTests: XCTestCase {
    func response(_ name: String) throws -> StatusResponseV1 {
        try Wire.decoder().decode(StatusResponseV1.self, from: fixture(name))
    }

    func testBlockedIsAttention() throws {
        let headline = Headline.make(response: try response("status-response-v1.json"), fetchError: nil)
        XCTAssertEqual(headline.severity, .attention)
        XCTAssertEqual(headline.text, "One position is already open (limit 1).")
    }

    func testAllowedIsOK() throws {
        let headline = Headline.make(response: try response("status-response-v1.minimal.json"), fetchError: nil)
        XCTAssertEqual(headline, Headline(text: "Entries allowed.", severity: .ok))
    }

    func testStaleAndUnavailableAreAlarms() throws {
        XCTAssertEqual(Headline.make(response: try response("status-response-v1.stale.json"),
                                     fetchError: nil).severity, .alarm)
        XCTAssertEqual(Headline.make(response: try response("status-response-v1.unavailable.json"),
                                     fetchError: nil).severity, .alarm)
    }

    func testFetchErrorWinsOverOldResponse() throws {
        let headline = Headline.make(response: try response("status-response-v1.minimal.json"),
                                     fetchError: "Local API not reachable: refused")
        XCTAssertEqual(headline.severity, .alarm)
        XCTAssertTrue(headline.text.hasPrefix("Local API not reachable"))
    }
}
