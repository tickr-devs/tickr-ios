@testable import ApertureKit
import Foundation
import Testing

@Suite("The bot's codes in words")
struct ApiTextTests {
  func block(_ cause: String, _ text: String = "bot text") throws -> EntryBlock {
    let json = #"{"cause": "\#(cause)", "text": "\#(text)", "attention": false}"#
    return try Wire.decoder().decode(EntryBlock.self, from: Data(json.utf8))
  }

  func fence(_ kind: String) throws -> Fence {
    let json = #"{"kind": "\#(kind)", "since": "2026-11-16T15:00:00.123Z", "text": "detail"}"#
    return try Wire.decoder().decode(Fence.self, from: Data(json.utf8))
  }

  @Test("Known codes read from the catalog; unknown ones fall back to the bot's text")
  func entryBlocks() throws {
    #expect(ApiText.entryBlock(try block("own_trade_open")) == String(localized: L10n.blockOwnTradeOpen))
    #expect(ApiText.entryBlock(try block("foreign_position")) == String(localized: L10n.fenceForeignPosition))
    #expect(ApiText.entryBlock(try block("brand_new_cause", "As the bot says")) == "As the bot says")
  }

  @Test("A fence reads as its kind and key")
  func fences() throws {
    #expect(ApiText.fence(try fence("foreign-position:EFGH"))
      == String(localized: L10n.fenceForeignPosition) + ApiText.keySeparator + "EFGH")
    #expect(ApiText.fence(try fence("entry-stop")) == String(localized: L10n.fenceEntryStop))
    #expect(ApiText.fence(try fence("new-kind:X")) == "new-kind:X")
  }

  @Test("The bot's detail stays readable after the fence's title")
  func fenceDetail() throws {
    #expect(ApiText.fenceWithDetail(try fence("entry-stop"))
      == String(localized: L10n.fenceEntryStop) + ApiText.detailSeparator + "detail")
  }

  @Test("A fence's or gate's cause reads as its sentence with the bot's values, else as the bot wrote it")
  func reasons() throws {
    let covered = #"{"kind": "unprotected", "since": "2026-11-16T15:00:00.123Z", "text": "bot words", "#
      + #""code": "stop_covers_part", "params": {"verified": "40", "expected": "100"}}"#
    let fence = try Wire.decoder().decode(Fence.self, from: Data(covered.utf8))
    let sentence = String(localized: L10n.fenceReasonStopCoversPart)
      .replacing("{verified}", with: "40").replacing("{expected}", with: "100")
    #expect(ApiText.fenceDetail(fence) == sentence)
    #expect(!sentence.contains("{"))
    let partial = covered.replacing(#", "expected": "100""#, with: "")
    #expect(ApiText.fenceDetail(try Wire.decoder().decode(Fence.self, from: Data(partial.utf8))) == "bot words")
    let unknown = covered.replacing("stop_covers_part", with: "brand_new")
    #expect(ApiText.fenceDetail(try Wire.decoder().decode(Fence.self, from: Data(unknown.utf8))) == "bot words")
    let closed = #"{"open": false, "cause": "bot words", "code": "trading_disabled", "#
      + #""params": {"environment": "production"}}"#
    let gate = try Wire.decoder().decode(Gate.self, from: Data(closed.utf8))
    #expect(ApiText.gate(gate)
      == String(localized: L10n.gateReasonTradingDisabled).replacing("{environment}", with: "production"))
  }

  @Test("Values fill a sentence in one pass; braces inside a value or unnamed stay as written")
  func fill() {
    let names: [ReasonParam] = [.symbol, .state]
    #expect(ReasonParam.fill("{symbol} is {state}", names: names, params: ["symbol": "{state}", "state": "x"])
      == "{state} is x")
    #expect(ReasonParam.fill("{symbol} and {other}", names: [.symbol], params: ["symbol": "AB"]) == "AB and {other}")
    #expect(ReasonParam.fill("{symbol} is {state}", names: names, params: ["symbol": "AB"]) == nil)
  }

  @Test("Order values and check rules translate; unknown ones stay as sent")
  func values() {
    #expect(ApiText.orderSide("SELL") == String(localized: L10n.orderSideSell))
    #expect(ApiText.orderType("STOP_LOSS") == String(localized: L10n.orderTypeStopLoss))
    #expect(ApiText.orderStatus("ACCEPTED") == String(localized: L10n.orderStatusAccepted))
    #expect(ApiText.orderStatus("WEIRD") == "WEIRD")
    #expect(ApiText.rule("spread_ratio") == String(localized: L10n.ruleSpreadRatio))
    #expect(ApiText.rule("new_rule") == "new_rule")
  }

  @Test("The headline is built from codes, with the status age in whole seconds")
  func headline() throws {
    let stale = try Wire.decoder().decode(StatusResponseV1.self, from: fixture("status-response-v1.stale.json"))
    #expect(Headline.make(response: stale, fetchError: nil).text == String(localized: L10n.headlineStale(42)))
    let calm = try Wire.decoder().decode(StatusResponseV1.self, from: fixture("status-response-v1.json"))
    #expect(Headline.make(response: calm, fetchError: nil).text == String(localized: L10n.blockOwnTradeOpen))
  }
}
