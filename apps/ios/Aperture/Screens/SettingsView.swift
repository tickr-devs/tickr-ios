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
      } header: {
        Text(L10n.Settings.botOnMac)
      } footer: {
        Text(L10n.Settings.addressFooter)
      }

      if let status = model.status {
        Section {
          row(L10n.Settings.state) { Text(status.botState.title) }
          row(L10n.Settings.environment) { Text(verbatim: status.environment) }
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
  }

  private func row<Value: View>(_ label: LocalizedStringResource, @ViewBuilder value: () -> Value) -> some View {
    LabeledContent {
      value()
    } label: {
      Text(label)
    }
  }

  private func save() {
    guard draft.isEmpty || Connection(address: draft).url != nil else { return }
    model.connection = Connection(address: draft)
    editing = false
  }

  private var connectionState: (text: LocalizedStringResource, color: Color) {
    if !model.isConfigured { return (L10n.Settings.noAddress, .secondary) }
    if model.fetchError != nil { return (L10n.Settings.notReachable, Palette.lossText) }
    if model.response == nil { return (L10n.Settings.connecting, .secondary) }
    if model.status == nil || model.response?.stale == true { return (L10n.Settings.notCurrent, Palette.warningText) }
    return (L10n.Settings.connected, Palette.profitText)
  }
}
