import Foundation
import TickrKit

/// What the Lab's cards work out from the replay, kept out of the views so it is tested.
enum LabFigures {
  /// Which version earned more with the bot's limits in a finished comparison.
  enum Verdict: Equatable {
    /// The second version earned this much more.
    case more(Decimal)
    /// The second version earned this much less.
    case less(Decimal)
    /// Both earned the same.
    case same
  }

  /// The active version's latest test on past days ("Which version trades"): the summary of a
  /// finished replay of the folder the bot lists as active over the last sessions; nil for a run
  /// of another version, of one day, or one not finished.
  static func activeTest(_ replay: LabReplayV1?) -> LabReplaySummaryV1? {
    guard let replay, replay.state == .done, replay.day == nil, let folder = replay.folder,
      replay.versions.contains(where: { $0.role == .active && $0.folder == folder }) else { return nil }
    return replay.summary
  }

  /// Which version earned more over the last sessions; nil without both results, and for one day
  /// (its own note says one day is only an example).
  static func verdict(_ replay: LabReplayV1) -> Verdict? {
    guard replay.day == nil, let first = replay.summary, let other = replay.compare?.summary else { return nil }
    let difference = other.botTotalUsd.value - first.botTotalUsd.value
    if difference > 0 { return .more(difference) }
    if difference < 0 { return .less(-difference) }
    return .same
  }
}
