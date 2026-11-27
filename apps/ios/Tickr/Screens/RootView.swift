import SwiftUI
import TickrKit

/// Five tabs, ordered by use during a trading day. Settings live behind the gear on Home.
struct RootView: View {
  @Environment(AppModel.self) private var model

  /// The iPhone screens (compact width); pairing links and notices are the app root's
  /// (`AdaptiveRoot`).
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
