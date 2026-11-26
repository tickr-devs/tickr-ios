import SwiftUI
import Testing
@testable import Tickr

/// Which screens the app shows: the Mac screens on an iPad in regular width and on the unfolded
/// iPhone Duo in landscape, with a connection; every other iPhone, landscape Pro Max included,
/// and the folded Duo keep the iPhone screens.
@Suite struct ScreenLayoutTests {
  /// A full-screen iPad in landscape, in points.
  private static let iPad = CGSize(width: 1_194, height: 834)
  /// A Pro Max in landscape, the widest iPhone that does not fold.
  private static let proMax = CGSize(width: 956, height: ScreenLayout.phoneLandscapeHeight)
  /// The unfolded Duo in landscape, as the Simulator has it (2026-11-26).
  private static let unfoldedDuo = CGSize(width: 951, height: 669)
  /// The folded Duo in landscape.
  private static let foldedDuo = CGSize(width: ScreenLayout.foldedDuoLength, height: 466)

  private static func pick(
    _ idiom: UIUserInterfaceIdiom, _ width: UserInterfaceSizeClass?, _ window: CGSize, configured: Bool = true
  ) -> ScreenLayout {
    ScreenLayout.pick(idiom: idiom, width: width, window: window, configured: configured)
  }

  @Test func iPadInRegularWidthShowsTheMacScreens() {
    #expect(Self.pick(.pad, .regular, Self.iPad) == .regular)
  }

  @Test func iPadInCompactWidthShowsTheIPhoneScreens() {
    #expect(Self.pick(.pad, .compact, Self.iPad) == .compact)
    #expect(Self.pick(.pad, nil, Self.iPad) == .compact)
  }

  @Test func proMaxInLandscapeKeepsItsOwnScreens() {
    #expect(Self.pick(.phone, .regular, Self.proMax) == .compact)
  }

  @Test func unfoldedDuoInLandscapeShowsTheMacScreens() {
    #expect(Self.pick(.phone, .regular, Self.unfoldedDuo) == .regular)
  }

  @Test func foldedDuoInLandscapeKeepsTheIPhoneScreens() {
    #expect(Self.pick(.phone, .regular, Self.foldedDuo) == .compact)
  }

  @Test func duoInCompactWidthShowsTheIPhoneScreens() {
    #expect(Self.pick(.phone, .compact, Self.unfoldedDuo) == .compact)
  }

  @Test func noConnectionShowsTheIPhoneScreensThatPair() {
    #expect(Self.pick(.pad, .regular, Self.iPad, configured: false) == .compact)
    #expect(Self.pick(.phone, .regular, Self.unfoldedDuo, configured: false) == .compact)
  }
}
