import SwiftUI
import TickrDesign
import TickrKit

/// One safety check of the Bot card, in plain words: its name, its value and its tone. It passes
/// unless its tone is a warning or a loss.
struct BotCheck: Identifiable {
  enum Kind: Hashable { case status, stops, entries, reconcile, stream, read, foreign }

  let id: Kind
  let label: LocalizedStringResource
  let value: String
  let tone: Tone
  /// The open positions' stops, for the stops check's symbol (the worst one's, never a fixed check).
  var stops: [StopState] = []

  var passes: Bool { tone != .warning && tone != .loss }

  /// Symbols of the checks.
  static let statusSymbol = "questionmark.circle"
  static let entriesSymbol = "paperplane"
  static let reconcileSymbol = "arrow.triangle.2.circlepath"
  static let streamSymbol = "waveform.path.ecg"
  static let readSymbol = "building.columns"
  static let foreignSymbol = "person.crop.circle.badge.questionmark"

  var symbol: String {
    switch id {
    case .status: Self.statusSymbol
    case .stops: StopState.combinedSymbol(stops)
    case .entries: Self.entriesSymbol
    case .reconcile: Self.reconcileSymbol
    case .stream: Self.streamSymbol
    case .read: Self.readSymbol
    case .foreign: Self.foreignSymbol
    }
  }
}

/// The Bot card's checks (mockup Main): one status line on the card, every check in its popover.
enum BotChecks {
  /// What the status line says: how many checks pass, and the one that leads when not all do
  /// (the first failing with a loss tone, else the first failing).
  struct Summary: Equatable {
    let passed: Int
    let total: Int
    let worst: BotCheck.Kind?
  }

  static func summary(_ checks: [BotCheck]) -> Summary {
    let worst = checks.first { $0.tone == .loss } ?? checks.first { !$0.passes }
    return Summary(passed: checks.filter(\.passes).count, total: checks.count, worst: worst?.id)
  }

  /// The six checks of a live status, in the design's order. The entry pause has none: Pause or
  /// Resume below shows it.
  static func checks(_ status: StatusV1, limits: BrokerReadAge.Limits?, now: Date) -> [BotCheck] {
    let positions = Board.positions(status)
    let verified = positions.filter { $0.stop.state.isProtected }.count
    // Positions or orders the bot did not place, in one check. A fence kind is its name, then ":"
    // and a key when it has one; ApiText reads the name into the generated FenceKind.
    let fenceKinds = Set(status.fences.compactMap { fence in
      ApiText.fenceKindCase(String(fence.kind.split(separator: Fence.keySeparator, maxSplits: 1).first ?? ""))
    })
    let foreign = !fenceKinds.isDisjoint(with: [.foreignPosition, .foreignOrder])
    let stream = status.freshness.stream
    let entries = positions.map { (symbol: $0.symbol, entry: $0.entry) }
      + status.tradesToday.map { (symbol: $0.symbol, entry: $0.entry) }
    let sent = EntrySent.summary(entries)
    let read = status.freshness.lastBrokerReadAt?.date
    return [
      BotCheck(id: .reconcile, label: L10n.Safety.reconciliation,
        value: status.fences.isEmpty
          ? String(localized: L10n.Safety.noFences) : String(localized: L10n.Common.fences(status.fences.count)),
        tone: status.fences.isEmpty ? .profit : .warning),
      BotCheck(id: .stops, label: L10n.Safety.brokerStops,
        value: positions.isEmpty
          ? String(localized: L10n.Common.noPosition) : String(localized: L10n.Safety.verified(verified, positions.count)),
        tone: StopState.combinedTone(positions.map(\.stop.state)), stops: positions.map(\.stop.state)),
      BotCheck(id: .entries, label: L10n.EntrySent.safetyRow,
        value: sent?.text ?? String(localized: L10n.Common.none), tone: sent?.tone ?? .neutral),
      BotCheck(id: .stream, label: L10n.Safety.quoteStream, value: stream.title,
        tone: stream == .fresh ? .profit : stream == .off ? .neutral : .warning),
      BotCheck(id: .read, label: L10n.Safety.lastBrokerRead, value: Format.age(since: read, now: now),
        tone: BrokerReadAge.tone(since: read, now: now, limits: limits)),
      BotCheck(id: .foreign, label: L10n.Safety.foreignAtBroker,
        value: String(localized: foreign ? L10n.Safety.present : L10n.Common.none),
        tone: foreign ? .loss : .profit),
    ]
  }

  /// How long the bot has been silent, short ("47 s", "2 min", "2 d").
  static func silence(since date: Date, now: Date) -> String {
    Elapsed.text(since: date, now: now)
  }
}

/// The Bot card's one big status line (mockup Main): "All checks pass", or the check that fails,
/// or "Bot not answering", with "Checks 6 of 6 · broker read 3 s ago" under it. A click opens
/// every check in plain words (`BotChecksPopover`). On a recorded day, or before a status, it is
/// a plain line: nothing to open.
struct BotStatusLine: View {
  @Environment(AppModel.self) private var model
  @State private var open = false

  /// Accessibility id of the line, for the UI tests.
  static let id = "overview-bot-checks"
  /// SF Symbol of the line when every check passes.
  static let passSymbol = "checkmark.circle"

