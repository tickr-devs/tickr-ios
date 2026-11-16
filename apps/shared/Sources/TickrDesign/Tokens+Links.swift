import SwiftUI

// Tokens of the card links (`HeaderLink`, `CardFooterLink`), the back capsule (`BackCapsule`) and
// the loader (`TickrLoader`), as on the Controls board (docs/design-system.md); in their own file
// because Tokens.swift is at SwiftLint's file length limit.

extension Tokens.Typography {
  /// A card's header link, the label of its footer link, and the back capsule's title and chevron,
  /// at the board's sizes (the Mac's; iOS follows text styles).
  public static let linkSize: CGFloat = 12
  public static let footerLinkSize: CGFloat = 12.5
  public static let backTitleSize: CGFloat = 15
  public static let backChevronSize: CGFloat = 17

  #if os(iOS)
  /// A card's header link (`HeaderLink`) and the label of its footer link (`CardFooterLink`).
  public static let link = Font.system(.footnote, weight: .semibold)
  public static let footerLink = Font.system(.subheadline, weight: .semibold)
  /// The back capsule's title and chevron (`BackCapsule`).
  public static let backTitle = Font.system(.subheadline, weight: .medium)
  public static let backChevron = Font.system(.body, weight: .semibold)
  #else
  /// A card's header link (`HeaderLink`) and the label of its footer link (`CardFooterLink`).
  public static let link = Font.system(size: linkSize, weight: .semibold)
  public static let footerLink = Font.system(size: footerLinkSize, weight: .semibold)
  /// The back capsule's title and chevron (`BackCapsule`).
  public static let backTitle = Font.system(size: backTitleSize, weight: .medium)
  public static let backChevron = Font.system(size: backChevronSize, weight: .semibold)
  #endif
}

extension Tokens.Opacity {
  /// A footer link's row under the pointer (`CardFooterLink`).
  public static let rowHover = 0.06
  /// A tinted chip's fill: the footer link's chevron chip.
  public static let tint = 0.14
  /// A `Badge`'s fill: its colour at 14 % (the boards' `.u-badge`).
  public static let badgeFill = 0.14
  /// A header link's fill under the pointer (`HeaderLink`).
  public static let linkHover = 0.2
  /// A header link's tinted outline (`HeaderLink`).
  public static let linkOutline = 0.22
}

extension Tokens.Size {
  /// The soft shadow under a glass control (`glassSurface`: the back capsule, header icons): blur
  /// radius and downward offset.
  public static let glassShadowRadius: CGFloat = 7
  public static let glassShadowOffset: CGFloat = 4
  /// The round chevron chip at the end of a footer link (`CardFooterLink`).
  public static let footerChip: CGFloat = 22
  /// The large loader of a whole pane (the Chart's, `TickrLoader`), and its ping dot.
  public static let loaderLarge: CGFloat = 56
  public static let loaderDotLarge: CGFloat = 7
  /// The ping dot of the compact loader.
  public static let loaderDot: CGFloat = 5
  #if os(iOS)
  /// A header link's capsule height (`HeaderLink`); its touch target is `touchTarget`.
  public static let headerLink: CGFloat = 30
  /// A footer link's row height (`CardFooterLink`): the whole row is the touch target.
  public static let footerLink: CGFloat = 44
  /// The compact loader inside a card (`TickrLoader`).
  public static let loader: CGFloat = 32
  #else
  /// A header link's capsule height (`HeaderLink`).
  public static let headerLink: CGFloat = 24
  /// A footer link's row height (`CardFooterLink`): the whole row is the click target.
  public static let footerLink: CGFloat = 36
  /// The compact loader inside a card (`TickrLoader`).
  public static let loader: CGFloat = 28
  #endif
}

extension Tokens.Motion {
  /// How much a footer link's row and the back capsule shrink while pressed (the board's `.cfoot`
  /// and `.bk`).
  public static let rowPressScale: CGFloat = 0.99
  public static let backPressScale: CGFloat = 0.96
  /// How far a footer link's chevron chip moves on under the pointer.
  public static let linkNudge: CGFloat = 2
  /// The loader (`TickrLoader`, ornament): seconds of one turn of its beam (a ping of its dot each
  /// turn), how far the dot's ping starts grown, and the share of the turn the beam's tail covers.
  public static let loaderTurnSeconds = 1.4
  public static let loaderPingScale: CGFloat = 1.7
  public static let loaderTail = 0.32
  /// Under Reduce Motion the loader's rings pulse instead (owner, 2026-11-16): seconds of one
  /// pulse, how faint a ring gets, and each inner ring's lag behind the one around it.
  public static let loaderPulseSeconds = 2.4
  public static let loaderPulseLow = 0.3
  public static let loaderPulseLagSeconds = 0.4
}
