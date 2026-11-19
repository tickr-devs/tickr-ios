import AppKit
import SwiftUI
import TickrDesign
import TickrKit

/// The Settings window (⌘,) as the design draws it (board "macOS — Settings"): the pane's name in
/// small monospace in the title bar, the design's tab strip, then the pane's cards on the pale
/// background. The app's own preferences are editable; the bot's configuration is shown read-only
/// because it lives in config/bot.toml, not in the app.
struct SettingsView: View {
  @Environment(AppModel.self) private var model
  @State private var tab: SettingsTab
  /// Where the pane is scrolled; back to the top on each tab, never the last tab's offset.
  @State private var scroll = ScrollPosition(edge: .top)
  @State private var contentHeight: CGFloat = 0
  /// Height of the title bar the window still reserves above the content (measured): the tab
  /// strip is drawn into it, so the pane asks for that much less height.
  @State private var titleInset: CGFloat = 0

  /// Width of the Settings window, in points (the design's compact 680).
  static let width: CGFloat = 680
  /// Tallest the pane area grows to its content before it scrolls, in points.
  static let maxPaneHeight: CGFloat = 600

  /// The window opens on General; previews and the layout checks open another pane.
  init(tab: SettingsTab = .general) {
    _tab = State(initialValue: tab)
  }

  var body: some View {
    VStack(spacing: 0) {
      SettingsTabBar(selection: $tab)
      ScrollView {
        pane
          .padding(Tokens.Space.l)
          .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
      }
      .scrollEdgeHints(position: $scroll)
      .scrollBounceBehavior(.basedOnSize)
      .frame(height: min(max(contentHeight, 1), Self.maxPaneHeight))
      .onChange(of: tab) { _, _ in scroll.scrollTo(edge: .top) }
    }
    .frame(width: Self.width)
    .background(Palette.background)
    // The window still adds the title bar's height below a view drawn up into it; the view asks
    // for that much less, so the window ends where the pane does, with no empty band.
    .padding(.bottom, -titleInset)
    // No title bar of its own: the tab strip sits in it, level with the window buttons (the strip
    // is centred and narrow enough to clear them), and the chosen tab says which pane this is.
    // The window keeps the pane's name for the Window menu.
    .ignoresSafeArea(.container, edges: .top)
    .navigationTitle(Text(tab.title))
    .toolbar(removing: .title)
    .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
    // Read once: the title bar's height does not change, and following it while the window
    // resizes would feed the window's own resizing back into its size (a layout loop).
    .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.top } action: { inset in
      if titleInset == 0 { titleInset = inset }
    }
    .task(id: model.baseURL) { await model.followJobs() }
  }

  @ViewBuilder private var pane: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      // The pane's cards rise one after another each time a tab is shown, as the design's.
      Group(subviews: paneCards) { cards in
        ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
          card.rise(step: index)
        }
      }
    }
    // A new identity per tab: the next tab's cards rise afresh.
    .id(tab)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  @ViewBuilder private var paneCards: some View {
    switch tab {
    case .general: GeneralSettings()
    case .trading: TradingSettings()
    case .notifications: NotificationSettings()
    case .environment: EnvironmentSettings()
    case .storage: StorageSettings()
    case .advanced: AdvancedSettings()
    }
  }
}

// MARK: - General

private struct GeneralSettings: View {
  @Environment(AppModel.self) private var model
  @AppStorage(Defaults.apiBaseURL) private var apiBaseURL = APIClient.defaultBaseURL.absoluteString
  @AppStorage(Defaults.showMenuBarExtra) private var showMenuBarExtra = true
  @State private var draft = ""
  @State private var invalid = false
  @FocusState private var editing: Bool

  /// URL schemes the local API address may use.
  static let schemes: Set = ["http", "https"]
  /// How long after the pane appears the address field's automatic focus is released.
  static let focusRelease: Duration = .milliseconds(150)

  var body: some View {
    Group {
      connection
      HStack(alignment: .top, spacing: Tokens.Space.s) {
        SettingsCard(L10n.Settings.menuBar, footnote: Text(L10n.Settings.menuBarNote)) {
          SwitchRow(L10n.Settings.showInMenuBar, isOn: $showMenuBarExtra)
        }
        ThemeCard()
      }
      .fixedSize(horizontal: false, vertical: true)
      DemoDaySection()
      JobsSection()
    }
    .onAppear { draft = model.address.absoluteString }
    .alert(String(localized: L10n.Settings.invalidAddress), isPresented: $invalid) {
      Button(String(localized: L10n.Settings.ok), role: .cancel) {}
    } message: {
      Text(L10n.Settings.enterAddress(APIClient.defaultBaseURL.absoluteString))
    }
  }

