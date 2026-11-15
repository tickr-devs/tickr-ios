import Foundation
import Testing
@testable import TickrKit

/// A contract error names the field and what is wrong with it in the person's language, never
/// Swift's English debug form of a DecodingError. Tests read the English default values.
@Suite struct WireDetailTests {
  /// What `Wire.detail` says about the status example with one wire rule broken.
  func detail(_ mutate: (inout [String: Any]) -> Void) throws -> String {
    var raw = try #require(JSONSerialization.jsonObject(with: fixture("status-v1.example.json")) as? [String: Any])
    mutate(&raw)
    let data = try JSONSerialization.data(withJSONObject: raw)
    do {
      _ = try Wire.decoder().decode(StatusV1.self, from: data)
    } catch {
      return Wire.detail(error)
    }
    Issue.record("the broken document decoded")
    return ""
  }

  @Test func missingKey() throws {
    #expect(try detail { $0.removeValue(forKey: "environment") } == "field environment is missing")
    #expect(try detail { $0.removeValue(forKey: "position") } == "field position is missing")
  }

  @Test func nullValue() throws {
    #expect(try detail { $0["environment"] = NSNull() } == "field environment is null")
  }

  @Test func wrongType() throws {
    #expect(try detail { $0["positions"] = "none" } == "field positions has the wrong type")
  }

  @Test func unknownEnumValue() throws {
    #expect(try detail { $0["bot_state"] = "sleeping" } == "field bot_state has a value this app cannot read")
  }

  @Test func wireRuleKeepsItsCause() throws {
    #expect(try detail { $0["result_today_gross_usd"] = 1.5 }
      == "field result_today_gross_usd: expected a decimal string")
    #expect(try detail { $0["schema_version"] = 2 }
      == "field schema_version: unsupported schema_version 2, this app reads 1")
  }

  @Test func notJSON() {
    do {
      _ = try Wire.decoder().decode(StatusV1.self, from: Data("not json".utf8))
      Issue.record("text decoded as a status")
    } catch {
      #expect(Wire.detail(error) == "the answer is not valid JSON")
    }
  }

  @Test func pathNamesArrayElementsByIndex() {
    struct Key: CodingKey {
      var stringValue: String
      var intValue: Int?
      init(stringValue: String) { self.stringValue = stringValue }
      init(intValue: Int) { self.stringValue = "Index \(intValue)"; self.intValue = intValue }
    }
    #expect(Wire.path([Key(stringValue: "positions"), Key(intValue: 0), Key(stringValue: "stop")])
      == "positions.0.stop")
  }
}
