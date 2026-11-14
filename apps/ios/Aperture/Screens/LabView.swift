import ApertureDesign
import ApertureKit
import SwiftUI

/// Strategy lab: the active strategy now; observer versions, replays and refusal counts arrive with
/// the API additions for them.
struct LabView: View {
  /// Order in which the blocks rise in (`rise(step:)`).
  private enum Order: Int { case active = 1, observers = 3 }

  @Environment(AppModel.self) private var model

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

        ContentUnavailableView {
          Label { Text(L10n.Lab.observers) } icon: { Image(systemName: "sparkles") }
        } description: {
          Text(L10n.Lab.observersBody)
        }
        .rise(step: Order.observers.rawValue)
      }
    }
  }
}
