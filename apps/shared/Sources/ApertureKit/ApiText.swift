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

  /// What the fence says, in the person's language when the bot sent its cause as a code with
  /// every value the sentence needs, else the bot's own words. It often says what to do ("close
  /// the position in the Webull app"), so it stays visible.
  public static func fenceDetail(_ fence: Fence) -> String {
    FenceReason(rawValue: fence.code)?.text(fence.params) ?? fence.text
  }

  /// The fence in words followed by what it says.
  public static func fenceWithDetail(_ fence: Fence) -> String {
    let title = Self.fence(fence)
    let detail = fenceDetail(fence)
    return detail.isEmpty ? title : title + detailSeparator + detail
  }

  /// The fence in words, about `symbol` when the apps know which open position it concerns: the
  /// symbol first, in place of the bot's internal key (a trade or order id), so it survives a cut
  /// line. Without a symbol, `fenceWithDetail`.
  public static func fenceWithDetail(_ fence: Fence, symbol: String?) -> String {
    guard let symbol else { return fenceWithDetail(fence) }
    let name = String(fence.kind.prefix { $0 != Fence.keySeparator })
    let title = FenceKind(rawValue: name.replacing("-", with: "_")).map { String(localized: $0.title) } ?? name
    let detail = fenceDetail(fence)
    return symbol + keySeparator + (detail.isEmpty ? title : title + detailSeparator + detail)
  }

  /// The trading gate's cause in the person's language, else the bot's own words.
  public static func gate(_ gate: Gate) -> String {
    GateReason(rawValue: gate.code)?.text(gate.params) ?? gate.cause
  }

  /// The gate's own reason code inside a GATE_CLOSED refusal's params.
  static let gateKey = "gate"

  /// A refused entry's detail in the person's language, from its code and values; nil when this
  /// app has no sentence for it or the bot did not send every value (show the bot's words then).
  public static func refusalDetail(code: String, params: [String: String]) -> String? {
    if code == RefusalCode.gateClosed.rawValue {
      return params[gateKey].flatMap(GateReason.init(rawValue:))?.text(params)
    }
    return RefusalReason(rawValue: code)?.text(params)
  }

  /// A structured refusal's detail: the sentence, else the bot's message.
  public static func refusal(_ refusal: RefusalV1) -> String {
    refusalDetail(code: refusal.code, params: refusal.params) ?? refusal.message
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