  /// The design's "Bot connection": the address in a mono field with Use Default and Connect, the
  /// connection's state under it with a dot, and what the address may be.
  private var connection: some View {
    let reachable = model.fetchError == nil
    return SettingsCard(L10n.Settings.botConnection,
      footnote: Text(L10n.Settings.addressFootnote(APIClient.defaultBaseURL.absoluteString))) {
      HStack(spacing: Tokens.Space.s) {
        Text(L10n.Settings.apiAddress)
          .font(Tokens.Typography.calloutMono)
          .foregroundStyle(Palette.textTertiary)
          .fixedSize()
        TextField(String(localized: L10n.Settings.apiAddress), text: $draft)
          .labelsHidden()
          .textFieldStyle(.roundedBorder)
          .font(Tokens.Typography.calloutMono)
          .focused($editing)
          .onSubmit(apply)
        Button(String(localized: L10n.Settings.useDefault)) {
          draft = APIClient.defaultBaseURL.absoluteString
          apply()
        }
        .buttonStyle(.action(.secondary, size: .compact))
        // Connect with the same address reads the bot again at once, so it is never off.
        Button(String(localized: L10n.Settings.connect), action: apply)
          .buttonStyle(.action(.primary, size: .compact))
          .keyboardShortcut(.defaultAction)
      }
      HStack(spacing: Tokens.Space.s) {
        // One pulse when the bot becomes reachable or unreachable, never per read.
        PulseDot(reachable ? Palette.profit : Palette.loss, event: reachable)
        Group {
          if let error = model.fetchError {
            ReadFailureNote(L10n.Settings.notReachable, detail: error, tone: .loss, defersToConnection: false)
          } else {
            Text(L10n.Settings.connectedTo(model.baseURL.absoluteString))
          }
        }
        .font(Tokens.Typography.callout)
        .foregroundStyle(reachable ? Palette.profitText : Palette.lossText)
      }
    } trailing: {
      Text(L10n.Settings.thisMac)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
    }
    // Settings opens with nothing in focus, so the address is not selected under the cursor:
    // AppKit gives the field focus once the window is up, so it is taken back just after.
    .task {
      try? await Task.sleep(for: Self.focusRelease)
      editing = false
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

/// The design's "Appearance · theme": System, Light or Dark as the apps' `SegmentSwitch`. A
/// choice other than System holds every window of the app in that appearance (Defaults.appearance).
private struct ThemeCard: View {
  @AppStorage(Defaults.appearance) private var appearance = ""

  /// The choices, by their stored value; the empty value follows the system.
  static let choices = ["", Defaults.light, Defaults.dark]

  var body: some View {
    SettingsCard(L10n.Settings.appearanceTheme, footnote: Text(note)) {
      SegmentSwitch(options: Self.choices.map { ($0, Text(Self.title($0))) },
        selection: Binding(get: { appearance }, set: { choose($0) }))
        .accessibilityLabel(Text(L10n.Settings.appearanceTheme))
    }
  }

  private var note: LocalizedStringResource {
    switch appearance {
    case Defaults.light: L10n.Settings.alwaysLight
    case Defaults.dark: L10n.Settings.alwaysDark
    default: L10n.Settings.followsSystem
    }
  }

  private static func title(_ value: String) -> LocalizedStringResource {
    switch value {
    case Defaults.light: L10n.Settings.themeLight
    case Defaults.dark: L10n.Settings.themeDark
    default: L10n.Settings.themeSystem
    }
  }

  private func choose(_ value: String) {
    appearance = value
    ThemeFade.apply(TickrMacApp.appearance(value))
  }
}

/// The "Demo day" switch as a card: the name with a one-line explanation, the demo chip while it
/// is on, and the switch in the Sandbox badge's colour. On, the app shows the demo day behind
/// the bot's address (AppModel.setDemoDay) and remembers the choice; the address above is
/// untouched.
private struct DemoDaySection: View {
  @Environment(AppModel.self) private var model
  @AppStorage(Defaults.demoDay) private var demoDay = false

  /// Accessibility id of the switch, for the UI tests.
  static let id = "settings-demo-day"

  var body: some View {
    SettingsCard(L10n.Settings.demoDay, footnote: Text(L10n.Settings.demoDayExplanation)) {
      HStack(spacing: Tokens.Space.m) {
        Toggle(isOn: Binding(get: { model.demoDay }, set: { on in
          demoDay = on
          model.setDemoDay(on)
        })) {
          Text(L10n.Settings.demoDay)
        }
        .labelsHidden()
        .toggleStyle(.designSwitch(tint: Palette.warning))
        .accessibilityIdentifier(Self.id)
        Text(L10n.Settings.demoDay)
          .font(Tokens.Typography.callout)
          .foregroundStyle(Palette.textSecondary)
          .accessibilityHidden(true)
        Spacer(minLength: Tokens.Space.s)
      }
    } trailing: {
      // On: the demo day's own environment badge (dashed violet), the one look of the demo.
      if model.demoDay {
        let demo = EnvironmentBadge.Kind.demo.rawValue
        EnvironmentBadge(ApiText.environment(demo), raw: demo, accessibilityLabel: ApiText.environmentLabel(demo))
      }
    }
    .animation(Tokens.Motion.quick, value: model.demoDay)
  }
}

// MARK: - Trading

private struct TradingSettings: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    if let settings = model.settings {
      // One column: three cards across are too cramped at the window's width.
      VStack(alignment: .leading, spacing: Tokens.Space.s) {
        SettingsCard(L10n.Common.strategy) {
          SettingsRow(L10n.Settings.activeStrategy) {
            Text(verbatim: settings.activeStrategy).foregroundStyle(Palette.accentText)
          }
          SettingsRow(L10n.Settings.observers, value: "\(settings.observers.count)")
          ForEach(settings.observers, id: \.self) { observer in
            HStack(spacing: Tokens.Space.s) {
              PulseDot(Palette.highlight, size: Tokens.Size.dotSmall, pulsing: false)
              Text(verbatim: observer)
                .font(Tokens.Typography.annotation)
                .foregroundStyle(Palette.textTertiary)
            }
          }
        }
        SettingsCard(L10n.Common.risk) {
          SettingsRow(L10n.Settings.plannedLoss, value: Money.usd(settings.risk.plannedLossUsd.value))
          SettingsRow(L10n.Settings.notionalCap, value: Money.usd(settings.risk.positionNotionalCapUsd.value))
          SettingsRow(L10n.Settings.dailyLossLimit, value: Money.usd(settings.risk.maxDailyLossUsd.value))
          SettingsRow(L10n.Settings.maxOpenPositions, value: "\(settings.risk.maxOpenPositions)")
          SettingsRow(L10n.Settings.maxQuoteAge, value: Format.seconds(settings.risk.maxQuoteAgeSeconds.value))
        }
        SettingsCard(L10n.Settings.session) {
          SettingsRow(L10n.Settings.marketTimezone, value: settings.session.timezone)
          SettingsRow(L10n.Settings.lastEntry, value: Self.beforeClose(settings.session.lastEntryMinutesBeforeClose))
          SettingsRow(L10n.Settings.flatten, value: Self.beforeClose(settings.session.flattenMinutesBeforeClose))
          SettingsRow(L10n.Settings.halfDays) {
            Text(settings.session.halfDaysEnabled ? L10n.Settings.traded : L10n.Settings.notTraded)
          }
        }
      }
      .fixedSize(horizontal: false, vertical: true)
      Text(L10n.Settings.configFootnote)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
        .padding(.horizontal, Tokens.Space.m)  // level with the text inside the cards
      FeaturesCard(settings: settings)
    } else {
      SettingsCard(L10n.Common.strategy) {
        Group {
          if let error = model.settingsError {
            ReadFailureNote(L10n.ReadFailed.settings, detail: error)
          } else {
            Text(L10n.Settings.readingSettings)
          }
        }
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textTertiary)
      }
    }
  }

