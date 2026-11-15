import ApertureDesign
import ApertureKit
import SwiftUI

/// Strategy lab: the active strategy now, then every observer (a shadow version that never trades)
/// with the symbols it would have entered, how often the bot agreed and its simulated result.
/// Approving a version stays on the Mac.
struct LabView: View {
  /// Order in which the blocks rise in (`rise(step:)`).
  private enum Order: Int { case active = 1, observers, refusals, later }

  @Environment(AppModel.self) private var model
  @State private var lab = Container.shared.labModel()

  var body: some View {
    Screen(L10n.Lab.title) {
      ConnectionPrompt()
      if let status = model.status {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
          HStack {
            CardLabel(L10n.Lab.active)
            Spacer()
            Text(L10n.Lab.trades)
              .font(Tokens.Typography.annotation)
              .padding(.horizontal, Tokens.Space.s)
              .padding(.vertical, Tokens.Space.xxs)
              .foregroundStyle(Palette.accentText)
              .background(Palette.accent.opacity(Tokens.Opacity.glow),
                in: RoundedRectangle(cornerRadius: Tokens.Radius.small))
          }
          HStack(spacing: Tokens.Space.s) {
            PulseDot(Palette.accent)
            Text(L10n.Common.strategyVersion(status.strategy.name, status.strategy.version))
              .font(.subheadline.monospaced().weight(.semibold))
            Spacer()
            Text(verbatim: Money.signed(status.resultTodayGrossUsd.value))
              .font(.subheadline.monospaced().bold())
              .foregroundStyle(Palette.result(status.resultTodayGrossUsd.value))
          }
        }
        .padding(Tokens.Space.l)
        .apertureCard()
        .rise(step: Order.active.rawValue)

        ObserversCard(lab: lab, traded: Set(status.tradesToday.map(\.symbol) + status.positions.map(\.symbol)))
          .rise(step: Order.observers.rawValue)
        RefusalsCard(counts: lab.refusals, failure: lab.refusalsFailure)
          .rise(step: Order.refusals.rawValue)
        Text(L10n.Lab.later)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
          .rise(step: Order.later.rawValue)
      }
    }
    .task(id: sessionKey) { await load() }
    .refreshable {
      await model.refresh()
      await load()
    }
  }

  /// The address and the status's session; a change reads the observers again.
  private var sessionKey: [String] {
    [model.connection.url?.absoluteString, model.status.map { WireDate(newYorkDateOf: $0.writtenAt.date).text }]
      .compactMap { $0 }
  }

  private func load() async {
    guard let url = model.connection.url, let status = model.status else { return }
    await lab.load(url, day: WireDate(newYorkDateOf: status.writtenAt.date))
  }
}

/// Why the active strategy's signals were refused that day: one bar per cause, longest first.
private struct RefusalsCard: View {
  let counts: [RefusalCount]?
  let failure: String?

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      CardLabel(L10n.Lab.refusals)
      if let failure {
        Text(counts == nil ? L10n.Lab.refusalsFailed(failure) : L10n.Watching.stale(failure))
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.warningText)
      }
      if let counts {
        if counts.isEmpty {
          Text(L10n.Lab.noRefusals)
            .font(Tokens.Typography.callout)
            .foregroundStyle(Palette.textTertiary)
        }
        let most = Double(counts.first?.count ?? 1)
        ForEach(counts) { count in
          VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
            HStack(alignment: .firstTextBaseline) {
              Group {
                if let code = count.cause.known {
                  Text(L10n.Cause.title(code))
                } else {
                  Text(verbatim: count.cause.code)
                }
              }
              .font(Tokens.Typography.callout)
              .foregroundStyle(Palette.textSecondary)
              Spacer()
              Text(verbatim: String(count.count))
                .font(Tokens.Typography.calloutMono.bold())
                .foregroundStyle(Palette.textPrimary)
            }
            ProgressView(value: Double(count.count), total: most)
              .tint(Palette.warning)
              .accessibilityHidden(true)
          }
          .accessibilityElement(children: .combine)
        }
      } else if failure == nil {
        ProgressView().frame(maxWidth: .infinity)
      }
    }
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, alignment: .leading)
    .apertureCard()
  }
}

/// Each observer of the day: name and version, the symbols it would have entered, how many of
/// them the bot also traded, and its simulated result (or why there is none).
private struct ObserversCard: View {
  let lab: LabModel
  let traded: Set<String>

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      CardLabel(L10n.Lab.board)
      if let observers = lab.observers {
        // A failed refresh after a good read: the rows stay, marked as the last read.
        if let failure = lab.failure {
          Text(L10n.Lab.failed(failure))
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.warningText)
        }
        if observers.observers.isEmpty {
          Text(L10n.Lab.noObservers)
            .font(Tokens.Typography.callout)
            .foregroundStyle(Palette.textTertiary)
        }
        ForEach(observers.observers.map { ObserverSummary($0, traded: traded) }) { summary in
          ObserverRow(summary: summary)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
      } else if let failure = lab.failure {
        Text(L10n.Lab.failed(failure))
          .font(Tokens.Typography.callout)
          .foregroundStyle(Palette.warningText)
      } else {
        ProgressView().frame(maxWidth: .infinity)
      }
    }
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, alignment: .leading)
    .apertureCard()
  }
}

private struct ObserverRow: View {
  let summary: ObserverSummary

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      HStack(spacing: Tokens.Space.s) {
        Image(systemName: "eye").foregroundStyle(Palette.highlight)
        Text(L10n.Common.strategyVersion(summary.name, summary.version))
          .font(.subheadline.monospaced().weight(.semibold))
        Spacer()
        if let result = summary.result {
          Text(verbatim: Money.signed(result))
            .font(.subheadline.monospaced().bold())
            .foregroundStyle(Palette.result(result))
        } else {
          Text(L10n.Lab.noResult)
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textQuaternary)
        }
      }
      if summary.result == nil, let cause = summary.resultCause {
        Text(verbatim: cause)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      }
      if let agreement = summary.agreement {
        ProgressView(value: agreement)
          .tint(Palette.highlight)
        Text(L10n.Lab.agreement(summary.shared.count, summary.entered.count,
          summary.entered.joined(separator: Format.separator)))
          .font(Tokens.Typography.captionMono)
          .foregroundStyle(Palette.textTertiary)
      } else {
        Text(L10n.Lab.noEntries)
          .font(Tokens.Typography.captionMono)
          .foregroundStyle(Palette.textTertiary)
      }
    }
    .accessibilityElement(children: .combine)
  }
}
