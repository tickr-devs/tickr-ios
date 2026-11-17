// Finds truncated text in the layout sweep's pictures (owner rule 2026-11-16: no truncated or
// clipped text anywhere in the apps, in English and Russian). SwiftUI ends a text that does not
// fit with an ellipsis, so every picture is read with Vision's text recognition and every line
// with an ellipsis is a failure, unless the ellipsis is part of the text itself: a string of the
// apps' String Catalogs that has one ("mean R · %@%: %@ … %@"), or one a control adds after a whole
// catalog text ("Stop Bot…", an action that asks first).
// Usage: swift apps/scripts/find_truncated_text.swift <folder or picture>...
// Prints one line per truncated text (picture, then the text as read) and exits 1 when there is
// any; exits 2 when no picture was found.
// `--self-test` instead checks the rules on recognized lines written below (`selfTestCases`),
// exits 1 when one is judged wrongly (CI: macos-app.yml).
import AppKit
import Foundation
import Vision

/// The repository's apps folder, found from this file's place (apps/scripts).
let apps = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
/// The String Catalogs whose texts may carry an ellipsis of their own.
let catalogs = [
  "macos/Tickr/Localizable.xcstrings",
  "ios/Tickr/Localizable.xcstrings",
  "shared/Sources/TickrKit/Resources/Localizable.xcstrings",
]
/// The ellipsis SwiftUI draws, and the three dots text recognition sometimes reads it as.
let ellipsis = "…"
let dots = "..."
/// Fewest letters of a whole catalog text that may stand before an ellipsis: shorter ones ("OK")
/// would excuse too many cut words.
let shortest = 4
/// Languages the pictures are read in (the apps' two).
let languages = ["en-US", "ru-RU"]

/// Catalog texts with an ellipsis of their own, as patterns that match them with their
/// placeholders filled in, as recognition reads them; and every whole catalog text without
/// placeholders, normalized: a control may add the ellipsis itself ("Stop Bot…", an action that
/// asks first), and a whole text before an ellipsis is not cut.
var wholeTexts: Set<String> = []

func ownEllipses() -> [NSRegularExpression] {
  var patterns: Set<String> = []
  for path in catalogs {
    guard let data = try? Data(contentsOf: apps.appending(path: path)),
      let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let strings = root["strings"] as? [String: Any] else {
      FileHandle.standardError.write(Data("cannot read \(path)\n".utf8))
      exit(2)
    }
    for (key, entry) in strings {
      var texts = [key]
      let localizations = (entry as? [String: Any])?["localizations"] as? [String: Any] ?? [:]
      for case let localization as [String: Any] in localizations.values {
        collect(localization, into: &texts)
      }
      for text in texts where text.contains(ellipsis) {
        patterns.insert(pattern(text))
        tailPatterns.formUnion(tails(text))
      }
      for text in texts where !text.contains("%") {
        let plain = normalized(text)
        if plain.count >= shortest { wholeTexts.insert(plain) }
      }
    }
  }
  return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: [.caseInsensitive]) }
}

/// Every `value` of a localization, its plural and device variations included.
func collect(_ node: Any, into texts: inout [String]) {
  if let dictionary = node as? [String: Any] {
    if let unit = dictionary["stringUnit"] as? [String: Any], let value = unit["value"] as? String {
      texts.append(value)
    }
    for (key, child) in dictionary where key != "stringUnit" { collect(child, into: &texts) }
  } else if let array = node as? [Any] {
    for child in array { collect(child, into: &texts) }
  }
}

/// A catalog text as a pattern over `normalized` text: placeholders match anything.
func pattern(_ text: String) -> String {
  let placeholder = try? NSRegularExpression(pattern: "%(\\d+\\$)?(lld|ld|d|@|f|\\.\\d+f|u|s)")
  let ns = text as NSString
  var parts: [String] = []
  var last = 0
  for match in placeholder?.matches(in: text, range: NSRange(location: 0, length: ns.length)) ?? [] {
    parts.append(NSRegularExpression.escapedPattern(
      for: normalized(ns.substring(with: NSRange(location: last, length: match.range.location - last)))))
    parts.append(".*")
    last = match.range.location + match.range.length
  }
  parts.append(NSRegularExpression.escapedPattern(for: normalized(ns.substring(from: last))))
  return parts.joined()
}

