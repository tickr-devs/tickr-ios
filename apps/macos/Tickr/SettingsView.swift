#if os(macOS)
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
    .task(id: model.endpoint) { await model.followJobs() }
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
  @AppStorage(Defaults.showMenuBarExtra) private var showMenuBarExtra = true
  @State private var signIn = Container.shared.signInState()
  @State private var notifications = Container.shared.notificationPermission()
  /// The sign-out question is open.
  @State private var askingSignOut = false

  var body: some View {
    Group {
      connection
      HStack(alignment: .top, spacing: Tokens.Space.s) {
        SettingsCard(L10n.Settings.menuBar) {
          SwitchRow(L10n.Settings.showInMenuBar, isOn: $showMenuBarExtra)
        }
        ThemeCard()
      }
      .fixedSize(horizontal: false, vertical: true)
      DemoDaySection()
      SessionSection()
      MorningCheckSection()
      SystemSection()
    }
  }

  /// The design's "Connection" (mockup v174, MacSystem > General): who this Mac is signed in as,
  /// the bot's address (built into the app) with the link's state, "Notifications · Off" while
  /// they are (board PushAsk), and Sign Out with what it does. A development address shows only
  /// its address and state.
  private var connection: some View {
    let reachable = model.fetchError == nil
    let ownAddress = model.address == BotAddress.url
    return SettingsCard(L10n.SignIn.connection) {
      if ownAddress, model.signedIn {
        Text(signIn.email.map { L10n.SignIn.signedInMac($0) } ?? L10n.SignIn.signedInNoEmail)
          .font(Tokens.Typography.callout)
          .foregroundStyle(Palette.textPrimary)
      }
      HStack(spacing: Tokens.Space.s) {
        Text(L10n.SignIn.bot)
          .font(Tokens.Typography.calloutMono)
          .foregroundStyle(Palette.textTertiary)
          .fixedSize()
        Text(verbatim: model.address.host() ?? model.address.absoluteString)
          .font(Tokens.Typography.calloutMono)
          .textSelection(.enabled)
        Spacer(minLength: Tokens.Space.s)
        // One pulse when the bot becomes reachable or unreachable, never per read.
        HStack(spacing: Tokens.Space.xs) {
          PulseDot(reachable ? Palette.profit : Palette.loss, event: reachable)
          if let error = model.fetchError {
            ReadFailureNote(L10n.Settings.notReachable, detail: error, tone: .loss, defersToConnection: false)
          } else {
            Text(L10n.Settings.connectedTo(model.baseURL.absoluteString))
          }
        }
        .font(Tokens.Typography.callout)
        .foregroundStyle(reachable ? Palette.profitText : Palette.lossText)
      }
      if ownAddress, model.signedIn, notifications.state == .notAsked || notifications.state == .denied {
        NotificationsOffRow(permission: notifications)
      }
      if ownAddress, model.signedIn {
        HStack(spacing: Tokens.Space.m) {
          Button(String(localized: L10n.SignIn.signOut)) { askingSignOut = true }
            .buttonStyle(.action(.secondary, size: .compact))
          Text(L10n.SignIn.outHintMac)
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textQuaternary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .task { await notifications.refresh() }
    .alert(Text(L10n.SignIn.outQuestionMac), isPresented: $askingSignOut) {
      Button(role: .destructive) { Task { await DeviceSignOut.run() } } label: { Text(L10n.SignIn.signOut) }
      Button(role: .cancel) {} label: { Text(L10n.SignIn.cancel) }
    } message: {
      Text(L10n.SignIn.outBody)
    }
  }
}

/// Settings › Connection's "Notifications · Off" (board PushAsk): Turn on opens the screen that
/// asks, or the system's settings once the system was told no.
private struct NotificationsOffRow: View {
  let permission: NotificationPermission

  var body: some View {
    HStack(spacing: Tokens.Space.s) {
      Image(systemName: NotificationsAskLayout.bellSymbol)
        .foregroundStyle(Palette.warningText)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: Tokens.Space.xs) {
        Text(L10n.Notifications.row)
          .font(Tokens.Typography.callout)
          .foregroundStyle(Palette.textPrimary)
        Text(L10n.Notifications.rowLine)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      }
      .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: Tokens.Space.s)
      StatusPill(L10n.Notifications.off, tone: .warning)
      Button(String(localized: L10n.Notifications.turnOn)) { permission.turnOn() }
        .buttonStyle(.action(.secondary, size: .compact))
    }
  }
}

