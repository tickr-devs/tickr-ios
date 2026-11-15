@testable import ApertureMac
import ApertureDesign
import Testing

@Suite("Toolbar connection dot")
@MainActor
struct ConnectionStatusTests {
  @Test("Fresh is green, stale amber, none or a failed read red")
  func color() {
    #expect(ConnectionStatus.color(hasStatus: true, stale: false, failed: false) == Palette.profit)
    #expect(ConnectionStatus.color(hasStatus: true, stale: true, failed: false) == Palette.warning)
    #expect(ConnectionStatus.color(hasStatus: true, stale: nil, failed: false) == Palette.warning)
    #expect(ConnectionStatus.color(hasStatus: true, stale: false, failed: true) == Palette.loss)
    #expect(ConnectionStatus.color(hasStatus: false, stale: nil, failed: false) == Palette.loss)
  }
}
