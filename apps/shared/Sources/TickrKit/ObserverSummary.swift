import Foundation

/// One observer's day as the Lab lists it: which symbols it would have entered and how many of
/// those the trading strategy also traded (agreement), and its result once the bot records one.
public struct ObserverSummary: Hashable, Sendable, Identifiable {
  public let name: String
  public let version: String
  /// Symbols the observer said ENTER on, in the order it first did.
  public let entered: [String]
  /// Those of `entered` the bot traded or holds that day.
  public let shared: [String]
  /// EXIT decisions.
  public let exits: Int
  /// The observer's simulated day result, and why it is missing when it is.
  public let result: Decimal?
  public let resultCause: String?

  public var id: String { "\(name) \(version)" }

  /// Share of `entered` the bot also traded, from 0 to 1; nil when the observer entered nothing.
  public var agreement: Double? {
    entered.isEmpty ? nil : Double(shared.count) / Double(entered.count)
  }

  /// `traded`: the symbols the trading strategy traded or holds on the observer's day.
  public init(_ observer: ObserverV1, traded: Set<String>) {
    name = observer.name
    version = observer.version
    var entered: [String] = []
    for decision in observer.decisions where decision.action == .enter && !entered.contains(decision.symbol) {
      entered.append(decision.symbol)
    }
    self.entered = entered
    shared = entered.filter(traded.contains)
    exits = observer.decisions.filter { $0.action == .exit }.count
    result = observer.resultGrossUSD?.value
    resultCause = ApiText.prose(observer.resultCauseCodes, text: observer.resultCause)
  }
}
