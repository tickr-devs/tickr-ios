import ApertureDesign
import ApertureKit
import SwiftUI

/// The standard Settings window (⌘,). The app's own preferences are editable; the bot's
/// configuration is shown read-only because it lives in config/bot.toml, not in the app.
struct SettingsView: View {
  /// Width of the Settings window, in points.
  static let width: CGFloat = 560
  /// SF Symbols of the tabs.
  static let generalSymbol = "gearshape"
  static let tradingSymbol = "chart.line.uptrend.xyaxis"
  static let notificationsSymbol = "bell.badge"
  static let environmentSymbol = "server.rack"
  static let storageSymbol = "internaldrive"
  static let advancedSymbol = "wrench.and.screwdriver"

  var body: some View {
    TabView {
      GeneralSettings().tabItem { Label(String(localized: L10n.Settings.general), systemImage: Self.generalSymbol) }
      TradingSettings().tabItem { Label(String(localized: L10n.Settings.trading), systemImage: Self.tradingSymbol) }
      NotificationSettings().tabItem { Label(String(localized: L10n.Settings.notifications), systemImage: Self.notificationsSymbol) }
      EnvironmentSettings().tabItem { Label(String(localized: L10n.Settings.environment), systemImage: Self.environmentSymbol) }
      StorageSettings().tabItem { Label(String(localized: L10n.Settings.storage), systemImage: Self.storageSymbol) }
      AdvancedSettings().tabItem { Label(String(localized: L10n.Settings.advanced), systemImage: Self.advancedSymbol) }
    }
    .frame(width: Self.width)
    .scenePadding()
  }
}

/// Where a read-only value comes from, shown under each bot-configuration section.
private struct ConfigFootnote: View {
  var body: some View {
    Text(L10n.Settings.configFootnote)
      .font(Tokens.Typography.caption).foregroundStyle(.secondary)
  }
}

private struct GeneralSettings: View {
  @Environment(AppModel.self) private var model
  @AppStorage(Defaults.apiBaseURL) private var apiBaseURL = APIClient.defaultBaseURL.absoluteString
  @AppStorage(Defaults.showMenuBarExtra) private var showMenuBarExtra = true
  @State private var draft = ""
  @State private var invalid = false

  /// URL schemes the local API address may use.
  static let schemes: Set = ["http", "https"]

  var body: some View {
    Form {
      Section {
        TextField(String(localized: L10n.Settings.apiAddress), text: $draft)
          .onSubmit(apply)
        HStack {
          Spacer()
          Button(String(localized: L10n.Settings.useDefault)) { draft = APIClient.defaultBaseURL.absoluteString; apply() }
          Button(String(localized: L10n.Settings.connect), action: apply).keyboardShortcut(.defaultAction)
            .disabled(draft == model.baseURL.absoluteString)
        }
      } header: {
        Text(L10n.Settings.botConnection)
      } footer: {
        Group {
          if let error = model.fetchError {
            Text(L10n.Settings.notReachable(error))
          } else {
            Text(L10n.Settings.connectedTo(model.baseURL.absoluteString))
          }
        }
        .font(Tokens.Typography.caption)
        .foregroundStyle(model.fetchError == nil ? Color.secondary : Palette.lossText)
      }
      Section(String(localized: L10n.Settings.menuBar)) {
        Toggle(String(localized: L10n.Settings.showInMenuBar), isOn: $showMenuBarExtra)
      }
      Section(String(localized: L10n.Settings.appearance)) {
        LabeledContent(String(localized: L10n.Settings.theme)) { Text(L10n.Settings.followsSystem) }
      }
    }
    .formStyle(.grouped)
    .onAppear { draft = model.baseURL.absoluteString }
    .alert(String(localized: L10n.Settings.invalidAddress), isPresented: $invalid) {
      Button(String(localized: L10n.Settings.ok), role: .cancel) {}
    } message: {
      Text(L10n.Settings.enterAddress(APIClient.defaultBaseURL.absoluteString))
    }
  }

  private func apply() {
    guard let url = URL(string: draft.trimmingCharacters(in: .whitespaces)),
      Self.schemes.contains(url.scheme ?? ""), url.host() != nil else {
      invalid = true
      return
    }
    apiBaseURL = url.absoluteString
    model.connect(to: url)
  }
}

