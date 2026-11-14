import SwiftUI

/// Five tabs, ordered by use during a trading day. Settings live behind the gear on Home.
struct RootView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    @Bindable var model = model
    TabView(selection: $model.selectedTab) {
      NavigationStack { HomeView() }
        .tabItem { Label { Text(L10n.App.home) } icon: { Image(systemName: "square.grid.2x2") } }
        .tag(AppTab.home)
      NavigationStack { PositionsView() }
        .tabItem { Label { Text(L10n.App.positions) } icon: { Image(systemName: "lock.shield") } }
        .tag(AppTab.positions)
      NavigationStack { ChartTab() }
        .tabItem { Label { Text(L10n.App.chart) } icon: { Image(systemName: "chart.xyaxis.line") } }
        .tag(AppTab.chart)
      NavigationStack { ActivityView() }
        .tabItem { Label { Text(L10n.App.activity) } icon: { Image(systemName: "list.bullet.rectangle") } }
        .tag(AppTab.activity)
      NavigationStack { LabView() }
        .tabItem { Label { Text(L10n.App.lab) } icon: { Image(systemName: "sparkles") } }
        .tag(AppTab.lab)
    }
    .modifier(NoticeOverlay())
  }
}
