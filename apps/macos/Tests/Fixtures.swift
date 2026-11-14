@testable import ApertureKit
import Foundation

/// The repository's contract fixtures (tests/api/fixtures), generated from the Python contract.
let fixturesDir = URL(fileURLWithPath: #filePath)
  .deletingLastPathComponent()  // Tests
  .deletingLastPathComponent()  // macos
  .deletingLastPathComponent()  // apps
  .deletingLastPathComponent()  // repository root
  .appendingPathComponent("tests/api/fixtures")

/// A fixture decoded with the wire decoder.
func fixture<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
  try Wire.decoder().decode(T.self, from: Data(contentsOf: fixturesDir.appendingPathComponent(name)))
}
