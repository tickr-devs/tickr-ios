import Foundation
import Testing
@testable import TickrKit

/// Cancel entry (mockup v160) on the contract fixtures: the command, the row of a working entry,
/// "Cancelling…" from the press until a broker read, "Cancelled at broker" for a moment once the
/// order is gone with nothing filled, and a fill that is never called cancelled.
@Suite struct EntryCancelTests {
  /// The working-entry status fixture (KLMN working, ABCD open), its `status` changed first.
  private func status(_ change: (inout [String: Any]) -> Void = { _ in }) throws -> StatusV1 {
    var response = try #require(JSONSerialization.jsonObject(with: fixture(Self.name)) as? [String: Any])
    var status = try #require(response["status"] as? [String: Any])
    change(&status)
    response["status"] = status
    let data = try JSONSerialization.data(withJSONObject: response)
    return try #require(try Wire.decoder().decode(StatusResponseV1.self, from: data).status)
  }

  private static let name = "status-response-v1.working-entry.json"
  private static let symbol = "KLMN"
  private static let commandId = "c-cancel-1"
  private static let start = Date(timeIntervalSince1970: 1_800_000_000)

  /// The status with KLMN's entry no longer listed; `filled` lists a KLMN position instead.
  private func entryGone(filled: Bool = false) throws -> StatusV1 {
    try status { status in
      status["working_entries"] = []
      if filled, var positions = status["positions"] as? [[String: Any]], var position = positions.first {
        position["symbol"] = Self.symbol
        positions.append(position)
        status["positions"] = positions
      }
    }
  }

  /// The status with KLMN's entry asked to cancel at the broker.
  private func cancelRequested() throws -> StatusV1 {
    try status { status in
      var entries = status["working_entries"] as? [[String: Any]] ?? []
      entries[0]["cancel_requested"] = true
      status["working_entries"] = entries
    }
  }

  /// The API's receipt of the operator's cancel of KLMN.
  private func queued() throws -> CommandV1 {
    let json: [String: Any] = ["command_id": Self.commandId, "kind": "cancel-own-orders",
      "requested_at": "2026-11-16T15:00:02.000Z", "source": "api", "symbol": Self.symbol,
      "mode": NSNull(), "schema_version": 1]
    return try Wire.decoder().decode(CommandV1.self, from: JSONSerialization.data(withJSONObject: json))
  }

  @Test func cancelEntrySendsCancelOwnOrdersForItsSymbol() {
    let command = OperatorCommand.cancelEntry(Self.symbol)
    #expect(command.kind == .cancelOwnOrders)
    #expect(command.path == OperatorCommand.cancelOwnOrders.path)
    #expect(command.body == ["symbol": Self.symbol])
    #expect(OperatorCommand.cancelOwnOrders.body.isEmpty, "cancelling every own order keeps its empty body")
  }

  @Test func aWorkingEntryShowsItsOrder() throws {
    let status = try status()
    let rows = EntryCancelWatch().rows(status, inFlight: nil)
    let row = try #require(rows.first)
    #expect(rows.count == 1)
    #expect(row.symbol == Self.symbol)
    #expect(row.quantity == 15)
    #expect(row.limitPrice == Decimal(string: "9.02"))
    #expect(row.stopPrice == Decimal(string: "8.78"))
    #expect(row.plannedLossUsd == Decimal(string: "3.60"))
    #expect(row.sentAt == status.workingEntries.first?.entry.sentAt?.date)
    #expect(row.phase == .working)
  }

  @Test func cancellingFromThePressUntilTheBrokerRead() throws {
    let working = try status()
    var watch = EntryCancelWatch()
    watch.read(working, now: Self.start)
    #expect(watch.rows(working, inFlight: .cancelEntry(Self.symbol)).first?.phase == .cancelling, "while sent")
    #expect(watch.rows(working, inFlight: .cancelEntry("ABCD")).first?.phase == .working, "another symbol's cancel")
    watch.queued(try queued())
    #expect(watch.rows(working, inFlight: nil).first?.phase == .cancelling, "queued, the bot not yet at it")
    let asked = try cancelRequested()
    watch.read(asked, now: Self.start + 1)
    #expect(watch.rows(asked, inFlight: nil).first?.phase == .cancelling, "the bot asked the broker")
  }

