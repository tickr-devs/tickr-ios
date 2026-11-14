import ApertureKit
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
    .onOpenURL { url in
      if let pairing = Pairing.parse(url.absoluteString) {
        model.pendingPairing = pairing
      } else {
        model.notice = Notice(L10n.Pair.notALink, tone: .failure)
      }
    }
    .alert(
      Text(L10n.Pair.ask(model.pendingPairing.flatMap { Connection.displayHost($0.url) } ?? String(localized: L10n.Pair.thisMac))),
      isPresented: Binding(get: { model.pendingPairing != nil }, set: { if !$0 { model.pendingPairing = nil } }),
      presenting: model.pendingPairing
    ) { pairing in
      Button { model.pair(pairing) } label: { Text(L10n.Pair.pair) }
      Button(role: .cancel) {} label: { Text(L10n.Common.cancel) }
    } message: { _ in
      Text(L10n.Pair.askMessage)
    }
  }
}
