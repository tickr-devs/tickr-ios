import Foundation

/// The "Demo day" switch of both apps' Settings. The demo day (`tickr demo`, docs/demo.md) is
/// reached through the bot's own API: it forwards every request under `/demo/` to the demo's API on
/// the Mac (api/demo_forward.py). So the switch never replaces the bot's address: it only puts
/// `/demo` in front of the path, the Mac and the phone use the address they already have, and the
/// phone's paired token goes to the paired host only (the API keeps it; it is never forwarded).
/// Switched off, the app is back on the very address it had.
public enum DemoDay {
  /// Path the bot's API forwards to the demo day (protocol constant, api/demo_forward.py).
  public static let path = "demo"

  /// The address the app talks to: the bot's own `address`, or the demo day behind it.
  public static func address(_ address: URL, demo: Bool) -> URL {
    demo ? address.appending(path: path, directoryHint: .notDirectory) : address
  }

  /// The day the app may show: with the switch on, only the demo day, which is the API's own
  /// "today" (its clock is the demo day's), so no other day can be picked.
  public static func day(_ selected: WireDate?, demo: Bool) -> WireDate? {
    demo ? nil : selected
  }
}
