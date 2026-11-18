import SwiftUI
import TickrDesign
import TickrKit

/// "Another strategy" on one closed trade: a strategy version picked here, replayed by the bot's
/// API on the trade's symbol and day (GET /trades/whatif), under what the bot did. Simulated and
/// read-only; the API refuses it during the session, and that reason is shown as sent.
struct AnotherStrategySheet: View {
  let activity: ActivityModel
  let url: URL
  let symbol: String
  let day: WireDate
  /// What the bot made: R per share (nil when its planned loss was zero) and USD.
  let botR: Decimal?
  let botUsd: Decimal

  @Environment(\.dismiss) private var dismiss
  /// The versions the bot can replay, once read.
  @State private var versions: Result<[LabVersionV1], WhatIfFailure>?
  @State private var version: String?
  @State private var answer: Result<TradeWhatIfV1, WhatIfFailure>?
  /// The version `answer` is of.
  @State private var answered: String?

  private var offered: [LabVersionV1] { (try? versions?.get()) ?? [] }
  /// The picked version while the bot offers it, else the first it offers.
  private var chosen: String? {
    if let version, offered.contains(where: { $0.folder == version }) { return version }
    return offered.first?.folder
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
          picker
          if chosen != nil { result }
          InfoCaption(L10n.Activity.anotherNote)
        }
        .padding(Tokens.Space.l)
      }
      .scrollEdgeHints()
      .background(Palette.background)
      .navigationTitle(Text(L10n.Activity.anotherTitle(symbol)))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(role: .close) { dismiss() }
        }
      }
    }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    .task { versions = await activity.replayableVersions(url) }
    .task(id: chosen) { await load() }
  }

  /// The versions as chips, or why there are none.
  @ViewBuilder private var picker: some View {
    switch versions {
    case nil:
      Skeleton(L10n.Common.loading) { SkeletonBlock(.pill, width: SkeletonRows.pill) }
    case .failure(let failure):
      ReadFailureNote(L10n.ReadFailed.versions, detail: failure.cause)
    case .success(let list) where list.isEmpty:
      InfoCaption(L10n.Activity.anotherNoVersions)
    case .success(let list):
      ChipFlow {
        ForEach(list, id: \.folder) { item in
          Button {
            version = item.folder
          } label: {
            Text(L10n.Lab.versionName(item.strategy ?? item.folder, item.version ?? Format.missing))
          }
          .buttonStyle(.chip(selected: item.folder == chosen, tone: .highlight))
        }
      }
    }
  }

  /// The answer for the chosen version only: another version's answer never shows under its chip.
  private var shown: Result<TradeWhatIfV1, WhatIfFailure>? {
    answered == chosen ? answer : nil
  }

  /// The bot's row, then the version's trades, its total and what became of its entries.
  private var result: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      line(Text(L10n.Activity.anotherBot).foregroundStyle(Palette.textSecondary), r: botR, usd: botUsd)
      switch shown {
      case nil:
        Skeleton(L10n.Common.loading) { SkeletonRows(Tokens.Loading.fewRows) }
      case .failure(let failure) where failure.refused:
        // Declined for now (the session is open), said as it is: not a failure.
        InfoCaption(verbatim: failure.cause)
      case .failure(let failure):
        ReadFailureNote(L10n.ReadFailed.whatIf, detail: failure.cause)
      case .success(let found):
        if let cause = found.causeText {
          InfoCaption(verbatim: cause)
        } else {
          ForEach(Array(found.trades.enumerated()), id: \.offset) { _, item in
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
              Text(L10n.Activity.anotherLeg(Format.time(item.openedAt.date), Format.time(item.closedAt.date),
                String(localized: ending(item.exitReason))))
                .foregroundStyle(Palette.textTertiary)
              Spacer(minLength: Tokens.Space.s)
              Text(verbatim: Risk.text(item.resultR.value, fractionDigits: StatDigits.r))
                .foregroundStyle(Palette.result(item.resultR.value))
            }
            .font(Tokens.Typography.captionMono)
          }
          Divider()
          line(Text(L10n.Lab.versionName(found.strategy ?? found.folder, found.version ?? Format.missing))
            .fontWeight(.semibold), r: found.resultR?.value, usd: found.resultGrossUsd?.value)
          if let signals = found.signals {
            Text(signals.filled + signals.missed + signals.rejected + signals.ignored == .zero
              ? L10n.Activity.anotherNoEntry
              : L10n.Activity.anotherSignals(signals.filled, signals.missed, signals.rejected, signals.ignored))
              .font(Tokens.Typography.caption)
              .foregroundStyle(Palette.textTertiary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
    }
    .padding(Tokens.Space.m)
    .tickrCard(radius: Tokens.Radius.card)
  }

  /// A title, then R and USD in the result's colour; a missing number reads as a dash.
  private func line(_ title: some View, r: Decimal?, usd: Decimal?) -> some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
        title
        Spacer(minLength: Tokens.Space.s)
        figures(r: r, usd: usd)
      }
      VStack(alignment: .leading, spacing: Tokens.Space.xs) {
        title
        HStack(spacing: Tokens.Space.s) { figures(r: r, usd: usd) }
      }
    }
    .font(Tokens.Typography.callout)
  }

  @ViewBuilder private func figures(r: Decimal?, usd: Decimal?) -> some View {
    Text(verbatim: r.map { Risk.text($0, fractionDigits: StatDigits.r) } ?? Format.missing)
      .font(Tokens.Typography.calloutMono.bold())
      .foregroundStyle(r.map { Palette.result($0) } ?? Palette.textQuaternary)
    Text(verbatim: usd.map { Money.signedUSD($0) } ?? Format.missing)
      .font(Tokens.Typography.calloutMono.bold())
      .foregroundStyle(usd.map { Palette.result($0) } ?? Palette.textQuaternary)
  }

  private func ending(_ reason: WhatIfExit) -> LocalizedStringResource {
    switch reason {
    case .stop: L10n.Activity.replayStop
    case .strategyExit: L10n.Activity.replayStrategyExit
    case .flatten: L10n.Activity.replayFlatten
    case .endOfData: L10n.Activity.replayEndOfData
    }
  }

  private func load() async {
    guard let chosen else { return }
    answer = nil
    let read = await activity.whatIf(url, symbol: symbol, day: day, version: chosen)
    guard !Task.isCancelled, chosen == self.chosen else { return }
    answer = read
    answered = chosen
  }
}
