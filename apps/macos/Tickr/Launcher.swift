#if os(macOS)
import SwiftUI

/// The Xcode app's entry point: Xcode compiles this folder as the app's one module. The `swift
/// build` app takes these screens as the library TickrScreens and has its own entry point
/// (Launch/TickrMacMain.swift), so a package build leaves this one out.
#if !SWIFT_PACKAGE
@main
enum XcodeMain {
  @MainActor
  static func main() { Launcher.main() }
}
#endif

/// Starts the macOS app, from either entry point.
public enum Launcher {
  @MainActor
  public static func main() {
    TickrMacApp.main()
  }
}
#endif
