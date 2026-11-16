import Foundation

/// The bot code version a run records (docs/api.md): the full git commit SHA, with `-dirty` when a
/// tracked file differed from that commit. People read the short form.
public enum CodeVersion {
  /// Hex digits of the commit people read, as `git log --oneline` shows one.
  public static let shortLength = 8
  /// The suffix of a version that ran with tracked files changed; always kept visible.
  public static let dirtySuffix = "-dirty"

  /// "6c4eec8b" or "6c4eec8b-dirty": the commit cut to `shortLength`, the dirty mark kept.
  public static func short(_ full: String) -> String {
    let dirty = full.hasSuffix(dirtySuffix)
    let commit = dirty ? String(full.dropLast(dirtySuffix.count)) : full
    return String(commit.prefix(shortLength)) + (dirty ? dirtySuffix : "")
  }
}
