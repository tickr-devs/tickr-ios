import SwiftUI
import TickrDesign
import TickrKit
import TickrScreens

/// Which screens the app shows (mockup v156, approved 2026-11-25): an iPad in regular width shows
/// the Mac screens (`RegularScreens`); compact width (iPad Slide Over and a third of the screen)
/// and every iPhone show the iPhone screens. An iPhone in landscape can be regular width too (Pro
/// Max), and it keeps its own landscape layout, so the idiom decides first.
enum ScreenLayout: Equatable {
  case compact, regular

  /// The layout for a device of `idiom` at `width`; the Mac screens also need a connection to
  /// show (the iPhone screens hold the pairing that makes one).
  static func pick(idiom: UIUserInterfaceIdiom, width: UserInterfaceSizeClass?, configured: Bool) -> ScreenLayout {
    idiom == .pad && width == .regular && configured ? .regular : .compact
  }
}

/// The app's root: the iPhone screens or the Mac screens by `ScreenLayout`, with what both need
/// (pairing links, notices). Only the layout shown reads the bot, and only while the app is in
/// front: the bot never depends on the phone or the iPad.
struct AdaptiveRoot: View {
  @Environment(AppModel.self) private var model
  @Environment(\.horizontalSizeClass) private var width
  @Environment(\.scenePhase) private var scenePhase
  @State private var showsSettings = false
  /// The Mac screens' section, kept while the iPhone screens show so that a round trip (fold and
  /// unfold) returns to it, unless a tab was picked meanwhile.
  @State private var section: AppSection = .overview
  /// The Mac screens' chart symbol; the iPhone screens keep theirs in the model.
  @AppStorage(RegularScreens.chartSymbolKey) private var regularSymbol = ""

  private var layout: ScreenLayout {
    ScreenLayout.pick(idiom: UIDevice.current.userInterfaceIdiom, width: width, configured: model.connection.url != nil)
  }

  var body: some View {
    let layout = layout
    let active = scenePhase == .active
    Group {
      switch layout {
      case .compact:
        RootView()
      case .regular:
        if let url = model.connection.url {
          RegularScreens(
            endpoint: model.connection.endpoint(for: url), section: $section, active: active,
            ownerCheck: { command, title in await Self.confirmOwner(command, title: title) },
            settings: { showsSettings = true })
          .sheet(isPresented: $showsSettings) {
            NavigationStack { SettingsView() }
          }
        }
      }
    }
    .modifier(NoticeOverlay())
    .onOpenURL { url in
      if let pairing = Pairing.parse(url.absoluteString) {
        model.pendingPairing = pairing
      } else {
        model.notice = Notice(L10n.Pair.notALink, tone: .failure)
      }
    }
    .alert(
      Text(L10n.Pair.ask(
        model.pendingPairing.flatMap { Connection.displayHost($0.url) } ?? String(localized: L10n.Pair.thisMac))),
      isPresented: Binding(get: { model.pendingPairing != nil }, set: { if !$0 { model.pendingPairing = nil } }),
      presenting: model.pendingPairing
    ) { pairing in
      Button { Task { await model.pair(pairing) } } label: { Text(L10n.Pair.pair) }
      Button(role: .cancel) {} label: { Text(L10n.Common.cancel) }
    } message: { _ in
      Text(L10n.Pair.askMessage)
    }
    // The iPhone screens' model reads the bot only while they are shown and the app is in front
    // (`RegularScreens` does the same for its own).
    // One screen across the two layouts: folding or unfolding a Duo, or resizing an iPad window,
    // keeps the section and the chart's symbol shown.
    .onChange(of: layout, initial: true) { _, new in
      switch new {
      case .regular:
        if AppTab(section) != model.selectedTab { section = AppSection(model.selectedTab) }
        if let symbol = model.selectedSymbol { regularSymbol = symbol }
      case .compact:
        if AppSection(model.selectedTab) != section { model.selectedTab = AppTab(section) }
        if !regularSymbol.isEmpty { model.selectedSymbol = regularSymbol }
      }
    }
    .onChange(of: active && layout == .compact, initial: true) { _, on in
      if on { model.start() } else { model.stop() }
    }
  }

  /// Face ID or the passcode before a command from the Mac screens, as the iPhone screens ask it
  /// (`BotControl.needsOwner`): every command but pausing entries, and starting the bot (`nil`).
  static func confirmOwner(_ command: OperatorCommand?, title: String) async -> Bool {
    if let command, !BotControl.needsOwner(command) { return true }
    return await Biometrics.confirm(String(localized: L10n.Control.reason(title))) == .confirmed
  }
}

/// The Mac screens' section for an iPhone tab: positions live on the Overview.
extension AppSection {
  init(_ tab: AppTab) {
    switch tab {
    case .home, .positions: self = .overview
    case .chart: self = .chart
    case .activity: self = .trades
    case .lab: self = .lab
    }
  }
}

/// The iPhone tab for a Mac screens' section: risk and account live on Home.
extension AppTab {
  init(_ section: AppSection) {
    switch section {
    case .overview, .risk: self = .home
    case .chart: self = .chart
    case .trades: self = .activity
    case .lab: self = .lab
    }
  }
}
