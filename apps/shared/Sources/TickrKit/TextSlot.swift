import Foundation

/// A sentence in the person's language with one part a view draws itself (a relative time that
/// keeps counting, `Text(date, style: .relative)`): the text before that part and after it. The
/// sentence is read with `marker` in the part's place, so each language puts it where its grammar
/// wants ("… 2 s ago", "… hace 2 s").
public struct TextSlot: Hashable, Sendable {
  /// Stands for the part while the sentence is read: the object replacement character, which no
  /// translation contains.
  public static let marker = "\u{FFFC}"

  public let before: String
  public let after: String

  /// `sentence` split at its first `marker`; a sentence without one is all `before`.
  public init(_ sentence: String) {
    guard let range = sentence.range(of: Self.marker) else {
      before = sentence
      after = ""
      return
    }
    before = String(sentence[..<range.lowerBound])
    after = String(sentence[range.upperBound...])
  }
}
