import Foundation
import Testing
import TickrKit

/// The repository's contract fixtures (tests/api/fixtures), read from the checkout: the tests run
/// in the Simulator, which sees the Mac's files.
let fixturesDir = URL(filePath: #filePath)
  .deletingLastPathComponent()  // TickrTests
  .deletingLastPathComponent()  // Tests
  .deletingLastPathComponent()  // ios
  .deletingLastPathComponent()  // apps
  .deletingLastPathComponent()  // repository root
  .appending(path: "tests/api/fixtures")

/// A fixture as a JSON object, to change a field before decoding.
func fixtureObject(_ name: String) throws -> [String: Any] {
  let data = try Data(contentsOf: fixturesDir.appending(path: name))
  return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
}

/// A fixture decoded with the wire decoder.
func fixture<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
  try Wire.decoder().decode(T.self, from: Data(contentsOf: fixturesDir.appending(path: name)))
}

/// A JSON object decoded with the wire decoder.
func decode<T: Decodable>(_ type: T.Type, _ object: Any) throws -> T {
  try Wire.decoder().decode(T.self, from: JSONSerialization.data(withJSONObject: object))
}
