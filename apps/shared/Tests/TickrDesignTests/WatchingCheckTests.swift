import Foundation
import Testing
import TickrDesign
@testable import TickrKit

/// The apps' price rule, as both apps pass it.
private let prices = PriceText.money

/// A watching-v1 row as the API sends it, with its deciding check and the decision's levels.
private func row(
  measured: String?, op: String = ">", threshold: String?, passed: Bool = false, rule: String = "ask_above_trigger",
  closeness: String? = nil, cause: String? = nil, trigger: String? = nil, invalidation: String? = nil,
  againstTrigger: Bool = true, decisive: Bool = true
) throws -> WatchingRowV1 {
  func quoted(_ text: String?) -> String { text.map { "\"\($0)\"" } ?? "null" }
  let check = decisive ? """
    {"rule": "\(rule)", "measured": \(quoted(measured)), "operator": "\(op)",
     "threshold": \(quoted(threshold)), "passed": \(passed), "note": ""}
    """ : "null"
  let json = """
  {"symbol": "ABCD", "at": "2026-11-16T15:00:00.000Z", "strategy": {"name": "price-action-v3", "version": "1"},
   "verdict": "WATCH", "decisive_check": \(check),
   "closeness": \(quoted(closeness)), "closeness_cause": \(quoted(cause)),
   "quote_age_seconds": null, "quote_age_cause": "not recorded",
   "trigger": \(quoted(trigger)), "invalidation": \(quoted(invalidation)), "against_trigger": \(againstTrigger)}
  """
  return try Wire.decoder().decode(WatchingRowV1.self, from: Data(json.utf8))
}

@Suite struct WatchingCheckTests {
  /// How far a share may sit from the decimal the bot sent, after the conversion to a Double.
  static let tolerance = 1e-9

  @Test("Unmet, below the trigger: the ask, the trigger and what is left, never a false comparison")
  func unmetBelowTrigger() throws {
    // The owner's screenshot: "57.10 > 57.1099" read as true; the ask is below the trigger.
    let r = try row(measured: "57.10", threshold: "57.1099", closeness: "0.9677", trigger: "57.10985",
      invalidation: "56.80")
    #expect(WatchingCheck.title(r) == "Ask above trigger")
    #expect(WatchingCheck.state(r, prices: prices) == "57.10 · trigger 57.11 · 0.01 to go")
    let nine = try row(measured: "9.61", threshold: "9.6300", closeness: "0.9", trigger: "9.63", invalidation: "9.43")
    #expect(WatchingCheck.state(nine, prices: prices) == "9.61 · trigger 9.63 · 0.02 to go")
    // The bar shows the bot's distance from the invalidation, not a full bar.
    #expect(abs((WatchingCheck.progress(r) ?? 1) - 0.9677) < Self.tolerance)
    #expect(WatchingCheck.scale(r, prices: prices) == "Empty at the invalidation 56.80, full at the trigger 57.11")
    #expect(WatchingCheck.unmeasured(r) == nil)
  }

  @Test("Met: the side the check needed, from its operator")
  func met() throws {
    let above = try row(measured: "57.12", threshold: "57.11", passed: true, closeness: nil, trigger: "57.11")
    #expect(WatchingCheck.state(above, prices: prices) == "57.12 · above trigger 57.11")
    let below = try row(measured: "9.90", op: "<", threshold: "10.00", passed: true, trigger: "10")
    #expect(WatchingCheck.state(below, prices: prices) == "9.90 · below trigger 10.00")
    let at = try row(measured: "57.11", op: ">=", threshold: "57.11", passed: true, trigger: "57.11")
    #expect(WatchingCheck.state(at, prices: prices) == "57.11 · at trigger 57.11")
  }

