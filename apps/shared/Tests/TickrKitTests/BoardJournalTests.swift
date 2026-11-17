import Foundation
import Testing
@testable import TickrKit

@Suite struct BoardJournalTests {
  func lines() throws -> [Board.Event] {
    let document = try Wire.decoder().decode(DayEventsV1.self, from: fixture("day-events-v1.json"))
    return Board.journal(document, price: { "\($0)" })
  }

  /// Every event of the fixture becomes a line, newest first, with no code of the bot in it.
  @Test func newestFirstInWords() throws {
    let shown = try lines()
    #expect(shown.count == 9)
    #expect(shown.map(\.time) == shown.map(\.time).sorted(by: >))
    #expect(shown.first?.id == "journal-752")
    #expect(shown.allSatisfy { !$0.text.contains("stopped-out") && !$0.text.contains("entry-stop") })
  }

  @Test func eachKindReadsAsItsLine() throws {
    let byID = Dictionary(uniqueKeysWithValues: try lines().map { ($0.id, $0) })
    let started = try #require(byID["journal-700"])
    #expect(started.text == "Started · price-action v1" && started.tone == .blue)
    let entry = try #require(byID["journal-729"])
    #expect(entry.text == "ABCD 100 @ 4.12 · stop 3.95" && entry.tone == .teal)
    let bought = try #require(byID["journal-733"])
    #expect(bought.tag == "BOUGHT" && bought.text == "ABCD 100 @ 4.11")
    #expect(byID["journal-736"]?.tag == "STOP SET")
    #expect(byID["journal-741"]?.text == "ABCD · to 4.02")
    #expect(byID["journal-745"]?.tag == "STOP FILLED")
    // A stop hit is an ordinary close: quiet, never the danger red.
    #expect(byID["journal-746"]?.tone == .muted)
    #expect(byID["journal-750"]?.tone == .amber)
    // A refused command's cause is read from its codes, in the person's language.
    let refused = try #require(byID["journal-752"])
    #expect(refused.tone == .red && refused.text.hasPrefix(Board.commandTitle(.flatten)))
  }

  @Test func anUnknownKindIsLeftOut() throws {
    var json = try #require(String(data: fixture("day-events-v1.json"), encoding: .utf8))
    json = json.replacingOccurrences(of: "\"bot-started\"", with: "\"something-new\"")
    let document = try Wire.decoder().decode(DayEventsV1.self, from: Data(json.utf8))
    #expect(Board.journal(document, price: { "\($0)" }).count == 8)
  }
}