/// Catalog texts whose own ellipsis has more after it, as patterns over a whole recognized line
/// (`shaped`) that may lack the text's first words (`tails`).
var tailPatterns: Set<String> = []

/// For a catalog text whose own ellipsis has values after it ("mean R · %@%: %@ … %@"): patterns
/// of the whole line as recognition may read it with the words before the first value split off
/// into a line of their own ("• 95%: -0.21 R ... +0.57 R" without "mean R"). Each keeps the rest
/// of the text exactly (its separators, "%:", the ellipsis and at least one character for every
/// value, so something follows the ellipsis) and may drop only whole leading words, never all of
/// them: a text SwiftUI cuts ends at its ellipsis, and a line that differs anywhere else is not
/// this text.
func tails(_ text: String) -> [String] {
  let ns = text as NSString
  let all = NSRange(location: 0, length: ns.length)
  guard let first = placeholder?.firstMatch(in: text, range: all),
    let last = text.range(of: ellipsis, options: .backwards),
    !text[last.upperBound...].trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
  let lead = ns.substring(to: first.range.location)
  let rest = rawPattern(ns.substring(from: first.range.location))
  // Every ending of the lead at a word's start, down to its last word or separator.
  let words = lead.split(separator: " ", omittingEmptySubsequences: true)
  return words.indices.map { start in
    "^" + rawPattern(words[start...].joined(separator: " ") + " ") + rest + "$"
  }
}

/// The values a catalog text leaves to its arguments (`%@`, `%1$@`, `%lld`, `%.2f`).
let placeholder = try? NSRegularExpression(pattern: "%(\\d+\\$)?(lld|ld|d|@|f|\\.\\d+f|u|s)")

/// A catalog text as a pattern over `shaped` text, word for word: a value is one or more
/// characters, spaces may be read or not, "·" may be read as "•", the ellipsis as three dots.
func rawPattern(_ text: String) -> String {
  let ns = text as NSString
  var parts: [String] = []
  var last = 0
  for match in placeholder?.matches(in: text, range: NSRange(location: 0, length: ns.length)) ?? [] {
    parts.append(literal(ns.substring(with: NSRange(location: last, length: match.range.location - last))))
    parts.append(".+")
    last = match.range.location + match.range.length
  }
  parts.append(literal(ns.substring(from: last)))
  return parts.joined()
}

/// The words between a text's values, as a pattern ("%%" is a written "%").
func literal(_ text: String) -> String {
  text.replacingOccurrences(of: "%%", with: "%").map { character -> String in
    switch character {
    case " ": return "\\s*"
    case "·": return "[·•]"
    case Character(ellipsis): return "(?:…|\\.\\.\\.)"
    default: return NSRegularExpression.escapedPattern(for: String(character))
    }
  }.joined()
}

/// A recognized line as the tail patterns read it: trimmed, spaces kept.
func shaped(_ line: String) -> String {
  line.trimmingCharacters(in: .whitespaces)
}

/// Text reduced to its letters, digits and ellipses, lowercased: recognition misreads spacing,
/// punctuation and separators ("·" as "•"), and reads the ellipsis as three dots.
func normalized(_ text: String) -> String {
  String(text.replacingOccurrences(of: dots, with: ellipsis).lowercased()
    .filter { $0.isLetter || $0.isNumber || String($0) == ellipsis })
}

/// Whether a line read as ending in an ellipsis ends with a whole catalog text and an ellipsis,
/// allowing one letter misread (recognition reads "стратегия" as "стратетия").
func ownEnding(_ plain: String) -> Bool {
  let read = Array(plain.dropLast())
  return wholeTexts.contains { whole in
    let text = Array(whole.hasSuffix(ellipsis) ? String(whole.dropLast()) : whole)
    guard read.count >= text.count else { return false }
    return distance(Array(read.suffix(text.count)), text) <= misreads
  }
}

/// Letters recognition may misread in a whole text before an ellipsis.
let misreads = 1

/// Edit distance between two short texts.
func distance(_ a: [Character], _ b: [Character]) -> Int {
  var row = Array(0...b.count)
  for (i, x) in a.enumerated() {
    var previous = row[0]
    row[0] = i + 1
    for (j, y) in b.enumerated() {
      let current = row[j + 1]
      row[j + 1] = min(row[j + 1] + 1, row[j] + 1, previous + (x == y ? 0 : 1))
      previous = current
    }
  }
  return row[b.count]
}

