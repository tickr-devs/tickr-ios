import CoreGraphics
import Foundation
import Testing
@testable import TickrMac

/// Every pane below the price pane takes the stretch of time the price pane really draws, so a
/// minute sits at the same x in each (owner, 2026-11-18: gridlines, candles and the crosshair
/// apart between the price pane and the panes below).
@Suite("Chart panes share the price pane's drawn time")
struct PaneAlignmentTests {
  /// A scale of one second per point from `origin` at the plot frame's left edge.
  static func scale(_ origin: Date) -> (CGFloat) -> Date? {
    { origin.addingTimeInterval(TimeInterval($0)) }
  }

  @Test("A scrolled plot gives the times at the pane's own edges, not the content's")
  func scrolledPlot() throws {
    let origin = Date(timeIntervalSince1970: 1_000_000)
    // Content 3000 points wide, scrolled 1200 points left, in a pane 800 points wide.
    let plot = CGRect(x: -1200, y: 0, width: 3000, height: 300)
    let domain = try #require(ShownWindow.domain(plot: plot, bounds: CGSize(width: 800, height: 300),
      value: Self.scale(origin)))
    #expect(domain.lowerBound == origin.addingTimeInterval(1200))
    #expect(domain.upperBound == origin.addingTimeInterval(2000))
  }

  @Test("An unscrolled plot inside the pane gives its own edges")
  func wholePlot() throws {
    let origin = Date(timeIntervalSince1970: 1_000_000)
    // The value axis takes the right 56 points of the pane.
    let plot = CGRect(x: 0, y: 0, width: 744, height: 300)
    let domain = try #require(ShownWindow.domain(plot: plot, bounds: CGSize(width: 800, height: 300),
      value: Self.scale(origin)))
    #expect(domain == origin...origin.addingTimeInterval(744))
  }

  @Test("Nothing measured while the plot is off the pane")
  func offPane() {
    let plot = CGRect(x: 900, y: 0, width: 100, height: 300)
    #expect(ShownWindow.domain(plot: plot, bounds: CGSize(width: 800, height: 300),
      value: Self.scale(.now)) == nil)
  }
}
