import SwiftUI
import TickrDesign
import TickrKit
import TickrScreens

/// Settings, behind the gear on Home: what the bot reports about itself, what this phone does, and
/// where the bot is. A grouped form whose sections are the design's cards, with no tab bar.
struct SettingsView: View {
  /// Info.plist key of the app's marketing version.
  static let versionKey = "CFBundleShortVersionString"
  /// Symbols of the rows' icons.
  static let statusSymbol = "antenna.radiowaves.left.and.right"
  static let signOutSymbol = "rectangle.portrait.and.arrow.right"
  static let stateSymbol = "power"
  static let startSymbol = "play.fill"
  static let configSymbol = "doc.plaintext.fill"
  static let appSymbol = "app.fill"
  static let contractSymbol = "doc.text.fill"
  static let demoSymbol = "theatermasks.fill"
  static let notificationsSymbol = "bell.fill"
  /// Accessibility id of the demo day switch, for the UI tests.
  static let demoDayID = "settings-demo-day"

  /// Order in which the cards rise in (`cardRise(step:)`), as on the design.
  private enum Order: Int {
    case connection = 1, bot, demo, notifications, environment, session, preflight, jobs, system, about
  }

  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var confirmSignOut = false
  @State private var signIn = Container.shared.signInState()
  @State private var notifications = Container.shared.notificationPermission()
  @State private var showControl = false
  @State private var confirmStart = false

  var body: some View {
    Form {
      Section {
      } header: {
        PushedHeader(title: L10n.Settings.title, back: L10n.App.home, action: dismiss)
          .formHeaderRow()
      }
      // As on the design: where the bot is, then the bot itself.
      connectionCard.cardRise(step: Order.connection.rawValue)
      if let status = model.status { botCard(status).cardRise(step: Order.bot.rawValue) }

      // The demo day switch (#411), in the design's card style.
      SettingsCard(L10n.Settings.demoDay, note: L10n.Settings.demoDayFooter) {
        Toggle(isOn: Binding(get: { model.connection.demo }, set: { model.connection = model.connection.demo($0) })) {
          Label { Text(L10n.Settings.demoDay) } icon: { SettingsIcon(Self.demoSymbol, tone: .warning) }
        }
        .tint(Palette.warning)
        .accessibilityIdentifier(Self.demoDayID)
      }
      .cardRise(step: Order.demo.rawValue)

      NotificationsSection().cardRise(step: Order.notifications.rawValue)

      if let status = model.status {
        EnvironmentSection(status: status).cardRise(step: Order.environment.rawValue)
      }
      if model.isConfigured {
        SessionSection(session: model.settings?.session, times: model.jobs?.session,
          cause: model.jobs?.sessionCauseText, moving: SessionSection.stripesMove(reduceMotion: reduceMotion, model: model))
          .cardRise(step: Order.session.rawValue)
        PreflightSection().cardRise(step: Order.preflight.rawValue)
        JobsSection().cardRise(step: Order.jobs.rawValue)
        SystemSection().cardRise(step: Order.system.rawValue)
      }

      SettingsCard(L10n.Settings.about) {
        SettingsRow(L10n.Settings.app, systemImage: Self.appSymbol, tone: .accent) {
          Text(verbatim: Bundle.main.object(forInfoDictionaryKey: Self.versionKey) as? String ?? Format.missing)
            .font(Tokens.Typography.bodyMono)
        }
        SettingsRow(L10n.Settings.contract, systemImage: Self.contractSymbol, tone: .info) {
          Text(L10n.Settings.contractVersion(Wire.apiVersion))
        }
      }
      .cardRise(step: Order.about.rawValue)
    }
    .scrollEdgeFades()
    .scrollContentBackground(.hidden)
    .background(TickrBackground())
    .listSectionSpacing(Tokens.Space.m)
    // The header row is the top: no extra form margin above it.
    .contentMargins(.top, 0, for: .scrollContent)
    .pushedScreen(L10n.Settings.title)
    .task(id: model.connection.url) { await model.followAccount() }
    .task(id: model.connection.url) { await model.followJobs() }
    .task(id: model.connection.url) { await model.refreshConfig() }
    .botControl(isPresented: $showControl)
    .alert(Text(L10n.Control.startTitle), isPresented: $confirmStart) {
      Button {
        Task {
          let reason = String(localized: L10n.Control.reason(String(localized: L10n.Control.startBot)))
          await model.startBot(confirmOwner: { await Biometrics.confirm(reason) })
        }
      } label: {
        Text(L10n.Control.startBot)
      }
      Button(role: .cancel) {} label: { Text(L10n.Common.cancel) }
    } message: {
      Text(L10n.Control.startWarning)
    }
    .onChange(of: model.canStartBot) { _, enabled in
      if !enabled { confirmStart = false }
    }
    .confirmationDialog(Text(Self.isPad ? L10n.SignIn.signOutIPad : L10n.SignIn.signOutIPhone),
      isPresented: $confirmSignOut, titleVisibility: .visible) {
      Button(role: .destructive) {
        Task { await model.signOut() }
      } label: {
        Text(L10n.SignIn.signOut)
      }
    } message: {
      Text(L10n.SignIn.signOutMessage)
    }
  }

