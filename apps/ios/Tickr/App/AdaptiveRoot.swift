import SwiftUI
import TickrDesign
import TickrKit
import TickrScreens

/// Which screens the app shows (mockup v156, approved 2026-11-25): an iPad in regular width shows
/// the Mac screens (`RegularScreens`); compact width (iPad Slide Over and a third of the screen)
/// shows the iPhone screens. An iPhone in landscape can be regular width too (Pro Max) and keeps
/// its own landscape layout; only the unfolded iPhone Duo in landscape, wider than any iPhone that
/// does not fold, shows the Mac screens (sidebar and content, the IOSDuo board). Folded, or
/// unfolded and upright, the Duo is compact width and shows the iPhone screens.
enum ScreenLayout: Equatable {
  case compact, regular

  /// Width of the widest iPhone that does not fold, in points: a Pro Max in landscape (440 × 956,
  /// iPhone 16 Pro Max and later). Apple has not published the Duo's sizes; its inner screen
  /// (7.6", the outer one's aspect ratio) is wider than this in landscape, and nothing else with
  /// the phone idiom is. Read by `pick`.
  static let widestPhone: CGFloat = 956

  /// The layout for a device of `idiom` in a window `windowWidth` points wide, of size class
  /// `width`; the Mac screens also need a connection to show (the iPhone screens hold the pairing
  /// that makes one).
  static func pick(
    idiom: UIUserInterfaceIdiom, width: UserInterfaceSizeClass?, windowWidth: CGFloat, configured: Bool
  ) -> ScreenLayout {
    guard width == .regular, configured else { return .compact }
    switch idiom {
    case .pad: return .regular
    case .phone: return windowWidth > widestPhone ? .regular : .compact
    default: return .compact
    }
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
  /// The window's width, which tells an unfolded iPhone Duo in landscape from a Pro Max.
  @State private var windowWidth: CGFloat = 0

  private var layout: ScreenLayout {
    ScreenLayout.pick(idiom: UIDevice.current.userInterfaceIdiom, width: width, windowWidth: windowWidth,
      configured: model.connection.url != nil)
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
            endpoint: model.connection.endpoint(for: url), active: active,
            ownerCheck: { command, title in await Self.confirmOwner(command, title: title) },
            settings: { showsSettings = true })
          .sheet(isPresented: $showsSettings) {
            NavigationStack { SettingsView() }
          }
        }
      }
    }
    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { windowWidth = $0 }
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
