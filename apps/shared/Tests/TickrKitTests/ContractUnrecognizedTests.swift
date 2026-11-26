import Foundation
import Testing
@testable import TickrKit

/// A later API may send a model state or a decider kind this app does not know yet: the app
/// reads it as `unrecognized` and the rest of the document still reads, instead of the whole
/// document failing for an installed app.
@Suite("Contract: a later API's enum value reads as unrecognized")
struct ContractUnrecognizedTests {
  /// The fixture `name` with `mutate` applied, as JSON data.
  func changed(_ name: String, _ mutate: (inout [String: Any]) -> Void) throws -> Data {
    var raw = try #require(JSONSerialization.jsonObject(with: fixture(name)) as? [String: Any])
    mutate(&raw)
    return try JSONSerialization.data(withJSONObject: raw)
  }

  @Test func knownValuesStillRead() throws {
    let system = try Wire.decoder().decode(SystemV1.self, from: fixture("system-v1.json"))
    #expect(system.model?.state == .off)
    let explain = try Wire.decoder().decode(ExplainV1.self, from: fixture("explain-v1.json"))
    #expect(explain.decider?.kind == .strategy)
    #expect(try Wire.decoder().decode(ModelState.self, from: Data(#""not_loaded""#.utf8)) == .notLoaded)
    #expect(try Wire.decoder().decode(DeciderKind.self, from: Data(#""model""#.utf8)) == .model)
  }

  @Test func laterModelStateKeepsTheSystemDocument() throws {
    let data = try changed("system-v1.json") { raw in
      var model = raw["model"] as? [String: Any] ?? [:]
      model["state"] = "warming_up"
      raw["model"] = model
    }
    let system = try Wire.decoder().decode(SystemV1.self, from: data)
    #expect(system.model?.state == .unrecognized)
    #expect(system.model?.enabled == false)
  }

  @Test func laterDeciderKindKeepsTheExplainDocument() throws {
    let data = try changed("explain-v1.json") { raw in
      var decider = raw["decider"] as? [String: Any] ?? [:]
      decider["kind"] = "ensemble"
      raw["decider"] = decider
    }
    let explain = try Wire.decoder().decode(ExplainV1.self, from: data)
    #expect(explain.decider?.kind == .unrecognized)
    #expect(explain.decider?.name == "price_action_v1")
  }

  @Test func aValueOfTheWrongTypeIsStillRefused() throws {
    #expect(throws: DecodingError.self) {
      try Wire.decoder().decode(DeciderKind.self, from: Data("1".utf8))
    }
  }
}
