import ApertureDesign
import ApertureKit
import SwiftUI

/// Settings, behind the gear on Home: where the bot is, what the bot reports about itself, and
/// what this phone does. A standard grouped form, as iOS settings are.
struct SettingsView: View {
  /// Info.plist key of the app's marketing version.
  static let versionKey = "CFBundleShortVersionString"
  /// Symbols of the rows' icons.
  static let statusSymbol = "antenna.radiowaves.left.and.right"
  static let pairSymbol = "qrcode"
  static let forgetSymbol = "link.badge.minus"
  static let stateSymbol = "power"
  static let gateOpenSymbol = "lock.open.fill"
  static let gateClosedSymbol = "lock.fill"
  static let strategySymbol = "cpu"
  static let lockScreenSymbol = "bell.badge.fill"
  static let appSymbol = "app.fill"
  static let contractSymbol = "doc.text.fill"

  @Environment(AppModel.self) private var model
  @State private var draft = ""
  @FocusState private var editing: Bool
  @State private var showPairing = false
  @State private var confirmForget = false

  var body: some View {
    Form {
      Section {
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
      } header: {
        Text(L10n.Settings.botOnMac)
      } footer: {
        Text(L10n.Settings.addressFooter)
      }

      if let status = model.status {
        Section {
          let running = status.botState == .running
          SettingsRow(L10n.Settings.state, systemImage: Self.stateSymbol, tone: running ? .accent : .neutral) {
            StatusPill(status.botState.title, tone: running ? .accent : .neutral,
              live: running && model.response?.stale == false, event: status.botState)
          }
          let open = status.tradingGate.open
          SettingsRow(L10n.Settings.gate, systemImage: open ? Self.gateOpenSymbol : Self.gateClosedSymbol,
            tone: open ? .profit : .warning) {
            StatusPill(open ? L10n.Settings.gateOpen : L10n.Settings.gateClosed, tone: open ? .profit : .warning)
          }
          if !open {
            InfoCaption(verbatim: ApiText.gate(status.tradingGate), tone: .warning)
          }
          SettingsRow(L10n.Settings.strategy, systemImage: Self.strategySymbol, tone: .highlight) {
            Badge(L10n.Common.strategyVersion(status.strategy.name, status.strategy.version), tone: .highlight)
          }
        } header: {
          Text(L10n.Settings.bot)
        }
      }

      if let status = model.status {
        EnvironmentSection(status: status)
      }
      if model.isConfigured {
        PreflightSection()
        SessionSection(session: model.settings?.session)
        JobsSection()
      }

      Section {
        SettingsRow(L10n.Settings.lockScreen, systemImage: Self.lockScreenSymbol, tone: .warning) {
          Badge(L10n.Settings.notYet, tone: .highlight, planned: true)
        }
      } header: {
        Text(L10n.Settings.notifications)
      } footer: {
        Text(L10n.Settings.notificationsFooter)
      }

      Section {
        SettingsRow(L10n.Settings.app, systemImage: Self.appSymbol, tone: .accent) {
          Text(verbatim: Bundle.main.object(forInfoDictionaryKey: Self.versionKey) as? String ?? Format.missing)
            .font(.body.monospaced())
        }
        SettingsRow(L10n.Settings.contract, systemImage: Self.contractSymbol, tone: .info) {
          Text(L10n.Settings.contractVersion(Wire.apiVersion))
        }
      } header: {
        Text(L10n.Settings.about)
      }
    }
    .navigationTitle(Text(L10n.Settings.title))
    .onAppear { draft = model.connection.address }
    .task(id: model.connection.url) { await model.followAccount() }
    .task(id: model.connection.url) { await model.followJobs() }
    .onChange(of: model.connection.address) { _, address in draft = address }
    .sheet(isPresented: $showPairing) { PairingSheet() }
    .confirmationDialog(Text(L10n.Pair.forgetTitle), isPresented: $confirmForget, titleVisibility: .visible) {
      Button(role: .destructive) {
        model.connection = Connection(address: model.connection.address)
      } label: {
        Text(L10n.Pair.forget)
      }
    } message: {
      Text(L10n.Pair.forgetMessage)
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
            if let pairing { model.pair(pairing) }
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
