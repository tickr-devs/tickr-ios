import Foundation
import Testing
@testable import TickrKit

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

  @Test("A known environment reads localized; another reads as the owner named it")
  func environments() {
    #expect(ApiText.environment("sandbox") == String(localized: L10n.environmentSandbox))
    #expect(ApiText.environment("production") == String(localized: L10n.environmentProduction))
    #expect(ApiText.environment("demo") == String(localized: L10n.environmentDemo))
    #expect(ApiText.environment("paper_v2") == "paper_v2")
    #expect(ApiText.environment("") == String(localized: L10n.environmentUnknown))
  }

  @Test("A fence reads as its kind; only a symbol key follows it, never a trade or order id")
  func fences() throws {
    #expect(ApiText.fence(try fence("foreign-position:EFGH"))
      == String(localized: L10n.fenceForeignPosition) + ApiText.keySeparator + "EFGH")
    #expect(ApiText.fence(try fence("entry-stop")) == String(localized: L10n.fenceEntryStop))
    #expect(ApiText.fence(try fence("foreign-order:manual-1")) == String(localized: L10n.fenceForeignOrder))
    #expect(ApiText.fence(try fence("exit-refused:t14")) == String(localized: L10n.fenceExitRefused))
    #expect(ApiText.fence(try fence("new-kind:X")) == String(localized: L10n.fenceOther))
    #expect(ApiText.fence(try fence("new-kind:X"), symbol: "ABCD")
      == "ABCD" + ApiText.keySeparator + String(localized: L10n.fenceOther))
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

  @Test("A refusal's detail reads as its sentence, a closed gate as the gate's; else nil")
  func refusals() {
    #expect(ApiText.refusalDetail(code: "QUOTE_STALE", params: ["age": "9", "limit": "5"])
      == RefusalReason.quoteStale.text(["age": "9", "limit": "5"]))
    #expect(ApiText.refusalDetail(code: "QUOTE_STALE", params: ["age": "9"]) == nil)
    #expect(ApiText.refusalDetail(code: "GATE_CLOSED", params: ["gate": "trading_disabled", "environment": "production"])
      == GateReason.tradingDisabled.text(["environment": "production"]))
    #expect(ApiText.refusalDetail(code: "GATE_CLOSED", params: [:]) == nil)
    #expect(ApiText.refusalDetail(code: "NEW_RULE", params: ["age": "9"]) == nil)
  }

  @Test("A code the bot writes in two shapes reads as the sentence whose values were sent")
  func shapes() throws {
    let total = ["realized": "-120", "reserved": "60", "new": "130", "total": "310", "ceiling": "300"]
    let room = ["room": "8", "min_room": "10", "ceiling": "300", "realized": "-232", "reserved": "60"]
    let byTotal = try #require(ApiText.refusalDetail(code: "DAILY_CEILING", params: total))
    let byRoom = try #require(ApiText.refusalDetail(code: "DAILY_CEILING", params: room))
    #expect(byTotal.contains("310") && !byTotal.contains("{"))
    #expect(byRoom.contains("8") && !byRoom.contains("{"))
    #expect(byTotal != byRoom)
    let stop = try #require(ApiText.refusalDetail(code: "ORDER_PRICES_INVALID", params: ["stop": "12.5", "limit": "12.4"]))
    #expect(stop.contains("12.5") && !stop.contains("{"))
  }

  @Test("Order values and check rules translate; unknown ones read as words, never as the code")
  func values() {
    #expect(ApiText.orderSide("SELL") == String(localized: L10n.orderSideSell))
    #expect(ApiText.orderType("STOP_LOSS") == String(localized: L10n.orderTypeStopLoss))
    #expect(ApiText.orderStatus("ACCEPTED") == String(localized: L10n.orderStatusAccepted))
    #expect(ApiText.orderStatus("WEIRD") == String(localized: L10n.orderStatusOther))
    #expect(ApiText.orderSide("SHORT") == String(localized: L10n.orderSideOther))
    #expect(ApiText.orderType("TRAILING") == String(localized: L10n.orderTypeOther))
    #expect(ApiText.rule("spread_ratio") == String(localized: L10n.ruleSpreadRatio))
    #expect(ApiText.rule("new_rule") == String(localized: L10n.ruleOther))
  }

  @Test("The headline is built from codes, with the status age in whole seconds")
  func headline() throws {
    let stale = try Wire.decoder().decode(StatusResponseV1.self, from: fixture("status-response-v1.stale.json"))
    #expect(Headline.make(response: stale, fetchError: nil).text == String(localized: L10n.headlineStale(42)))
    let calm = try Wire.decoder().decode(StatusResponseV1.self, from: fixture("status-response-v1.json"))
    // One open position with a verified stop: the headline says what the bot holds.
    #expect(Headline.make(response: calm, fetchError: nil).text == String(localized: L10n.headlineHoldingOne))
  }
}
