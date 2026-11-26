import SwiftUI
import TickrKit

/// A working entry's words (mockup v160, Mac Overview and iPhone Home): its label, the order, its
/// state line ("sent 10:42 · waiting for fill", "Cancelling…", "Cancelled at broker"), then the
/// planned stop and the most it loses if it fills, or, once cancelled, that no position opened.
/// The apps put the symbol and Cancel entry around it, each in its own layout. `compact` is the
/// iPhone's row beside positions (mockup v162): the order and a short state line only, the label
/// (`EntryBadge`) beside the symbol.
public struct EntryFacts: View {
  let row: EntryRow
  let compact: Bool

  public init(_ row: EntryRow, compact: Bool = false) {
    self.row = row
    self.compact = compact
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      if !compact { EntryBadge(row) }
      Text(order)
        .font(Tokens.Typography.callout.weight(.semibold))
        .foregroundStyle(Palette.textPrimary)
        .fixedSize(horizontal: false, vertical: true)
      HStack(spacing: Tokens.Space.xs) {
        switch row.phase {
        case .working: EmptyView()
        case .cancelling: Spinner()
        case .cancelled: Image(systemName: EntryLook.doneSymbol)
        }
        Text(line)
          .fixedSize(horizontal: false, vertical: true)
      }
      .font(Tokens.Typography.captionMono)
      .foregroundStyle(lineColor)
      if compact {
        EmptyView()
      } else if row.phase == .cancelled {
        Text(EntryText.noPosition)
          .font(Tokens.Typography.caption)
          .foregroundStyle(Palette.textTertiary)
      } else {
        Label {
          Text(EntryText.stopPlanned(Money.price(row.stopPrice))).font(Tokens.Typography.captionMono)
        } icon: {
          Image(systemName: EntryLook.stopSymbol)
        }
        .font(Tokens.Typography.caption)
        .foregroundStyle(Palette.textSecondary)
        Text(EntryText.maxLoss(Money.usd(row.plannedLossUsd)))
          .font(Tokens.Typography.caption)
          .foregroundStyle(Palette.textTertiary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var order: LocalizedStringResource {
    let quantity = Shares.text(row.quantity)
    let price = Money.price(row.limitPrice)
    return row.phase == .cancelled ? EntryText.buy(quantity, price) : EntryText.buying(quantity, price)
  }

  private var line: LocalizedStringResource {
    switch row.phase {
    case .working:
      if let limit = row.cancelLapsedAfter { return EntryText.cancelLapsed(DurationText.number(limit)) }
      return row.sentAt.map { ClockText.minutes($0) }.map { compact ? EntryText.sentWaitingShort($0) : EntryText.sentWaiting($0) }
        ?? EntryText.waiting
    case .cancelling: return EntryText.cancelling
    case .cancelled: return EntryText.cancelledAtBroker
    }
  }

  private var lineColor: Color {
    switch row.phase {
    case .working: row.cancelLapsedAfter == nil ? Palette.textTertiary : Palette.warningText
    case .cancelling: Palette.textSecondary
    case .cancelled: Palette.profitText
    }
  }
}

/// A working entry's label: "Working entry", or "Entry cancelled" once the broker cancelled it.
public struct EntryBadge: View {
  let row: EntryRow

  public init(_ row: EntryRow) { self.row = row }

  public var body: some View {
    Text(row.phase == .cancelled ? EntryText.cancelled : EntryText.working)
      .font(Tokens.Typography.label)
      .tracking(Tokens.Typography.labelTracking)
      .textCase(.uppercase)
      .foregroundStyle(EntryLook.color(row.phase))
  }
}

/// The working entry's dot beside its symbol: blue and pulsing while it works, amber while its
/// cancel is on its way, grey once cancelled.
public struct EntryDot: View {
  let phase: EntryRow.Phase

  public init(_ phase: EntryRow.Phase) { self.phase = phase }

  public var body: some View {
    PulseDot(EntryLook.color(phase), pulsing: phase == .working)
      .accessibilityHidden(true)
  }
}

/// The colours and symbols of a working entry, one place for both apps.
public enum EntryLook {
  /// SF Symbols: the planned stop's shield, the cancelled tick, a working order's clock, and the
  /// Cancel entry button's glyph.
  public static let stopSymbol = "shield"
  public static let doneSymbol = "checkmark"
  public static let workingSymbol = "clock"
  public static let cancelSymbol = "xmark.rectangle.portrait"

  /// The entry's colour in each phase.
  public static func color(_ phase: EntryRow.Phase) -> Color {
    switch phase {
    case .working: Palette.info
    case .cancelling: Palette.warning
    case .cancelled: Palette.textQuaternary
    }
  }
}
