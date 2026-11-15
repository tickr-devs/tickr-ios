import ApertureDesign
import ApertureKit
import SwiftUI

// The Overview's parts read from GET /flow and GET /watching: the latest event above the
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

/// The live flow's latest event on one still line, as in the design: its New York time, its tag
/// in its tone and what happened. A new event replaces the line; nothing scrolls. A recorded day
/// shows its last closed trade. A failed /flow read says so under it, since the stages and dots
/// below then lack the day's flow.
struct LatestEvent: View {
  @Environment(AppModel.self) private var model

  /// Accessibility id of the line, for the UI tests.
  static let id = "overview-latest-event"

  private struct Line {
    let time: Date
    let tag: String
    let text: String
    let color: Color
  }

  private var line: Line? {
    if model.isLive {
      // A risk refusal is an event too: the latest of the two leads.
      guard let status = model.status, let event = Board.latestEvent(status,
        skipped: model.skipped?.day == model.today ? model.skipped : nil) else { return nil }
      return Line(time: event.time, tag: event.tag, text: event.text, color: event.tone.color)
    }
    guard let trade = model.shownTrades.max(by: { $0.closedAt.date < $1.closedAt.date }) else { return nil }
    let result = trade.resultGrossUsd.value
    return Line(time: trade.closedAt.date, tag: Board.exitReasonTitle(trade.exitReason),
      text: "\(trade.symbol) \(Money.signed(result))", color: result >= 0 ? Palette.profitText : Palette.lossText)
  }

  @ViewBuilder var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.m) {
      if let line {
        Text(L10n.Risk.clock(Format.marketTime(line.time))).foregroundStyle(Palette.textQuaternary)
        Text(verbatim: line.tag).bold().textCase(.uppercase).foregroundStyle(line.color)
        Text(verbatim: line.text).foregroundStyle(Palette.textSecondary).truncationMode(.tail)
      } else {
        Text(verbatim: Format.missing).foregroundStyle(Palette.textQuaternary)
        Text(L10n.Flow.nothingYet).foregroundStyle(Palette.textTertiary)
      }
      Spacer(minLength: 0)
    }
    .font(Tokens.Typography.captionMono)
    .lineLimit(1)
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier(Self.id)
    if let error = model.flowError {
      Footnote(L10n.Screener.unavailable(error), color: Palette.warningText)
    }
  }
}

/// The symbols the strategy is closest to entering, with the check that decides each and how
/// close it is to passing.
struct WatchingCard: View {
  @Environment(AppModel.self) private var model

  /// Display cap on the rows shown (not an API limit); the card says how many there are in all.
  static let shown = 6
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
          VStack(spacing: Tokens.Space.s) {
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

/// One watched symbol as the design draws it: a sunken box with the symbol, its verdict tag and
/// the time on top, the deciding check below, and a thin bar of how close it is to passing.
private struct WatchingRow: View {
  let row: WatchingRowV1
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      HStack(spacing: Tokens.Space.s) {
        Text(verbatim: row.symbol)
          .font(Tokens.Typography.chip)
          .foregroundStyle(Palette.textPrimary)
        Badge(row.verdict.title, color: row.verdict.color)
        Spacer(minLength: 0)
        Text(verbatim: Format.marketMinute(row.at.date))
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      }
      Group {
        if let check = row.decisiveCheck {
          Text(verbatim: check.comparisonText)
            .foregroundStyle(Palette.textTertiary)
            .help(Text(verbatim: check.note))
        } else {
          Text(L10n.Watching.noCheck).foregroundStyle(Palette.textQuaternary)
        }
      }
      .font(Tokens.Typography.captionMono)
      .lineLimit(1)
      closeness
    }
    .padding(.horizontal, Tokens.Space.s)
    .padding(.vertical, Tokens.Space.s)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Palette.surfaceSunken, in: RoundedRectangle(cornerRadius: Tokens.Radius.medium))
    .overlay {
      RoundedRectangle(cornerRadius: Tokens.Radius.medium).strokeBorder(Palette.separator, lineWidth: Tokens.Stroke.thin)
    }
  }

  /// How close the deciding check is to passing, as a thin bar in the verdict's colour; empty
  /// with the cause as its tooltip when the bot cannot say.
  private var closeness: some View {
    let share = row.closeness.map { min(max(NSDecimalNumber(decimal: $0.value).doubleValue, 0), 1) }
    return GeometryReader { proxy in
      ZStack(alignment: .leading) {
        if let share {
          Capsule().fill(Palette.separator)
          Capsule().fill(row.verdict.color).frame(width: proxy.size.width * share)
        } else {
          // Unknown is a dashed outline, never an empty track that reads as 0 %.
          Capsule().strokeBorder(Palette.separatorStrong,
            style: StrokeStyle(lineWidth: Tokens.Stroke.thin, dash: Tokens.Stroke.dashFine))
        }
      }
    }
    .frame(height: Tokens.Size.barThin)
    .animation(reduceMotion ? nil : Tokens.Motion.fill, value: share)
    .help(share == nil ? row.closenessCause.map { Text(verbatim: $0) } ?? Text(L10n.Watching.closeness)
      : Text(L10n.Watching.closeness))
    .accessibilityLabel(Text(L10n.Watching.closeness))
    .accessibilityValue(share.map { Text($0, format: .percent) } ?? Text(verbatim: Format.missing))
  }
}

extension CheckV1 {
  /// "rule measured operator threshold" as the bot recorded them; a missing side is a dash.
  var comparisonText: String {
    "\(ApiText.rule(rule)) \(measured?.text ?? Format.missing) \(`operator`) \(threshold?.text ?? Format.missing)"
  }
}
