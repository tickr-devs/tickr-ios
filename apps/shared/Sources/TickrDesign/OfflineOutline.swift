import SwiftUI

/// A card's content while the link to the bot is down and nothing was ever read (mockup "no
/// connection" v2, owner 2026-11-18): the quiet grey outline of text lines, never zeros, "nothing
/// today" or an error of its own; the one connection banner above says why. It holds still: no
/// read is in flight to show (a loading `Skeleton` sweeps, this does not).
public struct OfflineOutline: View {
  let lines: Int

  /// - Parameter lines: how many lines of outline (`Tokens.Loading.fewLines`, `lines`, `manyLines`).
  public init(_ lines: Int = Tokens.Loading.lines) {
    self.lines = lines
  }

  public var body: some View {
    SkeletonLines(lines, leadingValue: true)
      .accessibilityHidden(true)
  }
}

public extension View {
  /// This view's content when nothing was ever read and the link is down (`ReadFailureContext
  /// .noData`): the quiet outline in its place, else the content itself. For a card's body.
  func offlineOutline(lines: Int = Tokens.Loading.lines) -> some View {
    modifier(OfflineOutlineModifier(lines: lines))
  }
}

private struct OfflineOutlineModifier: ViewModifier {
  let lines: Int
  @Environment(\.readFailureContext) private var context

  func body(content: Content) -> some View {
    if context?.noData == true {
      OfflineOutline(lines)
    } else {
      content
    }
  }
}
