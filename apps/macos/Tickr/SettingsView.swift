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
  @State private var tab: SettingsTab = .general
  @State private var contentHeight: CGFloat = 0

  /// Width of the Settings window, in points (the design's 820).
  static let width: CGFloat = 820
  /// Tallest the pane area grows to its content before it scrolls, in points.
  static let maxPaneHeight: CGFloat = 760

  var body: some View {
    VStack(spacing: 0) {
      SettingsTabBar(selection: $tab)
      ScrollView {
        pane
          .padding(.horizontal, Tokens.Space.xl)
          .padding(.vertical, Tokens.Space.l)
          .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
      }
      .scrollBounceBehavior(.basedOnSize)
      .frame(height: min(max(contentHeight, 1), Self.maxPaneHeight))
    }
    .frame(width: Self.width)
    .background(Palette.background)
    // The window keeps the pane's name (Window menu); the title bar shows it in the design's
    // small monospace instead of the system's bold title, with no glass behind it.
    .navigationTitle(Text(tab.title))
    .toolbar(removing: .title)
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text(tab.title)
          .font(Tokens.Typography.calloutMono)
          .foregroundStyle(Palette.textQuaternary)
          .fixedSize()
      }
      .sharedBackgroundVisibility(.hidden)
    }
    .toolbarBackground(Palette.titleBar, for: .windowToolbar)
    .toolbarBackgroundVisibility(.visible, for: .windowToolbar)
    .task(id: model.baseURL) { await model.followJobs() }
  }

  @ViewBuilder private var pane: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      switch tab {
      case .general: GeneralSettings()
      case .trading: TradingSettings()
      case .notifications: NotificationSettings()
      case .environment: EnvironmentSettings()
      case .storage: StorageSettings()
      case .advanced: AdvancedSettings()
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
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
      HStack(alignment: .top, spacing: Tokens.Space.m) {
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
        PulseDot(reachable ? Palette.profit : Palette.loss, pulsing: reachable,
          event: model.response.map { AnyHashable($0.servedAt) })
        Group {
          if let error = model.fetchError {
            Text(L10n.Settings.notReachable(error))
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

/// The design's "Appearance · theme": System, Light or Dark as a segmented strip. A choice other
/// than System holds every window of the app in that appearance (Defaults.appearance).
private struct ThemeCard: View {
  @AppStorage(Defaults.appearance) private var appearance = ""

  /// The choices, by their stored value; the empty value follows the system.
  static let choices = ["", Defaults.light, Defaults.dark]

  var body: some View {
    SettingsCard(L10n.Settings.appearanceTheme, footnote: Text(note)) {
      SegmentStrip(selection: Binding(get: { appearance }, set: { choose($0) }), choices: Self.choices) { value in
        Text(Self.title(value))
      }
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
    NSApplication.shared.appearance = TickrMacApp.appearance(value)
  }
}

/// The "Demo day" switch as a card: the name with a one-line explanation, the demo chip while it
/// is on, and the switch in the environment chip's colour. On, the app shows the demo day behind
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
        .toggleStyle(.switch)
        .controlSize(.small)
        .tint(Palette.warning)
        .accessibilityIdentifier(Self.id)
        Text(L10n.Settings.demoDay)
          .font(Tokens.Typography.callout)
          .foregroundStyle(Palette.textSecondary)
          .accessibilityHidden(true)
        Spacer(minLength: Tokens.Space.s)
      }
    } trailing: {
      if model.demoDay { Badge(L10n.Toolbar.demoChip, tone: .warning) }
    }
    .animation(Tokens.Motion.quick, value: model.demoDay)
  }
}

// MARK: - Trading

private struct TradingSettings: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    if let settings = model.settings {
      HStack(alignment: .top, spacing: Tokens.Space.m) {
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
                .lineLimit(1)
            }
          }
        }
        SettingsCard(L10n.Common.risk) {
          SettingsRow(L10n.Settings.plannedLoss, value: Format.usd(settings.risk.plannedLossUsd.value))
          SettingsRow(L10n.Settings.notionalCap, value: Format.usd(settings.risk.positionNotionalCapUsd.value))
          SettingsRow(L10n.Settings.dailyLossLimit, value: Format.usd(settings.risk.maxDailyLossUsd.value))
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
      FeaturesCard(settings: settings)
    } else {
      SettingsCard(L10n.Common.strategy) {
        Group {
          if let error = model.settingsError { Text(verbatim: error) } else { Text(L10n.Settings.readingSettings) }
        }
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textTertiary)
      }
    }
  }

  private static func beforeClose(_ minutes: Int) -> String { String(localized: L10n.Settings.beforeClose(minutes)) }
}

