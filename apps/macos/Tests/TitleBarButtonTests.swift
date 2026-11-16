import SwiftUI
import Testing
import TickrDesign
@testable import TickrMac

/// The title bar's icon buttons (sidebar, previous and next day) keep at least macOS's regular
/// control size (Apple HIG), drawn offscreen as the window would draw them.
@Suite("Title bar buttons")
@MainActor
struct TitleBarButtonTests {
  /// macOS's regular control height, in points (Apple HIG).
  static let regularControl: CGFloat = 28

  private func size(_ view: some View) -> CGSize {
    let renderer = ImageRenderer(content: view.fixedSize())
    return renderer.nsImage?.size ?? .zero
  }

  @Test("The day arrows are at least a regular control")
  func dayArrows() {
    for symbol in [Symbols.previous, Symbols.next] {
      let drawn = size(Button {} label: { Image(systemName: symbol) }.buttonStyle(TitleBarButtonStyle(square: true)))
      #expect(drawn.width >= Self.regularControl)
      #expect(drawn.height >= Self.regularControl)
    }
  }

  @Test("The sidebar button is at least a regular control, its glyph a toolbar glyph")
  func sidebar() {
    let drawn = size(Button {} label: { ShellIcon(kind: .sidebar, size: SidebarButton.glyphSize) }
      .buttonStyle(TitleBarButtonStyle(square: true)))
    #expect(drawn.width >= Self.regularControl)
    #expect(drawn.height >= Self.regularControl)
    #expect(SidebarButton.glyphSize >= TitleBarButtonStyle.height / 2)
  }
}
