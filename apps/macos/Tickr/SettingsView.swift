import SwiftUI
import TickrDesign
import TickrKit

/// The standard Settings window (⌘,). The app's own preferences are editable; the bot's
/// configuration is shown read-only because it lives in config/bot.toml, not in the app.
struct SettingsView: View {
  @Environment(AppModel.self) private var model

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
      Tab { GeneralSettings() } label: {
        Label(String(localized: L10n.Settings.general), systemImage: Self.generalSymbol)
      }
      Tab { TradingSettings() } label: {
        Label(String(localized: L10n.Settings.trading), systemImage: Self.tradingSymbol)
      }
      Tab { NotificationSettings() } label: {
        Label(String(localized: L10n.Settings.notifications), systemImage: Self.notificationsSymbol)
      }
      Tab { EnvironmentSettings() } label: {
        Label(String(localized: L10n.Settings.environment), systemImage: Self.environmentSymbol)
      }
      Tab { StorageSettings() } label: {
        Label(String(localized: L10n.Settings.storage), systemImage: Self.storageSymbol)
      }
      Tab { AdvancedSettings() } label: {
        Label(String(localized: L10n.Settings.advanced), systemImage: Self.advancedSymbol)
      }
    }
    .frame(width: Self.width)
    .scenePadding()
    .task(id: model.baseURL) { await model.followJobs() }
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
            .disabled(draft == model.address.absoluteString)
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
      DemoDaySection()
      JobsSection()
      Section(String(localized: L10n.Settings.menuBar)) {
        Toggle(String(localized: L10n.Settings.showInMenuBar), isOn: $showMenuBarExtra)
      }
      Section(String(localized: L10n.Settings.appearance)) {
        LabeledContent(String(localized: L10n.Settings.theme)) { Text(L10n.Settings.followsSystem) }
      }
    }
    .formStyle(.grouped)
    .onAppear { draft = model.address.absoluteString }
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

/// The "Demo day" switch as a design row: its glyph, the name with a one-line explanation, and the
/// switch in the environment chip's colour. On, the app shows the demo day behind the bot's
/// address (AppModel.setDemoDay) and remembers the choice; the address field above is untouched.
private struct DemoDaySection: View {
  @Environment(AppModel.self) private var model
  @AppStorage(Defaults.demoDay) private var demoDay = false

  /// SF Symbol of the row.
  static let symbol = "theatermasks"
  /// Accessibility id of the switch, for the UI tests.
  static let id = "settings-demo-day"

