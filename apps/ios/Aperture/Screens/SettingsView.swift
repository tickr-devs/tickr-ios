import ApertureDesign
import ApertureKit
import SwiftUI

/// Settings, behind the gear on Home: where the bot is, what the bot reports about itself, and
/// what this phone does. A standard grouped form, as iOS settings are.
struct SettingsView: View {
  /// Info.plist key of the app's marketing version.
  static let versionKey = "CFBundleShortVersionString"

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
        LabeledContent {
          Text(connectionState.text).foregroundStyle(connectionState.color)
        } label: {
          Text(L10n.Settings.status)
        }
        Button { showPairing = true } label: { Text(L10n.Pair.start) }
        if model.connection.token != nil {
          Button(role: .destructive) { confirmForget = true } label: { Text(L10n.Pair.forget) }
        }
      } header: {
        Text(L10n.Settings.botOnMac)
      } footer: {
        Text(L10n.Settings.addressFooter)
      }

      if let status = model.status {
        Section {
          row(L10n.Settings.state) { Text(status.botState.title) }
          row(L10n.Settings.gate) {
            Text(status.tradingGate.open ? L10n.Settings.gateOpen : L10n.Settings.gateClosed)
          }
          if !status.tradingGate.open {
            Text(verbatim: status.tradingGate.cause).font(.footnote).foregroundStyle(.secondary)
          }
          row(L10n.Settings.strategy) {
            Text(L10n.Common.strategyVersion(status.strategy.name, status.strategy.version))
          }
          if let runId = status.runId {
            row(L10n.Settings.run) { Text(verbatim: runId) }.font(.body.monospaced())
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
      }

      Section {
        row(L10n.Settings.lockScreen) { Text(L10n.Settings.notYet) }
      } header: {
        Text(L10n.Settings.notifications)
      } footer: {
        Text(L10n.Settings.notificationsFooter)
      }

      Section {
        row(L10n.Settings.app) {
          Text(verbatim: Bundle.main.object(forInfoDictionaryKey: Self.versionKey) as? String ?? Format.missing)
        }
        row(L10n.Settings.contract) { Text(L10n.Settings.contractVersion(Wire.apiVersion)) }
      } header: {
        Text(L10n.Settings.about)
      }
    }
    .navigationTitle(Text(L10n.Settings.title))
    .onAppear { draft = model.connection.address }
    .task(id: model.connection.url) { await followAccount() }
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

  private func row<Value: View>(_ label: LocalizedStringResource, @ViewBuilder value: () -> Value) -> some View {
    LabeledContent {
      value()
    } label: {
      Text(label)
    }
  }

  /// While Settings is on screen, read the bot's last broker read as often as its status.
  private func followAccount() async {
    while !Task.isCancelled {
      await model.refreshAccount()
      let seconds = model.response.map { NSDecimalNumber(decimal: $0.pollSeconds.value).doubleValue }
        ?? AppModel.initialPollSeconds
      try? await Task.sleep(for: .seconds(max(seconds, AppModel.minimumPollSeconds)))
    }
  }

  /// Saves the typed address; the paired token stays only while the address keeps the paired origin.
  private func save() {
    guard draft.isEmpty || Connection(address: draft).url != nil else { return }
    model.connection = model.connection.moved(to: draft)
    editing = false
  }

  private var connectionState: (text: LocalizedStringResource, color: Color) {
    if !model.isConfigured { return (L10n.Settings.noAddress, .secondary) }
    if model.connection.isRemote && model.connection.bearer == nil { return (L10n.Pair.notPaired, Palette.warningText) }
    if model.fetchError != nil { return (L10n.Settings.notReachable, Palette.lossText) }
    if model.response == nil { return (L10n.Settings.connecting, .secondary) }
    if model.status == nil || model.response?.stale == true { return (L10n.Settings.notCurrent, Palette.warningText) }
    return (L10n.Settings.connected, Palette.profitText)
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
