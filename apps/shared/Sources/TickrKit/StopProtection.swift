import Foundation

extension StopState {
  /// True only for a stop the broker confirmed working. A pending stop is sent and not confirmed:
  /// it does not protect the position yet. The one test of protection both apps use (TickrDesign
  /// maps it to a symbol and a tone, `Meanings.swift`).
  public var isProtected: Bool { self == .verified }

  /// True when every stop is verified (also for none).
  public static func allProtected(_ states: [StopState]) -> Bool {
    states.allSatisfy(\.isProtected)
  }
}
