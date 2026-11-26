import SwiftUI
import Testing
@testable import Tickr

/// Which screens the app shows: the Mac screens on an iPad in regular width and on the unfolded
/// iPhone Duo in landscape, with a connection; every other iPhone, landscape Pro Max included,
/// keeps the iPhone screens.
@Suite struct ScreenLayoutTests {
  /// A full-screen iPad in landscape, in points.
  private static let iPadWidth: CGFloat = 1_194
  /// A Pro Max in landscape, the widest iPhone that does not fold.
  private static let proMaxWidth = ScreenLayout.widestPhone
  /// The unfolded Duo in landscape, as the IOSDuo board draws it (1150 × 530).
  private static let duoWidth: CGFloat = 1_150

  @Test func iPadInRegularWidthShowsTheMacScreens() {
    #expect(ScreenLayout.pick(idiom: .pad, width: .regular, windowWidth: Self.iPadWidth, configured: true) == .regular)
  }

  @Test func iPadInCompactWidthShowsTheIPhoneScreens() {
    #expect(ScreenLayout.pick(idiom: .pad, width: .compact, windowWidth: Self.iPadWidth, configured: true) == .compact)
    #expect(ScreenLayout.pick(idiom: .pad, width: nil, windowWidth: Self.iPadWidth, configured: true) == .compact)
  }

  @Test func proMaxInLandscapeKeepsItsOwnScreens() {
    #expect(ScreenLayout.pick(idiom: .phone, width: .regular, windowWidth: Self.proMaxWidth, configured: true)
      == .compact)
  }

  @Test func unfoldedDuoInLandscapeShowsTheMacScreens() {
    #expect(ScreenLayout.pick(idiom: .phone, width: .regular, windowWidth: Self.duoWidth, configured: true) == .regular)
  }

  @Test func duoInCompactWidthShowsTheIPhoneScreens() {
    #expect(ScreenLayout.pick(idiom: .phone, width: .compact, windowWidth: Self.duoWidth, configured: true) == .compact)
  }

  @Test func noConnectionShowsTheIPhoneScreensThatPair() {
    #expect(ScreenLayout.pick(idiom: .pad, width: .regular, windowWidth: Self.iPadWidth, configured: false) == .compact)
    #expect(ScreenLayout.pick(idiom: .phone, width: .regular, windowWidth: Self.duoWidth, configured: false) == .compact)
  }
}
