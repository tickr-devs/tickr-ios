import SwiftUI
import TickrDesign
import TickrKit

// The Overview's parts read from GET /flow and GET /watching: the latest event above the
// pipeline, and the symbols the strategy is watching closely.

/// Values of the pipeline stages that combine the live status with the day's flow.
enum FlowStages {
  /// The reconcile stage: its value, or nil with why (a missing value never reads as fine).
  struct Reconcile: Equatable {
    let value: String?
    let note: String?
    /// The broker and the bot's records agree; false on a fence or a mismatch, nil when unknown.
    var agrees: Bool?
  }

  /// Live fences come first (they come from the status, newer than any reconciliation), then the
  /// latest reconciliation's mismatch or match; without one, unknown with the bot's cause.
  static func reconcile(liveFences: [Fence]?, latest: FlowReconcileV1?) -> Reconcile {
    if let fences = liveFences, !fences.isEmpty {
      return Reconcile(value: String(localized: L10n.Common.fences(fences.count)), note: nil, agrees: false)
    }
    switch latest?.agreement {
    case .mismatch: return Reconcile(value: String(localized: L10n.Screener.mismatch), note: nil, agrees: false)
    case .match: return Reconcile(value: String(localized: L10n.Flow.match), note: nil, agrees: true)
    case nil: return Reconcile(value: nil, note: latest?.agreementCause)
    }
  }
}

/// The symbols the screeners returned today, scrolling across the top of the live flow as in the
/// design: each a chip with the symbol over its screener and change, coloured by screener; one
/// the universe left out is greyed and says it was skipped, with the cause on hover. Every other
/// chip opens the Chart on its symbol, and the row stands still under the pointer. Still on a
/// recorded day or with Reduce Motion (then it scrolls by hand).
struct FlowChips: View {
  @Environment(AppModel.self) private var model
  @AppStorage(ChartView.Keys.symbol) private var chartSymbol = ""
  let chips: [FlowChipV1]
  let moving: Bool

  var body: some View {
    ChipsMarquee(
      items: chips, moving: moving, hint: { L10n.Common.openOnChart($0.symbol) },
      help: { Text(verbatim: FlowChip.help($0)) },
      // A symbol the universe left out has no chart to open.
      opens: { $0.excludedCause == nil },
      open: { chip in
        chartSymbol = chip.symbol
        model.section = .chart
      },
      chip: { FlowChip(chip: $0) })
  }
}

private struct FlowChip: View {
  let chip: FlowChipV1

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
      Text(verbatim: chip.symbol)
        .font(Tokens.Typography.chip)
        .foregroundStyle(Palette.textPrimary)
      Text(verbatim: detail)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(color)
        .strikethrough(chip.excludedCause != nil, color: color)
    }
    .lineLimit(1)
    .padding(.horizontal, Tokens.Space.m)
    .padding(.vertical, Tokens.Space.s)
    .frame(minWidth: Tokens.Size.flowChip, alignment: .leading)
    .background(Palette.surfaceSunken, in: RoundedRectangle(cornerRadius: Tokens.Radius.medium))
    .overlay {
      RoundedRectangle(cornerRadius: Tokens.Radius.medium).strokeBorder(Palette.separator, lineWidth: Tokens.Stroke.thin)
    }
    .accessibilityElement(children: .combine)
  }

  /// The chip's hover help: why it was skipped and why its change is missing, if so.
  static func help(_ chip: FlowChipV1) -> String {
    [chip.excludedCause, chip.changeCause].compactMap { $0 }.joined(separator: Format.lineSeparator)
  }

  /// "gainers +21.3%"; "skipped" for a symbol the universe left out.
  private var detail: String {
    if chip.excludedCause != nil { return String(localized: L10n.Flow.chipSkipped) }
    let source = chip.sources.first.map { String(localized: $0.chipTitle) } ?? Format.missing
    // Without a change (its cause is on hover), the screener alone: never a bare "—%".
    guard let change = chip.changePct else { return source }
    return String(localized: L10n.Flow.chipChange(source, Money.signed(change.value, fractionDigits: FlowChip.changeDigits)))
  }

  /// Decimals of the change, as the design writes it ("+6.4%").
  static let changeDigits = 1

  private var color: Color {
    if chip.excludedCause != nil { return Palette.textQuaternary }
    switch chip.sources.first {
    case .gainers: return Palette.profitText
    case .losers: return Palette.seriesATRText
    case .topActives: return Palette.infoText
    case nil: return Palette.textTertiary
    }
  }
}