  @Test("Exactly at the trigger of a strict check: not met, it needs the side beyond")
  func exactlyAtTrigger() throws {
    let above = try row(measured: "57.11", threshold: "57.11", closeness: "1", trigger: "57.11", invalidation: "56.80")
    #expect(WatchingCheck.state(above, prices: prices) == "57.11 · at the trigger, needs above")
    let below = try row(measured: "10.00", op: "<", threshold: "10.00", closeness: "1", trigger: "10", invalidation: "10.4")
    #expect(WatchingCheck.state(below, prices: prices) == "10.00 · at the trigger, needs below")
    // Unmet short side with room left: the distance is measured downwards.
    let short = try row(measured: "10.20", op: "<", threshold: "10.00", closeness: "0.5", trigger: "10",
      invalidation: "10.4")
    #expect(WatchingCheck.state(short, prices: prices) == "10.20 · trigger 10.00 · 0.20 to go")
  }

  @Test("Missing data: no failed check, a yes/no check, a check not against the trigger")
  func missingData() throws {
    // A WATCH with every check passed (no quote check recorded): says so, no bar.
    let noQuote = try row(measured: nil, threshold: nil, cause: "every recorded check passed", trigger: "9.6300",
      againstTrigger: false, decisive: false)
    #expect(WatchingCheck.title(noQuote) == nil)
    #expect(WatchingCheck.state(noQuote, prices: prices)
      == "Trigger 9.63 · every recorded check passed, no quote check recorded")
    #expect(WatchingCheck.progress(noQuote) == nil)
    #expect(WatchingCheck.unmeasured(noQuote) == nil)
    let nothing = try row(measured: nil, threshold: nil, cause: "every recorded check passed", againstTrigger: false,
      decisive: false)
    #expect(WatchingCheck.state(nothing, prices: prices) == "Every recorded check passed · nothing recorded to measure")
    // A yes/no check: "not met", no bar, the bot's cause instead.
    let flag = try row(measured: nil, op: "is", threshold: nil, rule: "quote_valid",
      cause: "quote_valid: a yes/no check has no measured value", againstTrigger: false)
    #expect(WatchingCheck.state(flag, prices: prices) == "not met")
    #expect(WatchingCheck.progress(flag) == nil)
    #expect(WatchingCheck.unmeasured(flag) != nil)
    // A count, not a price: what it needs, as recorded, with no price rounding and no scale.
    let count = try row(measured: "1", op: ">=", threshold: "2", rule: "trigger_confirmation", closeness: "0.5",
      trigger: "57.11", invalidation: "56.80", againstTrigger: false)
    #expect(WatchingCheck.state(count, prices: prices) == "1 · needs >= 2")
    #expect(WatchingCheck.scale(count, prices: prices) == nil)
    #expect(abs((WatchingCheck.progress(count) ?? 0) - 0.5) < Self.tolerance)
    // An older bot (no levels sent): the check's own values in words, never a false comparison.
    let old = try row(measured: "12.33", threshold: "12.35", closeness: "0.9983", againstTrigger: false)
    #expect(WatchingCheck.state(old, prices: prices) == "12.33 · needs > 12.35")
  }

  @Test("A check's values: a passed one states the comparison, a failed one what it needs")
  func valueText() throws {
    let passed = try #require(try row(measured: "12.40", threshold: "12.35", passed: true).decisiveCheck)
    #expect(passed.valueText == "12.40 > 12.35")
    let failed = try #require(try row(measured: "12.33", threshold: "12.35").decisiveCheck)
    #expect(failed.valueText == "12.33 · needs > 12.35")
    let flag = try #require(try row(measured: nil, op: "is", threshold: nil, passed: true).decisiveCheck)
    #expect(flag.valueText == "met")
  }

  @Test("An older bot's row decodes without the levels")
  func olderRow() throws {
    let json = """
    {"symbol": "ABCD", "at": "2026-11-16T15:00:00.000Z", "strategy": {"name": "price-action-v1", "version": "1"},
     "verdict": "WATCH", "decisive_check": null, "closeness": null, "closeness_cause": "every recorded check passed",
     "quote_age_seconds": null, "quote_age_cause": "not recorded"}
    """
    let r = try Wire.decoder().decode(WatchingRowV1.self, from: Data(json.utf8))
    #expect(r.trigger == nil && r.invalidation == nil && !r.againstTrigger)
  }
}