  @Test func goneWithNothingFilledIsCancelledForAMoment() throws {
    var watch = EntryCancelWatch()
    watch.read(try cancelRequested(), now: Self.start)
    let gone = try entryGone()
    watch.read(gone, now: Self.start + 1)
    let rows = watch.rows(gone, inFlight: nil)
    #expect(rows.map(\.symbol) == [Self.symbol])
    #expect(rows.first?.phase == .cancelled)
    watch.read(gone, now: Self.start + 1 + EntryCancelWatch.cancelledShownSeconds)
    #expect(watch.rows(gone, inFlight: nil).isEmpty, "then the card is empty again")
  }

  @Test func theOperatorsQueuedCancelCountsBeforeTheBotMarksIt() throws {
    var watch = EntryCancelWatch()
    watch.read(try status(), now: Self.start)
    watch.queued(try queued())
    let gone = try entryGone()
    watch.read(gone, now: Self.start + 1)
    #expect(watch.rows(gone, inFlight: nil).first?.phase == .cancelled)
  }

  @Test func aFillIsNeverCalledCancelled() throws {
    var watch = EntryCancelWatch()
    watch.read(try cancelRequested(), now: Self.start)
    let filled = try entryGone(filled: true)
    watch.read(filled, now: Self.start + 1)
    #expect(watch.rows(filled, inFlight: nil).isEmpty, "a partial fill is a position, shown as one")
  }

  @Test func anEntryGoneWithoutAnyCancelIsNotSaidCancelled() throws {
    var watch = EntryCancelWatch()
    watch.read(try status(), now: Self.start)
    let gone = try entryGone()
    watch.read(gone, now: Self.start + 1)
    #expect(watch.rows(gone, inFlight: nil).isEmpty, "the bot's own cancel or expiry is not the operator's")
  }

  @Test func aRefusedCancelIsNoLongerOnItsWay() throws {
    var watch = EntryCancelWatch()
    watch.queued(try queued())
    let refused = try status { status in
      var records = status["recent_commands"] as? [[String: Any]] ?? []
      records.insert(["command_id": Self.commandId, "kind": "cancel-own-orders",
        "requested_at": "2026-11-16T15:00:02.000Z", "processed_at": "2026-11-16T15:00:02.500Z",
        "outcome": "refused", "cause": "no working entry in KLMN", "cause_codes": []], at: 0)
      status["recent_commands"] = records
    }
    watch.read(refused, now: Self.start)
    #expect(watch.rows(refused, inFlight: nil).first?.phase == .working)
  }

  @Test func theHeadlineSaysHowManyEntriesWorkWithNoPositionOpen() throws {
    let one = try status { $0["positions"] = [] }
    #expect(Headline.detail(one) == "1 entry order working")
    let two = try status { status in
      status["positions"] = []
      var entries = status["working_entries"] as? [[String: Any]] ?? []
      var other = entries[0]
      other["symbol"] = "WXYZ"
      entries.append(other)
      status["working_entries"] = entries
    }
    #expect(Headline.detail(two) == "2 entry orders working")
    let none = try entryGone()
    #expect(Headline.detail(none) == "1 open · 1 protected by a verified broker stop", "no entry: positions alone")
    #expect(Headline.detail(try status()) == "1 position protected · 1 entry working", "mockup v162")
    let unverified = try status { status in
      var positions = status["positions"] as? [[String: Any]] ?? []
      var stop = positions[0]["stop"] as? [String: Any] ?? [:]
      stop["state"] = "missing"
      positions[0]["stop"] = stop
      status["positions"] = positions
    }
    #expect(Headline.detail(unverified) == "1 open · 0 protected by a verified broker stop · 1 entry working")
    let idle = try status { status in
      status["positions"] = []
      status["working_entries"] = []
    }
    #expect(Headline.detail(idle) == "No open position")
  }

  @Test func forgetDropsWhatWasFollowed() throws {
    var watch = EntryCancelWatch()
    watch.read(try cancelRequested(), now: Self.start)
    watch.read(try entryGone(), now: Self.start + 1)
    watch.forget()
    #expect(watch == EntryCancelWatch())
  }
}