extension ScreenerSource {
  /// The screener as a chip names it, in the person's language.
  var chipTitle: LocalizedStringResource {
    switch self {
    case .gainers: L10n.Flow.chipGainers
    case .losers: L10n.Flow.chipLosers
    case .topActives: L10n.Flow.chipActives
    }
  }
}

/// The live flow's latest event on one still line under the card's title: its New York time,
/// its tag in its tone and what happened. A new event replaces the line; nothing scrolls. A recorded
/// day shows its last closed trade.
struct LatestEvent: View {
  @Environment(AppModel.self) private var model
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Accessibility id of the line, for the UI tests.
  static let id = "overview-latest-event"

  private struct Line: Hashable {
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

  var body: some View {
    // A new event fades in over the old one: one fade per real event, still in between.
    ZStack(alignment: .leading) {
      row.id(line).transition(.opacity)
    }
    .animation(reduceMotion ? nil : Tokens.Motion.standard, value: line)
    .font(Tokens.Typography.captionMono)
    .lineLimit(1)
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier(Self.id)
  }

  private var row: some View {
    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.m) {
      if let line {
        Text(L10n.Risk.clock(Format.marketTime(line.time))).foregroundStyle(Palette.textQuaternary)
        // The tag says what happened: it never gives way; the text is cut instead.
        Text(verbatim: line.tag).bold().textCase(.uppercase).foregroundStyle(line.color).fixedSize()
        Text(verbatim: line.text).foregroundStyle(Palette.textSecondary).truncationMode(.tail)
      } else {
        Text(verbatim: Format.missing).foregroundStyle(Palette.textQuaternary)
        Text(L10n.Flow.nothingYet).foregroundStyle(Palette.textTertiary)
      }
    }
  }
}

/// The symbols the strategy is closest to entering, with the check that decides each and how
/// close it is to passing: the closest few at a fixed height, and "Show all N ›" opening the full
/// list (`WatchingAllPanel`) over the Overview.
struct WatchingCard: View {
  @Environment(AppModel.self) private var model
  @Environment(\.openWatchingAll) private var openWatchingAll

  /// Accessibility id of the card, for the UI tests.
  static let id = "overview-watching"

