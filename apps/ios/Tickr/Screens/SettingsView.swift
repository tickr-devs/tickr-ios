import SwiftUI
import TickrDesign
import TickrKit

/// Settings, behind the gear on Home: what the bot reports about itself, what this phone does, and
/// where the bot is. A grouped form whose sections are the design's cards, with no tab bar.
struct SettingsView: View {
  /// Info.plist key of the app's marketing version.
  static let versionKey = "CFBundleShortVersionString"
  /// Symbols of the rows' icons.
  static let statusSymbol = "antenna.radiowaves.left.and.right"
  static let pairSymbol = "qrcode"
  static let forgetSymbol = "minus.circle"
  static let stateSymbol = "power"
  static let gateClosedSymbol = "lock.fill"
  static let configSymbol = "doc.plaintext.fill"
  static let lockScreenSymbol = "bell.badge.fill"
  static let appSymbol = "app.fill"
  static let contractSymbol = "doc.text.fill"
  static let demoSymbol = "theatermasks.fill"
  /// Accessibility id of the demo day switch, for the UI tests.
  static let demoDayID = "settings-demo-day"

  /// Order in which the cards rise in (`cardRise(step:)`), as on the design.
  private enum Order: Int {
    case connection = 1, bot, demo, notifications, environment, session, preflight, jobs, about
  }

  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var draft = ""
  @FocusState private var editing: Bool
  @State private var showPairing = false
  @State private var confirmForget = false
  @State private var showControl = false
  @State private var confirmStart = false

  var body: some View {
    Form {
      Section {
        PushedHeader(title: L10n.Settings.title, back: L10n.App.home, action: dismiss)
      }
      .listRowBackground(Color.clear)
      .listRowInsets(EdgeInsets())
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

      SettingsCard(L10n.Settings.notifications, note: L10n.Settings.notificationsFooter) {
        SettingsRow(L10n.Settings.lockScreen, systemImage: Self.lockScreenSymbol, tone: .warning) {
          Badge(L10n.Settings.notYet, tone: .highlight, planned: true)
        }
      }
      .cardRise(step: Order.notifications.rawValue)

      if let status = model.status {
        EnvironmentSection(status: status).cardRise(step: Order.environment.rawValue)
      }
      if model.isConfigured {
        SessionSection(session: model.settings?.session,
          moving: SessionSection.stripesMove(reduceMotion: reduceMotion, model: model))
          .cardRise(step: Order.session.rawValue)
        PreflightSection().cardRise(step: Order.preflight.rawValue)
        JobsSection().cardRise(step: Order.jobs.rawValue)
      }

      SettingsCard(L10n.Settings.about) {
        SettingsRow(L10n.Settings.app, systemImage: Self.appSymbol, tone: .accent) {
          Text(verbatim: Bundle.main.object(forInfoDictionaryKey: Self.versionKey) as? String ?? Format.missing)
            .font(.body.monospaced())
        }
        SettingsRow(L10n.Settings.contract, systemImage: Self.contractSymbol, tone: .info) {
          Text(L10n.Settings.contractVersion(Wire.apiVersion))
        }
      }
      .cardRise(step: Order.about.rawValue)
    }
    .scrollContentBackground(.hidden)
    .background(TickrBackground())
    .listSectionSpacing(Tokens.Space.m)
    // The header row is the top: no extra form margin above it.
    .contentMargins(.top, 0, for: .scrollContent)
    .pushedScreen(L10n.Settings.title)
    .onAppear { draft = model.connection.address }
    .task(id: model.connection.url) { await model.followAccount() }
    .task(id: model.connection.url) { await model.followJobs() }
    .task(id: model.connection.url) { await model.refreshConfig() }
    .onChange(of: model.connection.address) { _, address in draft = address }
    .botControl(isPresented: $showControl)
    .sheet(isPresented: $showPairing) { PairingSheet() }
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
    .confirmationDialog(Text(L10n.Pair.forgetTitle), isPresented: $confirmForget, titleVisibility: .visible) {
      Button(role: .destructive) {
        model.connection = Connection(address: model.connection.address, demo: model.connection.demo)
      } label: {
        Text(L10n.Pair.forget)
      }
    } message: {
      Text(L10n.Pair.forgetMessage)
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
        if running && model.canCommand {
          Button { showControl = true } label: {
            Text(L10n.Settings.stop)
              .font(Tokens.Typography.buttonCompact)
              .foregroundStyle(Palette.lossText)
              .padding(.horizontal, Tokens.Space.m)
              .padding(.vertical, Tokens.Space.xs)
              .background(Palette.loss.opacity(Tokens.Opacity.wash), in: Capsule())
          }
          .buttonStyle(.borderless)
        } else if model.canStartBot && (status.botState == .stopped || model.response?.stale == true) {
          // Start as the design's green pill: the Mac's launchd starts the bot job, preflight first.
          Button { confirmStart = true } label: {
            Text(L10n.Settings.start)
              .font(Tokens.Typography.buttonCompact)
              .foregroundStyle(Palette.onAccent)
              .padding(.horizontal, Tokens.Space.m)
              .padding(.vertical, Tokens.Space.xs)
              .background(Palette.profit, in: Capsule())
          }
          .buttonStyle(.borderless)
        } else {
          StatusPill(status.botState.title, tone: running ? .accent : .neutral,
            live: running && model.response?.stale == false, event: status.botState)
        }
      } subtitle: {
        Text(status.positions.isEmpty ? L10n.Settings.holdsNothing : L10n.Settings.holds(status.positions.count))
      }
      NavigationLink {
        ConfigView()
      } label: {
        SettingsRow(L10n.Settings.configuration, systemImage: Self.configSymbol, tone: .neutral) {
          if let config = model.config {
            if config.valid {
              Badge(L10n.Settings.configValid, tone: .profit)
            } else {
              Badge(L10n.Settings.configInvalid, tone: .loss)
            }
          }
        }
      }
      // As on the design the card holds the bot and its file; a closed trading gate is the one
      // exception, as it stops every entry (the open gate and the strategy are on Home and Lab).
      if !status.tradingGate.open {
        SettingsRow(L10n.Settings.gate, systemImage: Self.gateClosedSymbol, tone: .warning) {
          // One pulse each time the closed gate changes (its cause), still in between.
          StatusPill(Text(L10n.Settings.gateClosed), tone: .warning, live: true, event: Self.gateEvent(status))
        }
        InfoCaption(verbatim: ApiText.gate(status.tradingGate), tone: .warning)
      }
    }
  }

  /// What the closed gate's dot pulses on: the gate itself, so a new cause (or the gate closing
  /// again) pulses once; nil while it is open, when the row is not shown.
  static func gateEvent(_ status: StatusV1) -> Gate? {
    status.tradingGate.open ? nil : status.tradingGate
  }

  /// Where the bot is: the address, the connection's state, pairing.
  private var connectionCard: some View {
    SettingsCard(L10n.Settings.botOnMac, note: L10n.Settings.addressFooter) {
      TextField(text: $draft, prompt: Text(verbatim: Connection.simulatorAddress)) {
        Text(L10n.Settings.botOnMac)
      }
      .keyboardType(.URL)
      .textContentType(.URL)
      .textInputAutocapitalization(.never)
      .autocorrectionDisabled()
      .focused($editing)
      .submitLabel(.done)
      .onSubmit(save)
      .font(.body.monospaced())
      if draft != model.connection.address {
        Button(action: save) { Text(L10n.Settings.saveAddress) }
          .disabled(!draft.isEmpty && Connection(address: draft).url == nil)
      }
      SettingsRow(L10n.Settings.status, systemImage: Self.statusSymbol, tone: connectionState.tone) {
        StatusPill(connectionState.text, tone: connectionState.tone)
      }
      Button { showPairing = true } label: {
        Label { Text(L10n.Pair.start) } icon: { SettingsIcon(Self.pairSymbol, tone: .info) }
      }
      if model.connection.token != nil {
        Button(role: .destructive) { confirmForget = true } label: {
          Label { Text(L10n.Pair.forget) } icon: { SettingsIcon(Self.forgetSymbol, tone: .loss) }
        }
      }
    }
  }

  /// Saves the typed address; the paired token stays only while the address keeps the paired origin.
  private func save() {
    guard draft.isEmpty || Connection(address: draft).url != nil else { return }
    model.connection = model.connection.moved(to: draft)
    editing = false
  }

  private var connectionState: (text: LocalizedStringResource, tone: Tone) {
    if !model.isConfigured { return (L10n.Settings.noAddress, .neutral) }
    if model.connection.isRemote && model.connection.bearer == nil { return (L10n.Pair.notPaired, .warning) }
    if model.fetchError != nil { return (L10n.Settings.notReachable, .loss) }
    if model.response == nil { return (L10n.Settings.connecting, .neutral) }
    if model.status == nil || model.response?.stale == true { return (L10n.Settings.notCurrent, .warning) }
    return (L10n.Settings.connected, .profit)
  }
}

