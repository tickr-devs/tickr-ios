import SwiftUI

/// A view with nothing to show yet, said the same everywhere in both apps: the calm brand mark,
/// a plain title and an optional line under it, centred in the room it is given (never pinned
/// to a corner of its card). A refused or failed read is `UnavailableState` instead.
public struct EmptyState: View {
  let title: Text
  let detail: Text?
  let tone: BrandMark.Tone

  /// `title`: what is missing; `detail`: why or what comes next; `tone`: `.muted` when the
  /// emptiness is not the calm normal (a list that could not be read).
  public init(_ title: Text, detail: Text? = nil, tone: BrandMark.Tone = .brand) {
    self.title = title
    self.detail = detail
    self.tone = tone
  }

  public init(_ title: LocalizedStringResource, detail: LocalizedStringResource? = nil, tone: BrandMark.Tone = .brand) {
    self.init(Text(title), detail: detail.map { Text($0) }, tone: tone)
  }

  public var body: some View {
    ContentUnavailableView {
      Label { title } icon: { BrandMark.empty(tone) }
    } description: {
      if let detail { detail }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
