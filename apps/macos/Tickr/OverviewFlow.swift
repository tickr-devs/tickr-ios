import SwiftUI
import TickrDesign
import TickrKit

// The Overview's parts read from GET /flow, GET /watching and GET /movers: the screeners' chips
// above the pipeline, the symbols the strategy is watching closely, and the fast movers.

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
    case nil: return Reconcile(value: nil, note: latest?.agreementCauseText)
    }
  }

  /// How many symbols each stage of a funnel dropped of the one before it (`counts` in stage
  /// order): nil for the first, for a stage whose count or whose previous count is not known, and
  /// where nothing was dropped (a later read can count more than an earlier one).
  static func dropped(_ counts: [Int?]) -> [Int?] {
    counts.indices.map { index in
      guard index > 0, let before = counts[index - 1], let count = counts[index], before > count else { return nil }
      return before - count
    }
  }

  /// A recorded day's reconcile stage, from its clean-day verdict (the bot keeps only the latest
  /// reconciliation, so the day's flow has none): a mismatch the journal recorded, else a match
  /// when the day had reconciliation passes; unknown, with the cause, while the verdict is.
  static func reconcile(recorded clean: CleanDay) -> Reconcile {
    if clean.causes.contains(where: { $0.kind == .reconcileMismatch }) {
      return Reconcile(value: String(localized: L10n.Screener.mismatch), note: nil, agrees: false)
    }
    guard clean.verdict != .unknown, clean.reconcileRows > 0 else {
      return Reconcile(value: nil, note: ApiText.prose(clean.causeCodes, text: clean.cause))
    }
    return Reconcile(value: String(localized: L10n.Flow.match), note: nil, agrees: true)
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
      items: chips, moving: moving, leastChipWidth: Tokens.Size.flowChip, hint: { L10n.Common.openOnChart($0.symbol) },
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
      SymbolText(chip.symbol)
        .font(Tokens.Typography.chip)
        .foregroundStyle(Palette.textPrimary)
      Text(verbatim: detail)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(color)
        .strikethrough(chip.excludedCause != nil, color: color)
    }
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
    [chip.excludedCauseText, chip.changeCauseText].compactMap { $0 }.joined(separator: Format.lineSeparator)
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

/// The symbols the strategy is closest to entering, with the check that decides each and how
/// close it is to passing: as many of the closest as fill the card's grid cell (no gap under the
/// footer), and "Show all N ›" opening the full list (`WatchingAllPanel`) over the Overview.
struct WatchingCard: View {
  @Environment(AppModel.self) private var model
  @Environment(\.openWatchingAll) private var openWatchingAll
  /// Below the design's grid (MainNarrow v110) the card is as tall as its content: the closest
  /// `CardArrangement.wideColumns` rows, across the full-width card on the two-column board and
  /// one under another on the one-column board.
  @Environment(\.overviewLayout) private var layout

  /// Accessibility id of the card, for the UI tests.
  static let id = "overview-watching"
  /// Space between two rows.
  static let rowSpacing = Tokens.Space.s

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
          let ordered = WatchingList.sorted(watching.rows, by: .closest)
          if !layout.sized {
            // The design's grid: as many of the closest rows as fill the card's cell, then the
            // footer on its bottom edge.
            FittingRows(ordered, id: \.symbol, spacing: Self.rowSpacing, fallback: WatchingList.shown) { index, row in
              // Each row opens the Chart on its symbol; the rows rise one after another as the card
              // shows them (a symbol the bot starts watching rises as it arrives).
              ChartLink(row.symbol) { WatchingRow(row: row) }
                .rise(step: index)
            } footer: { shown in
              footer(watching, shown: shown)
            }
          } else {
            let rows = Array(ordered.prefix(CardArrangement.wideColumns))
            sizedRows(rows)
            footer(watching, shown: rows.count)
          }
        }
      } else if let error = model.watchingError {
        ReadFailureNote(L10n.Watching.unavailable(error), detail: nil)
      } else {
        Skeleton(L10n.Common.loading) { SkeletonRows(Tokens.Loading.fewRows, badge: true) }
      }
    }
    // The rows take the skeleton's place without rising (design-system "Loading").
    .loadsInPlace(model.watching != nil || model.watchingError != nil)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(Self.id)
  }

  /// "Show all N · closest 3 of N ›": the card's footer link, last in the card, as on the
  /// Controls board; without more rows, only how many of all the watched symbols it shows.
  @ViewBuilder
  private func footer(_ watching: WatchingV1, shown: Int) -> some View {
    let closest = watching.total > shown ? L10n.Watching.closestOf(shown, watching.total) : nil
    if WatchingList.hasMore(watching.rows, shown: shown) {
      CardFooterLink(L10n.Watching.showAll, count: watching.rows.count, hint: closest) { openWatchingAll() }
    } else if let closest {
      Footnote(closest)
    }
  }

  /// Below the design's grid: the rows as tall as they are, across or one under another.
  @ViewBuilder
  private func sizedRows(_ rows: [WatchingRowV1]) -> some View {
    let links = ForEach(Array(rows.enumerated()), id: \.element.symbol) { index, row in
      ChartLink(row.symbol) { WatchingRow(row: row) }
        .frame(maxWidth: .infinity)
        .rise(step: index)
    }
    if layout != .oneColumn {
      HStack(alignment: .top, spacing: Self.rowSpacing) { links }
    } else {
      VStack(spacing: Self.rowSpacing) { links }
    }
  }
}

