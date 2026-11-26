#if os(iOS)
import SwiftUI
import TickrDesign
import TickrKit

/// The Mac screens on an iPad in regular width (mockup v156, boards IPadLandscape, IPadPortrait
/// and IPadSplit): the Mac sidebar and screens in a `NavigationSplitView`, and in the navigation
/// bar the connection status, the day, the bot's power button and the gear. Touch, not a
/// pointer: no title-bar line, no window sizes (the screens scroll in the room they get).
///
/// The iOS app shows it in regular width and its iPhone screens in compact width. It owns the
/// connection (address, token, demo day) and gives it here as `endpoint`; the model follows each
/// change. Only the layout on screen reads the bot: `active` starts and stops this model.
public struct RegularScreens: View {
  @State private var model = Container.shared.appModel()
  @State private var chart = Container.shared.chartModel()
  /// Whether the sidebar shows; the system's sidebar button switches it.
  @State private var columns = NavigationSplitViewVisibility.all
  /// Whether this model is reading the bot now (`active`); never started twice.
  @State private var polling = false

  let endpoint: APIClient.Endpoint
  let active: Bool
  let ownerCheck: @MainActor (OperatorCommand?, String) async -> Bool
  let settings: () -> Void

  /// - Parameters:
  ///   - endpoint: the iPad's connection: where to read and send, with its token.
  ///   - active: the scene is in front and this layout is the one shown.
  ///   - ownerCheck: Face ID or the passcode before a command (`AppModel.ownerCheck`).
  ///   - settings: opens the iPad's settings.
  public init(
    endpoint: APIClient.Endpoint, active: Bool,
    ownerCheck: @escaping @MainActor (OperatorCommand?, String) async -> Bool,
    settings: @escaping () -> Void
  ) {
    self.endpoint = endpoint
    self.active = active
    self.ownerCheck = ownerCheck
    self.settings = settings
  }

  public var body: some View {
    @Bindable var model = model
    NavigationSplitView(columnVisibility: $columns) {
      Sidebar(selection: $model.section)
        .navigationSplitViewColumnWidth(min: RootView.sidebarMin, ideal: RootView.sidebarIdeal, max: RootView.sidebarMax)
    } detail: {
      ScreenColumn()
        .navigationTitle(Text(model.section.title))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { RegularToolbar(settings: settings) }
    }
    .botCommandQuestions(in: .window)
    .hintHost()
    .readFailureContext(model)
    .environment(model)
    .environment(chart)
    .tint(Palette.info)
    .onAppear {
      // No launch opening here (the iPhone screens' own plays at launch): the cards rise at once.
      model.openingPlayed = true
      model.ownerCheck = ownerCheck
    }
    .onChange(of: endpoint, initial: true) { _, new in model.connect(to: new) }
    .onChange(of: active, initial: true) { _, on in poll(on) }
    .onDisappear { poll(false) }
  }

  private func poll(_ on: Bool) {
    guard on != polling else { return }
    polling = on
    if on { model.start() } else { model.stop() }
  }
}

/// The navigation bar's items on iPad, trailing: how old the status is, the day, the bot's power
/// button and the gear, each at least a touch target large.
private struct RegularToolbar: ToolbarContent {
  let settings: () -> Void

  var body: some ToolbarContent {
    ToolbarItem(placement: .topBarTrailing) { ConnectionStatus() }
      .sharedBackgroundVisibility(.hidden)
    ToolbarItem(placement: .topBarTrailing) { DayControls() }
      .sharedBackgroundVisibility(.hidden)
    ToolbarItem(placement: .topBarTrailing) { PowerButton() }
    ToolbarItem(placement: .topBarTrailing) {
      Button(action: settings) {
        Label { Text(L10n.Toolbar.settings) } icon: { Image(systemName: PowerButton.settingsSymbol) }
      }
    }
  }
}

/// Starts the bot when it is stopped, or asks to stop it while it runs (the same question as
/// Overview's Stop bot); dimmed when neither can be done now, and while a start is on its way.
private struct PowerButton: View {
  @Environment(AppModel.self) private var model

  /// SF Symbol of the power button.
  static let powerSymbol = "power"
  /// SF Symbol of the gear that opens the iPad's settings.
  static let settingsSymbol = "gearshape"

  var body: some View {
    Button {
      if model.canStopBot {
        model.press(.stopBot, in: .window)
      } else if model.canStartBot {
        Task { await model.startBot() }
      }
    } label: {
      Label {
        Text(model.canStopBot ? L10n.Settings.stopBotAction : L10n.Settings.startBotAction)
      } icon: {
        Image(systemName: Self.powerSymbol)
      }
    }
    .tint(model.canStopBot ? Palette.profitText : Palette.textTertiary)
    .disabled(!model.canStopBot && !model.canStartBot)
  }
}
#endif