/// Paste the pairing link the Mac left in its pairing file. Opening the link on the phone works too.
private struct PairingSheet: View {
  /// Lines the pasted link may take before the field scrolls.
  static let linkLines = 3...6

  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @State private var text = ""

  var body: some View {
    let pairing = Pairing.parse(text)
    NavigationStack {
      Form {
        Section {
          TextField(text: $text, prompt: Text(L10n.Pair.prompt), axis: .vertical) {
            Text(L10n.Pair.title)
          }
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .font(.footnote.monospaced())
          .lineLimit(Self.linkLines)
          PasteButton(payloadType: String.self) { strings in
            if let first = strings.first { text = first }
          }
        } footer: {
          Text(L10n.Pair.sheetFooter)
        }
        if let pairing {
          Section {
            LabeledContent {
              Text(verbatim: Connection.displayHost(pairing.url) ?? Format.missing)
            } label: {
              Text(L10n.Pair.address)
            }
          } header: {
            Text(L10n.Pair.mac)
          }
        } else if !text.isEmpty {
          Section {
            Text(L10n.Pair.invalid).foregroundStyle(Palette.lossText)
          }
        }
      }
      .navigationTitle(Text(L10n.Pair.title))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button { dismiss() } label: { Text(L10n.Common.cancel) }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button {
            if let pairing { Task { await model.pair(pairing) } }
            dismiss()
          } label: {
            Text(L10n.Pair.pair)
          }
          .disabled(pairing == nil)
        }
      }
    }
  }
}