/// The design's "Appearance": System, Light or Dark as the apps' `SegmentSwitch`. A choice other
/// than System holds every window of the app in that appearance (Defaults.appearance).
private struct ThemeCard: View {
  @AppStorage(Defaults.appearance) private var appearance = ""

  /// The choices, by their stored value; the empty value follows the system.
  static let choices = ["", Defaults.light, Defaults.dark]

  var body: some View {
    SettingsCard(L10n.Settings.appearance) {
      SegmentSwitch(options: Self.choices.map { ($0, Text(Self.title($0))) },
        selection: Binding(get: { appearance }, set: { choose($0) }))
        .accessibilityLabel(Text(L10n.Settings.theme))
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
        }
        SettingsCard(L10n.Common.risk) {
          SettingsRow(L10n.Settings.plannedLoss, value: Money.usd(settings.risk.plannedLossUsd.value))
          SettingsRow(L10n.Settings.notionalCap, value: Money.usd(settings.risk.positionNotionalCapUsd.value))
          SettingsRow(L10n.Settings.dailyLossLimit, value: Money.usd(settings.risk.maxDailyLossUsd.value))
          SettingsRow(L10n.Settings.maxOpenPositions, value: "\(settings.risk.maxOpenPositions)")
          SettingsRow(L10n.Settings.maxQuoteAge, value: Format.seconds(settings.risk.maxQuoteAgeSeconds.value))
        }
        SettingsCard(L10n.Settings.session) {
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
        .padding(.horizontal, Tokens.Space.l)  // level with the text inside the cards
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

// MARK: - Notifications

/// Which alerts go where (GET /alerts, PUT /alerts/routing): the shared `AlertRoutingPanel` in
/// this app's settings card. Each switch is one change sent to the bot at once.
private struct NotificationSettings: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    let routing = model.alertRouting
    SettingsCard(AlertText.title) {
      if let alerts = routing.alerts {
        AlertRoutingPanel(alerts, routing: routing) { cell, on in
          Task { await model.setAlertRoute(cell, on: on) }
        }
      } else if let error = routing.readError {
        ReadFailureNote(AlertText.readFailed, detail: error)
      } else {
        AlertRoutingPanelLoading()
      }
    }
    .task(id: model.endpoint) { await model.refreshAlerts() }
  }
}

// MARK: - Environment

/// The design's "Environment": the environment the bot runs in, big with a dot in its badge's
/// colour, then the trading gate with its cause and whether new entries are allowed. A status,
/// never a picker: config/bot.toml sets it, the app never does.
private struct EnvironmentSettings: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    let raw = model.status?.environment ?? model.settings?.environment
    SettingsCard(L10n.Settings.environment, info: L10n.Settings.environmentFixed) {
      HStack(spacing: Tokens.Space.s) {
        if let raw {
          PulseDot(EnvironmentBadge.Kind(raw: raw).tone.fill, pulsing: false)
          Text(verbatim: ApiText.environment(raw))
            .font(Tokens.Typography.heading)
            .foregroundStyle(Palette.textPrimary)
            .accessibilityLabel(Text(verbatim: ApiText.environmentLabel(raw)))
        } else {
          Text(verbatim: Format.missing)
            .font(Tokens.Typography.heading)
            .foregroundStyle(Palette.textQuaternary)
        }
      }
      if let status = model.status {
        let gate = status.tradingGate
        let entries = NewEntries.of(status)
        WrappingRow(L10n.Settings.tradingGate,
          value: String(localized: gate.open ? L10n.Settings.gateOpen : L10n.Settings.gateClosed)
            + Format.itemSeparator + ApiText.gate(gate),
          color: gate.open ? Palette.profitText : Palette.lossText)
        WrappingRow(L10n.Settings.newEntries, value: String(localized: entries.title), color: entries.color)
      }
    }
  }
}

