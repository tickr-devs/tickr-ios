@testable import ApertureKit
@testable import ApertureMac
import ApertureDesign
import Foundation
import Testing

@Suite("An open position's price and R, fresh or as of the newest bar")
struct PositionRowTests {
  @Test("A stale bar keeps the current figures empty but still gives R as of that bar")
  func staleBar() throws {
    let position = try #require(try fixture(StatusResponseV1.self, "status-response-v1.json").status?.position)
    let close = position.entryPrice.value
    let stale = PositionRow(position: position, lastBarClose: nil, lastBarAt: Date(), closes: [], latestClose: close)
    #expect(stale.resultR == nil)
    #expect(stale.unrealized == nil)
    #expect(stale.latestResultR == Risk.multiple(entry: stale.entry, stop: stale.stop, price: close))
    let fresh = PositionRow(position: position, lastBarClose: close, lastBarAt: Date(), closes: [], latestClose: close)
    #expect(fresh.resultR == fresh.latestResultR)
  }
}
