import Foundation

/// Words of Stop bot with open positions (backlog V4 variant A; boards Main, IOSHome), shared by
/// both apps, in English with their Spanish translation in Resources/Localizable.xcstrings
/// (docs/design-system.md, rule 2).
public enum StopText {
  // MARK: the question

  /// The question's title: "Stop the bot with 2 positions open?".
  public static func chooseTitle(_ count: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.stop.chooseTitle", defaultValue: "Stop the bot with \(count) positions open?",
      bundle: L10n.bundle)
  }
  /// Under the title on the iPhone: "Choose what happens to ABCD and KLMN.".
  public static func chooseBody(_ symbols: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.stop.chooseBody", defaultValue: "Choose what happens to \(symbols).", bundle: L10n.bundle)
  }
  /// The first answer, and the steps' heading.
  public static var closeAndStop: LocalizedStringResource {
    LocalizedStringResource("kit.stop.closeAndStop", defaultValue: "Close and stop", bundle: L10n.bundle)
  }
  /// What Close and stop does: "The bot closes ABCD and KLMN at market, then stops.".
  public static func closeAndStopDetail(_ symbols: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.stop.closeAndStopDetail", defaultValue: "The bot closes \(symbols) at market, then stops.",
      bundle: L10n.bundle)
  }
  /// The second answer.
  public static var leaveOpen: LocalizedStringResource {
    LocalizedStringResource("kit.stop.leaveOpen", defaultValue: "Leave open", bundle: L10n.bundle)
  }
  /// What Leave open does, with the broker stops' end at the close.
  public static var leaveOpenDetail: LocalizedStringResource {
    LocalizedStringResource("kit.stop.leaveOpenDetail",
      // swiftlint:disable:next line_length
      defaultValue: "The bot stops at once and nothing closes them. Positions stay open. They close only at the broker, by their stop or your own orders. Broker stops are day orders and expire at 4:00 PM ET, so a position can stay overnight without a stop.",
      bundle: L10n.bundle)
  }

  // MARK: the steps

  public static var closingPositions: LocalizedStringResource {
    LocalizedStringResource("kit.stop.closingPositions", defaultValue: "Closing positions", bundle: L10n.bundle)
  }
  public static var positionsClosed: LocalizedStringResource {
    LocalizedStringResource("kit.stop.positionsClosed", defaultValue: "Positions closed", bundle: L10n.bundle)
  }
  public static var stopping: LocalizedStringResource {
    LocalizedStringResource("kit.stop.stopping", defaultValue: "Stopping bot", bundle: L10n.bundle)
  }
  public static var stopped: LocalizedStringResource {
    LocalizedStringResource("kit.stop.stopped", defaultValue: "Bot stopped", bundle: L10n.bundle)
  }
  /// A refused close-and-stop, with the bot's cause in words.
  public static func refused(_ cause: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.stop.refused", defaultValue: "Close and stop refused: \(cause)", bundle: L10n.bundle)
  }

  // MARK: stopped with positions open

  /// The panel's title: "Bot stopped · 2 positions open".
  public static func stoppedOpen(_ count: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.stop.stoppedOpen", defaultValue: "Bot stopped · \(count) positions open", bundle: L10n.bundle)
  }
  /// Under the title: "stopped at 10:48:02 ET".
  public static func stoppedAt(_ time: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.stop.stoppedAt", defaultValue: "stopped at \(time) ET", bundle: L10n.bundle)
  }
  /// What nobody does for these positions now.
  public static var stoppedBody: LocalizedStringResource {
    LocalizedStringResource("kit.stop.stoppedBody",
      // swiftlint:disable:next line_length
      defaultValue: "The bot no longer watches these positions. They close only at the broker, by their stop or your own orders. Broker stops are day orders and expire at 4:00 PM ET, so a position can stay overnight without a stop.",
      bundle: L10n.bundle)
  }
  /// Column titles of the panel's table.
  public static var symbolColumn: LocalizedStringResource {
    LocalizedStringResource("kit.stop.symbolColumn", defaultValue: "Symbol", bundle: L10n.bundle)
  }
  public static var quantityColumn: LocalizedStringResource {
    LocalizedStringResource("kit.stop.quantityColumn", defaultValue: "Quantity", bundle: L10n.bundle)
  }
  public static var stopColumn: LocalizedStringResource {
    LocalizedStringResource("kit.stop.stopColumn", defaultValue: "Broker stop", bundle: L10n.bundle)
  }
  /// A row's size: "10 shares".
  public static func shares(_ quantity: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.stop.shares", defaultValue: "\(quantity) shares", bundle: L10n.bundle)
  }
  /// Under the table: the time of the bot's last broker read, never a fresher guess.
  public static func lastKnown(_ time: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.stop.lastKnown",
      defaultValue: "Last known from the broker at \(time) ET. On start the bot reads the broker again and takes them back.",
      bundle: L10n.bundle)
  }
  /// The same when the bot's last status has no broker read time.
  public static var lastKnownUnknown: LocalizedStringResource {
    LocalizedStringResource("kit.stop.lastKnownUnknown",
      defaultValue: "The bot's last status has no broker read time. On start the bot reads the broker again and takes them back.",
      bundle: L10n.bundle)
  }
}
