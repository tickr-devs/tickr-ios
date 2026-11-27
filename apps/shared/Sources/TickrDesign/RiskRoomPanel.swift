import SwiftUI
import TickrKit

// The Risk room card's content on both apps (mockup v115): the room left of the daily loss limit
// and its bar, the facts two to a row, then the "Last entry size" block (or its one-line summary,
// mockup Main). Each app wraps it in its own card with its own title and link; everything inside
// is this one view.

/// One fact of the card's grid: a label over its value, or over a badge (the records' "match").
public struct RiskFact: Identifiable {
  /// Where a fact sits in the grid, in reading order (mockup v115).
  public enum Place: Int, Hashable, Sendable {
    case netResult, reservations, positions, records
  }

  /// The records' fact as both apps show it: a badge on a match, amber otherwise, a dash with the
  /// bot's cause when nothing says.
  public static func records(_ agreement: RecordsAgreement) -> RiskFact {
    RiskFact(.records, RiskRoomText.recordsAgree, value: agreement.value ?? Money.missing,
      color: agreement.agrees.map { $0 ? Palette.profitText : Palette.warningText } ?? Palette.textQuaternary,
      badge: agreement.agrees == true, help: agreement.note)
  }

  public let id: Place
  let label: LocalizedStringResource
  let value: String
  let color: Color
  let badge: Bool
  let help: String?

  /// `badge` draws the value as a badge in `color`.
  public init(
    _ id: Place, _ label: LocalizedStringResource, value: String, color: Color = Palette.textPrimary,
    badge: Bool = false, help: String? = nil
  ) {
    self.id = id
    self.label = label
    self.value = value
    self.color = color
    self.badge = badge
    self.help = help
  }
}

/// The card's content below its title.
public struct RiskRoomPanel: View {
  /// The bot's room left today; nil shows a dash (the app never computes one).
  let room: Decimal?
  /// The daily loss limit.
  let limit: Decimal
  /// What open orders reserve of the room, if the bot said.
  let reserved: Decimal?
  let facts: [RiskFact]
  /// Nil while the day's latest size is not known (GET /watching not read): never "no entry".
  let sizing: EntrySizing?
  /// The last entry as one line with "Limits ›" opening every limit (`EntrySizingSummary`,
  /// mockup Main); false lists the limits on the card (`EntrySizingSection`).
  let summary: Bool
  /// Why the room shows a dash, under the bar (`RiskRoomText.roomNote`).
  let roomNote: LocalizedStringResource?

  public init(
    room: Decimal?, limit: Decimal, reserved: Decimal?, facts: [RiskFact], sizing: EntrySizing?, summary: Bool = false,
    roomNote: LocalizedStringResource? = nil
  ) {
    self.room = room
    self.limit = limit
    self.reserved = reserved
    self.facts = facts
    self.sizing = sizing
    self.summary = summary
    self.roomNote = roomNote
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      // The room in the accent and the limit beside it; under a narrow width the limit wraps.
      HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
        Text(verbatim: room.map(Money.usd) ?? Money.missing)
          .font(Tokens.Typography.metric)
          .foregroundStyle(room == nil ? Palette.textQuaternary : Palette.accentText)
          .contentTransition(.numericText())
          .fixedSize()
        Text(RiskRoomText.left(Money.usd(limit)))
          .font(Tokens.Typography.caption)
          .foregroundStyle(Palette.textQuaternary)
          .fixedSize(horizontal: false, vertical: true)
      }
      RoomBar(room: share(room), reserved: share(reserved))
      if let roomNote {
        InfoCaption(roomNote)
          .fixedSize(horizontal: false, vertical: true)
      }
      FactGrid(facts: facts)
      if let sizing {
        if summary { EntrySizingSummary(sizing: sizing) } else { EntrySizingSection(sizing: sizing) }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// A share of the limit, for the bar.
  private func share(_ value: Decimal?) -> Double {
    guard let value, limit > 0 else { return 0 }
    return NSDecimalNumber(decimal: value / limit).doubleValue
  }
}

/// The room left in the accent, then the reservations in amber after it, on the sunken track.
struct RoomBar: View {
  let room: Double
  let reserved: Double

  var body: some View {
    let shownRoom = Self.share(room)
    let shownReserved = min(max(reserved, 0), max(1 - shownRoom, 0))
    GeometryReader { proxy in
      HStack(spacing: 0) {
        Rectangle().fill(Palette.accent).frame(width: proxy.size.width * shownRoom)
        Rectangle().fill(Palette.warning).frame(width: proxy.size.width * shownReserved)
        Spacer(minLength: 0)
      }
      .grows(with: [shownRoom, shownReserved])
      .background(Palette.surfaceSunken)
      .clipShape(Capsule())
    }
    .frame(height: Tokens.Size.bar)
    .accessibilityHidden(true)
  }

  /// A share of the bar, 0...1: the bot's room may be negative after a gap through a stop.
  static func share(_ value: Double) -> Double {
    min(max(value, 0), 1)
  }
}

/// The facts two to a row, each a label over its value.
struct FactGrid: View {
  let facts: [RiskFact]

