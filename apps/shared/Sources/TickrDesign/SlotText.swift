import SwiftUI
import TickrKit

extension Text {
  /// `slot`'s sentence with `part` in its place: a part that draws itself, such as a relative time
  /// that keeps counting (`Text(date, style: .relative)`), inside a sentence in the person's
  /// language (`TextSlot`).
  public init(_ slot: TextSlot, around part: Text) {
    self.init("\(Text(verbatim: slot.before))\(part)\(Text(verbatim: slot.after))")
  }
}
