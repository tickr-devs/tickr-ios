import Foundation
import Testing
import TickrKit
@testable import TickrMac

/// The Settings session strip's motion: the now dot's ring plays when now passes a mark of the
/// session, and the now line moves once a minute.
@MainActor
@Suite("Session strip")
struct SessionStripTests {
  /// The jobs fixture's session (Mon Nov 16: open 09:30, last entry 15:45, flatten 15:55, close
  /// 16:00 New York).
  private func session() throws -> SessionTimesV1 {
    try #require(try fixture(JobsV1.self, "jobs-v1.json").session)
  }

  private func at(_ time: String) throws -> Date { try WireTime(time).date }

  @Test("The phase changes only when now passes a mark")
  func phase() throws {
    let session = try session()
    let phase = { (time: String) in SessionStrip.phase(at: try self.at(time), of: session) }
    #expect(try phase("2026-11-16T08:00:00.000Z") == 0)
    #expect(try phase("2026-11-16T09:00:00.000Z") == 1)  // 04:00, pre-market
    #expect(try phase("2026-11-16T14:29:59.000Z") == 1)
    #expect(try phase("2026-11-16T14:30:00.000Z") == 2)  // open
    #expect(try phase("2026-11-16T18:00:00.000Z") == 2)  // the same phase all through midday
    #expect(try phase("2026-11-16T20:45:00.000Z") == 3)  // last entry
    #expect(try phase("2026-11-16T20:55:00.000Z") == 4)  // flatten
    #expect(try phase("2026-11-16T21:00:00.000Z") == 5)  // close
    #expect(try phase("2026-11-17T01:00:00.000Z") == 6)  // 20:00, post-market ends
  }

  @Test("The now line moves to whole minutes only")
  func minute() throws {
    let start = try at("2026-11-16T15:00:00.000Z")
    #expect(SessionStrip.minute(try at("2026-11-16T15:00:59.900Z")) == start)
    #expect(SessionStrip.minute(start) == start)
    #expect(SessionStrip.minute(try at("2026-11-16T15:01:00.000Z")) == start.addingTimeInterval(60))
  }

  @Test("The extended hours come from the bot's calendar, the pre-market label with its time")
  func extendedHours() throws {
    let session = try session()
    let (start, end) = SessionStrip.bounds(session)
    #expect(start == (try at("2026-11-16T09:00:00.000Z")))  // 04:00 New York
    #expect(end == (try at("2026-11-17T01:00:00.000Z")))  // 20:00 New York
    #expect(SessionStrip.preLabel(session).key == "settings.preBacklogFrom")
  }
}
