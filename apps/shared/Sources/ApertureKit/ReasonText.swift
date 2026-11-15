import Foundation

extension ReasonParam {
  /// Around a value's name in a reason sentence: {name}.
  static let tokenStart: Character = "{"
  static let tokenEnd: Character = "}"

  /// `template` with each {name} of `names` replaced by its value, in one pass, so a value that
  /// itself holds braces stays as sent. Nil when the bot did not send one of the values; a brace
  /// pair that is not one of `names` stays as written.
  static func fill(_ template: String, names: [ReasonParam], params: [String: String]) -> String? {
    guard names.allSatisfy({ params[$0.rawValue] != nil }) else { return nil }
    let wanted = Set(names.map(\.rawValue))
    var result = ""
    var rest = template[...]
    while let start = rest.firstIndex(of: tokenStart), let end = rest[start...].firstIndex(of: tokenEnd) {
      result += rest[..<start]
      let name = String(rest[rest.index(after: start)..<end])
      if wanted.contains(name), let value = params[name] {
        result += value
      } else {
        result += rest[start...end]
      }
      rest = rest[rest.index(after: end)...]
    }
    return result + rest
  }
}

/// One way the bot words a reason code (api/reasons.py shapes): the sentence, naming each value
/// of `names` as {name}.
public struct ReasonSentence: Sendable {
  public let template: LocalizedStringResource
  public let names: [ReasonParam]

  public init(_ template: LocalizedStringResource, _ names: [ReasonParam]) {
    self.template = template
    self.names = names
  }

  /// The sentence with the values the bot sent; nil when one of them is missing.
  public func text(_ params: [String: String]) -> String? {
    ReasonParam.fill(String(localized: template), names: names, params: params)
  }
}
