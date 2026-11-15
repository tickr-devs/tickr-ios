import ApertureKit
import SwiftUI

/// Five tabs, ordered by use during a trading day. Settings live behind the gear on Home.
struct RootView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    @Bindable var model = model
    // Tab icons are outlines, as on the design, rather than the tab bar's default filled variants;
    // set on each icon so the screens inside keep their own symbol variants.
    TabView(selection: $model.selectedTab) {
      NavigationStack { HomeView() }
        .tabItem {
          Label { Text(L10n.App.home) } icon: {
            Image(systemName: "square.grid.2x2").environment(\.symbolVariants, .none)
          }
        }
        .tag(AppTab.home)
      NavigationStack { PositionsView() }
        .tabItem {
          Label { Text(L10n.App.positions) } icon: {
            Image(systemName: "lock").environment(\.symbolVariants, .none)
          }
        }
        .tag(AppTab.positions)
      NavigationStack { ChartTab() }
        .tabItem {
          Label { Text(L10n.App.chart) } icon: {
            Image(systemName: "chart.line.uptrend.xyaxis").environment(\.symbolVariants, .none)
          }
        }
        .tag(AppTab.chart)
      NavigationStack { ActivityView() }
        .tabItem {
          Label { Text(L10n.App.activity) } icon: {
            Image(systemName: "line.3.horizontal").environment(\.symbolVariants, .none)
          }
        }
        .tag(AppTab.activity)
      NavigationStack { LabView() }
        .tabItem {
          Label { Text(L10n.App.lab) } icon: {
            Image(systemName: "star").environment(\.symbolVariants, .none)
          }
        }
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
      Text(L10n.Pair.ask(
        model.pendingPairing.flatMap { Connection.displayHost($0.url) } ?? String(localized: L10n.Pair.thisMac))),
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
