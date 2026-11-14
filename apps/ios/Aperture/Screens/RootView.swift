import SwiftUI

/// Five tabs, ordered by use during a trading day. Settings live behind the gear on Home.
struct RootView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    @Bindable var model = model
    TabView(selection: $model.selectedTab) {
      NavigationStack { HomeView() }
        .tabItem { Label("Home", systemImage: "square.grid.2x2") }
        .tag(AppTab.home)
      NavigationStack { PositionsView() }
        .tabItem { Label("Positions", systemImage: "lock.shield") }
        .tag(AppTab.positions)
      NavigationStack { ChartTab() }
        .tabItem { Label("Chart", systemImage: "chart.xyaxis.line") }
        .tag(AppTab.chart)
      NavigationStack { ActivityView() }
        .tabItem { Label("Activity", systemImage: "list.bullet.rectangle") }
        .tag(AppTab.activity)
      NavigationStack { LabView() }
        .tabItem { Label("Lab", systemImage: "sparkles") }
        .tag(AppTab.lab)
    }
    .modifier(NoticeOverlay())
  }
}