/// One watched symbol as the design draws it: a sunken box with the symbol, its verdict tag and
/// the time on top, the deciding check and where it stands below (`WatchingCheck`), and a thin
/// bar of how far the measured value has come; without a measured distance, why instead of a bar.
struct WatchingRow: View {
  let row: WatchingRowV1
  @Environment(AppModel.self) private var model
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      HStack(spacing: Tokens.Space.s) {
        SymbolText(row.symbol)
          .font(Tokens.Typography.chip)
          .foregroundStyle(Palette.textPrimary)
        VerdictTag(verdict: row.verdict)
        Spacer(minLength: 0)
        // The symbol's live bid, as every other place shows it (the check below is the decision's
        // own measurement, once a minute).
        if let live = model.livePrice(row.symbol) {
          Text(verbatim: Money.price(live.bid))
            .font(Tokens.Typography.captionMono)
            .foregroundStyle(Palette.textPrimary)
            .contentTransition(.numericText())
            .help(Text(L10n.Position.bid))
        }
        quoteAge
      }
      Group {
        let state = WatchingCheck.state(row, prices: .money)
        if let check = row.decisiveCheck, let title = WatchingCheck.title(row) {
          // The check's name, then where the measured value stands against what it needs: side
          // by side when both fit on one line, else the figures under the name (a figure taking
          // the line left the name one letter wide).
          let name = Text(verbatim: title)
            .font(Tokens.Typography.caption)
            .foregroundStyle(Palette.textTertiary)
          let figures = Text(verbatim: state)
            .font(Tokens.Typography.captionMono)
            .foregroundStyle(Palette.textSecondary)
          ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
              name.frame(maxWidth: .infinity, alignment: .leading)
              figures
            }
            VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
              name
              figures
            }
          }
          .help(Text(verbatim: check.note))
        } else {
          // No failed check: what the record holds and lacks, in place of the check.
          Text(verbatim: state)
            .font(Tokens.Typography.captionMono)
            .foregroundStyle(Palette.textTertiary)
        }
      }
      .fixedSize(horizontal: false, vertical: true)
      if let share = WatchingCheck.progress(row) {
        closeness(share)
      } else if let cause = WatchingCheck.unmeasured(row) {
        Text(verbatim: cause)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
          .fixedSize(horizontal: false, vertical: true)
      }
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
          .help(Text(verbatim: [row.quoteAgeCauseText, String(localized: L10n.Watching.decidedAt(decided))]
            .compactMap { $0 }.joined(separator: Format.lineSeparator)))
      }
    }
    .font(Tokens.Typography.annotation)
    .foregroundStyle(Palette.textQuaternary)
  }

  /// Decimals of the quote's age, as the design writes it ("0.6 s").
  static let ageDigits = 1

  /// How far the measured value has come towards passing, as a thin bar in the verdict's colour;
  /// for a check against the trigger, from the invalidation (empty) to the trigger (full), which
  /// the tooltip names.
  private func closeness(_ share: Double) -> some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        Capsule().fill(Palette.separator)
        Capsule().fill(row.verdict.color).frame(width: proxy.size.width * share)
      }
    }
    .frame(height: Tokens.Size.barThin)
    .animation(reduceMotion ? nil : Tokens.Motion.fill, value: share)
    .help(WatchingCheck.scale(row, prices: .money).map { Text(verbatim: $0) } ?? Text(L10n.Watching.closeness))
    .accessibilityLabel(Text(L10n.Watching.closeness))
    .accessibilityValue(Text(share, format: .percent))
  }
}

/// A watched symbol's verdict as the design draws it: small mono capitals in an outline of the
/// verdict's colour, no fill.
struct VerdictTag: View {
  let verdict: Verdict

  var body: some View {
    Badge(verdict.title, color: verdict.color)
  }
}

extension CheckV1 {
  /// "rule measured operator threshold" as the bot recorded them; a missing side is a dash.
  var comparisonText: String {
    "\(ApiText.rule(rule)) \(valueText)"
  }
}

/// The day's fast movers (GET /movers): as many newest rows as fill the card (symbol, its one main
/// reason and the time; the rule behind the title's info button), then "Show all N ›" opening the
/// Symbols screen on its Fast movers tab. A new mover rises in as it arrives, a real event of the
/// bot.
struct FastMoversCard: View {
  @Environment(AppModel.self) private var model
  /// On the design's grid the card fills its cell with rows; below it the card is as tall as its
  /// content (`rowCap` rows).
  @Environment(\.overviewLayout) private var layout

