import Foundation

/// The "Demo day" switch of both apps' Settings. The apps carry the demo day with them: a
/// recording of the real bot on the simulated exchange (`tickr demo --record`, docs/demo.md),
/// played in a loop by `DemoSource`. On, the app talks to `address`, which the container answers
/// from that recording and never from the network, so the demo works anywhere and at any time,
/// without the Mac, its demo service or the bot. Off, the app is back on the very address it had:
/// the switch never changes the bot's address or the phone's pairing.
public enum DemoDay {
  /// The address of the demo day: no host on any network. `Container.apiClient` answers it from
  /// the recording (`DemoSource`); its scheme is one no URLSession serves.
  public static let address = URL(string: "tickr-demo://day")!

  /// The address the app talks to: the bot's own `address`, or the demo day.
  public static func address(_ address: URL, demo: Bool) -> URL {
    demo ? Self.address : address
  }

  /// Whether `url` is the demo day's address (answered by `DemoSource`).
  public static func isDemo(_ url: URL) -> Bool {
    url == address
  }

  /// The day the app may show: with the switch on, only the demo day, which is the recording's
  /// own "today" (its status says the demo day), so no other day can be picked.
  public static func day(_ selected: WireDate?, demo: Bool) -> WireDate? {
    demo ? nil : selected
  }
}
