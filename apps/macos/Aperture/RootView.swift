import ApertureDesign
import ApertureKit
import SwiftUI

/// Sidebar sections, ordered by how often they are used during a trading day.
enum AppSection: String, CaseIterable, Identifiable {
    case overview, chart, trades, risk, lab

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .chart: return "Chart"
        case .trades: return "Trades & days"
        case .risk: return "Risk & account"
        case .lab: return "Strategy lab"
        }
    }

    var symbol: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .chart: return "chart.xyaxis.line"
        case .trades: return "list.bullet.rectangle"
        case .risk: return "shield.lefthalf.filled"
        case .lab: return "sparkles"
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    private var section: AppSection { model.section }

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            Sidebar(selection: $model.section)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            ZStack(alignment: .bottom) {
                ApertureBackground()
                detail
                    .id(section)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                if let toast = model.toast {
                    CommandToast(command: toast)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.9), value: section)
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: model.toast)
            .navigationTitle(section.title)
            .navigationSubtitle(subtitle)
            .toolbar { DayToolbar() }
        }
    }

    @ViewBuilder private var detail: some View {
        switch section {
        case .overview: OverviewView()
        case .chart: ComingNext(section: .chart)
        case .trades: ComingNext(section: .trades)
        case .risk: ComingNext(section: .risk)
        case .lab: ComingNext(section: .lab)
        }
    }

    private var subtitle: String {
        let day = model.isLive ? "Today · \(Format.dayLabel(model.today))" : "Recorded day · \(Format.dayLabel(model.shownDay))"
        guard let status = model.status else { return day }
        return "\(day) · \(status.environment) · \(status.strategy.name) v\(status.strategy.version)"
    }
}

/// The sidebar list plus the bot's state at the bottom.
private struct Sidebar: View {
    @Environment(AppModel.self) private var model
    @Binding var selection: AppSection

    var body: some View {
        List(selection: Binding(get: { selection }, set: { if let value = $0 { selection = value } })) {
            Section("Operator") {
                ForEach(AppSection.allCases) { item in
                    Label(item.title, systemImage: item.symbol)
                        .badge(badge(for: item))
                        .tag(item)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) { BotStateCard().padding(12) }
    }

    private func badge(for item: AppSection) -> Int {
        item == .trades ? model.shownTradeCount : 0
    }
}

/// Bot state at the foot of the sidebar: a pulsing dot while it runs.
private struct BotStateCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CardLabel("Bot")
            HStack(spacing: 8) {
                PulseDot(color, pulsing: model.status?.botState == .running && model.isLive)
                Text(stateText).font(.callout.weight(.semibold)).foregroundStyle(color)
            }
            if let run = model.status?.runId {
                Text("run \(run.prefix(8))").font(.caption.monospaced()).foregroundStyle(Palette.dim)
            }
            Text(model.baseURL.host() ?? model.baseURL.absoluteString)
                .font(.caption.monospaced()).foregroundStyle(Palette.dim)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .apertureCard(radius: 12)
    }

    private var stateText: String {
        if model.fetchError != nil { return "API unreachable" }
        guard let response = model.response else { return "connecting…" }
        guard let status = response.status else { return "unavailable" }
        if response.stale { return "stale (\(status.botState.rawValue))" }
        return status.entryStop ? "\(status.botState.rawValue) · entries paused" : status.botState.rawValue
    }

    private var color: Color {
        guard let response = model.response, let status = response.status, !response.stale,
              model.fetchError == nil else { return Palette.redStrong }
        switch status.botState {
        case .running: return status.entryStop ? Palette.amberStrong : Palette.tealStrong
        case .starting, .stopping: return Palette.amberStrong
        case .stopped: return Palette.dim
        }
    }
}

/// Toolbar: ‹ day › with a menu of recorded days, and Today.
private struct DayToolbar: ToolbarContent {
    @Environment(AppModel.self) private var model

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button { model.showPreviousDay() } label: { Label("Previous Day", systemImage: "chevron.left") }
                .disabled(model.previousDay == nil)
                .help("Previous trading day (⌘[)")
            Menu {
                Button("Today") { model.showToday() }
                if !model.days.isEmpty { Divider() }
                ForEach(model.days.filter { $0.day != model.today }) { day in
                    Button("\(Format.dayLabel(day.day))   \(Money.signed(day.resultGrossUsd.value))   \(day.trades) trades") {
                        model.selectedDay = day.day
                    }
                }
            } label: {
                Text(model.isLive ? "Today · \(Format.dayLabel(model.today))" : Format.dayLabel(model.shownDay))
                    .font(.callout.monospaced())
            }
            .help("Pick a recorded trading day")
            Button { model.showNextDay() } label: { Label("Next Day", systemImage: "chevron.right") }
                .disabled(model.isLive)
                .help("Next trading day (⌘])")
        }
        ToolbarItem(placement: .primaryAction) {
            if !model.isLive {
                Button("Today") { model.showToday() }.help("Back to the live day (⌘T)")
            }
        }
    }
}

/// The result of a command the operator sent, shown at the bottom of the window.
struct CommandToast: View {
    let command: SentCommand

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(headline).font(.callout.weight(.semibold))
                if let detail { Text(detail).font(.caption).foregroundStyle(Palette.muted) }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.5)))
        .shadow(radius: 12, y: 6)
    }

    private var headline: String {
        switch command.outcome {
        case nil: return "\(command.title) queued for the bot"
        case .done: return "\(command.title): done"
        case .refused: return "\(command.title): refused"
        }
    }

    private var detail: String? {
        if let cause = command.cause { return cause }
        if let warning = command.warning { return "Warning: \(warning)" }
        return command.outcome == nil ? "The result appears here when the bot has handled it." : nil
    }

    private var symbol: String {
        switch command.outcome {
        case nil: return "clock.arrow.circlepath"
        case .done: return "checkmark.circle.fill"
        case .refused: return "xmark.octagon.fill"
        }
    }

    private var color: Color {
        switch command.outcome {
        case nil: return Palette.blueStrong
        case .done: return Palette.greenStrong
        case .refused: return Palette.redStrong
        }
    }
}

/// A section that arrives in the next update of the app.
struct ComingNext: View {
    let section: AppSection

    var body: some View {
        ContentUnavailableView {
            Label(section.title, systemImage: section.symbol)
        } description: {
            Text("This section is being rebuilt to the approved design and arrives in the next update.")
        }
    }
}
