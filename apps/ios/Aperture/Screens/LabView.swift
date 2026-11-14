import ApertureDesign
import ApertureKit
import SwiftUI

/// Strategy lab: the active strategy now; observer versions, replays and refusal counts arrive with
/// the API additions for them.
struct LabView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Screen("Strategy lab") {
            ConnectionPrompt()
            if let status = model.status {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        CardLabel("Active strategy")
                        Spacer()
                        Text("trades")
                            .font(.system(size: 10, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .foregroundStyle(Palette.tealStrong)
                            .background(Palette.teal.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
                    }
                    HStack(spacing: 8) {
                        PulseDot(Palette.teal)
                        Text("\(status.strategy.name) v\(status.strategy.version)")
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        Spacer()
                        Text(Money.signed(status.resultTodayGrossUsd.value))
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundStyle(Palette.result(status.resultTodayGrossUsd.value))
                    }
                }
                .padding(14)
                .apertureCard()
                .rise(0.05)

                ContentUnavailableView {
                    Label("Observers and replays", systemImage: "sparkles")
                } description: {
                    Text("How each observer version would have traded today, replays of past days and why signals "
                        + "were refused appear here once the bot's API publishes them. Approving a new version stays on the Mac.")
                }
                .rise(0.15)
            }
        }
    }
}
