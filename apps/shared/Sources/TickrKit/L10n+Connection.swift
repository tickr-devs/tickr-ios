import Foundation

/// Texts of the connection banner and empty state (ConnectionState) and the headline of a failed
/// read.
extension L10n {
  // MARK: Connection (ConnectionState)

  /// Title of the banner when nothing answers at the bot's address.
  static var connectionUnreachableTitle: LocalizedStringResource {
    LocalizedStringResource("kit.connection.unreachableTitle", defaultValue: "Can't reach the bot", bundle: bundle)
  }
  /// The banner's line over last known data; arguments: the last good read's time, the seconds
  /// between reads.
  static func connectionLastKnown(_ time: String, _ seconds: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.connection.lastKnown",
      defaultValue: "showing data from \(time) · retrying every \(seconds) s · commands off", bundle: bundle)
  }
  /// The line when nothing was ever read; argument: the seconds between reads.
  static func connectionNothingYet(_ seconds: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.connection.nothingYet",
      defaultValue: "nothing received yet · retrying every \(seconds) s · commands off", bundle: bundle)
  }
  /// Title of the empty state before an address is set.
  static var connectionNotConfiguredTitle: LocalizedStringResource {
    LocalizedStringResource("kit.connection.notConfiguredTitle", defaultValue: "Connect to your Mac", bundle: bundle)
  }
  /// The empty state's sentence before an address is set.
  static var connectionNotConfiguredBody: LocalizedStringResource {
    LocalizedStringResource("kit.connection.notConfiguredBody",
      defaultValue: "pair this device with the Mac in Settings", bundle: bundle)
  }
  /// Title when the API answers but the bot has written no status.
  static var connectionNoBotStatusTitle: LocalizedStringResource {
    LocalizedStringResource("kit.connection.noBotStatusTitle", defaultValue: "The bot has not reported yet",
      bundle: bundle)
  }
  /// Sentence when the API answers but the bot has written no status.
  static var connectionNoBotStatusBody: LocalizedStringResource {
    LocalizedStringResource("kit.connection.noBotStatusBody",
      defaultValue: "the Mac answers, the bot has no status · entries not possible", bundle: bundle)
  }
  /// The banner's action that reads again now.
  static var connectionRetry: LocalizedStringResource {
    LocalizedStringResource("kit.connection.retry", defaultValue: "Retry", bundle: bundle)
  }
  /// The banner's action that opens the connection settings.
  static var connectionSettings: LocalizedStringResource {
    LocalizedStringResource("kit.connection.settings", defaultValue: "Settings", bundle: bundle)
  }
  /// The disclosure that shows the technical detail.
  static var connectionDetails: LocalizedStringResource {
    LocalizedStringResource("kit.connection.details", defaultValue: "Details", bundle: bundle)
  }
  /// The details' first line; argument: the address the app reads from.
  static func connectionAddress(_ address: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.connection.address", defaultValue: "Address: \(address)", bundle: bundle)
  }
  /// Headline while the last read of the bot failed: plain words, the detail is in the banner.
  static var headlineNoConnection: LocalizedStringResource {
    LocalizedStringResource("kit.headline.noConnection", defaultValue: "Can't reach the bot. Entry status unknown.",
      bundle: bundle)
  }
}
