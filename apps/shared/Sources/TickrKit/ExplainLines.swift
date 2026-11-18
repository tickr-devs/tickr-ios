import Foundation

extension DecisionV1 {
  /// The lines an explanation lists, what decided the verdict first: the failed checks, then the
  /// admission (`checks.count`), then the passed checks, each group in the strategy's order. A card
  /// that fits only a few rows then shows why, never only a passed check (owner test 2026-11-18).
  public var explainLines: [Int] {
    let failed = checks.indices.filter { !checks[$0].passed }
    let passed = checks.indices.filter { checks[$0].passed }
    return failed + [checks.count] + passed
  }
}
