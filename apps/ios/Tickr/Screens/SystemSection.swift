import SwiftUI
import TickrDesign
import TickrKit

/// The design's "System" card in Settings (GET /system, mockup v120): the shared `SystemPanel`
/// in this app's settings card, with the summary pill beside its title.
struct SystemSection: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    SettingsCard(SystemText.title) {
      if let system = model.system { SystemPill(system) }
    } content: {
      if let system = model.system {
        SystemPanel(system, now: model.botNow)
      } else if let error = model.systemError {
        ReadFailureNote(SystemText.readFailed, detail: error)
      } else {
        SystemPanelLoading()
      }
    }
  }
}