/// The design's "Features · from config": switches that show what the configuration turns on.
/// Half days and live observers are real values; the rest are planned and marked so.
private struct FeaturesCard: View {
  let settings: SettingsV1

  var body: some View {
    SettingsCard(L10n.Settings.features, footnote: Text(L10n.Settings.featuresFootnote)) {
      row(L10n.Settings.featureTrailing, on: false) { PlannedTag().fixedSize() }
      row(L10n.Settings.featureExtendedHours, on: false) { PlannedTag().fixedSize() }
      row(L10n.Settings.featureShort, on: false) { PlannedTag().fixedSize() }
      row(L10n.Settings.featureChase, on: false) { PlannedTag().fixedSize() }
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
      ConfigSwitch(on: on)
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
          }
          .lineLimit(1)
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

/// The environment and the trading gate as the design's two-part strip: the environment the bot
/// runs in lit in its tone with the gate's state, the others muted and closed; then the gate, its
/// cause, the environment's name and the API version.
private struct EnvironmentSettings: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    let raw = model.status?.environment ?? model.settings?.environment
    SettingsCard(L10n.Settings.environmentGate, footnote: Text(L10n.Settings.environmentFixed)) {
      HStack(spacing: Tokens.Space.xs) {
        ForEach(Self.segments(current: raw), id: \.self) { segment in
          let active = segment == raw
          Text(verbatim: label(segment, active: active))
            .font(Tokens.Typography.annotationBold)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Tokens.Space.s)
            .foregroundStyle(active ? tone(segment).text : Palette.textQuaternary)
            .background(active ? tone(segment).fill.opacity(Tokens.Opacity.glow) : .clear,
              in: RoundedRectangle(cornerRadius: Tokens.Radius.small, style: .continuous))
        }
      }
      .padding(Tokens.Space.xs)
      .background(Palette.surfaceSunken, in: RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
        .strokeBorder(Palette.separator, lineWidth: Tokens.Stroke.thin))
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

  /// The parts of the strip: Sandbox and Production, with the environment in use in front when it
  /// is neither (the demo).
  static func segments(current: String?) -> [String] {
    let known = [BotEnvironment.sandbox.rawValue, BotEnvironment.production.rawValue]
    guard let current, !known.contains(current) else { return known }
    return [current] + known
  }

  /// "SANDBOX · gate open" for the environment in use; only the name for the others (the app
  /// knows nothing about an environment it is not connected to) and before the first status.
  private func label(_ raw: String, active: Bool) -> String {
    let name = ApiText.environment(raw).localizedUppercase
    guard active, let open = model.status?.tradingGate.open else { return name }
    return name + Format.itemSeparator + String(localized: open ? L10n.Settings.gateOpenShort : L10n.Settings.gateClosedShort)
  }

  private func tone(_ raw: String) -> Tone {
    raw == BotEnvironment.production.rawValue ? .loss : .warning
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
        StatTile(value: model.days.last.map { Format.dayLabel($0.day) } ?? Format.missing,
          label: L10n.Settings.firstRecordedDay)
        StatTile(value: "\(model.days.filter(\.hasBars).count)", label: L10n.Settings.daysWithBars)
      }
    }
    BackupSection()
  }

  private var historyNote: Text {
    model.historyError.map { Text(verbatim: $0) } ?? Text(L10n.Settings.historySource)
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
    SettingsCard(L10n.Settings.notAvailableYet) {
      SettingsRow(L10n.Settings.startStop) { PlannedTag(.needsAPI).fixedSize() }
      SettingsRow(L10n.Settings.editConfig) { PlannedTag().fixedSize() }
    }
  }
}

// MARK: - Jobs and session

/// The design's "Session" card with the jobs under it (GET /jobs): today's session as a strip,
/// then what runs on its own on the Mac, one row each: a dot in its colour (pulsing while it
/// runs), its name, when it runs, its state and its last or next time. Read while Settings is open.
struct JobsSection: View {
  @Environment(AppModel.self) private var model

