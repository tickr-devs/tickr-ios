import Foundation

/// How the observer rows name a strategy version and say what it is doing, shared by both apps:
/// "v3 · active" for the trading strategy, "v3 · rel vol 1.5×" for an observer that differs from
/// it in one setting (from the bot's `settings_differences`, never assumed), and "watching since
/// 15:08 · no entries yet" under an observer that started late and entered nothing.
public enum ObserverLabel {
  /// The dotted setting keys with a short name of their own; any other key reads by its last part.
  static let relativeVolumeKey = "indicators.minimum_relative_volume"
  /// Separates a dotted key's parts ("indicators.minimum_relative_volume").
  static let keySeparator: Character = "."
  /// Separates a strategy name's parts ("price-action-v3").
  static let nameSeparator: Character = "-"
  /// The version mark that starts a family part ("v3").
  static let familyMark: Character = "v"

  /// "v3" of "price-action-v3": the name's last part when it is "v" and digits; else the name.
  public static func family(_ name: String) -> String {
    guard let last = name.split(separator: nameSeparator).last, last.first == familyMark,
      last.count > 1, last.dropFirst().allSatisfy(\.isNumber) else { return name }
    return String(last)
  }

  /// "v3 · active": the trading strategy's row.
  public static func active(_ name: String) -> String {
    String(localized: L10n.observerActive(family(name)))
  }

  /// "v3 · rel vol 1.5×" when the bot says how the observer's settings differ from the active
  /// strategy's; "v3 · same settings" when they do not; "noise-band-v1 v1" (name and version)
  /// when the bot cannot compare them (another strategy, or a file changed since).
  public static func observer(_ observer: ObserverV1) -> String {
    guard let differences = observer.settingsDifferences else {
      return String(localized: L10n.observerVersion(observer.name, observer.version))
    }
    let parts = differences.isEmpty
      ? [String(localized: L10n.observerSameSettings)] : differences.map(difference)
    return ([family(observer.name)] + parts).joined(separator: separator)
  }

  /// One differing setting as the observer has it: "rel vol 1.5×", else "lookback_bars 8".
  public static func difference(_ difference: SettingDifferenceV1) -> String {
    let value = difference.value ?? ApiText.missing
    if difference.key == relativeVolumeKey { return String(localized: L10n.observerRelativeVolume(value)) }
    let name = difference.key.split(separator: keySeparator).last.map(String.init) ?? difference.key
    return String(localized: L10n.observerSetting(name, value))
  }

  /// The line under an observer's name: since when it watched, and "no entries yet" when it
  /// entered nothing ("watching since 15:08 · no entries yet"); nil when the bot gives no start.
  public static func since(_ observer: ObserverV1) -> String? {
    guard let start = observer.watchingSince?.date else { return nil }
    let watching = String(localized: L10n.observerWatchingSince(FlowBoard.newYorkMinute(start)))
    guard !observer.decisions.contains(where: { $0.action == .enter }) else { return watching }
    return watching + separator + String(localized: L10n.observerNoEntriesYet)
  }

  /// "active skipped: ABCD, WXYZ": the symbols the observer would have entered that the trading
  /// strategy did not trade; nil while there are none.
  public static func skipped(_ summary: ObserverSummary) -> String? {
    guard !summary.notTraded.isEmpty else { return nil }
    return String(localized: L10n.observerActiveSkipped(summary.notTraded.joined(separator: listSeparator)))
  }

  /// Joins the parts of a label ("v3 · rel vol 1.5×") and the symbols of a list.
  static let separator = " · "
  static let listSeparator = ", "
}