  /// Rows the card shows below the design's grid, and on it until the rows are measured; the rest
  /// are on the Symbols screen.
  static let rowCap = 4
  /// Space between two rows.
  static let rowSpacing = Tokens.Space.xs
  /// Accessibility id of the card, for the UI tests.
  static let id = "overview-fast-movers"

  var body: some View {
    Card(L10n.FastMovers.title) {
      // The rule behind an info button (mockup Main): each row names its one main reason.
      if let rules = model.movers?.rules {
        MoverRuleButton(rule: SymbolsBoard.rules(rules))
      }
    } content: {
      if let movers = model.movers {
        if movers.movers.isEmpty {
          Footnote(verbatim: movers.rulesCauseText ?? String(localized: L10n.FastMovers.none))
        } else {
          if !layout.sized {
            // The design's grid: as many of the newest rows as fill the card's cell, then the
            // footer on its bottom edge.
            FittingRows(movers.movers, id: \.symbol, spacing: Self.rowSpacing, fallback: Self.rowCap) { index, mover in
              ChartLink(mover.symbol) { FastMoverRow(mover: mover, rules: movers.rules) }
                .rise(step: index)
            } footer: { _ in
              footer(movers)
            }
          } else {
            VStack(spacing: Self.rowSpacing) {
              ForEach(Array(movers.movers.prefix(Self.rowCap).enumerated()), id: \.element.symbol) { index, mover in
                ChartLink(mover.symbol) { FastMoverRow(mover: mover, rules: movers.rules) }
                  .rise(step: index)
              }
            }
            .animation(Tokens.Motion.standard, value: movers.movers.prefix(Self.rowCap).map(\.symbol))
            footer(movers)
          }
        }
      } else if let error = model.moversError {
        ReadFailureNote(L10n.FastMovers.unavailable(error), detail: nil)
      } else {
        Skeleton(L10n.Common.loading) { SkeletonRows(Self.rowCap) }
      }
    }
    .loadsInPlace(model.movers != nil || model.moversError != nil)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(Self.id)
  }

  /// "Show all N ›" on the card's bottom edge: the Symbols screen on its Fast movers tab.
  private func footer(_ movers: MoversV1) -> some View {
    CardFooterLink(L10n.FastMovers.showAll, count: movers.movers.count) {
      withAnimation(Tokens.Motion.standard) { model.symbolsTab = .fastMovers }
    }
  }
}

/// One fast mover on the Overview (mockup Main): the symbol, its one main reason (the signal
/// furthest past its rule, `SymbolsBoard.mainReason`) and the bar's time. Texts wrap, never cut.
private struct FastMoverRow: View {
  let mover: FastMoverV1
  let rules: FastMoverRulesV1?

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
      SymbolText(mover.symbol)
        .font(Tokens.Typography.chip)
        .foregroundStyle(Palette.textPrimary)
      Text(verbatim: SymbolsBoard.mainReason(mover, rules: rules))
        .font(Tokens.Typography.caption)
        .foregroundStyle(Palette.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
      Text(verbatim: Format.marketTime(mover.at.date))
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
    }
    .padding(Tokens.Space.s)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Palette.surfaceSunken, in: RoundedRectangle(cornerRadius: Tokens.Radius.medium))
    .accessibilityElement(children: .combine)
  }
}

/// The fast movers' rule behind an info button: a click opens it in a popover.
private struct MoverRuleButton: View {
  let rule: String
  @State private var open = false

  var body: some View {
    Button { open = true } label: {
      Image(systemName: InfoCaption.infoSymbol)
        .font(Tokens.Typography.caption)
        .foregroundStyle(Palette.textTertiary)
        .frame(minWidth: Tokens.Size.headerLink, minHeight: Tokens.Size.headerLink)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .linkPointer()
    .help(Text(L10n.FastMovers.ruleHint))
    .accessibilityLabel(Text(L10n.FastMovers.ruleHint))
    .popover(isPresented: $open, arrowEdge: .bottom) {
      VStack(alignment: .leading, spacing: Tokens.Space.s) {
        CardLabel(L10n.FastMovers.ruleHint)
        Text(verbatim: rule)
          .font(Tokens.Typography.callout)
          .foregroundStyle(Palette.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(Tokens.Space.l)
      .frame(idealWidth: Tokens.Size.popover, maxWidth: Tokens.Size.popover, alignment: .leading)
      .background(Palette.surface)
    }
  }
}

extension AppModel {
  /// The shown day's reconcile stage: live fences and the latest reconciliation today; a
  /// recorded day's clean-day verdict otherwise (its flow carries no reconciliation).
  var shownReconcile: FlowStages.Reconcile {
    if !isLive, let clean = days.first(where: { $0.day == shownDay })?.clean {
      return FlowStages.reconcile(recorded: clean)
    }
    return FlowStages.reconcile(liveFences: isLive ? status?.fences : nil, latest: flow?.reconcile)
  }
}