  var body: some View {
    TimelineView(.periodic(from: .now, by: Tokens.Motion.clockTickSeconds)) { context in
      let now = model.botTime(context.date)
      if model.isLive, let status = model.status {
        let checks = BotChecks.checks(status, limits: BrokerReadAge.Limits(model.settings), now: now)
        Button { open = true } label: {
          face(checks, status: status, now: now)
        }
        .buttonStyle(.plain)
        .linkPointer()
        .accessibilityHint(Text(L10n.Bot.checksHint))
        .popover(isPresented: $open, arrowEdge: .bottom) {
          BotChecksPopover(checks: checks) {
            open = false
            model.section = .risk
          }
        }
      } else {
        plain(model.isLive ? L10n.Common.unavailable : L10n.Position.recordedDay)
      }
    }
    .accessibilityIdentifier(Self.id)
  }

  private func face(_ checks: [BotCheck], status: StatusV1, now: Date) -> some View {
    let summary = BotChecks.summary(checks)
    let worst = checks.first { $0.id == summary.worst }
    let silent = model.response?.stale == true
    let tone: Tone = silent ? .loss : worst?.tone ?? .profit
    let head = silent ? String(localized: L10n.Bot.notAnswering)
      : worst.map { [String(localized: $0.label), $0.value].joined(separator: Format.itemSeparator) }
        ?? String(localized: L10n.Bot.checksPass)
    let read = status.freshness.lastBrokerReadAt?.date
    let sub = read.map { L10n.Bot.checksCountRead(summary.passed, summary.total, Format.age(since: $0, now: now)) }
      ?? L10n.Bot.checksCount(summary.passed, summary.total)
    return HStack(spacing: Tokens.Space.m) {
      StateGlyph(silent ? BotCheck.readSymbol : worst?.symbol ?? Self.passSymbol, tone: tone,
        label: Text(verbatim: head))
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        Text(verbatim: head)
          .font(Tokens.Typography.figure)
          .foregroundStyle(silent || worst != nil ? tone.text : Palette.textPrimary)
          .fixedSize(horizontal: false, vertical: true)
        Text(sub)
          .font(Tokens.Typography.captionMono)
          .foregroundStyle(Palette.textTertiary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
      Chevron()
    }
    .padding(Tokens.Space.m)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Palette.surfaceSunken, in: RoundedRectangle(cornerRadius: Tokens.Radius.medium))
    .overlay {
      RoundedRectangle(cornerRadius: Tokens.Radius.medium).strokeBorder(Palette.separator, lineWidth: Tokens.Stroke.thin)
    }
    .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.medium))
    .accessibilityElement(children: .combine)
  }

  private func plain(_ text: LocalizedStringResource) -> some View {
    HStack(spacing: Tokens.Space.m) {
      StateGlyph(BotCheck.statusSymbol, tone: .neutral, label: text)
      Text(text).font(Tokens.Typography.figure).foregroundStyle(Palette.textTertiary)
      Spacer(minLength: 0)
    }
    .padding(Tokens.Space.m)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Palette.surfaceSunken, in: RoundedRectangle(cornerRadius: Tokens.Radius.medium))
    // Nothing was ever read: the outline, never "unavailable".
    .offlineOutline(lines: Tokens.Loading.fewLines)
  }
}

/// Every check of the Bot card in plain words, each with a dot in its tone, then Risk & account,
/// where their details are.
private struct BotChecksPopover: View {
  let checks: [BotCheck]
  let openRisk: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      CardLabel(L10n.Bot.checksTitle)
      Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Tokens.Space.m, verticalSpacing: Tokens.Space.s) {
        ForEach(checks) { check in
          GridRow {
            Circle().fill(check.tone.fill).frame(width: Tokens.Size.dotSmall, height: Tokens.Size.dotSmall)
              .accessibilityHidden(true)
            Text(check.label)
              .font(Tokens.Typography.callout)
              .foregroundStyle(Palette.textSecondary)
              .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: check.value)
              .font(Tokens.Typography.calloutMono)
              .foregroundStyle(check.passes ? Palette.textPrimary : check.tone.text)
              .fixedSize(horizontal: false, vertical: true)
              .gridColumnAlignment(.trailing)
          }
          .accessibilityElement(children: .combine)
        }
      }
      HeaderLink(L10n.RiskRoom.details, action: openRisk)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .padding(Tokens.Space.l)
    .frame(idealWidth: Tokens.Size.popover, maxWidth: Tokens.Size.popover, alignment: .leading)
    .background(Palette.surface)
  }
}

/// The bot's state as a pill, in the Bot card's header: "no answer · 47 s" while its status is stale.
struct BotPill: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    if let status = model.status {
      if model.isLive, let calm = model.botRun?.shortText {
        // Off by the schedule (mockup v190, page p-off): grey, never "no answer".
        StatusPill(verbatim: calm, tone: .neutral)
      } else if model.isLive, model.response?.stale == true {
        TimelineView(.periodic(from: .now, by: Tokens.Motion.clockTickSeconds)) { context in
          StatusPill(L10n.Bot.noAnswer(BotChecks.silence(since: status.writtenAt.date, now: model.botTime(context.date))),
            tone: .loss)
        }
      } else {
        let running = status.botState == .running
        let isCurrent = model.isLive && model.fetchError == nil && model.response?.stale == false
        StatusPill(verbatim: status.entryStop ? String(localized: L10n.Common.entriesPaused) : status.botState.title,
          tone: status.entryStop ? .warning : running ? .accent : .neutral,
          live: running && isCurrent, event: [AnyHashable(status.botState), AnyHashable(status.entryStop)])
      }
    }
  }
}