  var body: some View {
    Section {
      HStack(spacing: Tokens.Space.s) {
        StateGlyph(Self.symbol, tone: model.demoDay ? .warning : .neutral, label: L10n.Settings.demoDay, style: .compact)
        VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
          Text(L10n.Settings.demoDay)
          Text(L10n.Settings.demoDayExplanation)
            .font(Tokens.Typography.caption)
            .foregroundStyle(.secondary)
        }
        Spacer(minLength: Tokens.Space.s)
        if model.demoDay { Badge(L10n.Toolbar.demoChip, tone: .warning) }
        Toggle(isOn: Binding(get: { model.demoDay }, set: { on in
          demoDay = on
          model.setDemoDay(on)
        })) {
          Text(L10n.Settings.demoDay)
        }
        .labelsHidden()
        .toggleStyle(.switch)
        .tint(Palette.warning)
        .accessibilityIdentifier(Self.id)
      }
      .animation(Tokens.Motion.quick, value: model.demoDay)
    }
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
          LabeledContent(String(localized: L10n.Settings.maxQuoteAge),
            value: Format.seconds(settings.risk.maxQuoteAgeSeconds.value))
        } header: {
          Text(L10n.Common.risk)
        } footer: {
          ConfigFootnote()
        }
        Section {
          LabeledContent(String(localized: L10n.Settings.marketTimezone), value: settings.session.timezone)
          LabeledContent(String(localized: L10n.Settings.lastEntry),
            value: Self.beforeClose(settings.session.lastEntryMinutesBeforeClose))
          LabeledContent(String(localized: L10n.Settings.flatten),
            value: Self.beforeClose(settings.session.flattenMinutesBeforeClose))
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
        LabeledContent(String(localized: L10n.Settings.environment),
          value: (model.status?.environment ?? model.settings?.environment).map(ApiText.environment) ?? Format.missing)
        if let gate = model.status?.tradingGate {
          LabeledContent(String(localized: L10n.Settings.tradingGate),
            value: String(localized: gate.open ? L10n.Settings.gateOpen : L10n.Settings.gateClosed))
          LabeledContent(String(localized: L10n.Settings.gateCause), value: ApiText.gate(gate))
        }
        LabeledContent(String(localized: L10n.Settings.apiVersion),
          value: model.settings.map { "\($0.apiVersion)" } ?? Format.missing)
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
        LabeledContent(String(localized: L10n.Settings.firstRecordedDay),
          value: model.days.last.map { Format.dayLabel($0.day) } ?? Format.missing)
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
      BackupSection()
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

/// What runs on its own on the Mac (GET /jobs): the bot service, its reconcile loop and the launchd
/// jobs with their start times, as in the board's session card. Read while Settings is open.
struct JobsSection: View {
  @Environment(AppModel.self) private var model

  /// Symbols of the rows.
  static let serviceSymbol = "waveform.path.ecg"
  static let reconcileSymbol = "arrow.triangle.2.circlepath"
  static let launchdSymbol = "clock"
  /// Days in a week; launchd numbers them 0 (or 7) Sunday, 1 Monday … 6 Saturday.
  static let week = 7
  /// Shortest run of days written as a range ("Mon–Fri") rather than a list.
  static let shortestRange = 3
  /// Joins the first and last day of a range.
  static let rangeDash = "–"

  var body: some View {
    Section {
      if let jobs = model.jobs {
        service(jobs)
        reconcile(jobs.reconcile)
        ForEach(jobs.launchd, id: \.name) { job in
          LabeledContent {
            Text(verbatim: job.localTime + Format.itemSeparator + Self.days(job.weekdays))
              .font(Tokens.Typography.bodyMono)
          } label: {
            Label {
              Text(verbatim: Self.title(job.name))
            } icon: {
              StateGlyph(Self.launchdSymbol, tone: .info, label: Text(verbatim: Self.title(job.name)), style: .compact)
            }
          }
        }
      } else if let error = model.jobsError {
        Text(verbatim: error).foregroundStyle(Palette.warningText)
      } else {
        ProgressView().controlSize(.small)
      }
    } header: {
      Text(L10n.Settings.jobs)
    } footer: {
      Text(L10n.Settings.jobsFooter)
        .font(Tokens.Typography.caption).foregroundStyle(.secondary)
    }
  }

  /// The bot's state as its status reports it; a stale status proves nothing about the bot now, so
  /// it says so instead of repeating the last state.
  private func service(_ jobs: JobsV1) -> some View {
    let running = jobs.botState == .running && !jobs.statusStale
    let tone: Tone = jobs.statusStale ? .warning : running ? .accent : .neutral
    let title = jobs.statusStale ? String(localized: L10n.Settings.notReported)
      : jobs.botState?.title ?? String(localized: L10n.Settings.notRunning)
    return LabeledContent {
      StatusPill(verbatim: title, tone: tone, live: running, event: running)
    } label: {
      Label {
        Text(L10n.Settings.botService)
      } icon: {
        StateGlyph(Self.serviceSymbol, tone: tone, label: L10n.Settings.botService, style: .compact)
      }
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
    LabeledContent {
      Group {
        if let next = job.nextAt?.date, next > model.botNow {
          HStack(spacing: Tokens.Space.xs) {
            Text(L10n.Settings.nextIn)
            Text(timerInterval: Date.now...Date.now.addingTimeInterval(next.timeIntervalSince(model.botNow)))
              .monospacedDigit()
          }
        } else if let last = job.lastAt {
          Text(L10n.Settings.lastAt(Format.marketTime(last.date)))
        } else {
          Text(verbatim: Format.missing)
        }
      }
      .font(Tokens.Typography.bodyMono)
    } label: {
      Label {
        Text(L10n.Settings.reconcile)
      } icon: {
        StateGlyph(Self.reconcileSymbol, tone: .info, label: L10n.Settings.reconcile, style: .compact)
      }
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

/// The bot's database backup (GET /jobs): the last good one, or the failure when it is newer, with
/// its error; why neither is known when the bot cannot tell.
private struct BackupSection: View {
  @Environment(AppModel.self) private var model

  /// Symbol of the backup row.
  static let backupSymbol = "externaldrive"

  var body: some View {
    Section {
      if let job = model.jobs?.backup {
        let failed = job.lastFailedAt.map { failure in job.lastAt.map { failure.date > $0.date } ?? true } ?? false
        LabeledContent {
          if failed, let at = job.lastFailedAt {
            StatusPill(L10n.Settings.backupFailed(Format.marketTime(at.date)), tone: .loss)
          } else if let at = job.lastAt {
            Text(verbatim: Self.when(at.date)).font(Tokens.Typography.bodyMono)
          } else {
            Text(verbatim: Format.missing)
          }
        } label: {
          Label {
            Text(L10n.Settings.backup)
          } icon: {
            StateGlyph(Self.backupSymbol, tone: failed ? .loss : job.lastAt == nil ? .neutral : .profit,
              label: L10n.Settings.backup, style: .compact)
          }
        }
        if failed, let error = job.lastFailedError {
          Text(verbatim: error).foregroundStyle(Palette.lossText)
        }
        if let cause = job.cause {
          Text(verbatim: cause).foregroundStyle(Palette.warningText)
        }
      } else if let error = model.jobsError {
        Text(verbatim: error).foregroundStyle(Palette.warningText)
      } else {
        ProgressView().controlSize(.small)
      }
    } header: {
      Text(L10n.Settings.backup)
    } footer: {
      Text(L10n.Settings.backupFooter)
        .font(Tokens.Typography.caption).foregroundStyle(.secondary)
    }
  }

  /// "Mon, Nov 16 · 08:12:09" in New York time.
  private static func when(_ date: Date) -> String {
    Format.dayLabel(WireDate(newYorkDateOf: date)) + Format.itemSeparator + Format.marketTime(date)
  }
}
