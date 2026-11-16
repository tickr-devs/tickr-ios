import Foundation
import Testing
@testable import TickrKit

@Suite("Observer rows: the version, what sets it apart, since when it watched")
struct ObserverLabelTests {
  func observers() throws -> [ObserverV1] {
    try Wire.decoder().decode(ObserversV1.self, from: fixture("observers-v1.json")).observers
  }

  /// An observer that started at a 15:08 (New York) restart and has not entered yet.
  func lateObserver(enter: Bool = false) throws -> ObserverV1 {
    let json = """
      {"name": "price-action-v3", "version": "2-relvol-1.75", "decisions": [
        {"at": "2026-11-16T20:08:00.000Z", "symbol": "ABCD", "action": "\(enter ? "ENTER" : "WATCH")",
         "reasons": []}],
       "result_gross_usd": null, "result_cause": "no bars", "trades": [], "trades_cause": null,
       "trades_truncated": false, "watching_since": "2026-11-16T20:08:30.000Z",
       "settings_differences": [{"key": "indicators.minimum_relative_volume", "value": "1.75",
                                 "active_value": "2.0"}]}
      """
    return try Wire.decoder().decode(ObserverV1.self, from: Data(json.utf8))
  }

  @Test("The family is the name's last part when it is v and digits, else the whole name")
  func family() {
    #expect(ObserverLabel.family("price-action-v3") == "v3")
    #expect(ObserverLabel.family("v12") == "v12")
    #expect(ObserverLabel.family("noise-band") == "noise-band")
    #expect(ObserverLabel.family("price-action-v") == "price-action-v")
    #expect(ObserverLabel.family("price-action-vx2") == "price-action-vx2")
    #expect(ObserverLabel.active("price-action-v3") == "v3 · active")
  }

  @Test("An observer is named by what differs from the active strategy, from the bot's data")
  func labels() throws {
    let all = try observers()
    #expect(ObserverLabel.observer(all[0]) == "v1 · rel vol 1.5×")
    #expect(ObserverLabel.observer(all[1]) == "price-action-v2 v1")  // cannot be compared
    #expect(ObserverLabel.observer(all[2]) == "v2 · same settings")
    #expect(ObserverLabel.observer(try lateObserver()) == "v3 · rel vol 1.75×")
    let other = SettingDifferenceV1(key: "breakout.lookback_bars", value: "8", activeValue: "5")
    #expect(ObserverLabel.difference(other) == "lookback_bars 8")
    let removed = SettingDifferenceV1(key: "spike.signal_valid_bars", value: nil, activeValue: "3")
    #expect(ObserverLabel.difference(removed) == "signal_valid_bars \(ApiText.missing)")
  }

  @Test("Since when it watched, in New York time; no entries yet while it entered nothing")
  func since() throws {
    #expect(ObserverLabel.since(try lateObserver()) == "watching since 15:08 · no entries yet")
    #expect(ObserverLabel.since(try lateObserver(enter: true)) == "watching since 15:08")
    let all = try observers()
    #expect(ObserverLabel.since(all[0]) == "watching since 09:59")
    #expect(ObserverLabel.since(all[1]) == nil)  // no decisions that day
  }

  @Test("The symbols it would have entered that the active strategy skipped, once there are any")
  func skipped() throws {
    let first = try #require(try observers().first)
    #expect(ObserverSummary(first, traded: []).notTraded == ["ABCD"])
    #expect(ObserverLabel.skipped(ObserverSummary(first, traded: [])) == "active skipped: ABCD")
    #expect(ObserverLabel.skipped(ObserverSummary(first, traded: ["ABCD"])) == nil)
  }

  @Test("A bot that does not report the new keys decodes them as unknown")
  func olderBot() throws {
    let json = """
      {"name": "price-action-v3", "version": "2", "decisions": [], "result_gross_usd": null,
       "result_cause": "no bars", "trades": null, "trades_cause": "no bars", "trades_truncated": false}
      """
    let observer = try Wire.decoder().decode(ObserverV1.self, from: Data(json.utf8))
    #expect(observer.watchingSince == nil && observer.settingsDifferences == nil)
    #expect(ObserverLabel.observer(observer) == "price-action-v3 v2")
  }

  @Test("A line starts when its observer started watching, never before the axis start")
  func clipping() throws {
    let open = Date(timeIntervalSince1970: 1_000)
    let since = open.addingTimeInterval(3_600)
    let end = open.addingTimeInterval(7_200)
    let late = DayCurve(closes: [(end.addingTimeInterval(-60), 4)], reported: 5, complete: true, since: since)
    let corners = late.line(start: open, end: end)
    #expect(corners.map(\.at) == [since, end.addingTimeInterval(-60), end, end])
    #expect(corners.map(\.total) == [0, 4, 4, 5])
    #expect(DayCurve(closes: [], reported: nil, complete: true).line(start: open, end: end).first?.at == open)
    let early = DayCurve(closes: [], reported: nil, complete: true, since: open.addingTimeInterval(-60))
    #expect(early.line(start: open, end: end).first?.at == open)
    let observer = try lateObserver()
    let curve = try #require(DayCurve.observer(observer))
    #expect(curve.since == observer.watchingSince?.date)
  }

  @Test("The phone's line starts at the observer's start too, with its label and notes")
  func versionCurve() throws {
    let observer = try lateObserver()
    let curve = try #require(VersionCurve.simulated(observer, traded: []))
    let since = try #require(observer.watchingSince?.date)
    let line = curve.line(start: since.addingTimeInterval(-3_600), end: since.addingTimeInterval(600))
    #expect(line.first?.at == since)
    #expect(line.last?.at == since.addingTimeInterval(600))
    #expect(curve.label == "v3 · rel vol 1.75×")
    #expect(curve.notes == ["watching since 15:08 · no entries yet"])
    let entered = try #require(VersionCurve.simulated(try lateObserver(enter: true), traded: []))
    #expect(entered.notes == ["watching since 15:08", "active skipped: ABCD"])
    let active = VersionCurve.active(name: "price-action-v3", version: "2", trades: [], total: 0)
    #expect(active.label == "v3 · active")
    #expect(active.line(start: since, end: since.addingTimeInterval(60)).first?.at == since)
  }
}
