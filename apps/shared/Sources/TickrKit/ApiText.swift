import Foundation

/// The bot's codes in the person's language (ApiCodes.swift, with the catalog of this package):
/// a known code reads translated, an unknown one falls back to the bot's own English text, so a
/// newer bot never shows a blank. Both apps use these, so they say the same thing.
public enum ApiText {
  /// Shown wherever a value is missing: the one placeholder of both apps and TickrKit.
  public static let missing = "—"
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
    fenceTitle(fence.kind)
  }

  /// A fence's kind as the bot names it ("foreign-position:EFGH") in words. The key follows only
  /// when it is a symbol (a foreign position); every other key is the bot's trade or order id,
  /// which means nothing to a person. A kind this app does not know reads as "Other block".
  public static func fenceTitle(_ fenceKind: String) -> String {
    let parts = fenceKind.split(separator: Fence.keySeparator, maxSplits: 1).map(String.init)
    guard let kind = fenceKindCase(parts.first ?? fenceKind) else { return String(localized: L10n.fenceOther) }
    let title = String(localized: kind.title)
    return parts.count > 1 && symbolKeyed.contains(kind) ? title + keySeparator + parts[1] : title
  }

  /// Fences keyed by a symbol rather than by the bot's trade or client order id
  /// (src/tickr/engine/core.py `_set_fence`).
  static let symbolKeyed: Set<FenceKind> = [.foreignPosition]

  /// A fence's name ("foreign-position") as its case.
  public static func fenceKindCase(_ name: String) -> FenceKind? {
    FenceKind(rawValue: name.replacing("-", with: "_"))
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

  /// The fence's title about `symbol`, when the apps know which position it concerns: the
  /// symbol first, in place of the bot's internal key (a trade or order id). Without a symbol,
  /// `fence(_:)`.
  public static func fence(_ fence: Fence, symbol: String?) -> String {
    guard let symbol else { return Self.fence(fence) }
    let name = String(fence.kind.prefix { $0 != Fence.keySeparator })
    let title = String(localized: fenceKindCase(name)?.title ?? L10n.fenceOther)
    return symbol + keySeparator + title
  }

  /// `fence(_:symbol:)` followed by what the fence says, so the symbol survives a cut line.
  public static func fenceWithDetail(_ fence: Fence, symbol: String?) -> String {
    let title = Self.fence(fence, symbol: symbol)
    let detail = fenceDetail(fence)
    return detail.isEmpty ? title : title + detailSeparator + detail
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

  /// A broker order's side, type and status in words; a value this app does not know reads as
  /// "Unknown side", "Unknown type" or "Unknown status", never as the broker's code.
  public static func orderSide(_ raw: String) -> String {
    String(localized: OrderSide(rawValue: raw)?.title ?? L10n.orderSideOther)
  }

  public static func orderType(_ raw: String) -> String {
    String(localized: OrderKind(rawValue: raw)?.title ?? L10n.orderTypeOther)
  }

  public static func orderStatus(_ raw: String) -> String {
    String(localized: OrderStatus(rawValue: raw)?.title ?? L10n.orderStatusOther)
  }

  /// Where the bot trades (`environment` of status and settings) in words. The three known
  /// environments read localized; any other is a name the owner chose in config/bot.toml, so it
  /// reads as written (like a strategy name), and only an empty one reads as "Unknown environment".
  public static func environment(_ raw: String) -> String {
    if let known = BotEnvironment(rawValue: raw) { return String(localized: known.title) }
    return raw.isEmpty ? String(localized: L10n.environmentUnknown) : raw
  }

  /// The environment badge's spoken name ("Environment: Sandbox"), the same on every screen.
  public static func environmentLabel(_ raw: String) -> String {
    String(localized: L10n.environmentLabel(environment(raw)))
  }

  /// A strategy check's rule; a rule this app does not know (a newer strategy) reads as
  /// "Other check", never as the strategy's key.
  public static func rule(_ raw: String) -> String {
    String(localized: CheckRule(rawValue: raw)?.title ?? L10n.ruleOther)
  }
}

/// The environments the bot names in `environment`: the tables under [environments] in
/// config/bot.toml. Only for display; nothing in the apps behaves differently by environment.
public enum BotEnvironment: String, Sendable {
  case sandbox
  case production
  /// `tickr demo` (config/demo.toml).
  case demo

  public var title: LocalizedStringResource {
    switch self {
    case .sandbox: L10n.environmentSandbox
    case .production: L10n.environmentProduction
    case .demo: L10n.environmentDemo
    }
  }
}

extension Fence {
  /// Separates a fence's kind from its key in `kind` ("foreign-position:EFGH").
  public static let keySeparator: Character = ":"
}
