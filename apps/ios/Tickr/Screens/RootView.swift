import SwiftUI
import TickrKit

/// Five tabs, ordered by use during a trading day. Settings live behind the gear on Home.
struct RootView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    @Bindable var model = model
    // The design's own tab bar (`TickrTabBar`) sits under each tab's screen; the system bar is
    // hidden on every screen of every tab.
    GeometryReader { proxy in
      TabView(selection: $model.selectedTab) {
        ForEach(AppTab.ordered, id: \.self) { tab in
          Tab(value: tab) {
            NavigationStack { screen(tab) }
              .toolbarVisibility(.hidden, for: .tabBar)
          } label: {
            // The system bar is hidden: its label only names the tab.
            Text(tab.title)
          }
        }
      }
      .environment(\.screenBottomInset, proxy.safeAreaInsets.bottom)
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
  }

  @ViewBuilder
  private func screen(_ tab: AppTab) -> some View {
    switch tab {
    case .home: HomeView()
    case .positions: PositionsView()
    case .chart: ChartTab()
    case .activity: ActivityView()
    case .lab: LabView()
    }
  }
}