/// Whether the bot may open new positions: off while the gate is closed, paused by the
/// operator's entry-stop, else allowed.
enum NewEntries: Equatable {
  case allowed, paused, off

  var title: LocalizedStringResource {
    switch self {
    case .allowed: L10n.Settings.entriesAllowed
    case .paused: L10n.Settings.entriesPaused
    case .off: L10n.Settings.entriesOff
    }
  }

  var color: Color {
    switch self {
    case .allowed: Palette.profitText
    case .paused: Palette.warningText
    case .off: Palette.lossText
    }
  }

  /// The state of `status`.
  static func of(_ status: StatusV1) -> NewEntries {
    guard status.tradingGate.open else { return .off }
    return status.entryStop ? .paused : .allowed
  }
}

/// A key–value row whose value may run long (a gate's cause): the value wraps at the trailing
/// edge rather than pushing past the card.
private struct WrappingRow: View {
  let label: LocalizedStringResource
  let value: String
  let color: Color

  init(_ label: LocalizedStringResource, value: String, color: Color) {
    self.label = label
    self.value = value
    self.color = color
  }

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.m) {
      Text(label)
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textSecondary)
        .fixedSize()
      Spacer(minLength: Tokens.Space.m)
      Text(verbatim: value)
        .font(Tokens.Typography.calloutMono)
        .foregroundStyle(color)
        .multilineTextAlignment(.trailing)
        .fixedSize(horizontal: false, vertical: true)
    }
    .accessibilityElement(children: .combine)
  }
}

// MARK: - Storage

private struct StorageSettings: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    // Plain words on a failed read: its technical cause is the connection banner's (Details) or
    // the Trades screen's.
    SettingsCard(L10n.Settings.history, footnote: model.historyError.map { _ in Text(L10n.ReadFailed.history) },
      footnoteColor: Palette.lossText) {
      HStack(spacing: Tokens.Space.s) {
        StatTile(value: "\(model.days.count)", label: L10n.Settings.recordedDays)
        StatTile(value: model.days.last.map { DayText.day($0.day) } ?? Format.missing,
          label: L10n.Settings.firstRecordedDay)
        StatTile(value: "\(model.days.filter(\.hasBars).count)", label: L10n.Settings.daysWithBars)
      }
    }
    BackupSection()
  }
}

// MARK: - Advanced

private struct AdvancedSettings: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    SettingsCard(L10n.Settings.botStatusInApp) {
      HStack(spacing: Tokens.Space.s) {
        StatTile(dot: Palette.accent, label: L10n.Settings.statusRefresh,
          value: model.settings.map { String(localized: L10n.Settings.every(Format.seconds($0.pollSeconds.value))) }
            ?? Format.missing)
        StatTile(dot: Palette.warning, label: L10n.Settings.staleAfter,
          value: model.settings.map { Format.seconds($0.statusStaleSeconds.value) } ?? Format.missing)
      }
    }
    BotServiceCard()
    JobsSection()
    ConfigCard()
      .task(id: model.endpoint) { await model.refreshConfig() }
  }
}

/// The design's "Bot" card: the bot's state with a power glyph, Start (the API kickstarts the
/// launchd job, which runs the morning check first) and Stop (the stop-bot command, refused by
/// the bot while a trade is open). Stop asks first, inside the card, as the design draws the
/// question; Start does not, as on the board.
private struct BotServiceCard: View {
  @Environment(AppModel.self) private var model
  @State private var askingStop = false

  /// Symbol of the service glyph (the design's power sign).
  static let serviceSymbol = "power"
  /// Symbol of the Start button.
  static let startSymbol = "play.fill"

