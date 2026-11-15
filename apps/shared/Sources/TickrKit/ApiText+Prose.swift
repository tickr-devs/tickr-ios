import Foundation

extension ApiText {
  /// Joins the parts of a cause, as the bot joins them ("…; …").
  static let proseSeparator = "; "
  /// The code of a clean-day fault that quotes a fence's own cause, and its values: the fence
  /// as the bot names it and the fence's own reason code.
  static let fenceCauseCode = "fence"
  static let fenceKey = "fence"
  static let fenceCodeKey = "fence_code"

  /// A cause the API wrote itself (`<field>` with its `<field>_codes`) in the person's language.
  /// The bot's own `text` when a part has no sentence here (an unknown or unrecognized code, a
  /// value not sent), so a cause never reads half translated; also when no codes were sent.
  public static func prose(_ codes: [ReasonV1], text: String) -> String {
    let parts = codes.compactMap(prosePart)
    guard !parts.isEmpty, parts.count == codes.count else { return text }
    return parts.joined(separator: proseSeparator)
  }

  /// `prose` for an optional cause: nil stays nil.
  public static func prose(_ codes: [ReasonV1], text: String?) -> String? {
    text.map { prose(codes, text: $0) }
  }

  /// One part of a cause; a fence it names reads as the fence's title.
  static func prosePart(_ reason: ReasonV1) -> String? {
    var params = reason.params
    if let kind = params[fenceKey] { params[fenceKey] = fenceTitle(kind) }
    guard reason.code == fenceCauseCode else { return ProseReason(rawValue: reason.code)?.text(params) }
    guard let title = params[fenceKey],
      let detail = reason.params[fenceCodeKey].flatMap(FenceReason.init(rawValue:))?.text(reason.params)
    else { return nil }
    return title + detailSeparator + detail
  }
}
