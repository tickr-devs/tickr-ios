import ApertureDesign
import ApertureKit
import SwiftUI

/// The menu-bar extra: the bot's state, the day result, positions and the common controls,
/// without opening the main window.
struct MenuBarPanel: View {
  @Environment(AppModel.self) private var model
  @Environment(\.openWindow) private var openWindow

  /// Width of the menu-bar panel, in points.
  static let width: CGFloat = 360
  /// Lines the headline may wrap to.
  static let headlineLines = 2

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      HStack(spacing: Tokens.Space.m) {
        ApertureLogo(size: Tokens.Size.logoSmall)
        VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
          Text(verbatim: AppInfo.name).font(.headline)
          if let status = model.status {
            Text(verbatim: "\(status.environment) · \(Format.strategy(status.strategy))")
              .font(Tokens.Typography.captionMono).foregroundStyle(Palette.textQuaternary)
          }
        }
        Spacer()
        MoneyText(value: model.isLive ? model.shownResult : todayResult, usd: true,
          font: Tokens.Typography.bodyMono.weight(.bold))
      }
      HStack(spacing: Tokens.Space.s) {
        PulseDot(model.headline.severity.color, pulsing: model.headline.severity != .ok)
        Text(verbatim: model.headline.text).font(Tokens.Typography.callout.weight(.semibold))
          .foregroundStyle(model.headline.severity.color)
          .lineLimit(Self.headlineLines)
      }
      Divider()
      if let status = model.status, !Board.positions(status).isEmpty {
        ForEach(Board.positions(status), id: \.symbol) { position in
          HStack {
            Text(verbatim: position.symbol).font(Tokens.Typography.bodyMono.weight(.bold))
            Text(verbatim: "\(Format.quantity(position.quantity.value)) @ \(Format.price(position.entryPrice.value))")
              .font(Tokens.Typography.captionMono).foregroundStyle(Palette.textTertiary)
            Spacer()
            StopBadge(state: position.stop.state)
          }
        }
      } else {
        Text(L10n.Menu.noOpenPosition).font(Tokens.Typography.callout).foregroundStyle(Palette.textTertiary)
      }
      Divider()
      BotControls(compact: true)
      Divider()
      HStack {
        Button(String(localized: L10n.App.openApp)) {
          openWindow(id: WindowID.main)
          NSApplication.shared.activate()
        }
        Spacer()
        SettingsLink { Text(L10n.App.settings) }
        Button(String(localized: L10n.App.quit)) { NSApplication.shared.terminate(nil) }
      }
      .buttonStyle(.borderless)
    }
    .padding(Tokens.Space.l)
    .frame(width: Self.width)
  }

  /// The panel always shows today, even while the main window shows a recorded day.
  private var todayResult: Decimal {
    model.todayDocument?.resultGrossUsd.value ?? 0
  }
}