  /// Widths of the name and "when" columns, in points (the design's 86 and 130, the name widened
  /// for the Russian names).
  static let nameWidth: CGFloat = 120
  static let whenWidth: CGFloat = 130
  /// Days in a week; launchd numbers them 0 (or 7) Sunday, 1 Monday … 6 Saturday.
  static let week = 7
  /// Shortest run of days written as a range ("Mon–Fri") rather than a list.
  static let shortestRange = 3
  /// Joins the first and last day of a range.
  static let rangeDash = "–"

  var body: some View {
    SettingsCard(sessionTitle) {
      if let session = model.jobs?.session {
        SessionStrip(session: session, now: model.botNow)
      } else if let cause = model.jobs?.sessionCause {
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
        Text(verbatim: error).font(Tokens.Typography.callout).foregroundStyle(Palette.warningText)
      } else {
        ProgressView().controlSize(.small)
      }
    } trailing: {
      Text(L10n.Settings.timesET)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
    }
  }

  private var sessionTitle: LocalizedStringResource {
    guard let day = model.jobs?.session?.day else { return L10n.Settings.session }
    return L10n.Settings.sessionTitle(Format.dayLabel(day))
  }

  /// One job: dot (its tone, and whether it pulses), name, when, state, times.
  private func row(
    _ dot: (tone: Tone, live: Bool), name: Text, when: Text, state: Text,
    @ViewBuilder meta: () -> some View
  ) -> some View {
    let (tone, live) = dot
    return HStack(spacing: Tokens.Space.s) {
      PulseDot(tone.fill, pulsing: live, event: live ? model.jobs.map { AnyHashable($0.servedAt) } : nil)
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
    .lineLimit(1)
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
          Text(L10n.Settings.since(Format.marketMinute(started.date)))
        }
      }
    } else {
      row((.info, false), name: name, when: when, state: Text(verbatim: "")) { EmptyView() }
    }
  }

  /// A launchd job's name in the person's language; a job this app does not know reads as
  /// "Other job", never as its launchd name.
  static func title(_ name: String) -> String {
    guard let job = LaunchdJob(rawValue: name) else { return String(localized: L10n.Settings.jobOther) }
    switch job {
    case .preflight: return String(localized: L10n.Settings.jobPreflight)
    case .bot: return String(localized: L10n.Settings.jobBot)
    case .watchdog: return String(localized: L10n.Settings.jobWatchdog)
    }
  }

  /// The launchd jobs the bot installs on the Mac, by their wire names in jobs-v1.
  enum LaunchdJob: String {
    case preflight, bot, watchdog
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

/// Today's session as the design's strip: pre-market and post-market dashed and marked planned
/// (the bot trades the regular session only), the regular session in the accent with the minutes
/// after the flatten time in amber, the open, last entry, flatten and close times above and below,
/// and a line at now.
private struct SessionStrip: View {
  let session: SessionTimesV1
  let now: Date

  /// How long the extended sessions run around the regular one on a full day, in hours:
  /// pre-market from 04:00, post-market to 20:00 New York time (shown, not traded).
  static let preMarketHours: Double = 5.5
  static let postMarketHours: Double = 4
  /// Seconds in an hour.
  static let secondsPerHour: Double = 3600
  /// Height of the bar, and of the whole strip with a row of labels above and below, in points.
  static let barHeight: CGFloat = 22
  static let height: CGFloat = 62

  var body: some View {
    let open = session.regularOpen.date
    let close = session.regularClose.date
    let flatten = session.flattenAt.date
    let start = open.addingTimeInterval(-Self.preMarketHours * Self.secondsPerHour)
    let end = close.addingTimeInterval(Self.postMarketHours * Self.secondsPerHour)
    let span = end.timeIntervalSince(start)
    let barTop = (Self.height - Self.barHeight) / 2
    let below = Self.height - Tokens.Typography.annotationSize - Tokens.Space.xs
    GeometryReader { proxy in
      let width = proxy.size.width
      let x = { (date: Date) -> CGFloat in CGFloat(date.timeIntervalSince(start) / span) * width }
      ZStack(alignment: .topLeading) {
        planned.frame(width: x(open), height: Self.barHeight).offset(y: barTop)
        Rectangle().fill(Palette.accent.opacity(Tokens.Opacity.glow))
          .overlay(Rectangle().strokeBorder(Palette.accent, lineWidth: Tokens.Stroke.thin))
          .frame(width: x(close) - x(open), height: Self.barHeight).offset(x: x(open), y: barTop)
        Rectangle().fill(Palette.warning.opacity(Tokens.Opacity.faint))
          .frame(width: x(close) - x(flatten), height: Self.barHeight).offset(x: x(flatten), y: barTop)
        planned.frame(width: width - x(close), height: Self.barHeight).offset(x: x(close), y: barTop)
        if now > start && now < end {
          Rectangle().fill(Palette.textPrimary)
            .frame(width: Tokens.Stroke.bold, height: Self.height)
            .offset(x: x(now))
        }
        mark(L10n.Settings.markOpen(Format.marketMinute(open)), color: Palette.accentText, x: x(open))
        mark(L10n.Settings.markLastEntry(Format.marketMinute(session.lastEntryAt.date)), color: Palette.warningText,
          x: x(session.lastEntryAt.date), trailing: true)
        mark(L10n.Settings.markClose(Format.marketMinute(close)), color: Palette.accentText,
          x: x(close) + Tokens.Space.xs)
        mark(L10n.Settings.preBacklog, color: Palette.highlightText, x: Tokens.Space.s, y: below)
        mark(L10n.Settings.markFlatten(Format.marketMinute(flatten)), color: Palette.warningText,
          x: x(flatten), y: below, trailing: true)
        mark(L10n.Settings.postBacklog, color: Palette.highlightText, x: width - Tokens.Space.s, y: below,
          trailing: true)
      }
    }
    .frame(height: Self.height)
    .accessibilityElement(children: .combine)
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

  /// A planned stretch: the highlight's dashed outline over a light wash.
  private var planned: some View {
    Rectangle().fill(Palette.highlight.opacity(Tokens.Opacity.wash))
      .overlay(Rectangle().strokeBorder(Palette.highlight,
        style: StrokeStyle(lineWidth: Tokens.Stroke.thin, dash: Tokens.Stroke.dashFine)))
  }
}

/// The bot's database backup (GET /jobs) as the design's "Backups · storage": a green check with
/// what the backup is and when the last one was made, or the failure when it is newer, with its
/// error; why neither is known when the bot cannot tell; and how clean-up runs.
private struct BackupSection: View {
  @Environment(AppModel.self) private var model

  /// Symbols of the states and of the clean-up note.
  static let verifiedSymbol = "checkmark.circle.fill"
  static let failedSymbol = "xmark.circle.fill"
  static let unknownSymbol = "circle.dashed"
  static let cleanupSymbol = "trash"
  /// Separates the day from the time.
  static let dayTimeSeparator = " "

  var body: some View {
    SettingsCard(L10n.Settings.backups, footnote: Text(L10n.Settings.backupFooter)) {
      if let job = model.jobs?.backup {
        let failed = job.lastFailedAt.map { failure in job.lastAt.map { failure.date > $0.date } ?? true } ?? false
        if failed, let at = job.lastFailedAt {
          state(Self.failedSymbol, tone: .loss, Text(L10n.Settings.backupFailed(Self.when(at.date))))
          if let error = job.lastFailedError {
            Text(verbatim: error).font(Tokens.Typography.callout).foregroundStyle(Palette.lossText)
          }
        } else if let at = job.lastAt {
          state(Self.verifiedSymbol, tone: .profit, Text(L10n.Settings.backupVerified))
          Text(L10n.Settings.backupLast(Self.when(at.date)))
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textQuaternary)
        } else {
          state(Self.unknownSymbol, tone: .neutral, Text(verbatim: Format.missing))
        }
        if let cause = job.cause {
          Text(verbatim: cause).font(Tokens.Typography.callout).foregroundStyle(Palette.warningText)
        }
      } else if let error = model.jobsError {
        Text(verbatim: error).font(Tokens.Typography.callout).foregroundStyle(Palette.warningText)
      } else {
        ProgressView().controlSize(.small)
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
      text
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textPrimary)
    }
  }

  /// "Fri Nov 13 16:20" in New York time.
  static func when(_ date: Date) -> String {
    Format.dayLabel(WireDate(newYorkDateOf: date)) + dayTimeSeparator + Format.marketMinute(date)
  }
}