  var body: some View {
    SettingsCard(L10n.Common.bot) {
      HStack(spacing: Tokens.Space.m) {
        StateGlyph(Self.serviceSymbol, tone: tone, label: L10n.Common.bot, live: running,
          event: model.status?.botState)
        VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
          title.font(Tokens.Typography.body.weight(.semibold)).foregroundStyle(Palette.textPrimary)
          Text(note).font(Tokens.Typography.callout).foregroundStyle(Palette.textTertiary)
        }
        Spacer(minLength: Tokens.Space.s)
        Button { Task { await model.startBot() } } label: {
          Label { Text(L10n.Settings.startBotAction) } icon: { Image(systemName: Self.startSymbol) }
        }
        // Start is the card's main action; Stop is a destructive bot command, as on Overview.
        .buttonStyle(.action(.primary, size: .compact))
        .disabled(!model.canStartBot)
        .inFlight(model.botStarting ? Text(InFlightText.startBot) : nil)
        .hint(L10n.Settings.startBotHint)
        Button(role: .destructive) { askingStop = true } label: {
          Label { Text(L10n.Settings.stopBotAction) } icon: { Image(systemName: BotAction.stopSymbol) }
        }
        .buttonStyle(.command(.destructive, tag: model.demoDay ? Text(L10n.Bot.demoTag) : nil))
        .fixedSize()
        .disabled(!model.canStopBot)
        .inFlight(model.inFlight == .stopBot ? Text(OperatorCommand.stopBot.inFlightTitle) : nil)
        .hint(verbatim: BotAction.stopBot.explanation)
      }
      if askingStop {
        stopQuestion
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
    .animation(Tokens.Motion.quick, value: askingStop)
    // The question is withdrawn when the state no longer allows a stop.
    .onChange(of: model.canStopBot) { _, enabled in
      if !enabled { askingStop = false }
    }
  }

  /// The design's question inside the card: what happens, then Cancel and Stop.
  private var stopQuestion: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      Text(L10n.Bot.stopQuestion)
        .font(Tokens.Typography.body.weight(.semibold))
        .foregroundStyle(Palette.textPrimary)
      Text(verbatim: BotAction.stopBot.explanation)
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textTertiary)
        .fixedSize(horizontal: false, vertical: true)
      HStack(spacing: Tokens.Space.s) {
        Spacer()
        Button { askingStop = false } label: { Text(L10n.Common.cancel) }
          .buttonStyle(.action(.secondary, size: .compact))
          .keyboardShortcut(.cancelAction)
        Button(role: .destructive) {
          askingStop = false
          Task { await model.send(BotAction.stopBot.command, title: BotAction.stopBot.title) }
        } label: { Text(verbatim: BotAction.stopBot.title) }
          .buttonStyle(.action(.destructive, size: .compact))
          .disabled(!model.canStopBot)
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
/// each key's comment over its line (credentials appear only as variable names). Editing comes
/// later, behind a backup and a restart.
private struct ConfigCard: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    SettingsCard(model.config.map { L10n.Settings.configFile($0.file) } ?? L10n.Settings.configuration) {
      if let config = model.config {
        if let error = config.error {
          Text(verbatim: error).font(Tokens.Typography.callout).foregroundStyle(Palette.lossText)
            .fixedSize(horizontal: false, vertical: true)
        }
        ForEach(config.sections, id: \.name) { section in
          RowExpander {
            VStack(alignment: .leading, spacing: Tokens.Space.s) {
              ForEach(section.keys, id: \.key) { key in line(key) }
            }
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
      Text.joined(Text(verbatim: key.key).foregroundStyle(Palette.infoText),
        Text(verbatim: Self.assign).foregroundStyle(Palette.textTertiary),
        Text(verbatim: key.value).foregroundStyle(Palette.warningText))
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

/// The design's "Today's session" (GET /jobs): today's session as a strip, times ET, or why there
/// is none today. Read while Settings is open.
struct SessionSection: View {
  @Environment(AppModel.self) private var model
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    SettingsCard(sessionTitle) {
      if let session = model.jobs?.session {
        // The now line follows the bot's clock; it moves once a minute (`SessionStrip.minute`).
        TimelineView(.periodic(from: .now, by: Tokens.Motion.clockTickSeconds)) { context in
          SessionStrip(span: SessionSpan(session), now: model.botTime(context.date),
            moving: JobsSection.stripesMove(reduceMotion: reduceMotion, model: model))
        }
      } else if let cause = model.jobs?.sessionCauseText {
        Text(verbatim: cause).font(Tokens.Typography.callout).foregroundStyle(Palette.textTertiary)
      } else if let error = model.jobsError {
        ReadFailureNote(L10n.ReadFailed.jobs, detail: error)
      } else {
        Skeleton(L10n.Common.loading) { SkeletonLines(Tokens.Loading.fewLines) }
      }
    } trailing: {
      Text(L10n.Settings.timesET)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
    }
  }

  private var sessionTitle: LocalizedStringResource {
    guard let day = model.jobs?.session?.day else { return L10n.Settings.session }
    return L10n.Settings.sessionTitle(DayText.day(day))
  }
}

/// The design's "Scheduled jobs" (GET /jobs): what runs on its own on the Mac, one row each: a
/// dot in its colour (pulsing while it runs), its name, when it runs, its state and its last or
/// next time. Read while Settings is open.
struct JobsSection: View {
  @Environment(AppModel.self) private var model

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
    SettingsCard(L10n.Settings.jobs) {
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
      Text(L10n.Settings.jobsFooter)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
    }
  }

  /// Whether the session strip's planned stripes drift: an ornament that reads as "the bot is at
  /// work", so only while it is (`OrnamentGate`: running, live and fresh status, motion allowed).
  static func stripesMove(reduceMotion: Bool, model: AppModel) -> Bool {
    model.ornamentsMove(reduceMotion: reduceMotion)
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

/// Today's session as the design's strip: pre-market and post-market striped and dashed, marked
/// "not traded" (the bot trades the regular session only), the regular session in the accent with the
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
        mark(L10n.Settings.notTraded, color: Palette.textQuaternary, x: Tokens.Space.s, y: below)
          .hint(L10n.Settings.notTradedHint)
        mark(L10n.Settings.markFlatten(Format.marketMinute(flatten)), color: Palette.warningText,
          x: x(flatten), y: below, trailing: true)
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

/// The bot's database backup (GET /jobs) as the design's "Backup": a green check with "Backup
/// checked" and when the last one was made, or the failure when it is newer, with its error; why
/// neither is known when the bot cannot tell. How clean-up runs is the label's tooltip.
struct BackupSection: View {
  @Environment(AppModel.self) private var model

  /// Symbol of the unknown state (verified and failed draw `Symbols.passed` and `Symbols.failed`).
  static let unknownSymbol = "circle.dashed"
  /// Separates the day from the time.
  static let dayTimeSeparator = " "

  var body: some View {
    SettingsCard(L10n.Settings.backup, info: L10n.Settings.cleanup) {
      if let job = model.jobs?.backup {
        let failed = job.lastFailedAt.map { failure in job.lastAt.map { failure.date > $0.date } ?? true } ?? false
        if failed, let at = job.lastFailedAt {
          state(Symbols.failed, tone: .loss, Text(L10n.Settings.backupFailed(Self.when(at.date))), when: nil)
          if let error = job.lastFailedError {
            Text(verbatim: error).font(Tokens.Typography.callout).foregroundStyle(Palette.lossText)
          }
        } else if let at = job.lastAt {
          state(Symbols.passed, tone: .profit, Text(L10n.Settings.backupVerified), when: Self.when(at.date))
        } else {
          state(Self.unknownSymbol, tone: .neutral, Text(verbatim: Format.missing), when: nil)
        }
        if let cause = job.causeText {
          Text(verbatim: cause).font(Tokens.Typography.callout).foregroundStyle(Palette.warningText)
        }
      } else if let error = model.jobsError {
        ReadFailureNote(L10n.ReadFailed.jobs, detail: error)
      } else {
        Skeleton(L10n.Common.loading) { SkeletonLines(Tokens.Loading.fewLines) }
      }
    }
  }

  /// The state big beside its symbol, and when the backup was made at the trailing edge.
  private func state(_ symbol: String, tone: Tone, _ text: Text, when: String?) -> some View {
    HStack(spacing: Tokens.Space.s) {
      Image(systemName: symbol)
        .font(Tokens.Typography.symbol)
        .foregroundStyle(tone.fill)
        // Pops in as the card appears, and again when the backup's state changes (a new backup,
        // a failure): a new identity per state.
        .popIn(delay: Tokens.Motion.popStagger)
        .id(state(of: model.jobs?.backup))
      text
        .font(Tokens.Typography.heading)
        .foregroundStyle(Palette.textPrimary)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: Tokens.Space.s)
      if let when {
        Text(verbatim: when)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
          .fixedSize()
      }
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
#endif
