import ApertureDesign
import ApertureKit
import SwiftUI

// The Overview's parts read from GET /flow and GET /watching: the screener chips under the
// pipeline, and the symbols the strategy is watching closely.

/// Values of the pipeline stages that combine the live status with the day's flow.
enum FlowStages {
  /// The reconcile stage: its value, or nil with why (a missing value never reads as fine).
  struct Reconcile: Equatable {
    let value: String?
    let note: String?
  }

  /// Live fences come first (they come from the status, newer than any reconciliation), then the
  /// latest reconciliation's mismatch or match; without one, unknown with the bot's cause.
  static func reconcile(liveFences: [Fence]?, latest: FlowReconcileV1?) -> Reconcile {
    if let fences = liveFences, !fences.isEmpty {
      return Reconcile(value: String(localized: L10n.Common.fences(fences.count)), note: nil)
    }
    switch latest?.agreement {
    case .mismatch: return Reconcile(value: String(localized: L10n.Screener.mismatch), note: nil)
    case .match: return Reconcile(value: String(localized: L10n.Flow.match), note: nil)
    case nil: return Reconcile(value: nil, note: latest?.agreementCause)
    }
  }
}

/// The day's screener symbols as chips: change from the previous close, coloured by sign; a
/// symbol the universe left out is struck through, with the cause as its tooltip.
struct ScreenerChips: View {
  @Environment(AppModel.self) private var model

  /// Accessibility id of the chip row, for the UI tests.
  static let id = "overview-screener-chips"

  var body: some View {
    Group {
      if let chips = model.flow?.chips {
        if chips.isEmpty {
          Footnote(L10n.Screener.none)
        } else {
          ScrollView(.horizontal) {
            HStack(spacing: Tokens.Space.s) {
              ForEach(chips, id: \.symbol) { chip in
                Chip(chip: chip)
              }
            }
          }
          .scrollIndicators(.never)
        }
      } else if let error = model.flowError {
        Footnote(L10n.Screener.unavailable(error), color: Palette.warningText)
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(Self.id)
  }
}

private struct Chip: View {
  let chip: FlowChipV1

  var body: some View {
    let excluded = chip.excludedCause != nil
    HStack(spacing: Tokens.Space.xs) {
      Text(verbatim: chip.symbol)
        .font(Tokens.Typography.annotationBold)
        .strikethrough(excluded)
        .foregroundStyle(excluded ? Palette.textQuaternary : Palette.textPrimary)
      Text(verbatim: chip.changePct.map { String(localized: L10n.Trades.percent(Money.signed($0.value))) } ?? Format.missing)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(excluded ? Palette.textQuaternary : chip.changePct.map { Palette.result($0.value) } ?? Palette.textQuaternary)
    }
    .padding(.horizontal, Tokens.Space.s)
    .padding(.vertical, Tokens.Space.xxs)
    .background(Palette.surface, in: .capsule)
    .overlay(Capsule().strokeBorder(Palette.separatorStrong))
    .help(Text(verbatim: help))
    .accessibilityElement(children: .combine)
  }

  /// Why the chip looks as it does: the exclusion, the missing change, then the screeners.
  private var help: String {
    let sources = chip.sources.map { String(localized: $0.title) }.joined(separator: Format.listSeparator)
    return [chip.excludedCause.map { String(localized: L10n.Screener.excluded($0)) }, chip.changeCause, sources]
      .compactMap { $0 }
      .joined(separator: Format.lineSeparator)
  }
}

extension ScreenerSource {
  var title: LocalizedStringResource {
    switch self {
    case .gainers: L10n.Screener.gainers
    case .losers: L10n.Screener.losers
    case .topActives: L10n.Screener.topActives
    }
  }
}

/// The symbols the strategy is closest to entering, with the check that decides each and how
/// close it is to passing.
struct WatchingCard: View {
  @Environment(AppModel.self) private var model

  /// Display cap on the rows shown (not an API limit); the card says how many there are in all.
  static let shown = 6
  /// Width of a closeness bar, in points.
  static let barWidth: CGFloat = 120
  /// Accessibility id of the card, for the UI tests.
  static let id = "overview-watching"

  var body: some View {
    Card(L10n.Watching.title) {
      if let watching = model.watching, watching.total > 0 {
        Text(L10n.Watching.count(min(watching.rows.count, Self.shown), watching.total))
          .font(Tokens.Typography.captionMono)
          .foregroundStyle(Palette.textQuaternary)
      }
    } content: {
      if let watching = model.watching {
        if watching.rows.isEmpty {
          Footnote(L10n.Watching.none)
        } else {
          Grid(alignment: .leading, horizontalSpacing: Tokens.Space.l, verticalSpacing: Tokens.Space.s) {
            ForEach(watching.rows.prefix(Self.shown), id: \.symbol) { row in
              WatchingRow(row: row)
            }
          }
        }
      } else if let error = model.watchingError {
        Footnote(L10n.Watching.unavailable(error), color: Palette.warningText)
      } else {
        ProgressView().controlSize(.small)
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(Self.id)
  }
}

private struct WatchingRow: View {
  let row: WatchingRowV1

  var body: some View {
    GridRow {
      Text(verbatim: row.symbol).font(Tokens.Typography.calloutMono.weight(.semibold))
      Badge(row.verdict.title, color: row.verdict.color)
      Group {
        if let check = row.decisiveCheck {
          Text(verbatim: check.comparisonText)
            .foregroundStyle(Palette.textSecondary)
            .help(Text(verbatim: check.note))
        } else {
          Text(L10n.Watching.noCheck).foregroundStyle(Palette.textQuaternary)
        }
      }
      .font(Tokens.Typography.captionMono)
      .lineLimit(1)
      closeness
      Text(verbatim: Format.marketMinute(row.at.date))
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(Palette.textQuaternary)
    }
  }

  @ViewBuilder private var closeness: some View {
    if let value = row.closeness?.value {
      ProgressView(value: NSDecimalNumber(decimal: value).doubleValue)
        .tint(Palette.accent)
        .frame(width: WatchingCard.barWidth)
        .accessibilityLabel(Text(L10n.Watching.closeness))
        .help(Text(L10n.Watching.closeness))
    } else {
      Text(verbatim: Format.missing)
        .foregroundStyle(Palette.textQuaternary)
        .frame(width: WatchingCard.barWidth, alignment: .leading)
        .help(row.closenessCause.map { Text(verbatim: $0) } ?? Text(L10n.Watching.closeness))
    }
  }
}

extension CheckV1 {
  /// "rule measured operator threshold" as the bot recorded them; a missing side is a dash.
  var comparisonText: String {
    "\(rule) \(measured?.text ?? Format.missing) \(`operator`) \(threshold?.text ?? Format.missing)"
  }
}
