import Foundation
import Testing
import TickrDesign
@testable import TickrMac

@Suite("Toolbar connection dot")
@MainActor
struct ConnectionStatusTests {
  @Test("Fresh is green, stale amber, a failed read quiet grey, no status red")
  func color() {
    #expect(ConnectionStatus.color(hasStatus: true, stale: false, failed: false) == Palette.profit)
    #expect(ConnectionStatus.color(hasStatus: true, stale: true, failed: false) == Palette.warning)
    #expect(ConnectionStatus.color(hasStatus: true, stale: nil, failed: false) == Palette.warning)
    #expect(ConnectionStatus.color(hasStatus: true, stale: false, failed: true) == Palette.textQuaternary)
    #expect(ConnectionStatus.color(hasStatus: false, stale: nil, failed: false) == Palette.loss)
  }
}

@Suite("Sidebar bot state while the link is down")
@MainActor
struct SidebarBotStateTests {
  @Test("A failed read is a quiet grey 'No connection', never the red of danger")
  func failedReadIsQuiet() {
    #expect(String(localized: L10n.Root.apiUnreachable) == "No connection")
  }
}