private struct TradingSettings: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    Form {
      if let settings = model.settings {
        Section(String(localized: L10n.Common.strategy)) {
          LabeledContent(String(localized: L10n.Settings.activeStrategy), value: settings.activeStrategy)
          LabeledContent(String(localized: L10n.Settings.observers), value: settings.observers.isEmpty
            ? String(localized: L10n.Common.none) : settings.observers.formatted(.list(type: .and)))
        }
        Section {
          LabeledContent(String(localized: L10n.Settings.plannedLoss), value: Format.usd(settings.risk.plannedLossUsd.value))
          LabeledContent(String(localized: L10n.Settings.notionalCap),
            value: Format.usd(settings.risk.positionNotionalCapUsd.value))
          LabeledContent(String(localized: L10n.Settings.dailyLossLimit), value: Format.usd(settings.risk.maxDailyLossUsd.value))
          LabeledContent(String(localized: L10n.Settings.maxOpenPositions), value: "\(settings.risk.maxOpenPositions)")
          LabeledContent(String(localized: L10n.Settings.maxQuoteAge), value: Format.seconds(settings.risk.maxQuoteAgeSeconds.value))
        } header: {
          Text(L10n.Common.risk)
        } footer: {
          ConfigFootnote()
        }
        Section {
          LabeledContent(String(localized: L10n.Settings.marketTimezone), value: settings.session.timezone)
          LabeledContent(String(localized: L10n.Settings.lastEntry),
            value: Self.beforeClose(settings.session.lastEntryMinutesBeforeClose))
          LabeledContent(String(localized: L10n.Settings.flatten), value: Self.beforeClose(settings.session.flattenMinutesBeforeClose))
          LabeledContent(String(localized: L10n.Settings.halfDays), value: settings.session.halfDaysEnabled
            ? String(localized: L10n.Settings.traded) : String(localized: L10n.Settings.notTraded))
        } header: {
          Text(L10n.Settings.session)
        } footer: {
          ConfigFootnote()
        }
      } else {
        Section {
          Group {
            if let error = model.settingsError { Text(verbatim: error) } else { Text(L10n.Settings.readingSettings) }
          }
          .foregroundStyle(.secondary)
        }
      }
    }
    .formStyle(.grouped)
  }

  private static func beforeClose(_ minutes: Int) -> String { String(localized: L10n.Settings.beforeClose(minutes)) }
}

/// The alerts the bot sends (runtime/alerts.py `AlertKind`, grouped): every one is on and goes out
/// as a Mac notification and, with a recipient in the bot's env file, as an iMessage. Nothing here
/// is a switch, because the bot decides; phone push waits for the iOS app.
private struct NotificationSettings: View {
  /// One group of the bot's alert kinds: symbol, tone, title and the kinds it covers.
  struct AlertGroup: Identifiable {
    let symbol: String
    let tone: Tone
    let title: LocalizedStringResource
    let kinds: LocalizedStringResource
    var id: String { title.key }
  }

  /// Symbol of the phone push row.
  static let phoneSymbol = "iphone.radiowaves.left.and.right"

  /// The groups, most urgent first.
  static var groups: [AlertGroup] {
    [
      AlertGroup(symbol: "shield.slash", tone: .loss, title: L10n.Settings.alertUnprotected,
        kinds: L10n.Settings.alertUnprotectedKinds),
      AlertGroup(symbol: "xmark.octagon", tone: .loss, title: L10n.Settings.alertExit, kinds: L10n.Settings.alertExitKinds),
      AlertGroup(symbol: "power", tone: .loss, title: L10n.Settings.alertBot, kinds: L10n.Settings.alertBotKinds),
      AlertGroup(symbol: "eye.trianglebadge.exclamationmark", tone: .warning, title: L10n.Settings.alertWatchdog,
        kinds: L10n.Settings.alertWatchdogKinds),
      AlertGroup(symbol: "arrow.triangle.2.circlepath", tone: .warning, title: L10n.Settings.alertBroker,
        kinds: L10n.Settings.alertBrokerKinds),
      AlertGroup(symbol: "gauge.with.dots.needle.100percent", tone: .warning, title: L10n.Settings.alertLossLimit,
        kinds: L10n.Settings.alertLossLimitKinds),
      AlertGroup(symbol: "checklist", tone: .info, title: L10n.Settings.alertMorning, kinds: L10n.Settings.alertMorningKinds),
      AlertGroup(symbol: "binoculars", tone: .info, title: L10n.Settings.alertObservers,
        kinds: L10n.Settings.alertObserversKinds),
    ]
  }

