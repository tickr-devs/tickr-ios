import Foundation

/// The bot's codes in the person's language (ApiCodes.swift, with the catalog of this package):
/// a known code reads translated, an unknown one falls back to the bot's own English text, so a
/// newer bot never shows a blank. Both apps use these, so they say the same thing.
public enum ApiText {
  /// Joins a fence's kind and its key ("Foreign position · EFGH").
  static let keySeparator = " · "
  /// Between a fence's title and the bot's detail.
  static let detailSeparator = ": "

  /// Why entries are blocked.
  public static func entryBlock(_ block: EntryBlock) -> String {
    if let code = BlockCode(rawValue: block.cause) { return String(localized: code.title) }
    if let kind = FenceKind(rawValue: block.cause) { return String(localized: kind.title) }
    return block.text
  }

  /// A fence's kind with its key, if any; the bot's detail stays in `Fence.text`.
  public static func fence(_ fence: Fence) -> String {
    let parts = fence.kind.split(separator: Fence.keySeparator, maxSplits: 1).map(String.init)
    guard let name = parts.first, let kind = FenceKind(rawValue: name.replacing("-", with: "_")) else {
      return fence.kind
    }
    let title = String(localized: kind.title)
    return parts.count > 1 ? title + keySeparator + parts[1] : title
  }

  /// The fence in words followed by the bot's own detail, which often says what to do ("close the
  /// position in the Webull app") and stays visible until the bot sends it as codes.
  public static func fenceWithDetail(_ fence: Fence) -> String {
    let title = Self.fence(fence)
    return fence.text.isEmpty ? title : title + detailSeparator + fence.text
  }

  public static func orderSide(_ raw: String) -> String {
    OrderSide(rawValue: raw).map { String(localized: $0.title) } ?? raw
  }

  public static func orderType(_ raw: String) -> String {
    OrderKind(rawValue: raw).map { String(localized: $0.title) } ?? raw
  }

  public static func orderStatus(_ raw: String) -> String {
    OrderStatus(rawValue: raw).map { String(localized: $0.title) } ?? raw
  }

  /// A strategy check's rule; a rule this app does not know (a newer strategy) reads as named.
  public static func rule(_ raw: String) -> String {
    CheckRule(rawValue: raw).map { String(localized: $0.title) } ?? raw
  }
}

extension Fence {
  /// Separates a fence's kind from its key in `kind` ("foreign-position:EFGH").
  public static let keySeparator: Character = ":"
}
