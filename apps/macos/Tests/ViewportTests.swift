import Foundation
import Testing
@testable import TickrMac

@Suite("Chart zoom")
struct ViewportTests {
  @Test("Zooming in from the whole day shows fewer candles, never below the minimum")
  func zoomIn() {
    var viewport = Viewport()
    viewport.zoomIn(total: 100)
    #expect(viewport.visible == 67)
    for _ in 0..<20 { viewport.zoomIn(total: 100) }
    #expect(viewport.visible == Viewport.minimumVisible)
  }

  @Test("Zooming out reaches the whole day and stays there")
  func zoomOut() {
    var viewport = Viewport(visible: 60)
    viewport.zoomOut(total: 100)
    #expect(viewport.visible == 90)
    viewport.zoomOut(total: 100)
    #expect(viewport.visible == nil)
    viewport.zoomOut(total: 100)
    #expect(viewport.visible == nil)
  }

  @Test("A day shorter than the minimum is always shown whole")
  func shortDay() {
    var viewport = Viewport()
    viewport.zoomIn(total: Viewport.minimumVisible - 2)
    #expect(viewport.visible == nil)
  }

  @Test("A pinch is clamped to the minimum and to the whole day")
  func pinch() {
    var viewport = Viewport()
    viewport.show(3, total: 100)
    #expect(viewport.visible == Viewport.minimumVisible)
    viewport.show(150, total: 100)
    #expect(viewport.visible == nil)
  }

  @Test("Show whole day forgets the zoom and the scroll")
  func fit() {
    var viewport = Viewport(visible: 30, position: .now)
    viewport.fit()
    #expect(viewport == Viewport())
  }
}
