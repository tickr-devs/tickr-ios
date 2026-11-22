import SwiftUI

// MARK: - sheets as tall as their content

public extension View {
  /// A sheet as tall as its content (owner, 2026-11-20: the bot actions opened at half the screen,
  /// scrolled, and the scroll chevron sat on Cancel; "make the window a little bigger so all the
  /// content fits"). Apply it on the sheet's root, around a scroll view that carries
  /// `scrollEdgeHints()` or `scrollEdgeFades()`: the scroll view adds how far its content runs
  /// past its frame to the sheet's height (`SheetFitting`), and the sheet takes that height. Only
  /// when the content is taller than the screen does the sheet stop at full height and scroll, with the
  /// edge hints. On the Mac a sheet already takes its content's size, so this changes nothing there.
  func sheetFitsContent() -> some View {
    modifier(SheetFit())
  }
}

/// What a fitted sheet and its scroll view tell each other: `SheetFit` hands it down the
/// environment with the sheet's height; the scroll view's `ScrollEdgeHints` adds its overflow and
/// sets the height the sheet needs. An absolute height, not the overflow, so a page that shows
/// again (back from a page pushed inside the sheet) can tell it again as it was.
@MainActor @Observable final class SheetFitting {
  /// The sheet's height now, in points.
  @ObservationIgnored var sheet: CGFloat = 0 { didSet { recount() } }
  /// How far the shown page's scroll view runs past its visible height now, in points.
  @ObservationIgnored var overflow: CGFloat? { didSet { recount() } }
  /// The height the shown page needs, in points; nil until both are measured.
  var needed: CGFloat?

  /// Counted again from the latest pair whichever of the two changes: SwiftUI does not order the
  /// sheet's and the scroll view's callbacks, and a sum of a new value and a stale one would come
  /// out short by the change.
  private func recount() {
    if let height = SheetHeight.needed(sheet: sheet, overflow: overflow), height != needed { needed = height }
  }
}

/// The height a sheet needs: its own height now plus what its scroll view still hides (or minus
/// what it leaves empty). The sum does not depend on the sheet's current height, so one pass fits
/// and later passes ask for the same height. A detent's height excludes the bottom safe area, as
/// a view's own height does.
enum SheetHeight {
  static func needed(sheet: CGFloat, overflow: CGFloat?) -> CGFloat? {
    guard let overflow, sheet > 0 else { return nil }
    return (sheet + overflow).rounded(.up)
  }
}

struct SheetFit: ViewModifier {
  @State private var fitting = SheetFitting()

  func body(content: Content) -> some View {
    #if os(iOS)
    content
      .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { fitting.sheet = $0 }
      .environment(fitting)
      // Until the content is measured (the first layout, before the sheet is in view) the
      // system's half height; then the content's own. Taller than the screen, the system stops
      // it at full height.
      .presentationDetents([detent])
      .presentationDragIndicator(.visible)
    #else
    content
    #endif
  }

  #if os(iOS)
  private var detent: PresentationDetent {
    fitting.needed.map { .height($0) } ?? .medium
  }
  #endif
}