  var body: some View {
    Form {
      Section {
        ForEach(Self.groups) { group in
          HStack(spacing: Tokens.Space.s) {
            StateGlyph(group.symbol, tone: group.tone, label: group.title, style: .compact)
            VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
              Text(group.title)
              Text(group.kinds)
                .font(Tokens.Typography.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: Tokens.Space.s)
            StatusPill(L10n.Common.on, tone: .profit)
          }
        }
        HStack(spacing: Tokens.Space.s) {
          StateGlyph(Self.phoneSymbol, tone: .neutral, label: L10n.Settings.phonePush, style: .compact)
          Text(L10n.Settings.phonePush)
          Spacer(minLength: Tokens.Space.s)
          PlannedTag()
        }
      } header: {
        Text(L10n.Settings.botAlerts)
      } footer: {
        Text(L10n.Settings.alertsFooter)
          .font(Tokens.Typography.caption).foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
  }
}

private struct EnvironmentSettings: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    Form {
      Section {
        LabeledContent(String(localized: L10n.Settings.environment), value: model.status?.environment ?? model.settings?.environment ?? Format.missing)
        if let gate = model.status?.tradingGate {
          LabeledContent(String(localized: L10n.Settings.tradingGate),
            value: String(localized: gate.open ? L10n.Settings.gateOpen : L10n.Settings.gateClosed))
          LabeledContent(String(localized: L10n.Settings.gateCause), value: ApiText.gate(gate))
        }
        LabeledContent(String(localized: L10n.Settings.apiVersion), value: model.settings.map { "\($0.apiVersion)" } ?? Format.missing)
      } header: {
        Text(L10n.Settings.brokerEnvironment)
      } footer: {
        Text(L10n.Settings.environmentFixed)
          .font(Tokens.Typography.caption).foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
  }
}

private struct StorageSettings: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    Form {
      Section {
        LabeledContent(String(localized: L10n.Settings.recordedDays), value: "\(model.days.count)")
        LabeledContent(String(localized: L10n.Settings.firstRecordedDay), value: model.days.last.map { Format.dayLabel($0.day) } ?? Format.missing)
        LabeledContent(String(localized: L10n.Settings.daysWithBars), value: "\(model.days.filter(\.hasBars).count)")
      } header: {
        Text(L10n.Settings.history)
      } footer: {
        Group {
          if let error = model.historyError {
            Text(verbatim: error)
          } else {
            Text(L10n.Settings.historySource)
          }
        }
        .font(Tokens.Typography.caption).foregroundStyle(model.historyError == nil ? Color.secondary : Palette.lossText)
      }
    }
    .formStyle(.grouped)
  }
}

private struct AdvancedSettings: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    Form {
      Section {
        LabeledContent(String(localized: L10n.Settings.statusRefresh),
          value: model.settings.map { String(localized: L10n.Settings.every(Format.seconds($0.pollSeconds.value))) }
            ?? Format.missing)
        LabeledContent(String(localized: L10n.Settings.staleAfter),
          value: model.settings.map { Format.seconds($0.statusStaleSeconds.value) } ?? Format.missing)
        LabeledContent(String(localized: L10n.Settings.run), value: model.status?.runId ?? Format.missing)
      } header: {
        Text(L10n.Common.bot)
      } footer: {
        ConfigFootnote()
      }
      Section(String(localized: L10n.Settings.notAvailableYet)) {
        HStack { Text(L10n.Settings.startStop); Spacer(); PlannedTag(.needsAPI) }
        HStack { Text(L10n.Settings.editConfig); Spacer(); PlannedTag() }
      }
    }
    .formStyle(.grouped)
  }
}
