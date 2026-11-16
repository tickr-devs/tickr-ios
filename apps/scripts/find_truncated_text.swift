// Finds truncated text in the layout sweep's pictures (owner rule 2026-11-16: no truncated or
// clipped text anywhere in the apps, in English and Russian). SwiftUI ends a text that does not
// fit with an ellipsis, so every picture is read with Vision's text recognition and every line
// with an ellipsis is a failure, unless the ellipsis is part of the text itself: a string of the
// apps' String Catalogs that has one ("mean R · %@%: %@ … %@"), or one a control adds after a whole
// catalog text ("Stop Bot…", an action that asks first).
// Usage: swift apps/scripts/find_truncated_text.swift <folder or picture>...
// Prints one line per truncated text (picture, then the text as read) and exits 1 when there is
// any; exits 2 when no picture was found.
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
      for text in texts where text.contains(ellipsis) { patterns.insert(pattern(text)) }
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

let files = pictures(Array(CommandLine.arguments.dropFirst()))
guard !files.isEmpty else {
  print("no pictures found")
  exit(2)
}
let own = ownEllipses()
var truncated = 0
for file in files {
  for line in lines(in: file) where line.contains(ellipsis) || line.contains(dots) {
    let plain = normalized(line)
    let range = NSRange(location: 0, length: (plain as NSString).length)
    if own.contains(where: { $0.firstMatch(in: plain, range: range) != nil }) { continue }
    if plain.hasSuffix(ellipsis), ownEnding(plain) { continue }
    print("\(file.path)\t\(line)")
    truncated += 1
  }
}
print("\(files.count) pictures, \(truncated) truncated texts")
exit(truncated == 0 ? 0 : 1)
