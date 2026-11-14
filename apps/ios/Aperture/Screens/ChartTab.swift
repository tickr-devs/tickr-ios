import ApertureDesign
import ApertureKit
import SwiftUI

/// The full trading chart (candles, volume, VWAP/EMA, entry and stop levels, crosshair, zoom, day
/// picker) needs the bar data the bot's API is adding. Until then the tab says so.
struct ChartTab: View {
    @Environment(AppModel.self) private var model
    @State private var phase = false

    var body: some View {
        Screen("Chart") {
            ConnectionPrompt()
            if model.status != nil {
                VStack(spacing: 16) {
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(0..<14, id: \.self) { index in
                            let height = 24 + CGFloat((index * 37) % 60)
                            // A neutral skeleton, not price data.
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Palette.line2)
                                .frame(width: 10, height: phase ? height : height * 0.4)
                                .animation(.easeInOut(duration: 1.1).repeatForever().delay(Double(index) * 0.08), value: phase)
                        }
                    }
                    .frame(height: 90)
                    .accessibilityHidden(true)
                    ContentUnavailableView {
                        Label("Chart is on its way", systemImage: "chart.xyaxis.line")
                    } description: {
                        Text("Candles for the bot's symbols, with entry, stop and the bot's reasons, appear here once "
                            + "the bot's API serves captured bars.")
                    }
                }
                .padding(.top, 24)
                .rise()
                .onAppear { phase = true }
            }
        }
    }
}