  private static func beforeClose(_ minutes: Int) -> String { String(localized: L10n.Settings.beforeClose(minutes)) }
}

/// The design's "Features · from config": what the configuration turns on, each a status dot,
/// never a switch (the app edits none of it). Half days and live observers are real values; the
/// rest are planned and marked so.
private struct FeaturesCard: View {
  let settings: SettingsV1

  var body: some View {
    SettingsCard(L10n.Settings.features, footnote: Text(L10n.Settings.featuresFootnote)) {
      row(L10n.Settings.featureTrailing, on: false) { Badge.backlog }
      row(L10n.Settings.featureExtendedHours, on: false) { Badge.backlog }
      row(L10n.Settings.featureShort, on: false) { Badge.backlog }
      row(L10n.Settings.featureChase, on: false) { Badge.backlog }
      row(L10n.Settings.featureHalfDays, on: settings.session.halfDaysEnabled) {
        Text(settings.session.halfDaysEnabled ? L10n.Settings.traded : L10n.Settings.notTraded)
      }
      row(L10n.Settings.liveObservers, on: !settings.observers.isEmpty) {
        Text(verbatim: settings.observers.isEmpty ? String(localized: L10n.Common.none) : "\(settings.observers.count)")
      }
    }
  }

  private func row(_ title: LocalizedStringResource, on: Bool, @ViewBuilder tag: () -> some View) -> some View {
    HStack(spacing: Tokens.Space.m) {
      Circle()
        .fill(on ? Palette.accent : Palette.separatorStrong)
        .frame(width: Tokens.Size.dot, height: Tokens.Size.dot)
        .help(Text(on ? L10n.Common.on : L10n.Common.off))
        .accessibilityLabel(Text(on ? L10n.Common.on : L10n.Common.off))
      Text(title)
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textSecondary)
      Spacer(minLength: Tokens.Space.s)
      tag()
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
    }
    .accessibilityElement(children: .combine)
  }
}

// MARK: - Notifications

/// The alerts the bot sends (runtime/alerts.py `AlertKind`, grouped), one row per group with a dot
/// of its weight and the kinds it covers under it; every one is on and goes out as a Mac
/// notification and, with a recipient in the bot's env file, as an iMessage. Nothing here is a
/// switch, because the bot decides; phone push waits for the iOS app.
private struct NotificationSettings: View {
  /// One group: how loud it is, its title and the kinds it covers.
  struct AlertGroup: Identifiable {
    let tone: Tone
    let title: LocalizedStringResource
    let kinds: LocalizedStringResource
    var id: String { title.key }
  }

  /// The groups, loudest first, as the design lists them.
  static var groups: [AlertGroup] {
    [
      AlertGroup(tone: .loss, title: L10n.Settings.alertUnprotected, kinds: L10n.Settings.alertUnprotectedKinds),
      AlertGroup(tone: .loss, title: L10n.Settings.alertExit, kinds: L10n.Settings.alertExitKinds),
      AlertGroup(tone: .loss, title: L10n.Settings.alertBot, kinds: L10n.Settings.alertBotKinds),
      AlertGroup(tone: .loss, title: L10n.Settings.alertWatchdog, kinds: L10n.Settings.alertWatchdogKinds),
      AlertGroup(tone: .warning, title: L10n.Settings.alertBroker, kinds: L10n.Settings.alertBrokerKinds),
      AlertGroup(tone: .warning, title: L10n.Settings.alertLossLimit, kinds: L10n.Settings.alertLossLimitKinds),
      AlertGroup(tone: .warning, title: L10n.Settings.alertMorning, kinds: L10n.Settings.alertMorningKinds),
      AlertGroup(tone: .warning, title: L10n.Settings.alertToken, kinds: L10n.Settings.alertTokenKinds),
      AlertGroup(tone: .info, title: L10n.Settings.alertObservers, kinds: L10n.Settings.alertObserversKinds),
    ]
  }

  var body: some View {
    SettingsCard(L10n.Settings.alerts) {
      ForEach(Self.groups) { group in
        HStack(spacing: Tokens.Space.s) {
          PulseDot(group.tone.fill, size: Tokens.Size.dotSmall, pulsing: false)
          VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
            Text(group.title)
              .font(Tokens.Typography.callout)
              .foregroundStyle(Palette.textSecondary)
            Text(group.kinds)
              .font(Tokens.Typography.captionMono)
              .foregroundStyle(Palette.textQuaternary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer(minLength: Tokens.Space.s)
          MacDot()
          PhoneDot()
        }
        .accessibilityElement(children: .combine)
      }
      HStack(spacing: Tokens.Space.xs) {
        MacDot()
        Text(L10n.Settings.legendOn)
        PhoneDot()
        Text(L10n.Settings.legendPhone)
      }
      .font(Tokens.Typography.annotation)
      .foregroundStyle(Palette.textQuaternary)
      .padding(.top, Tokens.Space.xxs)
      Text(L10n.Settings.alertsNote)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
        .fixedSize(horizontal: false, vertical: true)
    } trailing: {
      Text(L10n.Settings.alertColumns)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
    }
  }
}

/// A Mac column dot: on.
private struct MacDot: View {
  var body: some View {
    Circle().fill(Palette.profit)
      .frame(width: Tokens.Size.dotSmall, height: Tokens.Size.dotSmall)
      .frame(width: Tokens.Size.rowSymbol)
      .accessibilityHidden(true)
  }
}

/// A phone column dot: an empty ring, phone push is planned.
private struct PhoneDot: View {
  var body: some View {
    Circle().strokeBorder(Palette.highlight, lineWidth: Tokens.Stroke.thin)
      .frame(width: Tokens.Size.dotSmall, height: Tokens.Size.dotSmall)
      .frame(width: Tokens.Size.rowSymbol)
      .accessibilityHidden(true)
  }
}

// MARK: - Environment

/// The environment and the trading gate: the environment the bot runs in as the one
/// `EnvironmentBadge` of both apps beside the gate's open or closed badge (as in the Overview
/// header); then the gate, its cause, the environment's name and the API version.
private struct EnvironmentSettings: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    let raw = model.status?.environment ?? model.settings?.environment
    SettingsCard(L10n.Settings.environmentGate, footnote: Text(L10n.Settings.environmentFixed)) {
      // The environment in use as a status, not a picker: config/bot.toml sets it, the app never does.
      HStack(spacing: Tokens.Space.s) {
        if let raw {
          EnvironmentBadge(ApiText.environment(raw), raw: raw, accessibilityLabel: ApiText.environmentLabel(raw))
        } else {
          Text(verbatim: Format.missing).foregroundStyle(Palette.textQuaternary)
        }
        // The gate at a glance beside it, the same badge as the headline's; its cause on hover.
        if let gate = model.status?.tradingGate {
          let shown: EntryGate = gate.open ? .open : .closed
          Badge(shown.title, symbol: shown.symbol, tone: shown.tone)
            .help(Text(verbatim: ApiText.gate(gate)))
        }
        Spacer(minLength: 0)
      }
      if let gate = model.status?.tradingGate {
        SettingsRow(L10n.Settings.tradingGate) {
          Text(gate.open ? L10n.Settings.gateOpen : L10n.Settings.gateClosed)
            .foregroundStyle(gate.open ? Palette.profitText : Palette.lossText)
        }
        SettingsRow(L10n.Settings.gateCause, value: ApiText.gate(gate))
      }
      SettingsRow(L10n.Settings.brokerEnvironment,
        value: raw.map { ApiText.environment($0).localizedLowercase } ?? Format.missing)
      SettingsRow(L10n.Settings.apiVersion, value: model.settings.map { "\($0.apiVersion)" } ?? Format.missing)
    }
  }
}

