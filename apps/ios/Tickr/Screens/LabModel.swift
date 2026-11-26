import Foundation
import Observation
import TickrKit

/// The Lab's reads: the shown day's refused signals and, for a recorded day, its record, read
/// when the tab opens and on refresh; and the replay, read while the Lab is open.
@MainActor
@Observable
final class LabModel {
  /// The shown recorded day's record (GET /days/<date>), once read; nil while today is shown.
  private(set) var pastDay: DayV1?
  /// Why it could not be read, if it could not.
  private(set) var pastDayFailure: String?
  /// The active strategy's refused signals of `refusalsDay` by cause (GET /skipped), once read.
  private(set) var refusals: [RefusalCount]?
  private(set) var refusalsDay: WireDate?
  /// Why they could not be read, if they could not.
  private(set) var refusalsFailure: String?
  /// The Lab's simulated replay of a strategy version over the recent sessions or one day, maybe
  /// compared with a second version (GET /lab/replay), read while the Lab is open.
  private(set) var replay: LabReplayV1?
  /// Why it could not be read, if it could not.
  private(set) var replayFailure: String?
  /// Why the last start was refused (409): a reason to wait, not a failure.
  private(set) var replayRefusal: String?
  /// A start is on its way to the bot.
  private(set) var replayStarting = false
  /// The replay as read when the refusal came, and when it came: a later read that differs means the
  /// replay moved on, and past `replaySeconds` the reason may no longer hold (the session closed),
  /// so either clears the refusal.
  @ObservationIgnored private var refusedAt: (state: LabReplayState?, runId: String?, at: Date)?
  /// The bot everything above came from.
  @ObservationIgnored private var source: URL?
  /// The bot the replay came from.
  @ObservationIgnored private var replaySource: URL?
  /// The current moment (Container.now; tests pin it).
  @ObservationIgnored @Injected(\.now) private var now

  /// Seconds between two reads of the replay while it is idle or done, and while it runs.
  static let replaySeconds = 30.0
  static let replayRunningSeconds = 3.0

  /// The bot's API at `url`, from the container, with the paired token only where it may go.
  private func client(_ url: URL) -> APIClient {
    Container.shared.apiClient(Container.shared.appModel().connection.endpoint(for: url))
  }

  /// Read the refusals of `day` from the bot at `url` and, for a recorded past day (`past`), its
  /// record, whose trades give the trading strategy's day, both at once; another bot's answers are
  /// dropped first.
  func load(_ url: URL, day: WireDate, past: Bool) async {
    if source != url {
      refusals = nil
      refusalsDay = nil
      refusalsFailure = nil
      pastDay = nil
      pastDayFailure = nil
      source = url
    }
    async let refusalsRead: Void = loadRefusals(url, day: day)
    async let dayRead: Void = past ? loadPastDay(url, day: day) : clearPastDay()
    _ = await (refusalsRead, dayRead)
  }

  /// Read the record of past day `day`. Another day's record is never shown under this one.
  func loadPastDay(_ url: URL, day: WireDate) async {
    if pastDay?.day != day {
      pastDay = nil
      pastDayFailure = nil
    }
    do {
      let read = try await client(url).day(day)
      guard read.day == day else {
        pastDayFailure = String(localized: L10n.Activity.otherDayAnswered(day.text, read.day.text))
        return
      }
      pastDay = read
      pastDayFailure = nil
    } catch is CancellationError {
      return
    } catch {
      pastDayFailure = ErrorText.text(error)
    }
  }

  private func clearPastDay() async {
    pastDay = nil
    pastDayFailure = nil
  }

  /// Read the refused signals of `day`. Another day's counts are never shown under this one.
  func loadRefusals(_ url: URL, day: WireDate) async {
    if refusalsDay != day {
      refusals = nil
      refusalsFailure = nil
      refusalsDay = day
    }
    do {
      let read = try await client(url).skipped(day: day)
      guard read.day == day, day == refusalsDay else { return }
      refusals = RefusalCount.make(read.signals)
      refusalsFailure = nil
    } catch is CancellationError {
      return
    } catch {
      if day == refusalsDay { refusalsFailure = ErrorText.text(error) }
    }
  }

  /// Read the replay of the bot at `url`; a failed read clears it, so an old result never reads as
  /// current.
  func refreshReplay(_ url: URL) async {
    resetReplay(for: url)
    do {
      let read = try await client(url).labReplay()
      guard url == replaySource else { return }
      replay = read
      replayFailure = nil
      if let refused = refusedAt, Self.refusalCleared(refused, by: read, now: now()) {
        replayRefusal = nil
        refusedAt = nil
      }
    } catch is CancellationError {
      return
    } catch {
      guard url == replaySource else { return }
      replay = nil
      replayFailure = AppModel.describe(error) ?? replayFailure
    }
  }

  /// Start the replay once: strategy folder `version` (the active one when nil), then `compare`
  /// over the same window, over the last sessions or over `day` only. A refusal (a run going, the
  /// session open, no data, a choice the bot does not offer) is kept as the reason, never retried.
  func startReplay(_ url: URL, version: String? = nil, compare: String? = nil, day: WireDate? = nil) async {
    resetReplay(for: url)
    replayStarting = true
    defer { replayStarting = false }
    do {
      let started = try await client(url).startLabReplay(version: version, compare: compare, day: day)
      guard url == replaySource else { return }
      replay = started
      replayFailure = nil
      replayRefusal = nil
      refusedAt = nil
    } catch APIError.refused(_, _, let cause) {
      guard url == replaySource else { return }
      replayRefusal = cause
      refusedAt = (replay?.state, replay?.runId, now())
    } catch is CancellationError {
      return
    } catch {
      guard url == replaySource else { return }
      replayFailure = AppModel.describe(error) ?? replayFailure
    }
  }

  /// Whether a refusal no longer holds: the replay read since moved on (another state or run), or
  /// `replaySeconds` have passed since it came, so its reason (the session open) may be gone.
  static func refusalCleared(
    _ refused: (state: LabReplayState?, runId: String?, at: Date), by read: LabReplayV1, now: Date
  ) -> Bool {
    refused.state != read.state || refused.runId != read.runId
      || now.timeIntervalSince(refused.at) >= replaySeconds
  }

  /// Read the replay until cancelled, more often while it runs; used while the Lab is open.
  func followReplay(_ url: URL) async {
    while !Task.isCancelled {
      await refreshReplay(url)
      let seconds = replay?.state == .running ? Self.replayRunningSeconds : Self.replaySeconds
      try? await Task.sleep(for: .seconds(seconds))
    }
  }

  /// Another bot's replay is dropped before anything of `url` is read.
  private func resetReplay(for url: URL) {
    guard replaySource != url else { return }
    replay = nil
    replayFailure = nil
    replayRefusal = nil
    refusedAt = nil
    replaySource = url
  }
}
