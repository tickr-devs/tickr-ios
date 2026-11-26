import SwiftUI

extension Text {
  /// Texts run together into one, each keeping its own style ("ATR 14 · 0.42" with the value in
  /// its colour). In place of `Text + Text`, deprecated in macOS and iOS 26. The joining format
  /// is only placeholders, so it lives here, in a package without a String Catalog, and no app
  /// catalog ever extracts it.
  public static func joined(_ first: Text, _ rest: Text...) -> Text {
    rest.reduce(first) { joined, next in Text("\(joined)\(next)") }
  }
}