  /// The bot as on the design: its state with what it holds and a Stop that opens bot control
  /// (where the stop is confirmed), the configuration file, then the trading gate and strategy.
  private func botCard(_ status: StatusV1) -> some View {
    SettingsCard(L10n.Settings.bot) {
      let running = status.botState == .running
      // The state as a row's title, in sentence case ("Running").
      SettingsRow(Text(verbatim: String(localized: status.botState.title).localizedCapitalized),
        systemImage: Self.stateSymbol, tone: running ? .profit : .neutral) {
        StatusPill(status.botState.title, tone: running ? .accent : .neutral,
          live: running && model.response?.stale == false, event: status.botState)
      } subtitle: {
        Text(status.positions.isEmpty ? L10n.Settings.holdsNothing : L10n.Settings.holds(status.positions.count))
      }
      // The design's command under the state: Stop bot (destructive; bot control confirms it) while
      // it runs, Start bot (primary; the Mac's launchd starts the bot job, preflight first) when
      // stopped.
      let tag = model.connection.demo ? Text(L10n.Control.demoTag) : nil
      if running && model.canCommand {
        Button { showControl = true } label: {
          Label { Text(L10n.Control.stopBot) } icon: { Image(systemName: BotControl.stopSymbol) }
        }
        .buttonStyle(.command(.destructive, tag: tag))
        .fixedSize(horizontal: false, vertical: true)
        .inFlight(model.inFlight == .stopBot ? Text(OperatorCommand.stopBot.inFlightTitle) : nil)
      } else if model.canStartBot && (status.botState == .stopped || model.response?.stale == true) {
        Button { confirmStart = true } label: {
          Label { Text(L10n.Control.startBot) } icon: { Image(systemName: Self.startSymbol) }
        }
        .buttonStyle(.command(.primary, tag: tag))
        .fixedSize(horizontal: false, vertical: true)
        .inFlight(model.botStarting ? Text(InFlightText.startBot) : nil)
      }
      NavigationLink {
        ConfigView()
      } label: {
        SettingsRow(L10n.Settings.configuration, systemImage: Self.configSymbol, tone: .neutral) {
          // Valid or not: a state with its word, as on both apps' Settings boards ("✓ VALID").
          if let config = model.config {
            if config.valid {
              StatusPill(L10n.Settings.configValid, systemImage: Symbols.passed, tone: .profit)
            } else {
              StatusPill(L10n.Settings.configInvalid, systemImage: Symbols.failed, tone: .loss)
            }
          }
        }
      }
      // As on the design the card holds the bot and its file; a closed trading gate is the one
      // exception, as it stops every entry (the open gate and the strategy are on Home and Lab).
      if !status.tradingGate.open {
        SettingsRow(L10n.Settings.gate, systemImage: Symbols.gateClosed, tone: EntryGate.closed.tone) {
          // The gate as a fact, the same badge as the Mac Overview's header (GATE CLOSED).
          Badge(L10n.Settings.gateClosed, tone: .warning)
        }
        InfoCaption(verbatim: ApiText.gate(status.tradingGate), tone: .warning)
      }
    }
  }

  /// The design's "Connection" (mockup v174, IOSSystem): who this phone is signed in as, the
  /// link's state, "Notifications · Off" while they are (board PushAsk: it opens the screen that
  /// asks, or the system's settings once the system was told no), and Sign Out (confirmed). A
  /// development address shows only the state.
  private var connectionCard: some View {
    SettingsCard(L10n.SignIn.connection) {
      if model.connection.signedIn {
        Text(signedInLine)
          .font(Tokens.Typography.subheadline)
          .foregroundStyle(Palette.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      SettingsRow(L10n.Settings.status, systemImage: Self.statusSymbol, tone: connectionState.tone) {
        StatusPill(connectionState.text, tone: connectionState.tone)
      }
      if model.connection.signedIn, notifications.state == .notAsked || notifications.state == .denied {
        Button { notifications.turnOn() } label: {
          SettingsRow(L10n.Notifications.row, systemImage: Self.notificationsSymbol, tone: .warning) {
            StatusPill(L10n.Notifications.off, tone: .warning)
          } subtitle: {
            Text(L10n.Notifications.rowLine)
          }
        }
      }
      if model.connection.signedIn {
        Button(role: .destructive) { confirmSignOut = true } label: {
          Label { Text(L10n.SignIn.signOut) } icon: { SettingsIcon(Self.signOutSymbol, tone: .loss) }
        }
      }
    }
    .task { await notifications.refresh() }
  }

  /// Whether this is an iPad (the texts name the device).
  private static var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

  private var signedInLine: LocalizedStringResource {
    guard let email = signIn.email else { return L10n.SignIn.signedInNoEmail }
    return Self.isPad ? L10n.SignIn.signedInIPad(email) : L10n.SignIn.signedInIPhone(email)
  }

  private var connectionState: (text: LocalizedStringResource, tone: Tone) {
    if !model.isConfigured { return (L10n.Settings.notReachable, .warning) }
    if model.fetchError != nil { return (L10n.Settings.notReachable, .loss) }
    if model.response == nil { return (L10n.Settings.connecting, .neutral) }
    // Off by the schedule (mockup v190, page p-off): the API answers and the bot's silence is expected.
    if model.botRun?.calm == true { return (L10n.Settings.connected, .profit) }
    if model.status == nil || model.response?.stale == true { return (L10n.Settings.notCurrent, .warning) }
    return (L10n.Settings.connected, .profit)
  }
}
