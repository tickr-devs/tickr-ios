import SwiftUI

// Tokens of the live price line (`LiveSparkline`, mockup v116 "Live sparkline"); in their own file
// because Tokens.swift is at SwiftLint's file length limit.

extension Tokens {
  /// The live price line of an open position (mockup v116).
  public enum Sparkline {
    /// Seconds for the line to draw itself in, once, as it appears.
    public static let drawSeconds: CFTimeInterval = 0.8
    /// The draw-in's timing curve: cubic-bezier(.2, .8, .2, 1).
    public static let drawCurve: [Float] = [0.2, 0.8, 0.2, 1]
    /// Seconds for the last point and the dot to glide to a new price, and for the line to slide
    /// left one point when a bar closes.
    public static let glideSeconds: CFTimeInterval = 0.4
    /// The glide's timing curve: cubic-bezier(.25, .1, .25, 1).
    public static let glideCurve: [Float] = [0.25, 0.1, 0.25, 1]
    /// Seconds of one ring around the dot after a new price.
    public static let ringSeconds: CFTimeInterval = 1.2
    /// The ring's timing curve: cubic-bezier(.2, .6, .3, 1).
    public static let ringCurve: [Float] = [0.2, 0.6, 0.3, 1]
    /// How far a ring grows, as a multiple of the dot.
    public static let ringScale: CGFloat = 3.4
    /// A ring's opacity as it starts; it fades to nothing.
    public static let ringOpacity: Float = 0.75
    /// A ring's stroke, in points.
    public static let ringStroke: CGFloat = 1.5
    /// The dot at the line's end, in points.
    public static let dot: CGFloat = 7
    /// The line on the iPhone's position cards, in points.
    public static let lineSmall: CGFloat = 2
    /// The line in larger charts (Mac Overview, iPhone Positions), in points.
    public static let lineLarge: CGFloat = 2.4
    /// Opacity of the fill under the line in larger charts.
    public static let fillOpacity: Float = 0.12
    /// Opacity of the line while its price is stale.
    public static let staleOpacity: Float = 0.75
    /// Seconds for the colours to change between live and stale.
    public static let toneSeconds: CFTimeInterval = 0.3
    /// Points (gaps) the iPhone's position cards show: the last 9 closes and the live price.
    public static let gapsSmall = 9
    /// Gaps larger charts show: the last 13 closes and the live price.
    public static let gapsLarge = 13
  }
}
