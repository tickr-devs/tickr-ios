import Foundation

/// The notifications screen and Settings › Connection's row (mockup v189, board PushAsk): every
/// text in English, Spanish in Localizable.xcstrings.
extension L10n {
  enum Notifications {
    /// The screen's title.
    static var title: LocalizedStringResource {
      LocalizedStringResource("notifications.title", defaultValue: "Turn on notifications", bundle: L10n.bundle)
    }
    /// Under the title.
    static var lead: LocalizedStringResource {
      LocalizedStringResource("notifications.lead",
        defaultValue: "Tickr tells you only what needs you.", bundle: L10n.bundle)
    }
    /// The first reason.
    static var alarms: LocalizedStringResource {
      LocalizedStringResource("notifications.alarms", defaultValue: "Alarms", bundle: L10n.bundle)
    }
    /// What an alarm is.
    static var alarmsLine: LocalizedStringResource {
      LocalizedStringResource("notifications.alarmsLine",
        defaultValue: "A stop not confirmed at the broker, or the bot not answering.", bundle: L10n.bundle)
    }
    /// The second reason.
    static var signIns: LocalizedStringResource {
      LocalizedStringResource("notifications.signIns", defaultValue: "Sign-ins", bundle: L10n.bundle)
    }
    /// What a sign-in notice is.
    static var signInsLine: LocalizedStringResource {
      LocalizedStringResource("notifications.signInsLine",
        defaultValue: "A new device signs in to your account.", bundle: L10n.bundle)
    }
    /// The iPhone's third reason.
    static var liveActivity: LocalizedStringResource {
      LocalizedStringResource("notifications.liveActivity", defaultValue: "Live Activity", bundle: L10n.bundle)
    }
    /// What the Live Activity shows.
    static var liveActivityLine: LocalizedStringResource {
      LocalizedStringResource("notifications.liveActivityLine",
        defaultValue: "Your positions on the Lock Screen and in the Dynamic Island.", bundle: L10n.bundle)
    }
    /// Brings the system's question.
    static var allow: LocalizedStringResource {
      LocalizedStringResource("notifications.allow", defaultValue: "Allow notifications", bundle: L10n.bundle)
    }
    /// Closes the screen.
    static var notNow: LocalizedStringResource {
      LocalizedStringResource("notifications.notNow", defaultValue: "Not now", bundle: L10n.bundle)
    }
    /// Under the buttons.
    static var foot: LocalizedStringResource {
      LocalizedStringResource("notifications.foot",
        defaultValue: "You can turn them on later in Settings › Connection.", bundle: L10n.bundle)
    }
    /// Settings › Connection: the row while notifications are off.
    static var row: LocalizedStringResource {
      LocalizedStringResource("notifications.row", defaultValue: "Notifications", bundle: L10n.bundle)
    }
    /// Under the row's title.
    static var rowLine: LocalizedStringResource {
      LocalizedStringResource("notifications.rowLine",
        defaultValue: "Alarms and sign-ins won’t reach you.", bundle: L10n.bundle)
    }
    /// The row's state.
    static var off: LocalizedStringResource {
      LocalizedStringResource("notifications.off", defaultValue: "Off", bundle: L10n.bundle)
    }
    /// The row's button on the Mac.
    static var turnOn: LocalizedStringResource {
      LocalizedStringResource("notifications.turnOn", defaultValue: "Turn on", bundle: L10n.bundle)
    }
  }
}
