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

  @Test("Zoom in is offered only while more than the minimum is on screen")
  func canZoomIn() {
    #expect(Viewport().canZoomIn(total: 100))
    #expect(Viewport(visible: Viewport.minimumVisible + 1).canZoomIn(total: 100))
    #expect(!Viewport(visible: Viewport.minimumVisible).canZoomIn(total: 100))
    // A range no longer than the minimum is shown whole and cannot be zoomed into.
    #expect(!Viewport().canZoomIn(total: Viewport.minimumVisible))
    var viewport = Viewport()
    for _ in 0..<20 { viewport.zoomIn(total: 100) }
    #expect(!viewport.canZoomIn(total: 100))
  }

  @Test("Fit is offered only while the window is zoomed in or scrolled back")
  func canFit() {
    #expect(!Viewport().canFit(total: 100))
    #expect(Viewport(visible: 30).canFit(total: 100))
    #expect(Viewport(visible: nil, position: .now).canFit(total: 100))
    // A window wider than the range already shows it whole.
    #expect(!Viewport(visible: 150).canFit(total: 100))
    var viewport = Viewport(visible: 30, position: .now)
    viewport.fit()
    #expect(!viewport.canFit(total: 100))
  }

  @Test("Show whole day forgets the zoom and the scroll")
  func fit() {
    var viewport = Viewport(visible: 30, position: .now)
    viewport.fit()
    #expect(viewport == Viewport())
  }

  @Test("A chart opens on its newest candles; a range shorter than that shows whole")
  func opening() {
    let viewport = Viewport.opening
    let long = Viewport.openingCandles * 4
    #expect(viewport.shown(total: long) == Viewport.openingCandles)
    #expect(viewport.shown(total: Viewport.openingCandles) == nil)
    var short = Viewport.opening
    short.zoomOut(total: Viewport.minimumVisible)
    #expect(short.visible == nil)
    // Zooming in on a short range starts from the whole range, not from the opening window.
    let total = Viewport.minimumVisible * 2
    var zooming = Viewport.opening
    zooming.zoomIn(total: total)
    #expect((zooming.visible ?? total) < total)
  }
}
