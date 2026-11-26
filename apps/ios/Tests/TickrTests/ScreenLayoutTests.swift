import SwiftUI
import Testing
@testable import Tickr
import TickrScreens

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

  @Test func aSectionSurvivesARoundTripThroughTheOtherLayout() {
    for section in [AppSection.overview, .chart, .trades, .lab] {
      #expect(AppSection(AppTab(section)) == section)
    }
    for tab in [AppTab.home, .chart, .activity, .lab] {
      #expect(AppTab(AppSection(tab)) == tab)
    }
  }

  @Test func sectionsWithoutTheirOwnTabMapToWhereTheyLive() {
    #expect(AppTab(AppSection.risk) == .home)
    #expect(AppSection(AppTab.positions) == .overview)
  }
}