// MARK: - Storage

private struct StorageSettings: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    SettingsCard(L10n.Settings.history, footnote: historyNote,
      footnoteColor: model.historyError == nil ? Palette.textQuaternary : Palette.lossText) {
      HStack(spacing: Tokens.Space.s) {
        StatTile(value: "\(model.days.count)", label: L10n.Settings.recordedDays)
        StatTile(value: model.days.last.map { DayText.day($0.day) } ?? Format.missing,
          label: L10n.Settings.firstRecordedDay)
        StatTile(value: "\(model.days.filter(\.hasBars).count)", label: L10n.Settings.daysWithBars)
      }
    }
    BackupSection()
  }

  private var historyNote: Text {
    // Plain words: the read's technical cause is the connection banner's (Details) or the
    // Trades screen's.
    model.historyError.map { _ in Text(L10n.ReadFailed.history) } ?? Text(L10n.Settings.historySource)
  }
}

// MARK: - Advanced

private struct AdvancedSettings: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    SettingsCard(L10n.Settings.botStatusInApp, footnote: Text(L10n.Settings.configFootnote)) {
      HStack(spacing: Tokens.Space.s) {
        StatTile(dot: Palette.accent, label: L10n.Settings.statusRefresh,
          value: model.settings.map { String(localized: L10n.Settings.every(Format.seconds($0.pollSeconds.value))) }
            ?? Format.missing)
        StatTile(dot: Palette.warning, label: L10n.Settings.staleAfter,
          value: model.settings.map { Format.seconds($0.statusStaleSeconds.value) } ?? Format.missing)
      }
    }
    BotServiceCard()
    ConfigCard()
      .task(id: model.baseURL) { await model.refreshConfig() }
  }
}

/// What the Bot service card asks before it acts.
private enum ServiceQuestion: Equatable {
  case start, stop
}

/// The design's "Bot service · launchd job" card: the bot's state with a power glyph, Start (the
/// API kickstarts the launchd job, preflight first) and Stop (the stop-bot command, refused by the
/// bot while a trade is open). Both ask first, inside the card, as the design draws the question.
private struct BotServiceCard: View {
  @Environment(AppModel.self) private var model
  @State private var question: ServiceQuestion?

  /// Symbol of the service glyph (the design's power sign).
  static let serviceSymbol = "power"
  /// Symbol of the Start button.
  static let startSymbol = "play.fill"

