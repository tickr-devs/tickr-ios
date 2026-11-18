import Foundation

/// Words of a capped list (`CappedList` in TickrDesign: a card's latest rows, then "Show all N ›"
/// opening every row in a sheet), shared by both apps, in English with their Russian translation in
/// Resources/Localizable.xcstrings (docs/design-system.md, rule 2).
public enum ListWords {
  /// The footer link under a capped list: "Show all 23 ›" (the count is its own chip).
  public static var showAll: LocalizedStringResource {
    LocalizedStringResource("kit.list.showAll", defaultValue: "Show all", bundle: L10n.bundle)
  }
  /// The sheet's close button, for VoiceOver.
  public static var close: LocalizedStringResource {
    LocalizedStringResource("kit.list.close", defaultValue: "Close", bundle: L10n.bundle)
  }
  /// The close button's tooltip on the Mac.
  public static var closeHelp: LocalizedStringResource {
    LocalizedStringResource("kit.list.closeHelp", defaultValue: "Close (Esc)", bundle: L10n.bundle)
  }
  /// Under the sheet's title: how many rows it holds, newest first.
  public static func allLatestFirst(_ count: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.list.allLatestFirst", defaultValue: "\(count) in all · latest first", bundle: L10n.bundle)
  }
}
