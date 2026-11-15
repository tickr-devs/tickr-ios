import Foundation

extension ReasonParam {
  /// Around a value's name in a reason sentence: {name}.
  static let open: Character = "{"
  static let close: Character = "}"

  /// `template` with each {name} of `names` replaced by its value, in one pass, so a value that
  /// itself holds braces stays as sent. Nil when the bot did not send one of the values; a brace
  /// pair that is not one of `names` stays as written.
  static func fill(_ template: String, names: [ReasonParam], params: [String: String]) -> String? {
    guard names.allSatisfy({ params[$0.rawValue] != nil }) else { return nil }
    let wanted = Set(names.map(\.rawValue))
    var result = ""
    var rest = template[...]
    while let start = rest.firstIndex(of: open), let end = rest[start...].firstIndex(of: close) {
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
