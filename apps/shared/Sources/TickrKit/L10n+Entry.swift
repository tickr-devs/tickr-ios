import Foundation

/// The words of a working entry and its Cancel entry (mockup v160), the same on both apps, in
/// English with their Spanish translation in Resources/Localizable.xcstrings.
public enum EntryText {
  /// The row's label while the order works or its cancel is on its way.
  public static var working: LocalizedStringResource {
    LocalizedStringResource("kit.entry.working", defaultValue: "Working entry", bundle: L10n.bundle)
  }
  /// The row's label once the broker cancelled it.
  public static var cancelled: LocalizedStringResource {
    LocalizedStringResource("kit.entry.cancelled", defaultValue: "Entry cancelled", bundle: L10n.bundle)
  }
  /// "Buying 10 @ 12.34 limit": the order while it works.
  public static func buying(_ quantity: String, _ price: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.entry.buying", defaultValue: "Buying \(quantity) @ \(price) limit", bundle: L10n.bundle)
  }
  /// "Buy 10 @ 12.34 limit": the order once cancelled.
  public static func buy(_ quantity: String, _ price: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.entry.buy", defaultValue: "Buy \(quantity) @ \(price) limit", bundle: L10n.bundle)
  }
  /// "sent 10:42 · waiting for fill".
  public static func sentWaiting(_ time: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.entry.sentWaiting", defaultValue: "sent \(time) · waiting for fill", bundle: L10n.bundle)
  }
  /// The same when the bot's journal has no send time.
  public static var waiting: LocalizedStringResource {
    LocalizedStringResource("kit.entry.waiting", defaultValue: "waiting for fill", bundle: L10n.bundle)
  }
  /// While the cancel is on its way.
  public static var cancelling: LocalizedStringResource {
    LocalizedStringResource("kit.entry.cancelling", defaultValue: "Cancelling…", bundle: L10n.bundle)
  }
  /// Once a broker read showed the order cancelled.
  public static var cancelledAtBroker: LocalizedStringResource {
    LocalizedStringResource("kit.entry.cancelledAtBroker", defaultValue: "Cancelled at broker", bundle: L10n.bundle)
  }
  /// "stop 11.90 planned": the stop the bot places once it fills.
  public static func stopPlanned(_ price: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.entry.stopPlanned", defaultValue: "stop \(price) planned", bundle: L10n.bundle)
  }
  /// "max loss $4.40 if filled".
  public static func maxLoss(_ amount: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.entry.maxLoss", defaultValue: "max loss \(amount) if filled", bundle: L10n.bundle)
  }
  /// Under a cancelled entry.
  public static var noPosition: LocalizedStringResource {
    LocalizedStringResource("kit.entry.noPosition", defaultValue: "No position opened", bundle: L10n.bundle)
  }
  /// The button.
  public static var cancel: LocalizedStringResource {
    LocalizedStringResource("kit.entry.cancel", defaultValue: "Cancel entry", bundle: L10n.bundle)
  }
  /// The button's help.
  public static var cancelHint: LocalizedStringResource {
    LocalizedStringResource("kit.entry.cancelHint", defaultValue: "Cancels the entry order at the broker", bundle: L10n.bundle)
  }
  /// The question: "Cancel the ABCD entry order?".
  public static func question(_ symbol: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.entry.question", defaultValue: "Cancel the \(symbol) entry order?", bundle: L10n.bundle)
  }
  /// What the cancel does: "The bot asks the broker to cancel the buy of 10 shares at 12.34. …".
  public static func explanation(_ quantity: String, _ price: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.entry.explanation",
      // swiftlint:disable:next line_length
      defaultValue: "The bot asks the broker to cancel the buy of \(quantity) shares at \(price). Nothing has filled, so no position opens. Entries stay on.",
      bundle: L10n.bundle)
  }
  /// Beside the symbol on an entry's chip in the Mac Positions row (mockup v162): "QRST · entry".
  public static var chipWord: LocalizedStringResource {
    LocalizedStringResource("kit.entry.chipWord", defaultValue: "entry", bundle: L10n.bundle)
  }
  /// The chip's spoken name: "Working entry QRST".
  public static func chipLabel(_ symbol: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.entry.chipLabel", defaultValue: "Working entry \(symbol)", bundle: L10n.bundle)
  }
  /// The iPhone's short state line on an entry row beside positions: "sent 10:46 · waiting for fill".
  public static func sentWaitingShort(_ time: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.entry.sentWaitingShort", defaultValue: "sent \(time) · waiting for fill", bundle: L10n.bundle)
  }
  /// The iPhone entry row's Cancel pill, and its spoken name: "Cancel the entry for QRST".
  public static var cancelShort: LocalizedStringResource {
    LocalizedStringResource("kit.entry.cancelShort", defaultValue: "Cancel", bundle: L10n.bundle)
  }
  public static func cancelFor(_ symbol: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.entry.cancelFor", defaultValue: "Cancel the entry for \(symbol)", bundle: L10n.bundle)
  }
  /// The question's answer that leaves the order working.
  public static var keep: LocalizedStringResource {
    LocalizedStringResource("kit.entry.keep", defaultValue: "Keep", bundle: L10n.bundle)
  }
}