  var body: some View {
    Card(L10n.Watching.title) {
      // What each row shows on the right, as in the design.
      Text(L10n.Watching.columns)
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(Palette.textQuaternary)
    } content: {
      if let watching = model.watching {
        if watching.rows.isEmpty {
          Footnote(L10n.Watching.none)
        } else {
          let rows = WatchingList.top(watching.rows)
          VStack(spacing: Tokens.Space.s) {
            // Each row opens the Chart on its symbol.
            // The rows rise one after another as the card shows them (a symbol the bot starts
            // watching rises as it arrives).
            ForEach(Array(rows.enumerated()), id: \.element.symbol) { index, row in
              ChartLink(row.symbol) { WatchingRow(row: row) }
                .rise(step: index)
            }
          }
          HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
            if WatchingList.hasMore(watching.rows) {
              MoreButton(L10n.Watching.showAll(watching.rows.count)) { openWatchingAll() }
            }
            Spacer(minLength: 0)
            // How many of all the watched symbols the card shows.
            if watching.total > rows.count {
              Footnote(L10n.Watching.closestOf(rows.count, watching.total))
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
struct WatchingRow: View {
  let row: WatchingRowV1
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      HStack(spacing: Tokens.Space.s) {
        Text(verbatim: row.symbol)
          .font(Tokens.Typography.chip)
          .foregroundStyle(Palette.textPrimary)
        VerdictTag(verdict: row.verdict)
        Spacer(minLength: 0)
        quoteAge
      }
      Group {
        if let check = row.decisiveCheck {
          // The check's name, then what it measured against what it needs, as in the design.
          // The name wraps in a narrow row; the figures stay whole beside it.
          HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
            Text(verbatim: ApiText.rule(check.rule))
              .font(Tokens.Typography.caption)
              .foregroundStyle(Palette.textTertiary)
              .frame(maxWidth: .infinity, alignment: .leading)
            Text(verbatim: check.valueText)
              .font(Tokens.Typography.captionMono)
              .foregroundStyle(Palette.textSecondary)
              .fixedSize()
          }
          .help(Text(verbatim: check.note))
        } else {
          Text(L10n.Watching.noCheck)
            .font(Tokens.Typography.captionMono)
            .foregroundStyle(Palette.textQuaternary)
        }
      }
      .fixedSize(horizontal: false, vertical: true)
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

  /// How old the quote was when the strategy decided, as the bot recorded it; a dash with the
  /// bot's cause when it has none. The decision's time is the tooltip.
  private var quoteAge: some View {
    let decided = Format.marketMinute(row.at.date)
    return Group {
      if let age = row.quoteAgeSeconds?.value {
        Text(L10n.Format.seconds(Money.plain(age, fractionDigits: WatchingRow.ageDigits)))
          .help(Text(L10n.Watching.quoteAgeHelp(decided)))
      } else {
        Text(verbatim: Format.missing)
          .help(Text(verbatim: [row.quoteAgeCause, String(localized: L10n.Watching.decidedAt(decided))]
            .compactMap { $0 }.joined(separator: Format.lineSeparator)))
      }
    }
    .font(Tokens.Typography.annotation)
    .foregroundStyle(Palette.textQuaternary)
  }

  /// Decimals of the quote's age, as the design writes it ("0.6 s").
  static let ageDigits = 1

  /// How close the deciding check is to passing, as a thin bar in the verdict's colour; empty
  /// with the cause as its tooltip when the bot cannot say.
  private var closeness: some View {
    let share = row.closeness.map { min(max(NSDecimalNumber(decimal: $0.value).doubleValue, 0), 1) }
    return GeometryReader { proxy in
      ZStack(alignment: .leading) {
        if let share {
          Capsule().fill(Palette.separator)
          Capsule().fill(row.verdict.watchingColor).frame(width: proxy.size.width * share)
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

/// A watched symbol's verdict as the design draws it: small mono capitals in an outline of the
/// verdict's colour, no fill.
private struct VerdictTag: View {
  let verdict: Verdict

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: Tokens.Radius.small, style: .continuous)
    Text(verdict.title)
      .textCase(.uppercase)
      .font(Tokens.Typography.badge)
      .lineLimit(1)
      .padding(.horizontal, Tokens.Space.xs)
      .padding(.vertical, Tokens.Space.xxs)
      .foregroundStyle(verdict.watchingColor)
      .overlay(shape.strokeBorder(verdict.watchingColor, lineWidth: Tokens.Stroke.thin))
      .fixedSize()
  }
}

extension Verdict {
  /// A watched symbol's colour, for its tag and its closeness bar: the decision's colour, with
  /// IGNORE in the design's pink rather than grey, so a symbol the strategy turned away reads apart
  /// from a quiet value.
  var watchingColor: Color {
    self == .ignore ? Palette.seriesATRText : color
  }
}

extension CheckV1 {
  /// "rule measured operator threshold" as the bot recorded them; a missing side is a dash.
  var comparisonText: String {
    "\(ApiText.rule(rule)) \(valueText)"
  }
}
