import SwiftUI
import Testing
@testable import Tickr

/// Which screens the app shows: the Mac screens only on an iPad in regular width with a
/// connection; every iPhone, landscape Pro Max included, keeps the iPhone screens.
@Suite struct ScreenLayoutTests {
  @Test func iPadInRegularWidthShowsTheMacScreens() {
    #expect(ScreenLayout.pick(idiom: .pad, width: .regular, configured: true) == .regular)
  }

  @Test func iPadInCompactWidthShowsTheIPhoneScreens() {
    #expect(ScreenLayout.pick(idiom: .pad, width: .compact, configured: true) == .compact)
    #expect(ScreenLayout.pick(idiom: .pad, width: nil, configured: true) == .compact)
  }

  @Test func iPhoneInRegularWidthKeepsItsOwnScreens() {
    #expect(ScreenLayout.pick(idiom: .phone, width: .regular, configured: true) == .compact)
  }

  @Test func noConnectionShowsTheIPhoneScreensThatPair() {
    #expect(ScreenLayout.pick(idiom: .pad, width: .regular, configured: false) == .compact)
  }
}
