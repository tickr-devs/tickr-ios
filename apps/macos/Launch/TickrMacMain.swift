import TickrScreens

/// Entry point of the `swift build` app (Package.swift): the screens live in the library
/// TickrScreens, which `Launcher` starts. The Xcode app compiles folder Tickr/ as one module and
/// has its own entry point there (`XcodeMain`, AlertCommand.swift).
@main
enum TickrMacMain {
  @MainActor
  static func main() { Launcher.main() }
}
