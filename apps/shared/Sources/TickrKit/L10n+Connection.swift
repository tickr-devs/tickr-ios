import Foundation

/// Texts of the connection banner and empty state (ConnectionState) and the headline of a failed
/// read.
extension L10n {
  // MARK: A failed read (APIError)

  /// An answer the app cannot read (a field it does not know): the app and the bot come from
  /// different releases. Says what to do, never the field path or the contract.
  static var apiUnreadable: LocalizedStringResource {
    LocalizedStringResource("kit.api.unreadable",
      defaultValue: "the app and the bot are from different releases: install the app from the bot's release",
      bundle: bundle)
  }

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
  /// Title of the banner when the bot answers but refuses this device's token.
  static var connectionRefusedTitle: LocalizedStringResource {
    LocalizedStringResource("kit.connection.refusedTitle", defaultValue: "The bot refuses this device", bundle: bundle)
  }
  /// The banner's line when the bot refuses this device's token: no retry fixes it.
  static var connectionRefusedBody: LocalizedStringResource {
    LocalizedStringResource("kit.connection.refusedBody",
      defaultValue: "this device is not signed in to the bot, retrying will not help: sign in again in Settings · commands off",
      bundle: bundle)
  }
  /// Title of the empty state before this device is signed in.
  static var connectionNotConfiguredTitle: LocalizedStringResource {
    LocalizedStringResource("kit.connection.notConfiguredTitle", defaultValue: "Sign in to your bot", bundle: bundle)
  }
  /// The empty state's sentence before this device is signed in.
  static var connectionNotConfiguredBody: LocalizedStringResource {
    LocalizedStringResource("kit.connection.notConfiguredBody",
      defaultValue: "sign in with your tickr.bot account in Settings", bundle: bundle)
  }
  /// Title when the API answers but the bot has written no status.
  static var connectionNoBotStatusTitle: LocalizedStringResource {
    LocalizedStringResource("kit.connection.noBotStatusTitle", defaultValue: "The bot has not reported yet",
      bundle: bundle)
  }
  /// Sentence when the API answers but the bot has written no status.
  static var connectionNoBotStatusBody: LocalizedStringResource {
    LocalizedStringResource("kit.connection.noBotStatusBody",
      defaultValue: "the server answers, the bot has no status · entries not possible", bundle: bundle)
  }
  /// The banner's action that reads again now.
  static var connectionRetry: LocalizedStringResource {
    LocalizedStringResource("kit.connection.retry", defaultValue: "Retry", bundle: bundle)
  }
  /// The banner's action that opens the connection settings.
  static var connectionSettings: LocalizedStringResource {
    LocalizedStringResource("kit.connection.settings", defaultValue: "Settings", bundle: bundle)
  }
  /// A card's calm placeholder while the link to the bot is down (the banner says why).
  static var connectionWaiting: LocalizedStringResource {
    LocalizedStringResource("kit.connection.waiting", defaultValue: "Waiting for the connection", bundle: bundle)
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

  // MARK: Signing in (SignIn)

  /// Why a sign-in ended: tickr.bot turned the account away.
  static var signInAccountRefused: LocalizedStringResource {
    LocalizedStringResource("kit.signIn.accountRefused",
      defaultValue: "this tickr.bot account may not reach the bot", bundle: bundle)
  }
  /// Why a sign-in ended: the sheet came back with an answer that is not this sign-in's.
  static var signInBadAnswer: LocalizedStringResource {
    LocalizedStringResource("kit.signIn.badAnswer",
      defaultValue: "tickr.bot sent an answer this sign-in does not expect", bundle: bundle)
  }
  /// Why a sign-in stopped short of the bot: it used a password or an emailed code only.
  static var accountNeedsStrongFactor: LocalizedStringResource {
    LocalizedStringResource("kit.signIn.needsStrongFactor",
      defaultValue: "Reaching the bot needs your passkey or authenticator app; sign in with one of them",
      bundle: bundle)
  }
  /// Why a sign-in step failed: tickr.bot could not be reached.
  static var accountUnreachable: LocalizedStringResource {
    LocalizedStringResource("kit.signIn.unreachable",
      defaultValue: "tickr.bot cannot be reached; check the connection and try again", bundle: bundle)
  }
  /// Why an emailed code was refused for good: the third wrong try ended it.
  static var accountCodeSpent: LocalizedStringResource {
    LocalizedStringResource("kit.signIn.codeSpent",
      defaultValue: "This code can't be used any more; send a new one", bundle: bundle)
  }
}