  var body: some View {
    SettingsCard(L10n.Settings.botService, footnote: Text(L10n.Settings.startStopFootnote)) {
      HStack(spacing: Tokens.Space.m) {
        StateGlyph(Self.serviceSymbol, tone: tone, label: L10n.Settings.botService, live: running,
          event: model.status?.botState)
        VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
          title.font(Tokens.Typography.body.weight(.semibold)).foregroundStyle(Palette.textPrimary)
          Text(note).font(Tokens.Typography.callout).foregroundStyle(Palette.textTertiary)
        }
        Spacer(minLength: Tokens.Space.s)
        Button { question = .start } label: {
          Label { Text(L10n.Settings.startBotAction) } icon: { Image(systemName: Self.startSymbol) }
        }
        // Start is the card's main action; Stop is a destructive bot command, as on Overview.
        .buttonStyle(.action(.primary, size: .compact))
        .disabled(!model.canStartBot)
        .inFlight(model.botStarting ? Text(InFlightText.startBot) : nil)
        .hint(L10n.Settings.startBotHint)
        Button(role: .destructive) { question = .stop } label: {
          Label { Text(L10n.Settings.stopBotAction) } icon: { Image(systemName: BotAction.stopSymbol) }
        }
        .buttonStyle(.command(.destructive, tag: model.demoDay ? Text(L10n.Bot.demoTag) : nil))
        .fixedSize()
        .disabled(!model.canStopBot)
        .inFlight(model.inFlight == .stopBot ? Text(OperatorCommand.stopBot.inFlightTitle) : nil)
        .hint(verbatim: BotAction.stopBot.explanation)
      }
      if let question {
        confirmation(question)
      }
      if let outcome = model.botStart {
        switch outcome {
        case .accepted(let cleared):
          Text(cleared ? L10n.Settings.startAcceptedCleared : L10n.Settings.startAccepted)
            .font(Tokens.Typography.callout).foregroundStyle(Palette.profitText)
        case .refused(let cause):
          Text(L10n.Settings.startRefused(cause))
            .font(Tokens.Typography.callout).foregroundStyle(Palette.lossText)
        }
      }
    }
    .animation(Tokens.Motion.quick, value: question)
    // A question asked in one state is withdrawn when the state no longer allows the action.
    .onChange(of: model.canStartBot) { _, enabled in
      if !enabled && question == .start { question = nil }
    }
    .onChange(of: model.canStopBot) { _, enabled in
      if !enabled && question == .stop { question = nil }
    }
  }

  /// The design's question inside the card: what happens, then Cancel and the action.
  private func confirmation(_ asked: ServiceQuestion) -> some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      Text(asked == .start ? L10n.Settings.startQuestion : L10n.Bot.stopQuestion)
        .font(Tokens.Typography.body.weight(.semibold))
        .foregroundStyle(Palette.textPrimary)
      Group {
        if asked == .start {
          Text(L10n.Settings.startExplanation)
        } else {
          Text(verbatim: BotAction.stopBot.explanation)
        }
      }
      .font(Tokens.Typography.callout)
      .foregroundStyle(Palette.textTertiary)
      .fixedSize(horizontal: false, vertical: true)
      HStack(spacing: Tokens.Space.s) {
        Spacer()
        Button { question = nil } label: { Text(L10n.Common.cancel) }
          .buttonStyle(.action(.secondary, size: .compact))
          .keyboardShortcut(.cancelAction)
        if asked == .start {
          Button {
            question = nil
            Task { await model.startBot() }
          } label: { Text(L10n.Settings.startQuestion) }
            .buttonStyle(.action(.primary, size: .compact))
            .disabled(!model.canStartBot)
        } else {
          Button(role: .destructive) {
            question = nil
            Task { await model.send(BotAction.stopBot.command, title: BotAction.stopBot.title) }
          } label: { Text(verbatim: BotAction.stopBot.title) }
            .buttonStyle(.action(.destructive, size: .compact))
            .disabled(!model.canStopBot)
        }
      }
    }
    .padding(Tokens.Space.m)
    .background(Palette.surfaceSunken, in: RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous)
      .strokeBorder(Palette.separatorStrong, lineWidth: Tokens.Stroke.thin))
    .transition(.opacity)
  }

  private var stale: Bool { model.response?.stale == true }
  private var running: Bool { model.status?.botState == .running && !stale }

  private var tone: Tone {
    if stale { return .warning }
    switch model.status?.botState {
    case .running: return .accent
    case .starting: return .info
    case .stopping: return .warning
    case .stopped, nil: return .neutral
    }
  }

  /// A stale status proves nothing about the bot now, so the card says so instead of the last state.
  private var title: Text {
    guard !stale, let state = model.status?.botState else { return Text(L10n.Settings.serviceNotReported) }
    return Text(verbatim: state.title)
  }

  private var note: LocalizedStringResource {
    guard !stale, let status = model.status else { return L10n.Settings.serviceStale }
    switch status.botState {
    case .running:
      return status.positions.isEmpty ? L10n.Settings.serviceFlat : L10n.Settings.serviceHolds(status.positions.count)
    case .starting: return L10n.Settings.serviceStarting
    case .stopping: return L10n.Settings.serviceStopping
    case .stopped: return L10n.Settings.serviceStopped
    }
  }
}

/// The bot's configuration file, read-only (GET /config), as the design's card: the file and
/// whether it loads and matches what runs in its header, then one folded group per table with
/// each key's comment over its line. Editing comes later, behind a backup and a restart.
private struct ConfigCard: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    SettingsCard(model.config.map { L10n.Settings.configFile($0.file) } ?? L10n.Settings.configuration,
      footnote: Text(L10n.Settings.configFooter)) {
      if let config = model.config {
        if let error = config.error {
          Text(verbatim: error).font(Tokens.Typography.callout).foregroundStyle(Palette.lossText)
            .fixedSize(horizontal: false, vertical: true)
        }
        ForEach(config.sections, id: \.name) { section in
          DisclosureGroup {
            VStack(alignment: .leading, spacing: Tokens.Space.s) {
              ForEach(section.keys, id: \.key) { key in line(key) }
            }
            .padding(.top, Tokens.Space.xs)
          } label: {
            Text(verbatim: section.name.isEmpty ? String(localized: L10n.Settings.configTop) : "[\(section.name)]")
              .font(Tokens.Typography.calloutMono)
              .foregroundStyle(Palette.highlightText)
          }
        }
      } else if let error = model.configError {
        ReadFailureNote(L10n.ReadFailed.config, detail: error)
      } else {
        Skeleton(L10n.Common.loading) { SkeletonLines(Tokens.Loading.manyLines) }
      }
    } trailing: {
      HStack(spacing: Tokens.Space.xs) {
        if let config = model.config {
          // Valid or not: a state with its word, as on both apps' Settings boards ("✓ VALID").
          StatusPill(config.valid ? L10n.Settings.configValid : L10n.Settings.configInvalid,
            systemImage: config.valid ? Symbols.passed : Symbols.failed, tone: config.valid ? .profit : .loss)
          if config.changedSinceStart {
            Badge(L10n.Settings.configChanged, tone: .warning).hint(L10n.Settings.configChangedHint)
          } else {
            Badge(L10n.Settings.configSame, tone: .neutral)
          }
        }
      }
    }
  }

  /// One key as the design writes it: its comment, then `key = value` in the design's colours.
  private func line(_ key: ConfigKeyV1) -> some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
      if !key.comment.isEmpty {
        Text(verbatim: Self.commentMark + key.comment)
          .foregroundStyle(Palette.textQuaternary)
          .fixedSize(horizontal: false, vertical: true)
      }
      (Text(verbatim: key.key).foregroundStyle(Palette.infoText)
        + Text(verbatim: Self.assign).foregroundStyle(Palette.textTertiary)
        + Text(verbatim: key.value).foregroundStyle(Palette.warningText))
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
    }
    .font(Tokens.Typography.annotation)
  }

  /// TOML's comment mark and assignment, as the file writes them.
  static let commentMark = "# "
  static let assign = " = "
}

// MARK: - Jobs and session

/// A job's state as its dot shows it; a change is one pulse of the dot.
struct JobDot: Hashable {
  let tone: Tone
  let live: Bool
}

