import SwiftUI
import TickrDesign
import TickrKit

/// What every section says about the link to the bot (TickrKit `ConnectionState`), above the
/// section's screen: the mockup's calm banner over the last known data (drawn dimmer, RootView) when
/// a read fails, or over the section's own empty cards when nothing was read yet; nothing while the
/// link is fine. The technical cause
/// (address, port, the API's own words) is behind "Details"; commands stay off while it shows
/// (`commandsEnabled`).
struct ConnectionBanner: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(AppModel.self) private var model
  /// The address Settings shows and the app reads at launch; the one-click fix writes it too.
  @AppStorage(Defaults.apiBaseURL) private var apiBaseURL = APIClient.defaultBaseURL.absoluteString
  /// A Retry is on its way: the button waits for it.
  @State private var retrying = false

  var body: some View {
    if let message = model.connectionMessage {
      ConnectionNotice(.banner, title: message.title, subtitle: message.subtitle,
        detailsLabel: ConnectionMessage.detailsLabel, details: details(message)) {
        if Self.offersOwnAddress && message.refused && model.address != APIClient.defaultBaseURL {
          // The bot refuses this address (a Host or token it does not accept): reading it again
          // never helps, going back to this Mac's own address does.
          Button {
            apiBaseURL = APIClient.defaultBaseURL.absoluteString
            model.connect(to: APIClient.defaultBaseURL)
          } label: { Text(ConnectionMessage.useAddress(Self.defaultAddress)) }
            .buttonStyle(.action(.primary, size: .compact))
        } else {
          Button {
            Task {
              retrying = true
              await model.refreshStatus()
              retrying = false
            }
          } label: { Text(ConnectionMessage.retry) }
            .buttonStyle(.action(.secondary, size: .compact))
            .disabled(retrying)
        }
        #if os(macOS)
        // On iPad the navigation bar's gear opens the settings.
        SettingsLink { Text(ConnectionMessage.settings) }
          .buttonStyle(.action(.ghost, size: .compact))
        #endif
      }
      .padding([.horizontal, .top], Tokens.Space.l)
      .transition(.moving(from: .top, reduceMotion: reduceMotion))
    }
  }

  /// Whether a refused address is answered with "use this Mac's own address": only on the Mac. An
  /// iPad has no bot of its own; its address and token come from pairing (the iPad's Settings).
  static var offersOwnAddress: Bool {
    #if os(macOS)
    true
    #else
    false
    #endif
  }

  /// This Mac's own API address as the banner names it ("127.0.0.1:8766").
  static var defaultAddress: String {
    let url = APIClient.defaultBaseURL
    let host = url.host() ?? url.absoluteString
    return url.port.map { "\(host):\($0)" } ?? host
  }

  /// The technical lines under "Details": the address read from, then the failure as the API
  /// client describes it.
  private func details(_ message: ConnectionMessage) -> [String] {
    guard let detail = message.details else { return [] }
    return [String(localized: ConnectionMessage.address(model.baseURL.absoluteString)), detail]
  }
}

extension View {
  /// Sets what every `ReadFailureNote` and card below says: while the link to the bot is down,
  /// cards say nothing of it and leave the failure to the connection banner; when nothing was
  /// ever read, they show their quiet outline. Set on each scene's root.
  func readFailureContext(_ model: AppModel) -> some View {
    environment(\.readFailureContext, ReadFailureContext(connectionDown: model.connectionState.failure != nil,
      noData: model.connectionState.isNeverConnected, detailsLabel: ConnectionMessage.detailsLabel,
      waiting: ConnectionMessage.waiting))
  }
}
