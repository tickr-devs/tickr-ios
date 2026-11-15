import Foundation
import Observation
import TickrKit

/// The Lab's "Explain a symbol" read: the decisions recorded on one symbol on one day
/// (GET /decisions). One read runs at a time: a new symbol or day cancels the running one, and an
/// answer that is not for the symbol and day last asked for is dropped, so a slow answer never
/// shows an old day's decisions as current.
@MainActor @Observable
final class ExplainModel {
  /// The symbol and day a read asks for.
  struct Request: Hashable, Sendable {
    let symbol: String
    let day: WireDate
  }

  /// Reads the decisions on a symbol on a day from the bot at a base URL.
  typealias Fetch = @Sendable (URL, String, WireDate) async throws -> DecisionsV1

  /// The read asked for last; nil before the first or after `cancel()`.
  private(set) var request: Request?
  /// The answer to `request`; nil while it runs or after it failed.
  private(set) var decisions: DecisionsV1?
  /// Why `request` failed, if it did.
  private(set) var error: String?
  /// True while `request` runs.
  private(set) var loading = false

  @ObservationIgnored private var task: Task<Void, Never>?
  @ObservationIgnored private let fetch: Fetch

  init(fetch: @escaping Fetch = ExplainModel.read) {
    self.fetch = fetch
  }

  /// The bot's own read, through the app's API client.
  static let read: Fetch = { baseURL, symbol, day in
    try await Container.shared.apiClient(APIClient.Endpoint(baseURL: baseURL)).decisions(symbol: symbol, day: day)
  }

  /// Reads `symbol` on `day`, cancelling a read still running for another symbol or day. The same
  /// request again while it runs changes nothing.
  func load(symbol: String, day: WireDate, baseURL: URL) {
    let wanted = Request(symbol: symbol, day: day)
    guard wanted != request || !loading else { return }
    task?.cancel()
    request = wanted
    decisions = nil
    error = nil
    loading = true
    let fetch = self.fetch
    task = Task { [weak self] in
      let result: Result<DecisionsV1, Error>
      do {
        result = .success(try await fetch(baseURL, symbol, day))
      } catch {
        result = .failure(error)
      }
      self?.finish(wanted, result)
    }
  }

  /// Stops the running read and forgets the last answer: the symbol or day changed.
  func cancel() {
    task?.cancel()
    task = nil
    request = nil
    decisions = nil
    error = nil
    loading = false
  }

  /// Waits for the running read; for the tests.
  func settle() async {
    await task?.value
  }

  /// Keeps an answer only when it is for the request asked for last, and of that symbol and day.
  private func finish(_ asked: Request, _ result: Result<DecisionsV1, Error>) {
    guard asked == request else { return }
    loading = false
    switch result {
    case .success(let read):
      guard read.symbol == asked.symbol, read.day == asked.day else { return }
      decisions = read
      error = nil
    case .failure(let failure):
      guard let text = ErrorText.describe(failure) else { return }
      decisions = nil
      error = text
    }
  }
}
