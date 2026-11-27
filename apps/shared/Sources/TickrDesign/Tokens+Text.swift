import SwiftUI

// Text roles and motion added with the design-skills polish (2026-11-27), kept beside `Tokens`
// (whose file is at its length limit).

extension Tokens.Typography {
  /// Row and card titles (a stop choice, a bot control, a section's lead line).
  public static let headline = Font.headline
  /// A title beside a figure in mono (a symbol's price line).
  public static let headlineMono = Font.headline.monospaced()
  /// Secondary lines under a title, explanations in a card.
  public static let subheadline = Font.subheadline
  /// A notice's title, an emphasised secondary line.
  public static let subheadlineStrong = Font.subheadline.weight(.semibold)
  /// A compact figure beside a symbol (a position's share count).
  public static let subheadlineMonoBold = Font.subheadline.monospaced().bold()
  /// Small print: footers, captions of steps, hints under a control.
  public static let footnote = Font.footnote
  public static let footnoteStrong = Font.footnote.weight(.semibold)
  public static let footnoteMono = Font.footnote.monospaced()
  public static let footnoteMonoBold = Font.footnote.monospaced().bold()
  /// A day switch's shown day.
  public static let bodyMedium = Font.body.weight(.medium)
  /// A section's figure in mono (the lab's model score).
  public static let title3MonoBold = Font.title3.monospaced().bold()
  /// A screen's result figure in mono (Activity's day result).
  public static let titleMonoBold = Font.title.monospaced().bold()
  /// A step's title in a working panel (the Mac entry sheet).
  public static let title3Strong = Font.title3.weight(.semibold)
  /// A large state symbol (working, done) in a panel.
  public static let symbolLarge = Font.largeTitle
}

extension Tokens.Motion {
  /// The tab bar's selection pill moving to another tab: a quick spring with a little bounce.
  public static let pill = Animation.spring(duration: pillSeconds, bounce: pillBounce)
  /// Seconds and bounce of `pill`.
  public static let pillSeconds = 0.4
  public static let pillBounce = 0.2
  /// The scale a small view (a badge, a check, a count) enters from and leaves to: never from
  /// nothing, which reads as popping out of a hole.
  public static let enterScale: CGFloat = 0.9
  /// Live values (a gauge, a ring, a count) moving to a new value: short, so the figure keeps up
  /// with the data instead of trailing it. `fill` stays for a figure filling on first appear.
  public static let live = Animation.smooth(duration: liveSeconds)
  /// Seconds of a live value's move to its new value.
  public static let liveSeconds = 0.3
  /// Seconds after a hint goes during which the next hint shows at once (no delay, no entrance).
  public static let hintWarmSeconds = 0.6
}

extension Tokens.Size {
  /// Room above a view, in points, that a two-line hint bubble needs to show above it (else it
  /// shows below, and grows from its top).
  public static let hintRoomAbove: CGFloat = 56
}
