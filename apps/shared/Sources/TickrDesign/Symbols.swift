import SwiftUI

/// One SF Symbol per meaning, for every screen of both apps (docs/design-system.md, "Symbols"):
/// the same meaning never draws two glyphs. `check_swift_rules.py` (rule `symbols`) fails a symbol
/// in the apps that competes with one of these for its meaning (`chevron.left` for "previous", an
/// outlined triangle for "failed").
public enum Symbols {
  /// One step back: the previous day or month, the way back from a pushed screen (the design's
  /// "‹"). `backward` turns with the reading direction.
  public static let previous = "chevron.backward"
  /// One step on: the next day or month, and a link's disclosure chevron (the design's "›").
  public static let next = "chevron.forward"
  /// Paused: entries paused, the Pause command.
  public static let pause = "pause.fill"
  /// A read or an action that failed: a failed day, chart bars that did not load.
  public static let failure = "exclamationmark.triangle.fill"
  /// A check that passed: a valid configuration, a verified key, a command done (the design's "✓").
  public static let passed = "checkmark.circle.fill"
  /// A check that failed: an invalid configuration, a refused command.
  public static let failed = "xmark.circle.fill"
  /// A clean day: the journal, the broker and the bot's records agree (the clean-day `Badge`).
  public static let cleanDay = "checkmark.seal.fill"
  /// A day that was not clean and needs a look (the clean-day `Badge`).
  public static let notCleanDay = "exclamationmark.triangle.fill"
}
