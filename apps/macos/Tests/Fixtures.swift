@testable import ApertureKit
@testable import ApertureMac
import Foundation

/// The repository's contract fixtures (tests/api/fixtures): the same folder the previews read.
let fixturesDir = FixtureProtocol.folder

/// A fixture decoded with the wire decoder.
func fixture<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
  try Wire.decoder().decode(T.self, from: Data(contentsOf: fixturesDir.appendingPathComponent(name)))
}
