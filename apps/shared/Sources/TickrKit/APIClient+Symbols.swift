import Foundation

// The reads of the Symbols screen and the Fast movers card (docs/api.md, GET /symbols and
// GET /movers), apart from APIClient.swift to keep that file within SwiftLint's length limit.
extension APIClient {
  /// Path of the symbols read.
  static let symbolsPath = "/symbols"
  /// Path of the fast movers read.
  static let moversPath = "/movers"

  /// Every symbol of `day` with the furthest stage it got to and where and why it stands now.
  public func symbols(day: WireDate) async throws -> SymbolsV1 {
    try await perform(request(path: Self.symbolsPath, query: [(Self.dateQuery, day.text)], body: nil), expect: Self.ok)
  }

  /// The fast movers of `day`, newest bar first, with the active strategy's thresholds.
  public func movers(day: WireDate) async throws -> MoversV1 {
    try await perform(request(path: Self.moversPath, query: [(Self.dateQuery, day.text)], body: nil), expect: Self.ok)
  }
}
