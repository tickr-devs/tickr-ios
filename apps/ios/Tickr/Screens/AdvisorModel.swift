import Foundation
import Observation
import TickrKit

/// The AI advisor's runs (GET /advisor), read when the Lab opens and on refresh, and the owner's
/// Accept or Reject (POST /advisor/decision). A decision is a note: the bot deploys nothing from it.
@MainActor
@Observable
final class AdvisorModel {
  /// The runs of the bot at `source`, once read.
  private(set) var runs: AdvisorRunsV1?
  /// Why they could not be read, if they could not.
  private(set) var failure: String?
  /// The run whose decision is on its way to the bot.
  private(set) var deciding: String?
  /// Why a decision was not recorded (the run is gone, or takes no decision), by run id, so one
  /// run's failure never shows on another; cleared once that run's decision is recorded.
  private(set) var decisionFailures: [String: String] = [:]
  /// The bot the runs came from.
  @ObservationIgnored private var source: URL?
  /// Bumped when a decision is sent and when its answer is in: a read started before then may
  /// predate the decision and must not replace the answer's runs.
  @ObservationIgnored private var decisionTurn = 0

  /// The bot's API at `url`, from the container, with the paired token only where it may go.
  private func client(_ url: URL) -> APIClient {
    Container.shared.apiClient(Container.shared.appModel().connection.endpoint(for: url))
  }

  /// One run by its id, from the last read.
  func run(_ id: String) -> AdvisorRunV1? {
    runs?.runs.first { $0.id == id }
  }

  /// Read the runs of the bot at `url`; another bot's runs are dropped first.
  func load(_ url: URL) async {
    reset(for: url)
    let turn = decisionTurn
    do {
      let read = try await client(url).advisor()
      guard url == source, turn == decisionTurn else { return }
      runs = read
      failure = nil
    } catch is CancellationError {
      return
    } catch {
      guard url == source, turn == decisionTurn else { return }
      failure = AppModel.describe(error)
    }
  }

  /// Record the owner's verdict on `run` once; the answer is the runs as they now stand.
  func decide(_ url: URL, run: String, verdict: OwnerVerdict) async {
    reset(for: url)
    deciding = run
    decisionTurn += 1
    defer {
      deciding = nil
      decisionTurn += 1
    }
    do {
      let read = try await client(url).decideAdvisor(run: run, verdict: verdict)
      guard url == source else { return }
      runs = read
      decisionFailures[run] = nil
    } catch APIError.refused(_, _, let cause) {
      guard url == source else { return }
      decisionFailures[run] = cause
    } catch is CancellationError {
      return
    } catch {
      guard url == source else { return }
      decisionFailures[run] = AppModel.describe(error)
    }
  }

  private func reset(for url: URL) {
    guard source != url else { return }
    runs = nil
    failure = nil
    decisionFailures = [:]
    source = url
  }
}