/// The design's "Session" card with the jobs under it (GET /jobs): today's session as a strip,
/// then what runs on its own on the Mac, one row each: a dot in its colour (pulsing while it
/// runs), its name, when it runs, its state and its last or next time. Read while Settings is open.
struct JobsSection: View {
  @Environment(AppModel.self) private var model
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Widths of the name and "when" columns, in points (the design's 86 and 130, the name widened
  /// for the longer translated names).
  static let nameWidth: CGFloat = 180
  static let whenWidth: CGFloat = 112
  /// Days in a week; launchd numbers them 0 (or 7) Sunday, 1 Monday … 6 Saturday.
  static let week = 7
  /// Shortest run of days written as a range ("Mon–Fri") rather than a list.
  static let shortestRange = 3
  /// Joins the first and last day of a range.
  static let rangeDash = "–"

  var body: some View {
    SettingsCard(sessionTitle) {
      if let session = model.jobs?.session {
        // The now line follows the bot's clock; it moves once a minute (`SessionStrip.minute`).
        TimelineView(.periodic(from: .now, by: Tokens.Motion.clockTickSeconds)) { context in
          SessionStrip(span: SessionSpan(session), now: model.botTime(context.date),
            moving: Self.stripesMove(reduceMotion: reduceMotion, model: model))
        }
      } else if let cause = model.jobs?.sessionCauseText {
        Text(verbatim: cause).font(Tokens.Typography.callout).foregroundStyle(Palette.textTertiary)
      }
      Rectangle().fill(Palette.separator).frame(height: Tokens.Stroke.thin)
        .padding(.vertical, Tokens.Space.xs)
      HStack {
        CardLabel(L10n.Settings.jobs)
        Spacer(minLength: Tokens.Space.s)
        Text(L10n.Settings.jobsFooter)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      }
      if let jobs = model.jobs {
        ForEach(jobs.launchd, id: \.name) { job in launchd(job, jobs: jobs) }
        reconcile(jobs.reconcile)
        backup(jobs.backup)
        api
      } else if let error = model.jobsError {
        ReadFailureNote(L10n.ReadFailed.jobs, detail: error)
      } else {
        Skeleton(L10n.Common.loading) { SkeletonRows(Tokens.Loading.rows, badge: true) }
      }
    } trailing: {
      Text(L10n.Settings.timesET)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
    }
  }

  /// Whether the session strip's planned stripes drift: an ornament that reads as "the bot is at
  /// work", so only while it is (`OrnamentGate`: running, live and fresh status, motion allowed).
  static func stripesMove(reduceMotion: Bool, model: AppModel) -> Bool {
    model.ornamentsMove(reduceMotion: reduceMotion)
  }

  private var sessionTitle: LocalizedStringResource {
    guard let day = model.jobs?.session?.day else { return L10n.Settings.session }
    return L10n.Settings.sessionTitle(DayText.day(day))
  }

  /// One job: dot (its tone, and whether it pulses), name, when, state, times.
  private func row(
    _ dot: (tone: Tone, live: Bool), name: Text, when: Text, state: Text,
    @ViewBuilder meta: () -> some View
  ) -> some View {
    let (tone, live) = dot
    return HStack(spacing: Tokens.Space.s) {
      // One pulse when the job's state changes (its tone or whether it runs), never per read.
      PulseDot(tone.fill, event: JobDot(tone: tone, live: live))
      name
        .font(Tokens.Typography.calloutMono)
        .foregroundStyle(Palette.textPrimary)
        .frame(width: Self.nameWidth, alignment: .leading)
      when
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textSecondary)
        .frame(width: Self.whenWidth, alignment: .leading)
      state
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textTertiary)
      Spacer(minLength: Tokens.Space.s)
      meta()
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
    }
    .accessibilityElement(children: .combine)
  }

  /// A launchd job; the bot's own job carries the bot's state, as its status reports it. A stale
  /// status proves nothing about the bot now, so it says so instead of repeating the last state.
  @ViewBuilder private func launchd(_ job: LaunchdJobV1, jobs: JobsV1) -> some View {
    let when = Text(verbatim: job.localTime + Format.itemSeparator + Self.days(job.weekdays))
    let name = Text(verbatim: Self.title(job.name))
    if LaunchdJob(rawValue: job.name) == .bot {
      let running = jobs.botState == .running && !jobs.statusStale
      let tone: Tone = jobs.statusStale ? .warning : running ? .accent : .neutral
      let state = jobs.statusStale ? String(localized: L10n.Settings.notReported)
        : jobs.botState?.title.localizedLowercase ?? String(localized: L10n.Settings.notRunning)
      row((tone, running), name: name, when: when, state: Text(verbatim: state)) {
        if running, let started = jobs.botStartedAt {
          Text(L10n.Settings.since(Self.started(started.date, now: model.botNow)))
        }
      }
    } else {
      row((.info, false), name: name, when: when, state: Text(verbatim: "")) { EmptyView() }
    }
  }

  /// When the bot started: the time alone on today's New York date, else with its day too
  /// ("Tue Nov 17 21:29"), so a start of last evening never reads as one of today.
  static func started(_ date: Date, now: Date) -> String {
    WireDate(newYorkDateOf: date) == WireDate(newYorkDateOf: now) ? Format.marketMinute(date) : BackupSection.when(date)
  }

  /// A launchd job's name in the person's language; a job this app does not know reads as
  /// "Other job", never as its launchd name.
  static func title(_ name: String) -> String {
    guard let job = LaunchdJob(rawValue: name) else { return String(localized: L10n.Settings.jobOther) }
    switch job {
    case .preflight: return String(localized: L10n.Settings.jobPreflight)
    case .bot: return String(localized: L10n.Settings.jobBot)
    case .watchdog: return String(localized: L10n.Settings.jobWatchdog)
    case .nightlyFetch: return String(localized: L10n.Settings.jobNightlyFetch)
    }
  }

  /// The launchd jobs the bot installs on the Mac, by their wire names in jobs-v1.
  enum LaunchdJob: String {
    case preflight, bot, watchdog
    case nightlyFetch = "nightly-fetch"
  }

  /// The next reconcile counting down while the bot runs, else when it last ran (New York time).
  private func reconcile(_ job: ReconcileJobV1) -> some View {
    let running = job.nextAt.map { $0.date > model.botNow } ?? false
    return row((.info, running), name: Text(L10n.Settings.reconcile),
      when: Text(L10n.Settings.every(Format.seconds(job.intervalSeconds.value))),
      state: Text(L10n.Settings.whileBotRuns)) {
      if let next = job.nextAt?.date, next > model.botNow {
        HStack(spacing: Tokens.Space.xs) {
          Text(L10n.Settings.nextIn)
          Text(timerInterval: Date.now...Date.now.addingTimeInterval(next.timeIntervalSince(model.botNow)))
            .monospacedDigit()
        }
      } else if let last = job.lastAt {
        Text(L10n.Settings.lastShort(Format.marketMinute(last.date)))
      } else {
        Text(verbatim: Format.missing)
      }
    }
  }

  /// The daily backup: verified with its time, or failed when the failure is newer.
  private func backup(_ job: BackupJobV1) -> some View {
    let failure = job.lastFailedAt.flatMap { failed in job.lastAt.map { failed.date > $0.date } ?? true ? failed : nil }
    let tone: Tone = failure != nil ? .loss : job.lastAt == nil ? .neutral : .profit
    let state: Text = failure.map { Text(L10n.Settings.backupFailed(Format.marketMinute($0.date))) }
      ?? (job.lastAt == nil ? Text(verbatim: Format.missing) : Text(L10n.Settings.verified))
    return row((tone, false), name: Text(L10n.Settings.backup), when: Text(L10n.Settings.daily), state: state) {
      if let at = job.lastAt {
        Text(L10n.Settings.lastShort(BackupSection.when(at.date)))
      }
    }
  }

  /// The bot's local API this app reads: always on, at the address in Bot connection.
  private var api: some View {
    let reachable = model.fetchError == nil
    let host = model.baseURL.host() ?? model.baseURL.absoluteString
    let address = model.baseURL.port.map { "\(host):\($0)" } ?? host
    return row((reachable ? .info : .loss, reachable), name: Text(L10n.Settings.jobApi),
      when: Text(L10n.Settings.alwaysOn),
      state: Text(reachable ? L10n.Settings.connected : L10n.Settings.unreachable)) {
      Text(verbatim: address)
    }
  }

  /// "Mon–Fri" for a run of days, else "Mon, Wed"; in the person's language.
  static func days(_ weekdays: [Int]) -> String {
    let symbols = Calendar.current.shortWeekdaySymbols
    // Monday first, Sunday last, as a working week reads.
    let order = Array(Set(weekdays.map { $0 % week })).sorted { ($0 + week - 1) % week < ($1 + week - 1) % week }
    guard order.allSatisfy({ symbols.indices.contains($0) }), let first = order.first, let last = order.last else {
      return weekdays.map(String.init).joined(separator: Format.listSeparator)
    }
    let contiguous = zip(order, order.dropFirst()).allSatisfy { ($0.0 + 1) % week == $0.1 }
    if contiguous && order.count >= shortestRange {
      return symbols[first] + rangeDash + symbols[last]
    }
    return order.map { symbols[$0] }.joined(separator: Format.listSeparator)
  }
}

