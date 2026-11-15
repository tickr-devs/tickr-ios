import SwiftUI
import TickrKit

/// Five tabs, ordered by use during a trading day. Settings live behind the gear on Home.
struct RootView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    @Bindable var model = model
    // Tab icons are outlines, as on the design, rather than the tab bar's default filled variants;
    // set on each icon so the screens inside keep their own symbol variants.
    TabView(selection: $model.selectedTab) {
      Tab(value: AppTab.home) {
        NavigationStack { HomeView() }
      } label: {
        Label { Text(L10n.App.home) } icon: {
          Image(systemName: "square.grid.2x2").environment(\.symbolVariants, .none)
        }
      }
      Tab(value: AppTab.positions) {
        NavigationStack { PositionsView() }
      } label: {
        Label { Text(L10n.App.positions) } icon: {
          Image(systemName: "lock").environment(\.symbolVariants, .none)
        }
      }
      Tab(value: AppTab.chart) {
        NavigationStack { ChartTab() }
      } label: {
        Label { Text(L10n.App.chart) } icon: {
          Image(systemName: "chart.line.uptrend.xyaxis").environment(\.symbolVariants, .none)
        }
      }
      Tab(value: AppTab.activity) {
        NavigationStack { ActivityView() }
      } label: {
        Label { Text(L10n.App.activity) } icon: {
          Image(systemName: "line.3.horizontal").environment(\.symbolVariants, .none)
        }
      }
      Tab(value: AppTab.lab) {
        NavigationStack { LabView() }
      } label: {
        Label { Text(L10n.App.lab) } icon: {
          Image(systemName: "star").environment(\.symbolVariants, .none)
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
      Button { model.pair(pairing) } label: { Text(L10n.Pair.pair) }
      Button(role: .cancel) {} label: { Text(L10n.Common.cancel) }
    } message: { _ in
      Text(L10n.Pair.askMessage)
    }
  }
}
