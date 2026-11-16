import SwiftUI

public extension Tokens {
  /// The on/off switch (`DesignSwitchStyle`), as the boards' `.sw`, in points.
  enum Switch {
    /// Track width and height.
    public static let width: CGFloat = 34
    public static let height: CGFloat = 20
    /// The knob's diameter, and its gap to the track's edge.
    public static let knob: CGFloat = 16
    public static let inset: CGFloat = 2
  }
}
