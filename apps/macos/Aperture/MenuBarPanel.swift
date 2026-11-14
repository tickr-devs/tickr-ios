import ApertureDesign
import ApertureKit
import SwiftUI

/// The menu-bar extra: the bot's state, the day result, positions and the common controls,
/// without opening the main window.
struct MenuBarPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ApertureLogo(size: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Aperture").font(.headline)
                    if let status = model.status {
                        Text("\(status.environment) · \(status.strategy.name) v\(status.strategy.version)")
                            .font(.caption.monospaced()).foregroundStyle(Palette.dim)
                    }
                }
                Spacer()
                MoneyText(value: model.isLive ? model.shownResult : todayResult, usd: true, size: 17, weight: .bold)
            }
            HStack(spacing: 8) {
                PulseDot(model.headline.severity.color, size: 8, pulsing: model.headline.severity != .ok)
                Text(model.headline.text).font(.callout.weight(.semibold))
                    .foregroundStyle(model.headline.severity.color)
                    .lineLimit(2)
            }
            Divider()
            if let status = model.status, !Board.positions(status).isEmpty {
                ForEach(Board.positions(status), id: \.symbol) { position in
                    HStack {
                        Text(position.symbol).font(.body.monospaced().weight(.bold))
                        Text("\(Format.quantity(position.quantity.value)) @ \(Format.price(position.entryPrice.value))")
                            .font(.caption.monospaced()).foregroundStyle(Palette.muted)
                        Spacer()
                        StopBadge(state: position.stop.state)
                    }
                }
            } else {
                Text("No open position").font(.callout).foregroundStyle(Palette.muted)
            }
            Divider()
            BotControls(compact: true)
            Divider()
            HStack {
                Button("Open Aperture") {
                    openWindow(id: WindowID.main)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
                Spacer()
                SettingsLink { Text("Settings…") }
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .frame(width: 360)
    }

    /// The panel always shows today, even while the main window shows a recorded day.
    private var todayResult: Decimal {
        model.todayDocument?.resultGrossUsd.value ?? 0
    }
}
