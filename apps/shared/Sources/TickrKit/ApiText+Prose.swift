import Foundation

extension ApiText {
  /// Joins the parts of a cause, as the bot joins them ("…; …").
  static let proseSeparator = "; "
  /// The code of a clean-day fault that quotes a fence's own cause, and its values: the fence
  /// as the bot names it and the fence's own reason code.
  static let fenceCauseCode = "fence"
  static let fenceKey = "fence"
  static let fenceCodeKey = "fence_code"
  /// The code of an emergency command's step with what it did, and its values: the step (a
  /// command kind) and the step's own reason code.
  static let commandStepCode = "command_step"
  static let stepKey = "step"
  static let stepCodeKey = "step_code"
  /// Values naming command kinds, as the bot lists them ("entry-stop-on, flatten").
  static let stepsKey = "steps"
  static let stepsSeparator = ", "

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

  /// One part of a cause; a fence it names reads as the fence's title, a command step as the
  /// command's title.
  static func prosePart(_ reason: ReasonV1) -> String? {
    var params = reason.params
    if let kind = params[fenceKey] { params[fenceKey] = fenceTitle(kind) }
    if let steps = params[stepsKey] {
      guard let titles = stepTitles(steps) else { return nil }
      params[stepsKey] = titles
    }
    if reason.code == commandStepCode {
      guard let title = reason.params[stepKey].flatMap(CommandKind.init(rawValue:)).map(Board.commandTitle),
        let code = reason.params[stepCodeKey], code != commandStepCode,
        let detail = prosePart(ReasonV1(code: code, params: reason.params))
      else { return nil }
      return title + detailSeparator + detail
    }
    guard reason.code == fenceCauseCode else { return ProseReason(rawValue: reason.code)?.text(params) }
    guard let title = params[fenceKey],
      let detail = reason.params[fenceCodeKey].flatMap(FenceReason.init(rawValue:))?.text(reason.params)
    else { return nil }
    return title + detailSeparator + detail
  }

  /// Command kinds the bot lists ("entry-stop-on, flatten") as the commands' titles; nil when
  /// one is not a command this app knows (show the bot's words then).
  static func stepTitles(_ steps: String) -> String? {
    let names = steps.components(separatedBy: stepsSeparator)
    let titles = names.compactMap { CommandKind(rawValue: $0).map(Board.commandTitle) }
    guard titles.count == names.count else { return nil }
    return titles.joined(separator: stepsSeparator)
  }
}