/// Today's session as the design's strip: pre-market and post-market striped, dashed and marked
/// planned (the bot trades the regular session only), the regular session in the accent with the
/// minutes after the flatten time in amber, the open, last entry, flatten and close times above
/// and below, and a line at now with a dot on top.
///
/// Its motion, as the design's: the now line glides to each new minute (`Motion.nowGlide`), and
/// its dot sends out one ring each time now passes a mark of the session (open, last entry,
/// flatten, close): one move per real change of the time, still in between. The planned stripes
/// drift while `moving` (ornament). Under Reduce Motion everything stands at its final place.
struct SessionStrip: View {
  /// Today's span from the bot's `/jobs` session (`SessionSpan`).
  let span: SessionSpan
  let now: Date
  /// Whether the planned stripes drift: `OrnamentGate`, as `JobsSection.stripesMove` decides.
  let moving: Bool

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Height of the bar, and of the whole strip with a row of labels above and below, in points.
  static let barHeight: CGFloat = 22
  static let height: CGFloat = 62
  /// Side of the dot on the now line, and how far the line starts above the bar, in points (the
  /// design's 10 px and 10 px).
  static let nowDot: CGFloat = 10
  static let lineAbove: CGFloat = 10

  /// The pre-market label: with the calendar's pre-market open, as the design's "PRE 04:00 ·
  /// BACKLOG"; without the time for an older bot's session.
  static func preLabel(_ span: SessionSpan) -> LocalizedStringResource {
    guard span.extendedHoursKnown else { return L10n.Settings.preBacklog }
    return L10n.Settings.preBacklogFrom(Format.marketMinute(span.start))
  }

