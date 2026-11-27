import Foundation
import Testing
@testable import TickrKit
@testable import TickrScreens

/// The Lab's Explain read: a slow answer for an old day or symbol never shows as current.
@MainActor
@Suite("Explain a symbol")
struct ExplainModelTests {
  static let base = APIClient.Endpoint(baseURL: URL(string: "http://127.0.0.1:8776")!)
  /// How long the slow first read takes, ignoring cancellation, in milliseconds.
  static let slowMilliseconds = 200
  /// Longer than the slow read, so its late answer has arrived before the checks.
  static let settleMilliseconds = 400

  /// The decisions fixture as if it were recorded on `day` (and for `symbol` when given).
  static func decisions(day: String, symbol: String? = nil) throws -> DecisionsV1 {
    let data = try Data(contentsOf: fixturesDir.appendingPathComponent("decisions-v1.json"))
    var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    object["day"] = day
    if let symbol { object["symbol"] = symbol }
    return try Wire.decoder().decode(DecisionsV1.self, from: JSONSerialization.data(withJSONObject: object))
  }

  @Test("A slow answer for the previous day is dropped when the day changed")
  func oldDayDropped() async throws {
    let old = try Self.decisions(day: "2026-11-13")
    let new = try Self.decisions(day: "2026-11-16")
    let model = ExplainModel { _, _, day in
      if day.text == old.day.text {
        // A server that answers late whatever the app does: the cancelled read still returns.
        try? await Task.sleep(for: .milliseconds(Self.slowMilliseconds))
        return old
      }
      return new
    }
    model.load(symbol: old.symbol, day: old.day, endpoint: Self.base)
    model.load(symbol: new.symbol, day: new.day, endpoint: Self.base)
    await model.settle()
    try await Task.sleep(for: .milliseconds(Self.settleMilliseconds))
    #expect(model.request == ExplainModel.Request(symbol: new.symbol, day: new.day))
    #expect(model.decisions?.day == new.day)
    #expect(model.loading == false)
  }

  @Test("An answer about another symbol or day than asked is not shown")
  func mismatchedAnswerDropped() async throws {
    let asked = try Self.decisions(day: "2026-11-16")
    let other = try Self.decisions(day: "2026-11-16", symbol: "WXYZ")
    let model = ExplainModel { _, _, _ in other }
    model.load(symbol: asked.symbol, day: asked.day, endpoint: Self.base)
    await model.settle()
    #expect(model.decisions == nil)
  }

  @Test("Cancelling stops the read and forgets its answer")
  func cancelForgets() async throws {
    let answer = try Self.decisions(day: "2026-11-16")
    let model = ExplainModel { _, _, _ in
      try? await Task.sleep(for: .milliseconds(Self.slowMilliseconds))
      return answer
    }
    model.load(symbol: answer.symbol, day: answer.day, endpoint: Self.base)
    model.cancel()
    try await Task.sleep(for: .milliseconds(Self.settleMilliseconds))
    #expect(model.request == nil)
    #expect(model.decisions == nil)
    #expect(model.loading == false)
  }
}
