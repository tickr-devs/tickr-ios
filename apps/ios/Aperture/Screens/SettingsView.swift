import ApertureKit
import SwiftUI

/// Settings, behind the gear on Home: where the bot is, what the bot reports about itself, and
/// what this phone does. A standard grouped form, as iOS settings are.
struct SettingsView: View {
  @Environment(AppModel.self) private var model
  @State private var draft = ""
  @FocusState private var editing: Bool

  var body: some View {
    Form {
      Section {
        TextField("http://127.0.0.1:8766", text: $draft)
          .keyboardType(.URL)
          .textContentType(.URL)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .focused($editing)
          .submitLabel(.done)
          .onSubmit(save)
          .font(.body.monospaced())
        if draft != model.connection.address {
          Button("Save Address", action: save)
            .disabled(!draft.isEmpty && Connection(address: draft).url == nil)
        }
        LabeledContent("Status") {
          Text(connectionState.text).foregroundStyle(connectionState.color)
        }
      } header: {
        Text("Bot on your Mac")
      } footer: {
        Text("The address of the bot's local API. In the Simulator the Mac's own address works. "
          + "On the phone, use the HTTPS address that Tailscale gives the Mac (see apps/ios/README.md).")
      }

      if let status = model.status {
        Section("Bot") {
          LabeledContent("State", value: status.botState.rawValue)
          LabeledContent("Environment", value: status.environment)
          LabeledContent("Trading gate") {
            Text(status.tradingGate.open ? "open" : "closed")
          }
          if !status.tradingGate.open {
            Text(status.tradingGate.cause).font(.footnote).foregroundStyle(.secondary)
          }
          LabeledContent("Strategy", value: "\(status.strategy.name) v\(status.strategy.version)")
          if let runId = status.runId {
            LabeledContent("Run", value: runId).font(.body.monospaced())
          }
        }
      }

      Section {
        LabeledContent("Lock-screen alerts", value: "Not yet")
      } header: {
        Text("Notifications")
      } footer: {
        Text("Alerts for stops, fills, paused entries and broker mismatches arrive when push notifications "
          + "are set up. Environment and limits are set in the bot's config on the Mac; the phone only shows them.")
      }

      Section("About") {
        LabeledContent("App", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
        LabeledContent("API contract", value: "v\(Wire.apiVersion)")
      }
    }
    .navigationTitle("Settings")
    .onAppear { draft = model.connection.address }
  }

  private func save() {
    guard draft.isEmpty || Connection(address: draft).url != nil else { return }
    model.connection = Connection(address: draft)
    editing = false
  }

  private var connectionState: (text: String, color: Color) {
    if !model.isConfigured { return ("No address", .secondary) }
    if model.fetchError != nil { return ("Not reachable", .red) }
    if model.response == nil { return ("Connecting…", .secondary) }
    if model.status == nil || model.response?.stale == true { return ("Reached, status not current", .orange) }
    return ("Connected", .green)
  }
}
