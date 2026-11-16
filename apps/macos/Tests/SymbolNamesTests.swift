import AppKit
import Foundation
import Testing

/// Every SF Symbol name the apps draw must exist: `Image(systemName:)` with an unknown name draws
/// nothing and logs only a console warning, so a wrong name ships as an empty circle or a blank
/// menu-bar item. The names are read from the sources of the shared package and of both apps:
/// each string literal passed to a `systemName:`, `systemImage:`, `symbol:` or
/// `systemSymbolName:` label, the value of each constant whose name ends in `Symbol`
/// (`static let universeSymbol = "…"`, the apps' convention for symbol names) and every constant
/// of TickrDesign's shared `Symbols` (`Symbols.swift`, one symbol per meaning). Both apps draw
/// from the one SF Symbols catalog, so this Mac's catalog checks the iOS names too.
@Suite("SF Symbol names")
struct SymbolNamesTests {
  /// The source folders read, relative to `apps/`.
  static let sourceFolders = ["shared/Sources", "macos/Tickr", "ios/Tickr"]
  /// Names that must be found, so a change that breaks the reading fails here instead of
  /// passing with nothing checked: one per source folder, and one of the shared `Symbols`.
  static let knownNames: Set<String> = ["questionmark.circle", "lock.open.fill", "clock.arrow.circlepath",
    "chevron.backward"]
  /// The file of TickrDesign's `Symbols`, whose constants are all symbol names.
  static let sharedSymbolsFile = "Symbols.swift"

  /// `apps/`, from this file's place in `apps/macos/Tests/`.
  static var apps: URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
  }

  /// Every symbol name in the sources, with where it is written ("macos/Tickr/X.swift:12").
  static func names() throws -> [(name: String, place: String)] {
    // A literal after a symbol argument label, or the value of a `…Symbol` constant.
    let literal = #/
      (?: \b (?: systemName | systemImage | symbol | systemSymbolName ) \s* : \s*
        | \b let \s+ \w* Symbol \s* (?: : \s* String \s* )? = \s* )
      " ( [a-z0-9]+ (?: \. [a-z0-9]+ )* ) "
      /#
    // A constant of the shared `Symbols`: every one is a symbol name, whatever it is called.
    let shared = #/
      \b let \s+ \w+ \s* = \s* " ( [a-z0-9]+ (?: \. [a-z0-9]+ )* ) "
      /#
    var found: [(name: String, place: String)] = []
    for folder in sourceFolders {
      let root = apps.appending(path: folder)
      let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
      for case let file as URL in files?.allObjects ?? [] where file.pathExtension == "swift" {
        let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
          let path = file.path.replacingOccurrences(of: apps.path + "/", with: "")
          for match in line.matches(of: literal) {
            found.append((String(match.output.1), "\(path):\(index + 1)"))
          }
          if file.lastPathComponent == sharedSymbolsFile {
            for match in line.matches(of: shared) {
              found.append((String(match.output.1), "\(path):\(index + 1)"))
            }
          }
        }
      }
    }
    return found
  }

  @Test("Every SF Symbol name in the apps' sources exists")
  func everyNameResolves() throws {
    let found = try Self.names()
    #expect(Self.knownNames.isSubset(of: Set(found.map(\.name))), "the sources were not read")
    for (name, place) in found {
      #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil,
        "\(place): no SF Symbol named \"\(name)\"")
    }
  }
}