  /// Facts on each row of the grid (mockup v115).
  static let columns = 2

  var body: some View {
    let rows = stride(from: 0, to: facts.count, by: Self.columns).map { Array(facts[$0..<min($0 + Self.columns, facts.count)]) }
    Grid(alignment: .topLeading, horizontalSpacing: Tokens.Space.m, verticalSpacing: Tokens.Space.s) {
      ForEach(rows, id: \.first?.id) { row in
        GridRow {
          ForEach(row) { fact in
            FactCell(fact: fact).frame(maxWidth: .infinity, alignment: .leading)
          }
        }
      }
    }
  }
}

private struct FactCell: View {
  let fact: RiskFact

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
      Text(fact.label)
        .font(Tokens.Typography.caption)
        .foregroundStyle(Palette.textTertiary)
        .fixedSize(horizontal: false, vertical: true)
      if fact.badge {
        Badge(verbatim: fact.value, color: fact.color)
      } else {
        Text(verbatim: fact.value)
          .font(Tokens.Typography.calloutMono)
          .foregroundStyle(fact.color)
          .contentTransition(.numericText())
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .help(fact.help.map { Text(verbatim: $0) } ?? Text(fact.label))
    .accessibilityElement(children: .combine)
  }
}

/// "Last entry size" on the Risk screens of both apps (mockup IOSRisk): the shares bought, big,
/// with where and when; the limit that set them; then each limit with the shares it allows, the
/// one that set the size in the accent. No formulas on screen. With no entry today, one line.
public struct EntrySizingSection: View {
  let sizing: EntrySizing

  public init(sizing: EntrySizing) {
    self.sizing = sizing
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      CardLabel(EntrySizing.title)
      if let shares = sizing.shares {
        // The shares beside where and when; under a narrow width the place wraps under them.
        ViewThatFits(in: .horizontal) {
          HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) { headline(shares); place }
          VStack(alignment: .leading, spacing: Tokens.Space.xxs) { headline(shares); place }
        }
        if let text = sizing.limitedBy {
          SizingCaption(text: text, color: sizing.captionColor)
        }
        ForEach(sizing.limits) { limit in
          HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.m) {
            Text(verbatim: limit.plain)
              .font(Tokens.Typography.caption)
              .fontWeight(limit.binds ? .semibold : .regular)
              .foregroundStyle(limit.binds ? Palette.textPrimary : Palette.textTertiary)
              .fixedSize(horizontal: false, vertical: true)
              .frame(maxWidth: .infinity, alignment: .leading)
            Text(verbatim: limit.allows)
              .font(Tokens.Typography.captionMono)
              .fontWeight(limit.binds ? .bold : .medium)
              .foregroundStyle(limit.binds ? Palette.accentText : Palette.textSecondary)
              .fixedSize()
          }
          .accessibilityElement(children: .combine)
        }
      } else {
        Text(verbatim: sizing.line)
          .font(Tokens.Typography.callout)
          .foregroundStyle(Palette.textTertiary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func headline(_ shares: String) -> some View {
    Text(verbatim: shares)
      .font(Tokens.Typography.metric)
      .foregroundStyle(Palette.textPrimary)
      .contentTransition(.numericText())
      .fixedSize()
  }

  @ViewBuilder private var place: some View {
    if let place = sizing.place {
      Text(verbatim: place)
        .font(Tokens.Typography.caption)
        .foregroundStyle(Palette.textQuaternary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

extension EntrySizing {
  /// The caption's colour: the accent for the limit that set a real size, amber when the record
  /// does not prove it, quiet for the example.
  var captionColor: Color {
    switch tone {
    case .bound: Palette.accentText
    case .example: Palette.textTertiary
    case .unproven: Palette.warningText
    }
  }
}

/// A sizing limit: its figures and the shares it allows, then a thin bar of how much of that the
/// size used. The limit that set the size is in the accent and bold, its bar full.
struct LimitRow: View {
  let limit: EntrySizing.Limit
  let step: Int

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
      HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.m) {
        Text(verbatim: limit.label)
          .font(Tokens.Typography.caption)
          .fontWeight(limit.binds ? .semibold : .regular)
          .foregroundStyle(limit.binds ? Palette.textPrimary : Palette.textTertiary)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)
        Text(verbatim: limit.allows)
          .font(Tokens.Typography.captionMono)
          .fontWeight(limit.binds ? .bold : .medium)
          .foregroundStyle(limit.binds ? Palette.accentText : Palette.textSecondary)
          .fixedSize()
      }
      GeometryReader { proxy in
        Capsule().fill(Palette.surfaceSunken)
          .overlay(alignment: .leading) {
            Capsule().fill(limit.binds ? Palette.accent : Palette.info.opacity(Tokens.Opacity.muted))
              .frame(width: proxy.size.width * limit.used)
              .grows(with: limit.used, step: step)
          }
      }
      .frame(height: Tokens.Size.barThin)
      .accessibilityHidden(true)
    }
    .accessibilityElement(children: .combine)
  }
}