  var body: some View {
    let open = span.regularOpen
    let close = span.regularClose
    let flatten = span.flatten
    let barTop = (Self.height - Self.barHeight) / 2
    let below = Self.height - Tokens.Typography.annotationSize - Tokens.Space.xs
    let minute = SessionSpan.minute(now)
    GeometryReader { proxy in
      let width = proxy.size.width
      let x = { (date: Date) -> CGFloat in CGFloat(span.share(date)) * width }
      ZStack(alignment: .topLeading) {
        planned.frame(width: x(open), height: Self.barHeight).offset(y: barTop)
        Rectangle().fill(Palette.accent.opacity(Tokens.Opacity.glow))
          .overlay(Rectangle().strokeBorder(Palette.accent, lineWidth: Tokens.Stroke.thin))
          .frame(width: x(close) - x(open), height: Self.barHeight).offset(x: x(open), y: barTop)
        Rectangle().fill(Palette.warning.opacity(Tokens.Opacity.faint))
          .frame(width: x(close) - x(flatten), height: Self.barHeight).offset(x: x(flatten), y: barTop)
        planned.frame(width: width - x(close), height: Self.barHeight).offset(x: x(close), y: barTop)
        if span.contains(minute) {
          Rectangle().fill(Palette.textPrimary)
            .frame(width: Tokens.Stroke.bold, height: Self.height - barTop + Self.lineAbove)
            .offset(x: x(minute), y: barTop - Self.lineAbove)
            .animation(reduceMotion ? nil : Tokens.Motion.nowGlide, value: minute)
        }
        mark(L10n.Settings.markOpen(Format.marketMinute(open)), color: Palette.accentText, x: x(open))
        mark(L10n.Settings.markLastEntry(Format.marketMinute(span.lastEntry)), color: Palette.warningText,
          x: x(span.lastEntry), trailing: true)
        mark(L10n.Settings.markClose(Format.marketMinute(close)), color: Palette.accentText,
          x: x(close) + Tokens.Space.xs)
        mark(Self.preLabel(span), color: Palette.highlightText, x: Tokens.Space.s, y: below)
        mark(L10n.Settings.markFlatten(Format.marketMinute(flatten)), color: Palette.warningText,
          x: x(flatten), y: below, trailing: true)
        mark(L10n.Settings.postBacklog, color: Palette.highlightText, x: width - Tokens.Space.s, y: below,
          trailing: true)
        // The dot over the labels, as the design's: the line passes behind them.
        if span.contains(minute) {
          nowDot
            .offset(x: x(minute) + (Tokens.Stroke.bold - Self.nowDot) / 2,
              y: barTop - Self.lineAbove - Self.nowDot / 2)
            .animation(reduceMotion ? nil : Tokens.Motion.nowGlide, value: minute)
        }
      }
    }
    .frame(height: Self.height)
    .accessibilityElement(children: .combine)
  }

  /// The now line's dot, centred on the line's top end; its ring plays once per change of
  /// `phase`.
  private var nowDot: some View {
    Circle().fill(Palette.textPrimary)
      .frame(width: Self.nowDot, height: Self.nowDot)
      .eventPulse(Circle(), color: Palette.textPrimary, scale: Tokens.Motion.blipScale,
        event: span.marksPassed(at: now))
  }

  /// A label at `x` (its leading edge, or its trailing edge when `trailing`), `y` from the top.
  private func mark(
    _ text: LocalizedStringResource, color: Color, x: CGFloat, y: CGFloat = 0, trailing: Bool = false
  ) -> some View {
    // A trailing label ends at `x`: it sits at the end of a frame that reaches from the strip's
    // leading edge to `x` (an alignment guide would move the whole strip instead).
    Text(text)
      .font(Tokens.Typography.annotation)
      .foregroundStyle(color)
      .fixedSize()
      // On the card's colour, so the now line passes behind a label rather than through it.
      .background(Palette.surface)
      .frame(width: trailing ? max(x - Tokens.Space.xs, 0) : nil, alignment: .trailing)
      .offset(x: trailing ? 0 : x, y: y)
  }

  /// A planned stretch: the highlight's stripes inside its dashed outline, as the design's.
  private var planned: some View {
    Hatch(Palette.highlight, moving: moving)
      .overlay(Rectangle().strokeBorder(Palette.highlight,
        style: StrokeStyle(lineWidth: Tokens.Stroke.thin, dash: Tokens.Stroke.dashFine)))
  }
}

/// The bot's database backup (GET /jobs) as the design's "Backups · storage": a green check with
/// what the backup is and when the last one was made, or the failure when it is newer, with its
/// error; why neither is known when the bot cannot tell; and how clean-up runs.
struct BackupSection: View {
  @Environment(AppModel.self) private var model

  /// Symbols of the unknown state and of the clean-up note (verified and failed draw
  /// `Symbols.passed` and `Symbols.failed`).
  static let unknownSymbol = "circle.dashed"
  static let cleanupSymbol = "trash"
  /// Separates the day from the time.
  static let dayTimeSeparator = " "

  var body: some View {
    SettingsCard(L10n.Settings.backups, footnote: Text(L10n.Settings.backupFooter)) {
      if let job = model.jobs?.backup {
        let failed = job.lastFailedAt.map { failure in job.lastAt.map { failure.date > $0.date } ?? true } ?? false
        if failed, let at = job.lastFailedAt {
          state(Symbols.failed, tone: .loss, Text(L10n.Settings.backupFailed(Self.when(at.date))))
          if let error = job.lastFailedError {
            Text(verbatim: error).font(Tokens.Typography.callout).foregroundStyle(Palette.lossText)
          }
        } else if let at = job.lastAt {
          state(Symbols.passed, tone: .profit, Text(L10n.Settings.backupVerified))
          Text(L10n.Settings.backupLast(Self.when(at.date)))
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textQuaternary)
        } else {
          state(Self.unknownSymbol, tone: .neutral, Text(verbatim: Format.missing))
        }
        if let cause = job.causeText {
          Text(verbatim: cause).font(Tokens.Typography.callout).foregroundStyle(Palette.warningText)
        }
      } else if let error = model.jobsError {
        ReadFailureNote(L10n.ReadFailed.jobs, detail: error)
      } else {
        Skeleton(L10n.Common.loading) { SkeletonLines(Tokens.Loading.fewLines) }
      }
      Label {
        Text(L10n.Settings.cleanup)
      } icon: {
        Image(systemName: Self.cleanupSymbol)
      }
      .labelStyle(ControlLabelStyle())
      .font(Tokens.Typography.callout)
      .foregroundStyle(Palette.textTertiary)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.top, Tokens.Space.xs)
    }
  }

  private func state(_ symbol: String, tone: Tone, _ text: Text) -> some View {
    HStack(spacing: Tokens.Space.s) {
      Image(systemName: symbol)
        .font(Tokens.Typography.symbol)
        .foregroundStyle(tone.fill)
        // Pops in as the card appears, and again when the backup's state changes (a new backup,
        // a failure): a new identity per state.
        .popIn(delay: Tokens.Motion.popStagger)
        .id(state(of: model.jobs?.backup))
      text
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textPrimary)
    }
  }

  /// What the check stands for: the newest backup or failure the bot reports. A change pops it.
  private func state(of job: BackupJobV1?) -> [WireTime?] {
    [job?.lastAt, job?.lastFailedAt]
  }

  /// "Fri Nov 13 16:20" in New York time.
  static func when(_ date: Date) -> String {
    DayText.day(WireDate(newYorkDateOf: date)) + dayTimeSeparator + Format.marketMinute(date)
  }
}
