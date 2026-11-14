import ApertureDesign
import ApertureKit
import SwiftUI

/// The standard Settings window (⌘,). The app's own preferences are editable; the bot's
/// configuration is shown read-only because it lives in config/bot.toml, not in the app.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings().tabItem { Label("General", systemImage: "gearshape") }
            TradingSettings().tabItem { Label("Trading", systemImage: "chart.line.uptrend.xyaxis") }
            NotificationSettings().tabItem { Label("Notifications", systemImage: "bell.badge") }
            EnvironmentSettings().tabItem { Label("Environment", systemImage: "server.rack") }
            StorageSettings().tabItem { Label("Storage", systemImage: "internaldrive") }
            AdvancedSettings().tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }
        }
        .frame(width: 560)
        .scenePadding()
    }
}

/// Where a read-only value comes from, shown under each bot-configuration section.
private struct ConfigFootnote: View {
    var body: some View {
        Text("Read from the bot's local API. Change it in config/bot.toml and restart the bot.")
            .font(.caption).foregroundStyle(.secondary)
    }
}

private struct GeneralSettings: View {
    @Environment(AppModel.self) private var model
    @AppStorage(Defaults.apiBaseURL) private var apiBaseURL = APIClient.defaultBaseURL.absoluteString
    @AppStorage(Defaults.showMenuBarExtra) private var showMenuBarExtra = true
    @State private var draft = ""
    @State private var invalid = false

    var body: some View {
        Form {
            Section {
                TextField("Local API address", text: $draft)
                    .onSubmit(apply)
                HStack {
                    Spacer()
                    Button("Use Default") { draft = APIClient.defaultBaseURL.absoluteString; apply() }
                    Button("Connect", action: apply).keyboardShortcut(.defaultAction)
                        .disabled(draft == model.baseURL.absoluteString)
                }
            } header: {
                Text("Bot connection")
            } footer: {
                Text(model.fetchError.map { "Not reachable: \($0)" } ?? "Connected to \(model.baseURL.absoluteString).")
                    .font(.caption).foregroundStyle(model.fetchError == nil ? Color.secondary : Palette.redStrong)
            }
            Section("Menu bar") {
                Toggle("Show Aperture in the menu bar", isOn: $showMenuBarExtra)
            }
            Section("Appearance") {
                LabeledContent("Theme", value: "Follows the system appearance")
            }
        }
        .formStyle(.grouped)
        .onAppear { draft = model.baseURL.absoluteString }
        .alert("Invalid address", isPresented: $invalid) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Enter an http address of the bot's local API, such as \(APIClient.defaultBaseURL.absoluteString).")
        }
    }

    private func apply() {
        guard let url = URL(string: draft.trimmingCharacters(in: .whitespaces)),
              url.scheme == "http" || url.scheme == "https", url.host() != nil else {
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
                Section("Strategy") {
                    LabeledContent("Active strategy", value: settings.activeStrategy)
                    LabeledContent("Observers", value: settings.observers.isEmpty ? "none" : settings.observers.joined(separator: ", "))
                }
                Section {
                    LabeledContent("Planned loss per trade", value: "\(Money.plain(settings.risk.plannedLossUsd.value)) USD")
                    LabeledContent("Position notional cap", value: "\(Money.plain(settings.risk.positionNotionalCapUsd.value)) USD")
                    LabeledContent("Daily loss limit (net)", value: "\(Money.plain(settings.risk.maxDailyLossUsd.value)) USD")
                    LabeledContent("Open positions at most", value: "\(settings.risk.maxOpenPositions)")
                    LabeledContent("Quote age at most", value: "\(Money.plain(settings.risk.maxQuoteAgeSeconds.value)) s")
                } header: {
                    Text("Risk")
                } footer: {
                    ConfigFootnote()
                }
                Section {
                    LabeledContent("Market timezone", value: settings.session.timezone)
                    LabeledContent("Last entry", value: "\(settings.session.lastEntryMinutesBeforeClose) min before close")
                    LabeledContent("Flatten", value: "\(settings.session.flattenMinutesBeforeClose) min before close")
                    LabeledContent("Half days", value: settings.session.halfDaysEnabled ? "traded" : "not traded")
                } header: {
                    Text("Session")
                } footer: {
                    ConfigFootnote()
                }
            } else {
                Section { Text(model.settingsError ?? "Reading the bot's settings…").foregroundStyle(.secondary) }
            }
        }
        .formStyle(.grouped)
    }
}

private struct NotificationSettings: View {
    var body: some View {
        Form {
            Section {
                ForEach(["Position opened or closed", "Broker stop not verified", "Reconciliation fence",
                         "Daily loss limit reached", "Bot stopped or API unreachable"], id: \.self) { item in
                    HStack {
                        Toggle(item, isOn: .constant(false)).disabled(true)
                        PlannedTag()
                    }
                }
            } header: {
                Text("macOS notifications")
            } footer: {
                Text("System notifications arrive in a later update. Until then the menu-bar icon shows the state.")
                    .font(.caption).foregroundStyle(.secondary)
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
                LabeledContent("Environment", value: model.status?.environment ?? model.settings?.environment ?? "—")
                if let gate = model.status?.tradingGate {
                    LabeledContent("Trading gate", value: gate.open ? "open" : "closed")
                    LabeledContent("Gate cause", value: gate.cause)
                }
                LabeledContent("Local API version", value: model.settings.map { "\($0.apiVersion)" } ?? "—")
            } header: {
                Text("Broker environment")
            } footer: {
                Text("The environment is set in config/bot.toml. The app cannot switch it, by design.")
                    .font(.caption).foregroundStyle(.secondary)
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
                LabeledContent("Recorded days", value: "\(model.days.count)")
                LabeledContent("First recorded day", value: model.days.last.map { Format.dayLabel($0.day) } ?? "—")
                LabeledContent("Days with captured bars", value: "\(model.days.filter(\.hasBars).count)")
            } header: {
                Text("History")
            } footer: {
                Text(model.historyError ?? "History is read from the bot's database and bar captures, read-only.")
                    .font(.caption).foregroundStyle(model.historyError == nil ? Color.secondary : Palette.redStrong)
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
                LabeledContent("Status refresh", value: model.settings.map { "every \(Money.plain($0.pollSeconds.value)) s" } ?? "—")
                LabeledContent("Status stale after", value: model.settings.map { "\(Money.plain($0.statusStaleSeconds.value)) s" } ?? "—")
                LabeledContent("Run", value: model.status?.runId ?? "—")
            } header: {
                Text("Bot")
            } footer: {
                ConfigFootnote()
            }
            Section("Not available yet") {
                HStack { Text("Start and stop the bot from the app"); Spacer(); PlannedTag(.needsAPI) }
                HStack { Text("Edit the bot's configuration"); Spacer(); PlannedTag() }
            }
        }
        .formStyle(.grouped)
    }
}
