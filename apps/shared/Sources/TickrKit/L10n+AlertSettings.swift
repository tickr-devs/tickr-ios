import Foundation

/// Texts of the notification settings on both apps (GET /alerts, PUT /alerts/routing).
public enum AlertText {
  static var bundle: LocalizedStringResource.BundleDescription { L10n.bundle }

  /// The settings section's title.
  public static var title: LocalizedStringResource {
    LocalizedStringResource("kit.alerts.title", defaultValue: "Notifications", bundle: bundle)
  }
  /// Heading of the channels the bot alerts through.
  public static var channels: LocalizedStringResource {
    LocalizedStringResource("kit.alerts.channels", defaultValue: "Channels", bundle: bundle)
  }
  /// Heading of the alert kinds the owner can switch.
  public static var alerts: LocalizedStringResource {
    LocalizedStringResource("kit.alerts.alerts", defaultValue: "Alerts", bundle: bundle)
  }
  /// The Telegram channel.
  public static var telegramChannel: LocalizedStringResource {
    LocalizedStringResource("kit.alerts.channel.telegram", defaultValue: "Telegram", bundle: bundle)
  }
  /// The iPhone app's push channel.
  public static var pushChannel: LocalizedStringResource {
    LocalizedStringResource("kit.alerts.channel.push", defaultValue: "iPhone push", bundle: bundle)
  }
  /// Column of Telegram (short).
  public static var telegramColumn: LocalizedStringResource {
    LocalizedStringResource("kit.alerts.column.telegram", defaultValue: "Telegram", bundle: bundle)
  }
  /// Column of iPhone push (short).
  public static var pushColumn: LocalizedStringResource {
    LocalizedStringResource("kit.alerts.column.push", defaultValue: "Push", bundle: bundle)
  }
  /// Who the Telegram message goes to.
  public static var telegramNote: LocalizedStringResource {
    LocalizedStringResource("kit.alerts.note.telegram",
      defaultValue: "To the chat in the bot's settings", bundle: bundle)
  }
  /// Why push is not built yet.
  public static var pushNote: LocalizedStringResource {
    LocalizedStringResource("kit.alerts.note.push", defaultValue: "Needs an Apple Developer membership", bundle: bundle)
  }
  /// The latest morning check proved the channel works.
  public static var works: LocalizedStringResource {
    LocalizedStringResource("kit.alerts.works", defaultValue: "Works", bundle: bundle)
  }
  /// No morning check has run yet.
  public static var noPreflight: LocalizedStringResource {
    LocalizedStringResource("kit.alerts.noPreflight", defaultValue: "No morning check yet", bundle: bundle)
  }
  /// The morning check's record cannot be read.
  public static var preflightUnreadable: LocalizedStringResource {
    LocalizedStringResource("kit.alerts.preflightUnreadable", defaultValue: "Morning check unreadable", bundle: bundle)
  }
  /// The morning check found the channel does not work.
  public static var checkFailed: LocalizedStringResource {
    LocalizedStringResource("kit.alerts.checkFailed", defaultValue: "Failed the morning check", bundle: bundle)
  }
  /// The channel does not exist yet.
  public static var notBuilt: LocalizedStringResource {
    LocalizedStringResource("kit.alerts.notBuilt", defaultValue: "Not built yet", bundle: bundle)
  }
  /// The owner has not set the channel up in the bot's settings.
  public static var notConfigured: LocalizedStringResource {
    LocalizedStringResource("kit.alerts.notConfigured",
      defaultValue: "Not set up in the bot's settings", bundle: bundle)
  }
  /// Group of alerts that need the owner now.
  public static var critical: LocalizedStringResource {
    LocalizedStringResource("kit.alerts.group.critical", defaultValue: "Needs you now", bundle: bundle)
  }
  /// Group of trading alerts.
  public static var trading: LocalizedStringResource {
    LocalizedStringResource("kit.alerts.group.trading", defaultValue: "Trading", bundle: bundle)
  }
  /// Group of alerts about the day and the bot.
  public static var day: LocalizedStringResource {
    LocalizedStringResource("kit.alerts.group.day", defaultValue: "Day and bot", bundle: bundle)
  }
  /// Group of model lab alerts.
  public static var lab: LocalizedStringResource {
    LocalizedStringResource("kit.alerts.group.lab", defaultValue: "Model lab", bundle: bundle)
  }
  /// Title of the alerts that cannot be turned off.
  public static var alwaysOn: LocalizedStringResource {
    LocalizedStringResource("kit.alerts.alwaysOn", defaultValue: "Always on everywhere", bundle: bundle)
  }
  /// Why some alerts cannot be turned off.
  public static var alwaysOnNote: LocalizedStringResource {
    LocalizedStringResource("kit.alerts.alwaysOnNote",
      defaultValue: "They need you now, so they cannot be turned off.", bundle: bundle)
  }
  /// VoiceOver: an alert that cannot be turned off.
  public static var locked: LocalizedStringResource {
    LocalizedStringResource("kit.alerts.locked", defaultValue: "Always on", bundle: bundle)
  }
  /// The routing file is out of shape.
  public static var routingUnusable: LocalizedStringResource {
    LocalizedStringResource("kit.alerts.routingUnusable",
      // swiftlint:disable:next line_length
      defaultValue: "The routing file cannot be used, so every alert goes everywhere. Delete it on the Mac to choose again.", bundle: bundle)
  }
  /// Note under the alert switches.
  public static var appliesNext: LocalizedStringResource {
    LocalizedStringResource("kit.alerts.appliesNext",
      defaultValue: "A change applies from the next alert. The alerts feed always gets every alert.", bundle: bundle)
  }
  /// The settings could not be read.
  public static var readFailed: LocalizedStringResource {
    LocalizedStringResource("kit.alerts.readFailed",
      defaultValue: "Notification settings could not be read", bundle: bundle)
  }
  /// An alert kind this app does not know.
  public static var otherAlert: LocalizedStringResource {
    LocalizedStringResource("kit.alerts.otherAlert", defaultValue: "Other alert", bundle: bundle)
  }
  /// A change the bot did not make, with why.
  public static func notChanged(_ cause: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.alerts.notChanged", defaultValue: "Not changed: \(cause)", bundle: bundle)
  }

  /// An alert kind in words; one this app does not know reads as "Other alert", never its code.
  public static func kind(_ raw: String) -> LocalizedStringResource {
    AlertKindCode(rawValue: raw)?.title ?? otherAlert
  }
}