/// Every PNG under the arguments.
func pictures(_ arguments: [String]) -> [URL] {
  var found: [URL] = []
  for argument in arguments {
    let url = URL(fileURLWithPath: argument)
    if url.pathExtension.lowercased() == "png" {
      found.append(url)
      continue
    }
    let walker = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil)
    while let file = walker?.nextObject() as? URL {
      if file.pathExtension.lowercased() == "png" { found.append(file) }
    }
  }
  return found.sorted { $0.path < $1.path }
}

/// The lines of text in a picture.
func lines(in picture: URL) -> [String] {
  guard let image = NSImage(contentsOf: picture),
    let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return [] }
  let request = VNRecognizeTextRequest()
  request.recognitionLevel = .accurate
  request.recognitionLanguages = languages
  request.usesLanguageCorrection = false
  try? VNImageRequestHandler(cgImage: cgImage).perform([request])
  return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
}

/// Whether a recognized line is a cut text: it has an ellipsis that is not a catalog text's own.
func isTruncated(_ line: String, own: [NSRegularExpression], tails: [NSRegularExpression]) -> Bool {
  guard line.contains(ellipsis) || line.contains(dots) else { return false }
  let plain = normalized(line)
  let range = NSRange(location: 0, length: (plain as NSString).length)
  if own.contains(where: { $0.firstMatch(in: plain, range: range) != nil }) { return false }
  let read = shaped(line)
  let whole = NSRange(location: 0, length: (read as NSString).length)
  if tails.contains(where: { $0.firstMatch(in: read, range: whole) != nil }) { return false }
  if plain.hasSuffix(ellipsis), ownEnding(plain) { return false }
  return true
}

/// Recognized lines and whether each is a cut text, checked by `--self-test`.
let selfTestCases: [(line: String, truncated: Bool)] = [
  // The catalog's own "mean R · %@%: %@ … %@", whole and with its first words split off.
  ("mean R · 95%: -0.21 R … +0.57 R", false),
  ("• 95%: -0.21 R ... +0.57 R", false),
  ("R · 95%: -0.21 R … +0.57 R", false),
  ("средний R · 95%: -0.21 R … +0.57 R", false),
  // The same ending, but nothing after its ellipsis: cut.
  ("• 95%: -0.21 R ...", true),
  // Its ellipsis followed by text, but the rest is not the catalog text's ("%:" missing, or no
  // separator before the value once the words are gone).
  ("95% -0.21 R … +0.57 R", true),
  ("95%: -0.21 R … +0.57 R", true),
  ("max drawdown … +1.10 R", true),
  // Texts that are not in a catalog, ending in an ellipsis: cut.
  ("max drawdo...", true),
  ("профит-фак…", true),
  ("Some words of a title that did not fit…", true),
  // A whole catalog text with an ellipsis a control added ("Stop Bot…"): not cut.
  ("Stop Bot…", false),
  // No ellipsis at all.
  ("max drawdown", false),
]

let own = ownEllipses()
let tailExpressions = tailPatterns.compactMap { try? NSRegularExpression(pattern: $0, options: [.caseInsensitive]) }
if CommandLine.arguments.dropFirst().first == "--self-test" {
  var wrong = 0
  for test in selfTestCases where isTruncated(test.line, own: own, tails: tailExpressions) != test.truncated {
    print("judged wrongly: \(test.line) (expected \(test.truncated ? "cut" : "not cut"))")
    wrong += 1
  }
  print("\(selfTestCases.count) lines, \(wrong) judged wrongly")
  exit(wrong == 0 ? 0 : 1)
}

let files = pictures(Array(CommandLine.arguments.dropFirst()))
guard !files.isEmpty else {
  print("no pictures found")
  exit(2)
}
var truncated = 0
for file in files {
  for line in lines(in: file) where isTruncated(line, own: own, tails: tailExpressions) {
    print("\(file.path)\t\(line)")
    truncated += 1
  }
}
print("\(files.count) pictures, \(truncated) truncated texts")
exit(truncated == 0 ? 0 : 1)
